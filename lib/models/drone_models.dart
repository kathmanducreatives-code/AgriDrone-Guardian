import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';

const String kDefaultDeviceIp = '192.168.1.76';

Map<String, dynamic> _normalizeMap(Map<dynamic, dynamic> map) {
  return map.map((key, value) => MapEntry(key.toString(), value));
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double _asDouble(dynamic value, {double fallback = 0.0}) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
  }
  return fallback;
}

class DroneStatus {
  final String status; // "online" | "scanning" | "api_error"
  final String ip; // e.g. "192.168.1.76"
  final int rssi; // signal strength
  final String camera;
  final int lastSeen;
  final int battery;
  final bool isFlying;

  DroneStatus({
    this.status = "offline",
    this.ip = kDefaultDeviceIp,
    this.rssi = -100,
    this.camera = "Unknown",
    this.lastSeen = 0,
    this.battery = 100,
    this.isFlying = false,
  });

  factory DroneStatus.fromSnapshot(DataSnapshot snapshot) {
    if (!snapshot.exists) return DroneStatus();
    final map = snapshot.value as Map<dynamic, dynamic>?;
    if (map == null) return DroneStatus();

    String rawStatus = "offline";
    int battery = 100;
    bool isFlying = false;

    var statusData = map['status'];

    // Attempt to handle both Map and JSON string (strict or loose)
    Map<String, dynamic>? dataMap;

    if (statusData is Map) {
      dataMap = statusData.map(
        (k, v) => MapEntry(k.toString().toUpperCase(), v),
      );
    } else if (statusData is String) {
      final String sData = statusData;
      if (sData.startsWith('{')) {
        try {
          final decoded = jsonDecode(sData);
          if (decoded is Map) {
            dataMap = decoded.map(
              (k, v) => MapEntry(k.toString().toUpperCase(), v),
            );
          }
        } catch (_) {
          // Sloppy parsing for non-standard string representations
          final upper = sData.toUpperCase();
          if (upper.contains('CONNECTED: TRUE') ||
              upper.contains('"CONNECTED": TRUE') ||
              upper.contains('"CONNECTED":TRUE')) {
            rawStatus = "online";
          }

          final batteryMatch = RegExp(r'BATTERY:\s*(\d+)').firstMatch(upper);
          if (batteryMatch != null)
            battery = int.tryParse(batteryMatch.group(1)!) ?? 100;

          if (upper.contains('FLYING: TRUE')) isFlying = true;
          if (upper.contains('IS_ACTIVE: TRUE')) rawStatus = "scanning";
        }
      } else {
        rawStatus = sData;
      }
    }

    if (dataMap != null) {
      final bVal = dataMap['BATTERY'];
      if (bVal is num)
        battery = bVal.toInt();
      else if (bVal is String)
        battery = int.tryParse(bVal) ?? 100;

      final fVal = dataMap['FLYING'];
      isFlying = fVal == true || fVal.toString().toUpperCase() == 'TRUE';

      final cVal = dataMap['CONNECTED'];
      final isConnected =
          cVal == true || cVal.toString().toUpperCase() == 'TRUE';

      final actVal = dataMap['IS_ACTIVE'] ?? dataMap['SCANNING'];
      final isActive =
          actVal == true || actVal.toString().toUpperCase() == 'TRUE';

      if (isActive == true)
        rawStatus = "scanning";
      else if (isConnected)
        rawStatus = "online";
      else
        rawStatus = "offline";
    }

    // Final safety check: if status is still a JSON-like string, clean it up
    if (rawStatus.contains('{') || rawStatus.contains(':')) {
      rawStatus = (battery > 0) ? "online" : "offline";
    }

    return DroneStatus(
      status: rawStatus,
      ip: map['ip']?.toString() ?? kDefaultDeviceIp,
      rssi: (map['rssi'] as num?)?.toInt() ?? -100,
      camera: map['camera']?.toString() ?? "Unknown",
      lastSeen: (map['lastSeen'] as num?)?.toInt() ?? 0,
      battery: battery,
      isFlying: isFlying,
    );
  }
}

class CameraConfig {
  final int quality;
  final int brightness;
  final int contrast;
  final int saturation;
  final int sharpness;
  final bool vflip;
  final bool hmirror;
  final int framesize;

  const CameraConfig({
    this.quality = 14,
    this.brightness = 1,
    this.contrast = 1,
    this.saturation = 0,
    this.sharpness = 2,
    this.vflip = false,
    this.hmirror = false,
    this.framesize = 7,
  });

  CameraConfig copyWith({
    int? quality,
    int? brightness,
    int? contrast,
    int? saturation,
    int? sharpness,
    bool? vflip,
    bool? hmirror,
    int? framesize,
  }) {
    return CameraConfig(
      quality: quality ?? this.quality,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      sharpness: sharpness ?? this.sharpness,
      vflip: vflip ?? this.vflip,
      hmirror: hmirror ?? this.hmirror,
      framesize: framesize ?? this.framesize,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'quality': quality,
      'brightness': brightness,
      'contrast': contrast,
      'saturation': saturation,
      'sharpness': sharpness,
      'vflip': vflip,
      'hmirror': hmirror,
      'framesize': framesize,
    };
  }

  factory CameraConfig.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const CameraConfig();
    final normalized = _normalizeMap(map);
    return CameraConfig(
      quality: _asInt(normalized['quality'], fallback: 14),
      brightness: _asInt(normalized['brightness'], fallback: 1),
      contrast: _asInt(normalized['contrast'], fallback: 1),
      saturation: _asInt(normalized['saturation']),
      sharpness: _asInt(normalized['sharpness'], fallback: 2),
      vflip: _asBool(normalized['vflip']),
      hmirror: _asBool(normalized['hmirror']),
      framesize: _asInt(normalized['framesize'], fallback: 7),
    );
  }
}

class EspDeviceStatus {
  final String deviceId;
  final String fieldId;
  final String cropType;
  final String localFlightId;
  final String remoteFlightId;
  final int nextPatchIndex;
  final int maxPatchesFlash;
  final bool captureEnabled;
  final bool uploadInProgress;
  final bool uploadComplete;
  final String uploadMessage;
  final int flashUsedBytes;
  final int flashTotalBytes;
  final bool wifiConnected;
  final String ip;
  final bool gpsFix;
  final double? lat;
  final double? lon;
  final CameraConfig cameraConfig;
  final String? error;

  const EspDeviceStatus({
    this.deviceId = '',
    this.fieldId = '',
    this.cropType = '',
    this.localFlightId = '',
    this.remoteFlightId = '',
    this.nextPatchIndex = 1,
    this.maxPatchesFlash = 0,
    this.captureEnabled = false,
    this.uploadInProgress = false,
    this.uploadComplete = false,
    this.uploadMessage = 'offline',
    this.flashUsedBytes = 0,
    this.flashTotalBytes = 0,
    this.wifiConnected = false,
    this.ip = kDefaultDeviceIp,
    this.gpsFix = false,
    this.lat,
    this.lon,
    this.cameraConfig = const CameraConfig(),
    this.error,
  });

  bool get isOnline => wifiConnected && error == null;
  int get bufferedPatchCount => nextPatchIndex > 1 ? nextPatchIndex - 1 : 0;

  factory EspDeviceStatus.offline({required String ip, String? error}) {
    return EspDeviceStatus(
      ip: ip,
      uploadMessage: error ?? 'offline',
      error: error,
    );
  }

  factory EspDeviceStatus.fromJson(Map<String, dynamic> json) {
    return EspDeviceStatus(
      deviceId: json['device_id']?.toString() ?? '',
      fieldId: json['field_id']?.toString() ?? '',
      cropType: json['crop_type']?.toString() ?? '',
      localFlightId: json['local_flight_id']?.toString() ?? '',
      remoteFlightId: json['remote_flight_id']?.toString() ?? '',
      nextPatchIndex: _asInt(json['next_patch_index'], fallback: 1),
      maxPatchesFlash: _asInt(json['max_patches_flash']),
      captureEnabled: _asBool(json['capture_enabled']),
      uploadInProgress: _asBool(json['upload_in_progress']),
      uploadComplete: _asBool(json['upload_complete']),
      uploadMessage: json['upload_message']?.toString() ?? 'idle',
      flashUsedBytes: _asInt(json['flash_used_bytes']),
      flashTotalBytes: _asInt(json['flash_total_bytes']),
      wifiConnected: _asBool(json['wifi_connected']),
      ip: json['ip']?.toString() ?? kDefaultDeviceIp,
      gpsFix: _asBool(json['gps_fix']),
      lat: json['lat'] == null ? null : _asDouble(json['lat']),
      lon: json['lon'] == null ? null : _asDouble(json['lon']),
      cameraConfig: CameraConfig.fromMap(json),
    );
  }
}

enum LabCommandPhase { idle, pending, success, error }

class LabCommandState {
  final String action;
  final LabCommandPhase phase;
  final String message;
  final DateTime? startedAt;

  const LabCommandState({
    required this.action,
    required this.phase,
    required this.message,
    this.startedAt,
  });

  bool get isPending => phase == LabCommandPhase.pending;

  factory LabCommandState.idle(String action, {String message = 'Idle'}) {
    return LabCommandState(
      action: action,
      phase: LabCommandPhase.idle,
      message: message,
    );
  }

  factory LabCommandState.pending(
    String action, {
    String message = 'Working...',
  }) {
    return LabCommandState(
      action: action,
      phase: LabCommandPhase.pending,
      message: message,
      startedAt: DateTime.now(),
    );
  }

  factory LabCommandState.success(String action, {String message = 'Done'}) {
    return LabCommandState(
      action: action,
      phase: LabCommandPhase.success,
      message: message,
      startedAt: DateTime.now(),
    );
  }

  factory LabCommandState.error(String action, {String message = 'Failed'}) {
    return LabCommandState(
      action: action,
      phase: LabCommandPhase.error,
      message: message,
      startedAt: DateTime.now(),
    );
  }
}

class InferenceDetection {
  final String disease;
  final double confidence;
  final String severity;

  const InferenceDetection({
    this.disease = 'Unknown',
    this.confidence = 0.0,
    this.severity = 'unknown',
  });

  factory InferenceDetection.fromMap(Map<dynamic, dynamic> map) {
    final normalized = _normalizeMap(map);
    return InferenceDetection(
      disease: normalized['disease']?.toString() ?? 'Unknown',
      confidence: _asDouble(normalized['confidence']),
      severity: normalized['severity']?.toString() ?? 'unknown',
    );
  }
}

class InferenceResult {
  final String disease;
  final double confidence;
  final String severity;
  final String? model;
  final String? cropWarning;
  final List<InferenceDetection> allDetections;
  final String? latestImageUrl;
  final String? latestDecodedImageUrl;

  const InferenceResult({
    this.disease = 'Unknown',
    this.confidence = 0.0,
    this.severity = 'unknown',
    this.model,
    this.cropWarning,
    this.allDetections = const [],
    this.latestImageUrl,
    this.latestDecodedImageUrl,
  });

  factory InferenceResult.fromJson(Map<String, dynamic> json) {
    final rawDetections = json['all_detections'];
    final detections = rawDetections is List
        ? rawDetections
              .whereType<Map>()
              .map(InferenceDetection.fromMap)
              .toList(growable: false)
        : const <InferenceDetection>[];

    return InferenceResult(
      disease: json['disease']?.toString() ?? 'Unknown',
      confidence: _asDouble(json['confidence']),
      severity: json['severity']?.toString() ?? 'unknown',
      model: json['model']?.toString(),
      cropWarning: json['crop_warning']?.toString(),
      allDetections: detections,
      latestImageUrl: json['debug_latest_image_url']?.toString(),
      latestDecodedImageUrl: json['debug_latest_decoded_image_url']?.toString(),
    );
  }
}

class Detection {
  final String disease;
  final double confidence;
  final String severity;
  final String crop;
  final int timestamp;

  Detection({
    this.disease = "Unknown",
    this.confidence = 0.0,
    this.severity = "unknown",
    this.crop = "unknown",
    this.timestamp = 0,
  });

  factory Detection.fromSnapshot(DataSnapshot snapshot) {
    if (!snapshot.exists) return Detection();
    final map = snapshot.value as Map<dynamic, dynamic>?;
    if (map == null) return Detection();

    return Detection(
      disease: map['disease']?.toString() ?? "Unknown",
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      severity: map['severity']?.toString() ?? "unknown",
      crop: map['crop']?.toString() ?? "unknown",
      timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
    );
  }

  factory Detection.fromMap(Map<dynamic, dynamic> map) {
    return Detection(
      disease: map['disease']?.toString() ?? "Unknown",
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      severity: map['severity']?.toString() ?? "unknown",
      crop: map['crop']?.toString() ?? "unknown",
      timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
    );
  }
}

class SoilData {
  final double moisture;
  final double temperature;
  final double humidity;
  final double gpsLat;
  final double gpsLng;

  SoilData({
    this.moisture = 0.0,
    this.temperature = 0.0,
    this.humidity = 0.0,
    this.gpsLat = 0.0,
    this.gpsLng = 0.0,
  });

  factory SoilData.fromSnapshot(DataSnapshot snapshot) {
    if (!snapshot.exists) return SoilData();
    final map = snapshot.value as Map<dynamic, dynamic>?;
    if (map == null) return SoilData();

    return SoilData(
      moisture: (map['moisture'] as num?)?.toDouble() ?? 0.0,
      temperature: (map['temperature'] as num?)?.toDouble() ?? 0.0,
      humidity: (map['humidity'] as num?)?.toDouble() ?? 0.0,
      gpsLat: (map['gps_lat'] as num?)?.toDouble() ?? 0.0,
      gpsLng: (map['gps_lng'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class AppConfig {
  final String crop;
  final int scanInterval;
  final double confidence;
  final String ip;
  final CameraConfig cameraConfig;

  AppConfig({
    this.crop = "Rice",
    this.scanInterval = 300,
    this.confidence = 0.5,
    this.ip = kDefaultDeviceIp,
    this.cameraConfig = const CameraConfig(),
  });

  factory AppConfig.fromSnapshot(DataSnapshot snapshot) {
    if (!snapshot.exists) return AppConfig();
    final map = snapshot.value as Map<dynamic, dynamic>?;
    if (map == null) return AppConfig();

    return AppConfig(
      crop: map['crop']?.toString() ?? "Rice",
      scanInterval: (map['scan_interval'] as num?)?.toInt() ?? 300,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.5,
      ip: map['ip']?.toString() ?? kDefaultDeviceIp,
      cameraConfig: map['camera'] is Map
          ? CameraConfig.fromMap(map['camera'] as Map)
          : const CameraConfig(),
    );
  }
}
