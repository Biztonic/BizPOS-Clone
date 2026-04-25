import 'dart:async';

class PrinterLogService {
  static final PrinterLogService _instance = PrinterLogService._internal();
  factory PrinterLogService() => _instance;
  PrinterLogService._internal();

  final StreamController<String> _logController = StreamController<String>.broadcast();
  Stream<String> get logStream => _logController.stream;

  final List<String> _logs = [];
  List<String> get logs => List.unmodifiable(_logs);

  void log(String message) {
    final timestamp = DateTime.now().toIso8601String().split('T').last.split('.').first;
    final logMessage = "[$timestamp] $message";
    _logs.add(logMessage);
    // Keep only last 100 logs
    if (_logs.length > 100) {
      _logs.removeAt(0);
    }
    _logController.add(logMessage);
  }

  void clearLogs() {
    _logs.clear();
    _logController.add("Logs cleared.");
  }
}
