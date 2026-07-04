// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:flutter/services.dart';

class ScannerService {
  // Singleton
  static final ScannerService _instance = ScannerService._internal();
  factory ScannerService() => _instance;
  ScannerService._internal();

  final StreamController<String> _scanController = StreamController<String>.broadcast();
  Stream<String> get scanStream => _scanController.stream;

  // Buffer for HID keyboard input
  String _buffer = '';
  DateTime _lastKeyTime = DateTime.now();

  bool _isInitialized = false;

  void init() {
    if (_isInitialized) return;
    // Listen to raw keyboard events
    RawKeyboard.instance.addListener(_handleKeyEvent);
    _isInitialized = true;
  }

  void dispose() {
    RawKeyboard.instance.removeListener(_handleKeyEvent);
    _isInitialized = false;
    // DO NOT close _scanController here as it's a singleton and used across screens
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final now = DateTime.now();
      // If time between keys is too long, reset buffer (manual typing vs scanner)
      if (now.difference(_lastKeyTime).inMilliseconds > 150) {
        _buffer = '';
      }
      _lastKeyTime = now;

      if (event.logicalKey == LogicalKeyboardKey.enter || 
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        if (_buffer.trim().isNotEmpty) {
          _scanController.add(_buffer.trim());
          _buffer = '';
        }
      } else {
        // Append printable characters
        if (event.character != null && event.character!.isNotEmpty) {
          _buffer += event.character!;
        }
      }
    }
  }
}
