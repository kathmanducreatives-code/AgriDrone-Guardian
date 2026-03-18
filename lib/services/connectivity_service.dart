import "package:flutter/material.dart";
import 'dart:async';
import 'package:http/http.dart' as http;

enum DroneConnectionState {
  direct, // Same WiFi as drone (192.168.1.76)
  cloud,  // Remote monitoring via Firebase
  offline // No data from either
}

class ConnectivityService {
  static const String defaultDroneIp = '192.168.1.76';

  String _droneIp = defaultDroneIp;
  final Duration pingInterval = const Duration(seconds: 10);
  
  final _connectionStateController = StreamController<DroneConnectionState>.broadcast();
  Stream<DroneConnectionState> get connectionStateStream => _connectionStateController.stream;

  final _latencyController = StreamController<Duration>.broadcast();
  Stream<Duration> get latencyStream => _latencyController.stream;

  Timer? _pingTimer;
  DroneConnectionState _currentState = DroneConnectionState.offline;
  bool _firebaseConnected = false;

  String get droneIp => _droneIp;

  void updateDroneIp(String value) {
    _droneIp = value.trim().isEmpty ? defaultDroneIp : value.trim();
  }

  void startPinging() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(pingInterval, (_) => _checkDirectConnection());
    _checkDirectConnection(); // Initial check
  }

  void stopPinging() {
    _pingTimer?.cancel();
  }

  void updateFirebaseStatus(bool connected) {
    _firebaseConnected = connected;
    _updateState();
  }

  Future<void> _checkDirectConnection() async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await http.get(Uri.parse('http://$_droneIp/')).timeout(const Duration(seconds: 3));
      stopwatch.stop();
      if (response.statusCode == 200) {
        _latencyController.add(stopwatch.elapsed);
        _setInternalState(DroneConnectionState.direct);
      } else {
        _setInternalState(_firebaseConnected ? DroneConnectionState.cloud : DroneConnectionState.offline);
      }
    } catch (_) {
      _setInternalState(_firebaseConnected ? DroneConnectionState.cloud : DroneConnectionState.offline);
    }
  }

  void _setInternalState(DroneConnectionState state) {
    if (_currentState != state) {
      _currentState = state;
      _connectionStateController.add(_currentState);
    }
  }

  void _updateState() {
    // If we were direct, we stay direct unless the ping fails (handled in _checkDirectConnection)
    // If we were not direct, and firebase status changed, we update to cloud or offline
    if (_currentState != DroneConnectionState.direct) {
      _setInternalState(_firebaseConnected ? DroneConnectionState.cloud : DroneConnectionState.offline);
    }
  }

  Future<bool> triggerCapture() async {
    try {
      final response = await http.get(Uri.parse('http://$_droneIp/capture')).timeout(const Duration(seconds: 15));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Local capture failed: $e');
      return false;
    }
  }

  Future<String> forceStartDirect() async {
    try {
      final response = await http.get(Uri.parse('http://$_droneIp/START')).timeout(const Duration(seconds: 10));
      return 'Status: ${response.statusCode} - ${response.body}';
    } on TimeoutException {
      return 'Connection Failed: Timeout (10s) - Ensure you are on the drone\'s WiFi network.';
    } catch (e) {
      return 'Connection Failed: $e - Drone unreachable.';
    }
  }

  void dispose() {
    _pingTimer?.cancel();
    _connectionStateController.close();
    _latencyController.close();
  }
}
