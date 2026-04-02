import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';

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
    this.ip = "192.168.1.76",
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
      dataMap = statusData.map((k, v) => MapEntry(k.toString().toUpperCase(), v));
    } else if (statusData is String) {
      final String sData = statusData;
      if (sData.startsWith('{')) {
        try {
          final decoded = jsonDecode(sData);
          if (decoded is Map) {
            dataMap = decoded.map((k, v) => MapEntry(k.toString().toUpperCase(), v));
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
          if (batteryMatch != null) battery = int.tryParse(batteryMatch.group(1)!) ?? 100;
          
          if (upper.contains('FLYING: TRUE')) isFlying = true;
          if (upper.contains('IS_ACTIVE: TRUE')) rawStatus = "scanning";
        }
      } else {
        rawStatus = sData;
      }
    }

    if (dataMap != null) {
      final bVal = dataMap['BATTERY'];
      if (bVal is num) battery = bVal.toInt();
      else if (bVal is String) battery = int.tryParse(bVal) ?? 100;

      final fVal = dataMap['FLYING'];
      isFlying = fVal == true || fVal.toString().toUpperCase() == 'TRUE';

      final cVal = dataMap['CONNECTED'];
      final isConnected = cVal == true || cVal.toString().toUpperCase() == 'TRUE';
      
      final actVal = dataMap['IS_ACTIVE'] ?? dataMap['SCANNING'];
      final isActive = actVal == true || actVal.toString().toUpperCase() == 'TRUE';

      if (isActive == true) rawStatus = "scanning";
      else if (isConnected) rawStatus = "online";
      else rawStatus = "offline";
    }

    // Final safety check: if status is still a JSON-like string, clean it up
    if (rawStatus.contains('{') || rawStatus.contains(':')) {
       rawStatus = (battery > 0) ? "online" : "offline";
    }

    return DroneStatus(
      status: rawStatus,
      ip: map['ip']?.toString() ?? "192.168.1.76",
      rssi: (map['rssi'] as num?)?.toInt() ?? -100,
      camera: map['camera']?.toString() ?? "Unknown",
      lastSeen: (map['lastSeen'] as num?)?.toInt() ?? 0,
      battery: battery,
      isFlying: isFlying,
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

  AppConfig({
    this.crop = "Rice",
    this.scanInterval = 300,
    this.confidence = 0.5,
  });

  factory AppConfig.fromSnapshot(DataSnapshot snapshot) {
    if (!snapshot.exists) return AppConfig();
    final map = snapshot.value as Map<dynamic, dynamic>?;
    if (map == null) return AppConfig();

    return AppConfig(
      crop: map['crop']?.toString() ?? "Rice",
      scanInterval: (map['scan_interval'] as num?)?.toInt() ?? 300,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.5,
    );
  }
}
