/// Matches the JSON shape returned by the ESP32-S3 firmware GET /status:
/// {
///   "device_id", "ip", "rssi_dbm",
///   "lat", "lng", "alt_m", "hdop",
///   "gps_valid", "gps_age_ms",
///   "session_active", "session_id",
///   "capture_count", "latest_image_url",
///   "uptime_ms", "stream_url"
/// }
class DroneStatusV3 {
  final String deviceId;
  final String ip;
  final int rssiDbm;

  final double lat;
  final double lng;
  final double altM;
  final double hdop;
  final bool gpsValid;
  final int gpsAgeMs;

  final bool sessionActive;
  final String sessionId;
  final int captureCount;
  final String latestImageUrl;

  final int uptimeMs;
  final String streamUrl;

  const DroneStatusV3({
    this.deviceId = 'esp32-drone-01',
    this.ip = '',
    this.rssiDbm = -100,
    this.lat = 27.690657,
    this.lng = 85.295091,
    this.altM = 0,
    this.hdop = 99,
    this.gpsValid = false,
    this.gpsAgeMs = 9999,
    this.sessionActive = false,
    this.sessionId = '',
    this.captureCount = 0,
    this.latestImageUrl = '',
    this.uptimeMs = 0,
    this.streamUrl = '',
  });

  factory DroneStatusV3.fromJson(Map<String, dynamic> j) {
    return DroneStatusV3(
      deviceId: j['device_id'] as String? ?? 'esp32-drone-01',
      ip: j['ip'] as String? ?? '',
      rssiDbm: (j['rssi_dbm'] as num?)?.toInt() ?? -100,
      lat: (j['lat'] as num?)?.toDouble() ?? 27.690657,
      lng: (j['lng'] as num?)?.toDouble() ?? 85.295091,
      altM: (j['alt_m'] as num?)?.toDouble() ?? 0,
      hdop: (j['hdop'] as num?)?.toDouble() ?? 99,
      gpsValid: j['gps_valid'] as bool? ?? false,
      gpsAgeMs: (j['gps_age_ms'] as num?)?.toInt() ?? 9999,
      sessionActive: j['session_active'] as bool? ?? false,
      sessionId: j['session_id'] as String? ?? '',
      captureCount: (j['capture_count'] as num?)?.toInt() ?? 0,
      latestImageUrl: j['latest_image_url'] as String? ?? '',
      uptimeMs: (j['uptime_ms'] as num?)?.toInt() ?? 0,
      streamUrl: j['stream_url'] as String? ?? '',
    );
  }

  /// Formatted uptime e.g. "3h 12m" or "45s"
  String get uptimeFormatted {
    final s = uptimeMs ~/ 1000;
    if (s < 60) return '${s}s';
    final m = s ~/ 60;
    if (m < 60) return '${m}m ${s % 60}s';
    return '${m ~/ 60}h ${m % 60}m';
  }

  /// Signal quality label
  String get signalLabel {
    if (rssiDbm >= -60) return 'STRONG';
    if (rssiDbm >= -70) return 'GOOD';
    if (rssiDbm >= -80) return 'FAIR';
    return 'WEAK';
  }

  /// Short session ID for display (first 8 chars)
  String get sessionShort =>
      sessionId.length >= 8 ? sessionId.substring(0, 8) : sessionId;
}
