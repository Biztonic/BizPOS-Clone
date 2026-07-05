import 'dart:async';
import 'package:flutter/services.dart';

/// Service that detects barcode scanner input from HID (keyboard-emulating)
/// hardware scanners — both USB and Bluetooth.
///
/// Works on Android, Windows, macOS, and Web by listening to
/// [HardwareKeyboard] events. Distinguishes rapid scanner input from
/// normal user typing via inter-key timing (< 80ms between characters
/// is treated as scanner input, vs human typing which is typically > 100ms).
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
  Timer? _scanTimeout;

  bool _isInitialized = false;

  void init() {
    if (_isInitialized) return;
    // Use the modern HardwareKeyboard API instead of deprecated RawKeyboard
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _isInitialized = true;
  }

  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _scanTimeout?.cancel();
    _isInitialized = false;
    // DO NOT close _scanController here as it's a singleton and used across screens
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final now = DateTime.now();
      final timeSinceLastKey = now.difference(_lastKeyTime).inMilliseconds;

      // If time between keys is too long, reset buffer (manual typing vs scanner)
      // Scanners typically send characters < 50ms apart; humans type > 100ms apart
      if (timeSinceLastKey > 80) {
        _buffer = '';
      }
      _lastKeyTime = now;

      // Cancel any pending scan timeout
      _scanTimeout?.cancel();

      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        if (_buffer.trim().isNotEmpty && _buffer.trim().length >= 3) {
          // Only emit if buffer has 3+ chars (real barcodes are at least 3 digits)
          _scanController.add(_buffer.trim());
          _buffer = '';
        }
        return false; // Don't consume Enter key so TextFields can still use it
      } else {
        // Append printable characters
        final char = event.character;
        if (char != null && char.isNotEmpty && char.codeUnitAt(0) >= 32) {
          _buffer += char;

          // Set a timeout: if no Enter comes within 300ms after last char,
          // and buffer has enough chars, treat it as a scan anyway
          // (some scanners may not send Enter)
          _scanTimeout = Timer(const Duration(milliseconds: 300), () {
            if (_buffer.trim().isNotEmpty && _buffer.trim().length >= 6) {
              _scanController.add(_buffer.trim());
              _buffer = '';
            }
          });
        }
      }
    }
    return false; // Don't consume events — let them propagate to TextFields
  }
}
