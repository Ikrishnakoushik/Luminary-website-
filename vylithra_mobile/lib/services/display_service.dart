import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DisplayService {
  static const MethodChannel _channel = MethodChannel('in.vylithra.app/display');
  static const String _prefKey = 'display_refresh_rate_mode';

  static final DisplayService _instance = DisplayService._internal();
  factory DisplayService() => _instance;
  DisplayService._internal();

  /// Initialize and apply saved refresh rate preference
  Future<void> init() async {
    final mode = await getSavedMode();
    await applyMode(mode);
  }

  /// Get current display refresh rate in Hz (e.g. 60.0, 90.0, 120.0)
  Future<double> getCurrentRefreshRate() async {
    try {
      final rate = await _channel.invokeMethod<double>('getRefreshRate');
      return rate ?? 60.0;
    } catch (_) {
      return 60.0;
    }
  }

  /// Get list of supported display refresh rates on this device
  Future<List<double>> getSupportedRefreshRates() async {
    try {
      final rates = await _channel.invokeListMethod<double>('getSupportedRefreshRates');
      return rates ?? [60.0];
    } catch (_) {
      return [60.0];
    }
  }

  /// Apply refresh rate mode ('high', '90', 'standard')
  Future<bool> applyMode(String mode) async {
    try {
      final success = await _channel.invokeMethod<bool>('setRefreshRateMode', {'mode': mode});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, mode);
      return success ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Get user's saved refresh rate mode
  Future<String> getSavedMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefKey) ?? 'high';
    } catch (_) {
      return 'high';
    }
  }
}
