import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/drone_models.dart';
import '../models/drone_status_v3.dart';
import '../models/drone_log.dart';
import '../models/photo_model.dart';
import '../services/backend_service.dart';
import '../services/drone_service.dart';
import '../services/supabase_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ESP32 IP — persisted in SharedPreferences so it survives hot-reloads
// ─────────────────────────────────────────────────────────────────────────────

class Esp32IpNotifier extends Notifier<String> {
  static const _key = 'esp32_ip';

  @override
  String build() {
    _loadSaved();
    return '192.168.1.76'; // default until loaded
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null && saved.trim().isNotEmpty) {
      state = saved.trim();
    }
  }

  Future<void> set(String ip) async {
    final trimmed = ip.trim();
    if (trimmed == state) return;
    state = trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, trimmed);
  }
}

final esp32IpProvider =
    NotifierProvider<Esp32IpNotifier, String>(() => Esp32IpNotifier());

// ─────────────────────────────────────────────────────────────────────────────
//  DroneService instance — recreated when IP changes
// ─────────────────────────────────────────────────────────────────────────────

final droneServiceProvider = Provider<DroneService>((ref) {
  final ip = ref.watch(esp32IpProvider);
  return DroneService(ip);
});

final supabaseServiceProvider = Provider<SupabaseService>(
  (_) => SupabaseService(),
);

// ─────────────────────────────────────────────────────────────────────────────
//  ESP32 live status — polls /status every 3 s
//  Emits null when drone is unreachable (UI shows "offline")
// ─────────────────────────────────────────────────────────────────────────────

final esp32StatusProvider = StreamProvider.autoDispose<DroneStatusV3?>((ref) {
  final service = ref.watch(droneServiceProvider);
  return service.statusStream(intervalSeconds: 3);
});

// ─────────────────────────────────────────────────────────────────────────────
//  Supabase capture logs — async, refreshed manually
// ─────────────────────────────────────────────────────────────────────────────

class DroneLogsNotifier extends AsyncNotifier<List<DroneLog>> {
  @override
  Future<List<DroneLog>> build() =>
      ref.read(supabaseServiceProvider).fetchCaptures();

  Future<void> refresh({String? sessionId}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(supabaseServiceProvider).fetchCaptures(
            sessionId: sessionId,
          ),
    );
  }
}

final droneLogsProvider =
    AsyncNotifierProvider<DroneLogsNotifier, List<DroneLog>>(
        () => DroneLogsNotifier());

// GPS track for field map (loaded on demand)
final gpsTrackProvider =
    FutureProvider.autoDispose.family<List<DroneLog>, String>(
  (ref, sessionId) =>
      ref.read(supabaseServiceProvider).fetchGpsTrack(sessionId: sessionId),
);

// ─────────────────────────────────────────────────────────────────────────────
//  Mission state — wired to ESP32 /session endpoints
// ─────────────────────────────────────────────────────────────────────────────

class MissionState {
  final bool sessionActive;
  final String sessionId;
  final int captureCount;
  final bool isAutoCapturing;
  final String? lastError;
  final List<int>? lastPreviewBytes; // raw JPEG of last capture

  const MissionState({
    this.sessionActive = false,
    this.sessionId = '',
    this.captureCount = 0,
    this.isAutoCapturing = false,
    this.lastError,
    this.lastPreviewBytes,
  });

  MissionState copyWith({
    bool? sessionActive,
    String? sessionId,
    int? captureCount,
    bool? isAutoCapturing,
    String? lastError,
    List<int>? lastPreviewBytes,
    bool clearError = false,
    bool clearPreview = false,
  }) {
    return MissionState(
      sessionActive: sessionActive ?? this.sessionActive,
      sessionId: sessionId ?? this.sessionId,
      captureCount: captureCount ?? this.captureCount,
      isAutoCapturing: isAutoCapturing ?? this.isAutoCapturing,
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastPreviewBytes:
          clearPreview ? null : (lastPreviewBytes ?? this.lastPreviewBytes),
    );
  }
}

class MissionNotifier extends Notifier<MissionState> {
  Timer? _autoCaptureTimer;

  @override
  MissionState build() => const MissionState();

  DroneService get _svc => ref.read(droneServiceProvider);

  // ── Sync state FROM /status poll so counters stay live ──
  void syncFromStatus(DroneStatusV3 s) {
    // Only update passively — don't override isAutoCapturing
    state = state.copyWith(
      sessionActive: s.sessionActive,
      sessionId: s.sessionId,
      captureCount: s.captureCount,
    );
  }

  // ── Session lifecycle ─────────────────────────────────────
  Future<void> startSession() async {
    try {
      final id = await _svc.startSession();
      state = state.copyWith(
        sessionActive: true,
        sessionId: id,
        captureCount: 0,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(lastError: 'Start failed: $e');
    }
  }

  Future<void> stopSession() async {
    _stopAutoCapture();
    try {
      await _svc.stopSession();
      state = state.copyWith(
        sessionActive: false,
        isAutoCapturing: false,
        clearError: true,
      );
      // Refresh Supabase photo list after session ends
      ref.read(droneLogsProvider.notifier).refresh();
    } catch (e) {
      state = state.copyWith(lastError: 'Stop failed: $e');
    }
  }

  // ── Manual single capture ─────────────────────────────────
  Future<void> takeSnapshot() async {
    try {
      final bytes = await _svc.capture();
      state = state.copyWith(
        lastPreviewBytes: bytes,
        captureCount: state.captureCount + 1,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(lastError: 'Capture failed: $e');
    }
  }

  // ── Auto-capture (timed interval) ────────────────────────
  Future<void> startAutoCapture({int intervalMs = 5000}) async {
    if (state.isAutoCapturing) return;
    if (!state.sessionActive) {
      await startSession();
      if (!state.sessionActive) return; // start failed
    }
    state = state.copyWith(isAutoCapturing: true);
    _scheduleCapture(intervalMs);
  }

  void _scheduleCapture(int intervalMs) {
    _autoCaptureTimer?.cancel();
    _autoCaptureTimer = Timer(Duration(milliseconds: intervalMs), () async {
      if (!state.isAutoCapturing) return;
      try {
        final bytes = await _svc.capture();
        state = state.copyWith(
          lastPreviewBytes: bytes,
          captureCount: state.captureCount + 1,
          clearError: true,
        );
      } catch (e) {
        state = state.copyWith(lastError: 'Auto-capture: $e');
      }
      if (state.isAutoCapturing) _scheduleCapture(intervalMs);
    });
  }

  void stopAutoCapture() {
    _stopAutoCapture();
    state = state.copyWith(isAutoCapturing: false);
  }

  void _stopAutoCapture() {
    _autoCaptureTimer?.cancel();
    _autoCaptureTimer = null;
  }
}

final missionProvider =
    NotifierProvider<MissionNotifier, MissionState>(() => MissionNotifier());

// ─────────────────────────────────────────────────────────────────────────────
//  Legacy Firebase providers (kept for backward compat with report screen etc.)
// ─────────────────────────────────────────────────────────────────────────────

final firebaseDatabaseProvider = Provider<FirebaseDatabase>(
  (_) => FirebaseDatabase.instance,
);

final droneStatusProvider = StreamProvider<DroneStatus>((ref) {
  final db = ref.watch(firebaseDatabaseProvider);
  return db.ref('drone').onValue.map((e) => DroneStatus.fromSnapshot(e.snapshot));
});

final latestDetectionProvider = StreamProvider<Detection>((ref) {
  final db = ref.watch(firebaseDatabaseProvider);
  return db
      .ref('detection/latest')
      .onValue
      .map((e) => Detection.fromSnapshot(e.snapshot));
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
  return db.ref('soil').onValue.map((e) => SoilData.fromSnapshot(e.snapshot));
});

final configProvider = StreamProvider<AppConfig>((ref) {
  final db = ref.watch(firebaseDatabaseProvider);
  return db.ref('config').onValue.map((e) => AppConfig.fromSnapshot(e.snapshot));
});

// ─────────────────────────────────────────────────────────────────────────────
//  Backend service (FastAPI — used for IP discovery)
// ─────────────────────────────────────────────────────────────────────────────

final backendServiceProvider = Provider<BackendService>(
  (_) => BackendService(),
);

// ─────────────────────────────────────────────────────────────────────────────
//  Legacy photos (kept for report screen, uses FastAPI)
// ─────────────────────────────────────────────────────────────────────────────

class PhotosNotifier extends AsyncNotifier<List<PhotoModel>> {
  @override
  Future<List<PhotoModel>> build() =>
      ref.read(backendServiceProvider).listPhotos(limit: 100);

  Future<void> load({String? flightId}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref
          .read(backendServiceProvider)
          .listPhotos(flightId: flightId, limit: 100),
    );
  }
}

final photosProvider =
    AsyncNotifierProvider<PhotosNotifier, List<PhotoModel>>(
        () => PhotosNotifier());

// Helpers kept for settings screen
Future<void> updateConfig(String key, dynamic value) async {
  final ref = FirebaseDatabase.instance.ref('config/$key');
  await ref.set(value);
}
