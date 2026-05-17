import 'package:flutter/material.dart';

class RouterNotifier extends ChangeNotifier {
  void notify() {
    debugPrint('🔔 RouterNotifier: Notifying listeners...');
    notifyListeners();
  }
}
