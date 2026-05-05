import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/drone_models.dart';

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
