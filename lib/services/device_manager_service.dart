// ignore_for_file: constant_identifier_names
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum DisplayType { cfd, order_board, digital_signage }
enum DisplayConnection { hdmi, network, browser }

class DisplayDevice {
  String name;
  String? address;
  DisplayType type;
  DisplayConnection connection;

  DisplayDevice({required this.name, this.address, required this.type, required this.connection});

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'type': type.index,
        'connection': connection.index,
      };

  factory DisplayDevice.fromJson(Map<String, dynamic> json) => DisplayDevice(
        name: json['name'],
        address: json['address'],
        type: DisplayType.values[json['type']],
        connection: DisplayConnection.values[json['connection']],
      );
}

class DeviceManagerService {
  static final DeviceManagerService _instance = DeviceManagerService._internal();

  factory DeviceManagerService() {
    return _instance;
  }

  DeviceManagerService._internal();

  List<DisplayDevice> _savedDisplays = [];
  List<DisplayDevice> get savedDisplays => _savedDisplays;

  Future<void> init() async {
    await _loadSavedDisplays();
  }

  Future<void> addDisplay(DisplayDevice device) async {
    _savedDisplays.add(device);
    await _saveDisplays();
  }

  Future<void> removeDisplay(int index) async {
    if (index >= 0 && index < _savedDisplays.length) {
      _savedDisplays.removeAt(index);
      await _saveDisplays();
    }
  }

  Future<void> _saveDisplays() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> jsonList = _savedDisplays.map((d) => json.encode(d.toJson())).toList();
    await prefs.setStringList('saved_display_devices', jsonList);
  }

  Future<void> _loadSavedDisplays() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? jsonList = prefs.getStringList('saved_display_devices');
    if (jsonList != null) {
      try {
        _savedDisplays = jsonList.map((jsonStr) => DisplayDevice.fromJson(json.decode(jsonStr))).toList();
      } catch (e) { /* Error ignored */ }
    }
    
    // Fallback Mock Data if empty (so user sees something initially)
    if (_savedDisplays.isEmpty) {
        _savedDisplays.addAll([
            DisplayDevice(name: "HDMI - Main Counter TV", type: DisplayType.digital_signage, connection: DisplayConnection.hdmi),
            DisplayDevice(name: "Kitchen Monitor 1", type: DisplayType.order_board, connection: DisplayConnection.network, address: "192.168.1.50"),
        ]);
        await _saveDisplays();
    }
  }
}
