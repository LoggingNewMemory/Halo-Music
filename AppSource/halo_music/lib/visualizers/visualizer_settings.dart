import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VisualizerSettings extends ValueNotifier<String> {
  static final VisualizerSettings instance = VisualizerSettings._();

  VisualizerSettings._() : super('wave') {
    // 'wave' as default, can be 'cube', 'bars', 'wave', or 'none'
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    value = prefs.getString('active_visualizer') ?? 'wave';
  }

  Future<void> setVisualizer(String type) async {
    value = type;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_visualizer', type);
  }
}
