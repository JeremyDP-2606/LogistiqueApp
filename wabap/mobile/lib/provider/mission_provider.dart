import 'package:wabap/backend/backend.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wabap/models/Inscription.dart';
import 'package:wabap/provider/api_providers.dart';

import '../models/Mission.dart';

class MissionNotifier extends StateNotifier<AsyncValue<List<Mission>>> {
  MissionNotifier() : super(const AsyncValue.loading());

  String? nextToken;
  List<Mission> cache = [];

  Future<void> reloadMission() async {
    loadMission(force: true);
    state = const AsyncValue.loading();
  }

  Future<void> loadMission({force = false}) async {
    try {
      safePrint(">>>> missionProvider : loadMission() hasValue=[${state.hasValue}] - force=[$force]");
      if (state.hasValue && !force) {
        state = state.asData!;
      } else {
        PaginationResponse<Mission> rep = await API.loadMissions();
        nextToken = rep.nextToken;
        cache = rep.list;
        safePrint(">>>> loadMission : rep=[$rep]");
        state = AsyncValue.data(cache);
      }
    } catch (error, stack) {
      safePrint(">>>> loadMission ERROR : error=[$error] - stack=[$stack]");
      state = AsyncValue.error(error, stack);
    }
  }

  Future<void> loadMoreMission() async {
    safePrint(">>>> missionProvider : loadMoreMission() hasValue=[${state.hasValue}]");
    if (isMoreMission()) {
      try {
        PaginationResponse<Mission> rep = await API.loadMissions(nextToken);
        nextToken = rep.nextToken;
        cache.addAll(rep.list);
        safePrint(">>>> loadMoreTournee : rep=[$rep]");
        state = AsyncValue.data(cache);
      } catch (error, stack) {
        safePrint(">>>> loadMoreTournee ERROR : error=[$error] - stack=[$stack]");
        state = AsyncValue.error(error, stack);
      }
    }
  }

  bool isMoreMission() {
    return nextToken != null;
  }

  Mission? getMission(String missionId) {
    try {
      return state.asData?.value.firstWhere((m) => m.id == missionId);
    } catch (e) {
      safePrint(">>>> getMission ERROR : e=[$e]");
    }
    return null;
  }

  Inscription? getInscription(String missionId, String userId) {
    try {
      return getMission(missionId)?.inscriptions?.firstWhere((i) => i.livreurID == userId);
    } catch (e) {
      safePrint(">>>> getInscription ERROR : e=[$e]");
    }
    return null;
  }

  Future<void> addInscrption(Inscription inscription) async {
    safePrint(">>>> missionProvider : addInscrption($inscription)");
    try {
      final mission = getMission(inscription.mission!.id);
      if (mission == null) throw Exception("Mission null");
      final inscriptions = mission.inscriptions ?? [];
      inscriptions.add(inscription);
      final newMission = mission.copyWith(inscriptions: inscriptions);
      final newListMission = state.asData?.value.map((mission) {
        if (mission.id == newMission.id) return newMission;
        return mission;
      }).toList();
      if (newListMission != null) {
        state = AsyncValue.data(newListMission);
      }
    } catch (error, stack) {
      safePrint(">>>> addInscrption ERROR : error=[$error]");
      state = AsyncValue.error(error, stack);
    }
  }

  Future<void> deleteInscrption(Inscription inscription) async {
    safePrint(">>>> missionProvider : deleteInscrption($inscription)");
    try {
      final mission = getMission(inscription.mission!.id);
      if (mission == null) throw Exception("Mission null");
      final inscriptions = mission.inscriptions ?? [];
      inscriptions.removeWhere((i) => i.id == inscription.id);
      final newMission = mission.copyWith(inscriptions: inscriptions);
      final newListMission = state.asData?.value.map((mission) {
        if (mission.id == newMission.id) return newMission;
        return mission;
      }).toList();
      if (newListMission != null) {
        state = AsyncValue.data(newListMission);
      }
    } catch (error, stack) {
      safePrint(">>>> deleteInscrption ERROR : error=[$error]");
      state = AsyncValue.error(error, stack);
    }
  }
}

final missionProvider = StateNotifierProvider<MissionNotifier, AsyncValue<List<Mission>>>(
  (ref) => MissionNotifier(),
);
