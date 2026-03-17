import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import '../firebase_options.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../models/detection_model.dart';
import '../models/soil_model.dart';

class DroneStatus {
  final bool connected;
  final bool flying;
  final int battery;
  final int lastSeen;

  DroneStatus({
    required this.connected,
    required this.flying,
    required this.battery,
    required this.lastSeen,
  });

  factory DroneStatus.fromMap(Map data) {
    return DroneStatus(
      connected: data['connected'] == true,
      flying: data['flying'] == true,
      battery: (data['battery'] ?? 0) is int ? data['battery'] : 0,
      lastSeen: (data['lastSeen'] ?? 0) is int ? data['lastSeen'] : 0,
    );
  }
}

class FirebaseService {
  FirebaseDatabase? _db;
  bool firebaseReady = false;

  Future<void> init() async {
    try {
      // Firebase.initializeApp() is already called in main() before runApp().
      // We just grab the existing instance here.
      final dbUrl = DefaultFirebaseOptions.web.databaseURL ??
          'https://agridrone-guardian-default-rtdb.asia-southeast1.firebasedatabase.app';
      _db = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: dbUrl,
      );

      firebaseReady = true;

      // Persistence might be problematic on some web environments
      try {
        _db!.setPersistenceEnabled(true);
      } catch (e) {
        debugPrint('Persistence Error: $e');
      }

      try {
        await FirebaseAuth.instance.signInAnonymously();
      } catch (_) {}

      try {
        await FirebaseMessaging.instance.requestPermission();
      } catch (_) {}
    } catch (e) {
      debugPrint('FirebaseService init error: $e');
      firebaseReady = false;
    }
  }

  Stream<List<DetectionModel>> detectionsStream() {
    if (_db == null) return Stream.value([]);
    return _db!.ref('detections').onValue.map((event) {
      final List<DetectionModel> list = [];
      final data = event.snapshot.value;
      
      if (data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            final Map<String, dynamic> map = Map<String, dynamic>.from(value);
            list.add(DetectionModel.fromMap(map));
          }
        });
      }
      
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }

  Stream<List<SoilModel>> soilStream() {
    if (_db == null) return Stream.value([]);
    return _db!.ref('soil').onValue.map((event) {
      final List<SoilModel> list = [];
      final data = event.snapshot.value;
      
      if (data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            final Map<String, dynamic> map = Map<String, dynamic>.from(value);
            list.add(SoilModel.fromMap(map));
          }
        });
      }
      
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return list;
    });
  }

  Stream<DroneStatus?> droneStream() {
    if (_db == null) return Stream.value(null);
    return _db!.ref('drone/status').onValue.map((event) {
      final data = event.snapshot.value;
      if (data is Map) {
        return DroneStatus.fromMap(data);
      }
      return null;
    });
  }

  Future<List<DetectionModel>> fetchDetectionsOnce() async {
    if (_db == null) return [];
    try {
      final snapshot = await _db!.ref('detections').get();
      final List<DetectionModel> list = [];
      final data = snapshot.value;
      if (data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            final Map<String, dynamic> map = Map<String, dynamic>.from(value);
            list.add(DetectionModel.fromMap(map));
          }
        });
      }
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<List<SoilModel>> fetchSoilOnce() async {
    if (_db == null) return [];
    try {
      final snapshot = await _db!.ref('soil').get();
      final List<SoilModel> list = [];
      final data = snapshot.value;
      if (data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            final Map<String, dynamic> map = Map<String, dynamic>.from(value);
            list.add(SoilModel.fromMap(map));
          }
        });
      }
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return list;
    } catch (_) {
      return [];
    }
  }
}