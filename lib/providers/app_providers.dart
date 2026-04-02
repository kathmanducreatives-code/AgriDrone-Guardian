import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/drone_models.dart';
import '../services/esp_api_service.dart';
import '../services/inference_api_service.dart';
import '../services/lab_preferences_service.dart';

final firebaseDatabaseProvider = Provider<FirebaseDatabase>((ref) {
  return FirebaseDatabase.instance;
});

final labPreferencesServiceProvider = Provider<LabPreferencesService>((ref) {
  return LabPreferencesService();
});

final espApiServiceProvider = Provider<EspApiService>((ref) {
  return const EspApiService();
});

final inferenceApiServiceProvider = Provider<InferenceApiService>((ref) {
  return const InferenceApiService();
});

final droneStatusProvider = StreamProvider<DroneStatus>((ref) {
  final db = ref.watch(firebaseDatabaseProvider);
  return db.ref('drone').onValue.map((event) {
    return DroneStatus.fromSnapshot(event.snapshot);
  });
});

final latestDetectionProvider = StreamProvider<Detection>((ref) {
  final db = ref.watch(firebaseDatabaseProvider);
  return db.ref('detection/latest').onValue.map((event) {
    return Detection.fromSnapshot(event.snapshot);
  });
});

final detectionHistoryProvider = StreamProvider<List<Detection>>((ref) {
  final db = ref.watch(firebaseDatabaseProvider);
  return db.ref('detection/history').onValue.map((event) {
    if (!event.snapshot.exists) return [];
    final map = event.snapshot.value as Map<dynamic, dynamic>?;
    if (map == null) return [];

    List<Detection> history = [];
    map.forEach((key, value) {
      if (value is Map) {
        // Value includes timestamp as key usually, or embedded.
        final d = Detection.fromMap(value);
        history.add(
          Detection(
            disease: d.disease,
            confidence: d.confidence,
            severity: d.severity,
            crop: d.crop,
            timestamp: int.tryParse(key.toString()) ?? d.timestamp,
          ),
        );
      }
    });

    history.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return history;
  });
});

final soilDataProvider = StreamProvider<SoilData>((ref) {
  final db = ref.watch(firebaseDatabaseProvider);
  return db.ref('soil').onValue.map((event) {
    return SoilData.fromSnapshot(event.snapshot);
  });
});

final configProvider = StreamProvider<AppConfig>((ref) {
  final db = ref.watch(firebaseDatabaseProvider);
  return db.ref('config').onValue.map((event) {
    return AppConfig.fromSnapshot(event.snapshot);
  });
});

final commandProvider = Provider<void>((ref) {
  // A helper function provider to write commands easily if needed
  return;
});

class LabDeviceIpNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    final prefs = ref.read(labPreferencesServiceProvider);
    final localIp = await prefs.getDeviceIp();
    if (localIp != null && localIp.trim().isNotEmpty) {
      return localIp.trim();
    }

    try {
      final config = await ref.watch(configProvider.future);
      if (config.ip.trim().isNotEmpty) {
        return config.ip.trim();
      }
    } catch (_) {
      // Fall back to the hardcoded development IP below.
    }

    return kDefaultDeviceIp;
  }

  Future<void> setIp(String ip) async {
    final normalized = ip.trim();
    if (normalized.isEmpty) return;

    state = const AsyncLoading();
    await ref.read(labPreferencesServiceProvider).setDeviceIp(normalized);
    await ref.read(firebaseDatabaseProvider).ref('config/ip').set(normalized);
    state = AsyncData(normalized);
  }
}

final labDeviceIpProvider = AsyncNotifierProvider<LabDeviceIpNotifier, String>(
  LabDeviceIpNotifier.new,
);

final labDeviceStatusProvider = StreamProvider.autoDispose<EspDeviceStatus>((
  ref,
) async* {
  final ip = await ref.watch(labDeviceIpProvider.future);
  final service = ref.watch(espApiServiceProvider);

  while (true) {
    try {
      yield await service.fetchStatus(ip);
    } catch (error) {
      yield EspDeviceStatus.offline(ip: ip, error: error.toString());
    }

    await Future<void>.delayed(const Duration(seconds: 5));
  }
});

final labCameraConfigProvider = StateProvider<CameraConfig>((ref) {
  return const CameraConfig();
});

final labCameraConfigSourceIpProvider = StateProvider<String?>((ref) {
  return null;
});

final labScanStateProvider = StateProvider<LabCommandState>((ref) {
  return LabCommandState.idle('scan', message: 'Ready to trigger a scan');
});

final labCameraApplyStateProvider = StateProvider<LabCommandState>((ref) {
  return LabCommandState.idle('camera', message: 'Camera controls are ready');
});

final labInferenceStateProvider = StateProvider<LabCommandState>((ref) {
  return LabCommandState.idle('upload', message: 'Select an image to test');
});

final labInferenceResultProvider = StateProvider<InferenceResult?>((ref) {
  return null;
});

// A helper FutureProvider to send a scan command
Future<void> triggerScanCommand() async {
  final ref = FirebaseDatabase.instance.ref('drone/command');
  await ref.set('scan');
}

Future<void> updateConfig(String key, dynamic value) async {
  final ref = FirebaseDatabase.instance.ref('config/$key');
  await ref.set(value);
}
