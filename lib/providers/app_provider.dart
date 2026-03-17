import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../services/firebase_service.dart';
import '../services/connectivity_service.dart';
import '../models/detection_model.dart';
import '../models/soil_model.dart';

class AppProvider extends ChangeNotifier {
  final FirebaseService _firebase = FirebaseService();
  final ConnectivityService _connectivity = ConnectivityService();
  
  List<DetectionModel> detections = [];
  List<SoilModel> soil = [];
  DroneStatus? droneStatus;
  
  bool isLoading = false;
  String? errorMessage;
  String selectedCrop = 'rice';
  bool firebaseConnected = false;
  bool isScanning = false;

  // Connectivity Suite State
  DroneConnectionState connectionState = DroneConnectionState.offline;
  Duration currentLatency = Duration.zero;
  int currentRssi = -42; // Placeholder as requested

  StreamSubscription? _detectionsSub;
  StreamSubscription? _soilSub;
  StreamSubscription? _droneSub;
  StreamSubscription? _connSub;
  StreamSubscription? _latencySub;

  Future<void> init() async {
    _setLoading(true);
    await _firebase.init();
    firebaseConnected = _firebase.firebaseReady;

    // Listen to Firebase streams
    _detectionsSub = _firebase.detectionsStream().listen((data) {
      detections = data;
      firebaseConnected = true;
      _connectivity.updateFirebaseStatus(true);
      notifyListeners();
    });

    _soilSub = _firebase.soilStream().listen((data) {
      soil = data;
      firebaseConnected = true;
      notifyListeners();
    });

    _droneSub = _firebase.droneStream().listen((status) {
      droneStatus = status;
      firebaseConnected = true;
      notifyListeners();
    });

    // Connectivity Service
    _connectivity.startPinging();
    _connSub = _connectivity.connectionStateStream.listen((state) {
      connectionState = state;
      notifyListeners();
    });
    _latencySub = _connectivity.latencyStream.listen((latency) {
      currentLatency = latency;
      notifyListeners();
    });

    // Fallback for initial load
    await Future.delayed(const Duration(seconds: 4));
    if (detections.isEmpty) {
      await fetchInitialData();
    }
    
    _setLoading(false);
  }

  Future<void> fetchInitialData() async {
    final d = await _firebase.fetchDetectionsOnce();
    final s = await _firebase.fetchSoilOnce();
    if (d.isNotEmpty) detections = d;
    if (s.isNotEmpty) soil = s;
    notifyListeners();
  }

  void setCrop(String crop) {
    selectedCrop = crop;
    notifyListeners();
  }

  Future<void> refreshNow() async {
    _setLoading(true);
    await fetchInitialData();
    _setLoading(false);
  }

  void _setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }

  Future<void> triggerMission(bool start) async {
    if (start) {
      errorMessage = "Waking AI...";
      notifyListeners();
      
      try {
        // Send wake-up call to Render API
        final response = await http.get(Uri.parse('https://agridrone-api.onrender.com/')).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          errorMessage = "AI Online. Starting mission...";
          notifyListeners();
          await _firebase.updateMissionStatus(true);
        } else {
          errorMessage = "Render API wake-up failed. Check server.";
          notifyListeners();
        }
      } catch (e) {
        errorMessage = "Error connecting to AI server: $e";
        notifyListeners();
      }
      
      Future.delayed(const Duration(seconds: 3), () {
        errorMessage = null;
        notifyListeners();
      });
    } else {
      await _firebase.updateMissionStatus(false);
    }
  }

  Future<void> triggerCapture() async {
    if (connectionState != DroneConnectionState.direct) return;
    
    isScanning = true;
    notifyListeners();

    final success = await _connectivity.triggerCapture();
    
    if (!success) {
      errorMessage = "Server Wake-up in Progress... (Render.com cold start)";
      notifyListeners();
      Future.delayed(const Duration(seconds: 5), () {
        errorMessage = null;
        notifyListeners();
      });
    }

    // Keep scanning overlay for at least 3 seconds for effect
    await Future.delayed(const Duration(seconds: 3));
    isScanning = false;
    notifyListeners();
  }

  Stream<String> get rawDroneStream => _firebase.rawDroneStream();

  @override
  void dispose() {
    _detectionsSub?.cancel();
    _soilSub?.cancel();
    _droneSub?.cancel();
    _connSub?.cancel();
    _latencySub?.cancel();
    _connectivity.dispose();
    super.dispose();
  }
}
