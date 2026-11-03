import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wabap/models/Colis.dart';

// Model for a Colis in Tournee
class ColisInTournee {
  final Colis colis;
  String damaged;
  File? image;
  File? imgSignature;
  bool isScanned;
  bool isValidatedByGPS;

  ColisInTournee({
    required this.colis,
    this.damaged = "",
    this.image,
    this.isScanned = false,
    this.isValidatedByGPS = false,
  });

  // Method to create a copy with updated fields
  ColisInTournee copyWith({
    String? damaged,
    File? image,
    bool? isScanned,
    bool? isValidatedByGPS,
  }) {
    return ColisInTournee(
      colis: colis,
      damaged: damaged ?? this.damaged,
      image: image ?? this.image,
      isScanned: isScanned ?? this.isScanned,
      isValidatedByGPS: isValidatedByGPS ?? this.isValidatedByGPS,
    );
  }
}

// Notifier to manage the list of ColisInTournee
class ColisInTourneeNotifier extends StateNotifier<List<ColisInTournee>> {
  ColisInTourneeNotifier() : super([]);

  // Initialize the list with data
  void setColisInTourneeList(List<ColisInTournee> list){
    state = list;
  }

  void setColisList(List<Colis> list){
    List<ColisInTournee> listColisInTournee = [];
    for(int i = 0; i < list.length; i++){
      listColisInTournee.add( ColisInTournee( colis: list[i], damaged:"") );
    }
    state = listColisInTournee;
  }

  // Update a specific ColisInTournee
  void updateColis(ColisInTournee updatedColis) {
    state = state.map((colis) {
      return colis.colis.id == updatedColis.colis.id ? updatedColis : colis;
    }).toList();
  }

  // ✅ New method to update multiple colis at once
  void updateColisInTournee(List<ColisInTournee> updatedList) {
    state = updatedList;
  }
}

final colisInTourneeProvider =
StateNotifierProvider<ColisInTourneeNotifier, List<ColisInTournee>>(
      (ref) => ColisInTourneeNotifier(),
);

final colisInTourneeDeliveryPhaseProvider =
StateNotifierProvider<ColisInTourneeNotifier, List<ColisInTournee>>(
      (ref) => ColisInTourneeNotifier(),
);
