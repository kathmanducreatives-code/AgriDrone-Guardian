import 'dart:async';

import 'package:flutter/material.dart';

import '../models/detection_model.dart';
import '../models/soil_model.dart';
import '../services/firebase_service.dart';
import '../services/connectivity_service.dart';
import 'package:http/http.dart' as http;

class AppProvider extends ChangeNotifier {
  final FirebaseService _service = FirebaseService();
  final ConnectivityService _connectivityService = ConnectivityService();

  bool isLoading = true;
  bool firebaseConnected = false;
  String? errorMessage;

  String selectedCrop = 'rice';

  List<DetectionModel> detections = [];
  List<SoilModel> soil = [];
  DroneStatus? droneStatus;
  
  DroneConnectionState connectionState = DroneConnectionState.offline;
  Duration currentLatency = Duration.zero;
  bool isCapturing = false;

  StreamSubscription? _detSub;
  StreamSubscription? _soilSub;
  StreamSubscription? _droneSub;
  StreamSubscription? _connSub;
  StreamSubscription? _droneConnSub;
  StreamSubscription? _latencySub;

  Future<void> init() async {
    try {
      await _service.init();
      
      // Wait for Firebase streams to emit before checking for empty data
      await Future.delayed(const Duration(seconds: 4));

      _connSub = _service.connectionStream().listen((connected) {
        firebaseConnected = connected;
        _connectivityService.updateFirebaseStatus(connected);
        notifyListeners();
      });

      _droneConnSub = _connectivityService.connectionStateStream.listen((state) {
        connectionState = state;
        notifyListeners();
      });

      _latencySub = _connectivityService.latencyStream.listen((latency) {
        currentLatency = latency;
        notifyListeners();
      });

      _connectivityService.startPinging();

      final cachedDetections = await _service.loadCachedDetections();
      if (cachedDetections.isNotEmpty) {
        detections = cachedDetections;
      }

      final cachedSoil = await _service.loadCachedSoil();
      if (cachedSoil.isNotEmpty) {
        soil = cachedSoil;
      }

      if (_service.firebaseReady) {
        _detSub = _service.detectionsStream().listen((items) {
          if (items.isNotEmpty) {
            detections = items;
            _service.cacheDetections(items);
          }
          notifyListeners();
        });

        _soilSub = _service.soilStream().listen((items) {
          if (items.isNotEmpty) {
            soil = items;
            _service.cacheSoil(items);
          }
          notifyListeners();
        });

        _droneSub = _service.droneStatusStream().listen((status) {
          if (status != null) droneStatus = status;
          notifyListeners();
        });
      }

      if (detections.isEmpty) {
        detections = _mockDetections();
      }
      if (soil.isEmpty) {
        soil = _mockSoil();
      }

      isLoading = false;
      notifyListeners();
    } catch (_) {
      errorMessage = 'Unable to load data. Showing demo data.';
      detections = _mockDetections();
      soil = _mockSoil();
      isLoading = false;
      notifyListeners();
    }
  }

  void setCrop(String crop) {
    selectedCrop = crop;
    notifyListeners();
  }

  Future<void> refreshNow() async {
    if (!_service.firebaseReady) return;
    try {
      final det = await _service.fetchDetectionsOnce();
      if (det.isNotEmpty) {
        detections = det;
        await _service.cacheDetections(det);
      }
      final soilNow = await _service.fetchSoilOnce();
      if (soilNow.isNotEmpty) {
        soil = soilNow;
        await _service.cacheSoil(soilNow);
      }
      errorMessage = null;
    } catch (_) {
      errorMessage = 'Could not refresh right now. Using last data.';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _detSub?.cancel();
    _soilSub?.cancel();
    _droneSub?.cancel();
    _connSub?.cancel();
    _droneConnSub?.cancel();
    _latencySub?.cancel();
    _connectivityService.dispose();
    super.dispose();
  }

  Future<void> captureImage(BuildContext context) async {
    if (connectionState != DroneConnectionState.direct) return;

    isCapturing = true;
    notifyListeners();

    try {
      final response = await http
          .get(Uri.parse('http://${_connectivityService.droneIp}/capture'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image captured successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to capture');
      }
    } on TimeoutException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Server Wake-up in Progress (Handling cold start...)'),
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      isCapturing = false;
      notifyListeners();
    }
  }

  List<DetectionModel> _mockDetections() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return [
      DetectionModel(
        crop: 'rice',
        disease: 'Neck Blast',
        confidence: 0.87,
        severity: 'severe',
        imageUrl:
            'https://via.placeholder.com/800x500.png?text=Drone+Image',
        timestamp: now - 1000 * 60 * 5,
      ),
      DetectionModel(
        crop: 'wheat',
        disease: 'Leaf Rust',
        confidence: 0.62,
        severity: 'mild',
        imageUrl:
            'https://via.placeholder.com/800x500.png?text=Drone+Image',
        timestamp: now - 1000 * 60 * 30,
      ),
    ];
  }

  List<SoilModel> _mockSoil() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return List.generate(24, (i) {
      final ts = now - (23 - i) * 60 * 60 * 1000;
      final val = 35 + (i % 6) * 5;
      return SoilModel(moisture: val.toDouble(), timestamp: ts);
    });
  }
}
