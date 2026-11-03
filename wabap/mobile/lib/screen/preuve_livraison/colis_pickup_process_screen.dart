import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wabap/provider/auth_provider.dart';
import 'colis_pickup_scanner_view.dart';
import 'damage_report_view.dart';
import 'signature_view.dart';
import 'package:wabap/provider/colis_tournee_provider.dart';
import 'package:wabap/provider/colis_provider.dart';
import 'package:wabap/models/Colis.dart';
import 'package:wabap/models/Tournee.dart';


class PackageProcessScreen extends ConsumerStatefulWidget {
  final String tourneeId;
  final Tournee? tournee;
  final bool isDeliveringPhase;
  final List<Colis>? listColisToDeliver;

  const PackageProcessScreen({super.key, required this.tourneeId, required this.isDeliveringPhase,
    this.listColisToDeliver, this.tournee,
  });

  @override
  PackageProcessScreenState createState() => PackageProcessScreenState();
}

class PackageProcessScreenState extends ConsumerState<PackageProcessScreen> {
  int currentStep = 1;
  late String titlePage;
  bool isLoading = true;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    titlePage = widget.isDeliveringPhase ? "Livraison des colis" : "Récupération des colis";

    if(!widget.isDeliveringPhase){
      Future.microtask(() async {
        ref.read(colisInTourneeProvider.notifier).state = [];
        await ref.read(colisProvider(widget.tourneeId).notifier).loadAllColisInTournee();
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      });
    } else {
      Future.microtask(() {
        ref
            .read(colisInTourneeDeliveryPhaseProvider.notifier)
            .setColisList(widget.listColisToDeliver ?? []);
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      });
    }
  }

  void _nextStep() {
    setState(() {
      currentStep++;
    });
  }

  void _previousStep() {
    setState(() {
      currentStep--;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authProvider).myId;

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text("User authentication required!")),
      );
    }

    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(titlePage)),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Chargement des colis..."),
            ],
          ),
        ),
      );
    }

    return Scaffold(
        appBar: AppBar(title: Text(titlePage)),
        body: currentStep == 1
            ? ScannerView(onNext: _nextStep,isDeliveringPhase: widget.isDeliveringPhase)
            : currentStep == 2
            ? DamageReportView(onNext: _nextStep, onPrevious: _previousStep,isDeliveringPhase: widget.isDeliveringPhase)
            : SignatureView(
          onPrevious: _previousStep, isDeliveringPhase: widget.isDeliveringPhase, isColisStatic : true, tournee: widget.tournee
        ),
    );
  }
}
