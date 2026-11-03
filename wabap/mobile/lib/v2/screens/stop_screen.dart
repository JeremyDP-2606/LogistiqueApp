import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:signature/signature.dart';

import '../../colors.dart';
import '../common.dart';
import '../platform_api.dart';
import '../platform_models.dart';
import '../demo_hooks.dart';
import '../proof_upload.dart';

/// Collecte ou livraison d'un point (spec §5) : la validation n'est possible que lorsque
/// toutes les preuves exigées sont fournies. Renvoie true si le point a été traité.
class StopScreen extends StatefulWidget {
  final String tourId;
  final TourStop stop;
  final List<CommentPresetItem> presets;
  const StopScreen({super.key, required this.tourId, required this.stop, required this.presets});
  @override
  State<StopScreen> createState() => _StopScreenState();
}

class _StopScreenState extends State<StopScreen> {
  late final Set<String> _handled = widget.stop.parcels.map((p) => p.id).toSet();
  final Map<String, String> _scanned = {}; // parcelId → code
  final List<String> _extraCodes = []; // étiquettes en réserve scannées à la collecte
  final List<String> _photoKeys = [];
  String? _signatureKey;
  final _signer = TextEditingController();
  final _otp = TextEditingController();
  final _comment = TextEditingController();
  String? _presetId;
  Position? _position;
  bool _busy = false;

  Requirements get _req => widget.stop.requirements;
  String get _kind => widget.stop.isPickup ? 'PICKUP' : 'DELIVERY';

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    try {
      final p = await Geolocator.getCurrentPosition();
      if (mounted) setState(() => _position = p);
    } catch (_) {}
  }

  List<String> get _missing {
    final m = <String>[];
    final toScan = _req.scanParcelIds.where(_handled.contains).where((id) => !_scanned.containsKey(id));
    if (toScan.isNotEmpty) m.add('${toScan.length} scan(s)');
    if (_req.photo && _photoKeys.isEmpty) m.add('photo');
    if (_req.signature && (_signatureKey == null || _signer.text.trim().isEmpty)) m.add('signature avec nom');
    if (_req.geoloc && _position == null) m.add('position GPS');
    if (_req.otp && _otp.text.trim().length < 4) m.add('code de confirmation');
    if (_handled.isEmpty) m.add('au moins un colis');
    return m;
  }

  Future<void> _scan() async {
    final code = DemoHooks.scan != null
        ? await DemoHooks.scan!(widget.stop, _scanned.keys.toSet())
        : await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const _ScanPage()));
    if (code == null) return;
    try {
      // Contrôle serveur : signature, client du point, colis attendu ou étiquette en réserve
      final r = await PlatformApi.scan(widget.tourId, widget.stop.id, code);
      setState(() {
        if (r.reserved) {
          if (!_extraCodes.contains(code)) _extraCodes.add(code);
        } else {
          _scanned[r.parcelId] = code;
          _handled.add(r.parcelId);
        }
      });
      if (mounted) showInfo(context, r.reserved ? 'Étiquette en réserve ajoutée comme nouveau colis' : 'Colis reconnu');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<String?> _takePhoto(String kind) async {
    final Uint8List? data;
    if (DemoHooks.takePhoto != null) {
      data = await DemoHooks.takePhoto!();
    } else {
      final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 60, maxWidth: 1600);
      data = x == null ? null : await x.readAsBytes();
    }
    if (data == null) return null;
    setState(() => _busy = true);
    try {
      return await ProofUpload.bytes(data, tourId: widget.tourId, kind: kind);
    } catch (e) {
      if (mounted) showError(context, 'Envoi de la photo impossible : $e');
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sign() async {
    final bytes = await Navigator.of(context).push<List<int>>(MaterialPageRoute(builder: (_) => const _SignaturePage()));
    if (bytes == null) return;
    setState(() => _busy = true);
    try {
      final key = await ProofUpload.bytes(Uint8List.fromList(bytes), tourId: widget.tourId, kind: 'signature', ext: 'png');
      setState(() => _signatureKey = key);
    } catch (e) {
      if (mounted) showError(context, 'Envoi de la signature impossible : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await PlatformApi.submitStop({
        'stopId': widget.stop.id,
        'parcelIds': _handled.toList(),
        'scannedCodes': [..._scanned.values, ..._extraCodes],
        'proofs': {
          'photoKeys': _photoKeys,
          if (_signatureKey != null) 'signatureKey': _signatureKey,
          if (_signer.text.trim().isNotEmpty) 'signerName': _signer.text.trim(),
          if (_otp.text.trim().isNotEmpty) 'otpCode': _otp.text.trim(),
        },
        if (_position != null) 'position': {'latitude': _position!.latitude, 'longitude': _position!.longitude},
        if (_presetId != null || _comment.text.trim().isNotEmpty) 'comment': {'presetId': _presetId, 'text': _comment.text.trim()},
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _fail() async {
    final failures = widget.presets.where((p) => p.kind == 'FAILURE').toList();
    String? presetId;
    String? photoKey;
    final text = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setSt) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(c).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Signaler un échec', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...failures.map((p) => RadioListTile<String>(
                  dense: true,
                  value: p.id,
                  groupValue: presetId, // ignore: deprecated_member_use
                  title: Text(p.label),
                  onChanged: (v) => setSt(() => presetId = v), // ignore: deprecated_member_use
                )),
            TextField(controller: text, decoration: const InputDecoration(labelText: 'Précision (interne, facultatif)')),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final k = await _takePhoto('echec');
                if (k != null) setSt(() => photoKey = k);
              },
              icon: Icon(photoKey == null ? Icons.photo_camera : Icons.check_circle, color: photoKey == null ? null : C.ok),
              label: Text(photoKey == null ? 'Photo obligatoire' : 'Photo ajoutée'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: C.error, minimumSize: const Size.fromHeight(48)),
              onPressed: presetId == null || photoKey == null ? null : () => Navigator.pop(c, true),
              child: const Text('Confirmer l’échec'),
            ),
          ]),
        ),
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await PlatformApi.failStop({
        'stopId': widget.stop.id,
        'comment': {'presetId': presetId, 'text': text.text.trim()},
        'proofs': {'photoKeys': [photoKey]},
        if (_position != null) 'position': {'latitude': _position!.latitude, 'longitude': _position!.longitude},
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _proofTile({required IconData icon, required String label, required bool done, String? detail, VoidCallback? onTap}) => Card(
        color: C.white,
        child: ListTile(
          leading: Icon(done ? Icons.check_circle : icon, color: done ? C.ok : C.secondary),
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: detail == null ? null : Text(detail),
          trailing: onTap == null ? null : const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = widget.stop;
    final missing = _missing;
    final presets = widget.presets.where((p) => p.kind == _kind).toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F2),
      appBar: AppBar(backgroundColor: s.isPickup ? C.blue : C.ok, foregroundColor: C.white, title: Text('${s.isPickup ? 'Collecte' : 'Livraison'} · point ${s.sequence}')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (s.place.name != null) Text(s.place.name!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          Text(s.place.formatted),
          if (s.place.instructions != null) Text(s.place.instructions!, style: const TextStyle(color: C.textColor)),
          const SizedBox(height: 12),
          const Text('Colis', style: TextStyle(fontWeight: FontWeight.w700)),
          ...s.parcels.map((p) => CheckboxListTile(
                dense: true,
                value: _handled.contains(p.id),
                onChanged: _req.scanParcelIds.contains(p.id) ? null : (v) => setState(() => v == true ? _handled.add(p.id) : _handled.remove(p.id)),
                title: Text('Colis ${p.index ?? ''}/${p.total ?? ''}'),
                subtitle: Text(_req.scanParcelIds.contains(p.id) ? (_scanned.containsKey(p.id) ? 'Scanné' : 'Scan obligatoire') : p.id),
                secondary: Icon(_scanned.containsKey(p.id) ? Icons.qr_code_2 : Icons.inventory_2_outlined, color: _scanned.containsKey(p.id) ? C.ok : C.textColor),
              )),
          if (_extraCodes.isNotEmpty) Text('${_extraCodes.length} étiquette(s) en réserve ajoutée(s)', style: const TextStyle(color: C.ok)),
          OutlinedButton.icon(onPressed: _scan, icon: const Icon(Icons.qr_code_scanner), label: const Text('Scanner un colis')),
          const SizedBox(height: 12),
          if (_req.any) const Text('Preuves exigées', style: TextStyle(fontWeight: FontWeight.w700)),
          if (_req.photo)
            _proofTile(
              icon: Icons.photo_camera,
              label: 'Photo',
              done: _photoKeys.isNotEmpty,
              detail: _photoKeys.isEmpty ? 'Colis ou lieu de dépôt' : '${_photoKeys.length} photo(s)',
              onTap: () async {
                final k = await _takePhoto('photo');
                if (k != null) setState(() => _photoKeys.add(k));
              },
            ),
          if (_req.signature) ...[
            _proofTile(icon: Icons.draw, label: 'Signature', done: _signatureKey != null, onTap: _sign),
            TextField(controller: _signer, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Nom du signataire')),
          ],
          if (_req.geoloc)
            _proofTile(icon: Icons.my_location, label: 'Position GPS', done: _position != null,
                detail: _position == null ? 'Recherche…' : 'Précision ${_position!.accuracy.round()} m', onTap: _locate),
          if (_req.otp)
            TextField(
              controller: _otp,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(labelText: 'Code de confirmation du destinataire'),
            ),
          const SizedBox(height: 12),
          const Text('Commentaire (facultatif)', style: TextStyle(fontWeight: FontWeight.w700)),
          Wrap(
            spacing: 8,
            children: presets
                .map((p) => ChoiceChip(
                      label: Text(p.label),
                      selected: _presetId == p.id,
                      onSelected: (v) => setState(() => _presetId = v ? p.id : null),
                    ))
                .toList(),
          ),
          TextField(controller: _comment, decoration: const InputDecoration(labelText: 'Texte libre (interne)')),
          const SizedBox(height: 16),
          TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: C.error),
              onPressed: _fail,
              icon: const Icon(Icons.report_problem_outlined),
              label: Text(s.isPickup ? 'Collecte impossible' : 'Livraison impossible'),
            ),
          const SizedBox(height: 80),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: C.primary, minimumSize: const Size.fromHeight(52)),
            onPressed: missing.isNotEmpty || _busy ? null : _submit,
            icon: const Icon(Icons.check),
            label: Text(missing.isEmpty ? 'Valider ${s.isPickup ? 'la collecte' : 'la livraison'}' : 'Manque : ${missing.join(', ')}'),
          ),
        ),
      ),
    );
  }
}

class _ScanPage extends StatefulWidget {
  const _ScanPage();
  @override
  State<_ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<_ScanPage> {
  bool _done = false;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Scanner l’étiquette')),
        body: MobileScanner(
          onDetect: (capture) {
            final code = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
            if (code == null || _done) return;
            _done = true;
            Navigator.of(context).pop(code);
          },
        ),
      );
}

class _SignaturePage extends StatefulWidget {
  const _SignaturePage();
  @override
  State<_SignaturePage> createState() => _SignaturePageState();
}

class _SignaturePageState extends State<_SignaturePage> {
  final _controller = SignatureController(penStrokeWidth: 3, penColor: Colors.black, exportBackgroundColor: Colors.white);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Signature du destinataire'), actions: [
          IconButton(onPressed: _controller.clear, icon: const Icon(Icons.refresh), tooltip: 'Effacer'),
        ]),
        body: Column(children: [
          Expanded(child: Signature(controller: _controller, backgroundColor: Colors.white)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: C.primary, minimumSize: const Size.fromHeight(50)),
                onPressed: () async {
                  if (_controller.isEmpty) return;
                  final png = await _controller.toPngBytes();
                  if (context.mounted) Navigator.of(context).pop(png?.toList());
                },
                child: const Text('Valider la signature'),
              ),
            ),
          ),
        ]),
      );
}
