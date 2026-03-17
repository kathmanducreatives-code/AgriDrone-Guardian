import 'package:flutter/material.dart';
import 'dart:async';
import '../services/firebase_service.dart';
import '../models/detection_model.dart';
import '../models/soil_model.dart';

class AppProvider extends ChangeNotifier {
  final FirebaseService _firebase = FirebaseService();
  
  List<DetectionModel> detections = [];
  List<SoilModel> soil = [];
  DroneStatus? droneStatus;
  
  bool isLoading = false;
  String? errorMessage;
  String selectedCrop = 'rice';
  bool firebaseConnected = false;

  StreamSubscription? _detectionsSub;
  StreamSubscription? _soilSub;
  StreamSubscription? _droneSub;

  Future<void> init() async {
    _setLoading(true);
    await _firebase.init();
    firebaseConnected = _firebase.firebaseReady;

    // Listen to Firebase streams
    _detectionsSub = _firebase.detectionsStream().listen((data) {
      detections = data;
      firebaseConnected = true;
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

  @override
  void dispose() {
    _detectionsSub?.cancel();
    _soilSub?.cancel();
    _droneSub?.cancel();
    super.dispose();
  }
}
