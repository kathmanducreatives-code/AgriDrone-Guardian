/// One row from the Supabase `drone_logs` table.
/// Matches supabase_schema_v2.sql columns.
class DroneLog {
  final String id;
  final String sessionId;
  final double lat;
  final double lng;
  final double? altitudeM;
  final double? hdop;
  final bool gpsValid;
  final String imageUrl;
  final String deviceId;
  final String logType; // "capture" | "gps"
  final DateTime? capturedAt;

  const DroneLog({
    this.id = '',
    this.sessionId = '',
    this.lat = 0,
    this.lng = 0,
    this.altitudeM,
    this.hdop,
    this.gpsValid = false,
    this.imageUrl = '',
    this.deviceId = '',
    this.logType = 'gps',
    this.capturedAt,
  });

  bool get isCapture => logType == 'capture';
  bool get hasImage => imageUrl.isNotEmpty;

  factory DroneLog.fromJson(Map<String, dynamic> j) {
    return DroneLog(
      id: j['id'] as String? ?? '',
      sessionId: j['session_id'] as String? ?? '',
      lat: (j['lat'] as num?)?.toDouble() ?? 0,
      lng: (j['lng'] as num?)?.toDouble() ?? 0,
      altitudeM: (j['altitude_m'] as num?)?.toDouble(),
      hdop: (j['hdop'] as num?)?.toDouble(),
      gpsValid: j['gps_valid'] as bool? ?? false,
      imageUrl: j['image_url'] as String? ?? '',
      deviceId: j['device_id'] as String? ?? '',
      logType: j['log_type'] as String? ?? 'gps',
      capturedAt: j['captured_at'] != null
          ? DateTime.tryParse(j['captured_at'] as String)
          : null,
    );
  }

  String get formattedTime {
    final dt = capturedAt?.toLocal();
    if (dt == null) return '';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    return '$h:$m  $d/$mo';
  }
}
