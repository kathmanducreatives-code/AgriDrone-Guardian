import 'package:shared_preferences/shared_preferences.dart';

class LabPreferencesService {
  static const String _deviceIpKey = 'lab.device_ip';

  Future<String?> getDeviceIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_deviceIpKey);
  }

  Future<void> setDeviceIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deviceIpKey, ip);
  }
}
