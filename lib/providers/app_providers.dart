import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/drone_models.dart';
import '../models/photo_model.dart';
import '../services/backend_service.dart';

final firebaseDatabaseProvider = Provider<FirebaseDatabase>((ref) {
  return FirebaseDatabase.instance;
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
        history.add(Detection(
          disease: d.disease,
          confidence: d.confidence,
          severity: d.severity,
          crop: d.crop,
          timestamp: int.tryParse(key.toString()) ?? d.timestamp,
        ));
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

// A helper FutureProvider to send a scan command
Future<void> triggerScanCommand() async {
  final ref = FirebaseDatabase.instance.ref('drone/command');
  await ref.set('scan');
}

Future<void> updateConfig(String key, dynamic value) async {
  final ref = FirebaseDatabase.instance.ref('config/$key');
  await ref.set(value);
}

// ─── Mission state ───────────────────────────────────────────────────────────

class MissionState {
  final String? flightId;
  final String? missionFolder;
  final int sessionCapturedCount;
  final bool isAutoCapturing;
  final int patchIndex;
  final String esp32Ip;
  final String? lastError;
  final Map<String, dynamic>? cameraStatus;

  const MissionState({
    this.flightId,
    this.missionFolder,
    this.sessionCapturedCount = 0,
    this.isAutoCapturing = false,
    this.patchIndex = 0,
    this.esp32Ip = '172.17.163.199',
    this.lastError,
    this.cameraStatus,
  });

  MissionState copyWith({
    String? flightId,
    String? missionFolder,
    int? sessionCapturedCount,
    bool? isAutoCapturing,
    int? patchIndex,
    String? esp32Ip,
    String? lastError,
    Map<String, dynamic>? cameraStatus,
    bool clearFlightId = false,
    bool clearMissionFolder = false,
    bool clearError = false,
    bool clearCameraStatus = false,
  }) {
    return MissionState(
      flightId: clearFlightId ? null : (flightId ?? this.flightId),
      missionFolder: clearMissionFolder ? null : (missionFolder ?? this.missionFolder),
      sessionCapturedCount: sessionCapturedCount ?? this.sessionCapturedCount,
      isAutoCapturing: isAutoCapturing ?? this.isAutoCapturing,
      patchIndex: patchIndex ?? this.patchIndex,
      esp32Ip: esp32Ip ?? this.esp32Ip,
      lastError: clearError ? null : (lastError ?? this.lastError),
      cameraStatus: clearCameraStatus ? null : (cameraStatus ?? this.cameraStatus),
    );
  }
}

class MissionNotifier extends Notifier<MissionState> {
  final BackendService _backend = BackendService();
  Timer? _autoCaptureTimer;

  @override
  MissionState build() => const MissionState();

  void setEsp32Ip(String ip) {
    if (ip == state.esp32Ip) return;
    _stopAutoCapture();
    state = state.copyWith(esp32Ip: ip, clearFlightId: true, clearMissionFolder: true);
  }

  /// Auto-discover the ESP32 IP from the FastAPI device registry.
  /// Called on startup so the app always uses the latest IP without manual config.
  Future<void> autoDiscoverIp({String deviceId = 'esp32-drone-01'}) async {
    final ip = await _backend.fetchDeviceIp(deviceId);
    if (ip != null && ip.trim().isNotEmpty && ip.trim() != state.esp32Ip) {
      state = state.copyWith(esp32Ip: ip.trim());
    }
  }

  Future<void> fetchCameraStatus() async {
    try {
      final status = await _backend.getCameraStatus(state.esp32Ip);
      state = state.copyWith(cameraStatus: status, clearError: true);
    } catch (e) {
      state = state.copyWith(lastError: e.toString());
    }
  }

  Future<bool> setCameraControl(String varName, int val) async {
    try {
      await _backend.setCameraControl(state.esp32Ip, varName, val);
      await fetchCameraStatus();
      return true;
    } catch (e) {
      state = state.copyWith(lastError: e.toString());
      return false;
    }
  }

  Future<void> startAutoCapture({
    required String deviceId,
    int captureIntervalMs = 5000,
    String cropType = 'rice',
  }) async {
    if (state.isAutoCapturing) return;
    try {
      final flight = await _backend.createFlight(
        deviceId: deviceId,
        cropType: cropType,
        captureIntervalMs: captureIntervalMs,
      );
      final flightId = flight['flight_id'] as String;
      final missionFolder = flight['storage_folder'] as String?;
      state = state.copyWith(
        flightId: flightId,
        missionFolder: missionFolder,
        isAutoCapturing: true,
        patchIndex: 0,
        sessionCapturedCount: 0,
        clearError: true,
      );
      _scheduleCapture(captureIntervalMs, cropType);
    } catch (e) {
      state = state.copyWith(lastError: 'Failed to start mission: $e');
    }
  }

  void _scheduleCapture(int intervalMs, String cropType) {
    _autoCaptureTimer?.cancel();
    _autoCaptureTimer = Timer(Duration(milliseconds: intervalMs), () async {
      await _doCapture(cropType);
      if (state.isAutoCapturing) _scheduleCapture(intervalMs, cropType);
    });
  }

  Future<void> _doCapture(String cropType) async {
    final flightId = state.flightId;
    if (flightId == null) return;
    try {
      await _backend.esp32Capture(
        flightId: flightId,
        esp32Ip: state.esp32Ip,
        patchIndex: state.patchIndex,
        cropType: cropType,
      );
      state = state.copyWith(
        patchIndex: state.patchIndex + 1,
        sessionCapturedCount: state.sessionCapturedCount + 1,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(lastError: 'Capture failed: $e');
    }
  }

  void stopAutoCapture() {
    _stopAutoCapture();
    state = state.copyWith(
      isAutoCapturing: false,
      clearFlightId: true,
      clearMissionFolder: true,
      sessionCapturedCount: 0,
      patchIndex: 0,
    );
  }

  void _stopAutoCapture() {
    _autoCaptureTimer?.cancel();
    _autoCaptureTimer = null;
  }

  @override
  void dispose() {
    _autoCaptureTimer?.cancel();
  }
}

final missionProvider = NotifierProvider<MissionNotifier, MissionState>(() => MissionNotifier());

// ─── Photos ──────────────────────────────────────────────────────────────────

class PhotosNotifier extends AsyncNotifier<List<PhotoModel>> {
  final BackendService _backend = BackendService();

  @override
  Future<List<PhotoModel>> build() => _backend.listPhotos(limit: 100);

  Future<void> load({String? flightId}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _backend.listPhotos(flightId: flightId, limit: 100),
    );
  }
}

final photosProvider =
    AsyncNotifierProvider<PhotosNotifier, List<PhotoModel>>(() => PhotosNotifier());
