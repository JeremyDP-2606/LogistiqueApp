import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:wabap/provider/auth_provider.dart';
import 'package:wabap/provider/colis_tournee_provider.dart';
import 'package:wabap/widgets/item_colis_tournee.dart';



class DamageReportView extends ConsumerStatefulWidget {
  final void Function() onNext;
  final void Function() onPrevious;
  final bool isDeliveringPhase;

  const DamageReportView({
    super.key,
    required this.onNext,
    required this.onPrevious,
    required this.isDeliveringPhase,
  });

  @override
  ConsumerState<DamageReportView> createState() => _DamageReportViewState();
}

class _DamageReportViewState extends ConsumerState<DamageReportView> {
  late final ValueNotifier<bool> isLoading;
  late final ValueNotifier<String?> errorMessage;

  @override
  void initState() {
    super.initState();
    isLoading = ValueNotifier<bool>(false);
    errorMessage = ValueNotifier<String?>(null);
  }

  @override
  void dispose() {
    isLoading.dispose();
    errorMessage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scannedCount = widget.isDeliveringPhase
        ? ref.watch(colisInTourneeDeliveryPhaseProvider).where((item) => item.isScanned).length
        : ref.watch(colisInTourneeProvider).where((item) => item.isScanned).length;
    return Column(
      children: [
        const Divider(color: Colors.white, height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            ),
          child: Column(
            children: [
              const Text(
                "Signalement des dommages",
                style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Nb de colis scannés : $scannedCount",
                style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        const Divider(thickness: 4, height: 10),
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 15.0),
                itemCount: widget.isDeliveringPhase
                    ? ref.watch(colisInTourneeDeliveryPhaseProvider).length
                    : ref.watch(colisInTourneeProvider).length,
                itemBuilder: (context, index) {
                  final colisInTournee = widget.isDeliveringPhase
                      ? ref.watch(colisInTourneeDeliveryPhaseProvider)[index]
                      : ref.watch(colisInTourneeProvider)[index];
                  return ColisInTourneeItem(
                    colisInTournee: colisInTournee,
                    staticItem: false,
                    isDeliveringPhase: widget.isDeliveringPhase,
                  );
                },
                separatorBuilder: (context, index) => const Divider(height: 0.5),
              ),
            ),
          ),
        ),
        const Divider(thickness: 4, height: 30),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  ValueListenableBuilder<String?>(
                    valueListenable: errorMessage,
                    builder: (context, error, _) {
                      if (error != null) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            error,
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: widget.onPrevious,
                          child: const Text("Retour"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ValueListenableBuilder<bool>(
                          valueListenable: isLoading,
                          builder: (context, loading, _) {
                            return ElevatedButton(
                              onPressed: loading ? null : widget.onNext,
                              child: loading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text("Suivant"),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
