// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Validation Agent that acts effectively as an AI user interacting with the app.
class AppDriver {
  final WidgetTester tester;

  AppDriver(this.tester);

  /// Taps a widget by its Key and waits for the animation to settle.
  Future<void> tap(String key) async {
    final finder = find.byKey(Key(key));
    if (!tester.any(finder)) {
      // Try scrolling to it if in a scroll view?
      // For now, fail with clear message
      throw Exception("Element with Key '$key' not found on screen.");
    }
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }
  
  /// Taps a widget by text content
  Future<void> tapText(String text) async {
    final finder = find.text(text);
     if (!tester.any(finder)) {
      throw Exception("Element with Text '$text' not found on screen.");
    }
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Taps a widget by its Tooltip message
  Future<void> tapTooltip(String message) async {
    final finder = find.byTooltip(message);
     if (!tester.any(finder)) {
      throw Exception("Element with Tooltip '$message' not found.");
    }
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Enters text into a TextField found by Key.
  Future<void> enterText(String key, String text) async {
    final finder = find.byKey(Key(key));
    await tester.enterText(finder, text);
    await tester.pumpAndSettle();
  }

  /// Verifies that a widget with the given Key exists.
  void expectKey(String key) {
    expect(find.byKey(Key(key)), findsOneWidget, reason: "Expected to find widget with Key '$key'");
  }

  /// Verifies that text exists.
  void expectText(String text) {
    expect(find.text(text), findsOneWidget, reason: "Expected to find text '$text'");
  }
  
  /// Verifies text does NOT exist.
  void expectNoText(String text) {
    expect(find.text(text), findsNothing, reason: "Expected NOT to find text '$text'");
  }

  /// Waits for a Finder to find a widget.
  Future<void> waitFor(Finder finder, {Duration timeout = const Duration(seconds: 20)}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      if (tester.any(finder)) return;
      await tester.pump(const Duration(milliseconds: 500));
    }
    throw Exception("Timed out waiting for $finder");
  }
  
  /// Waits for text to appear
  Future<void> waitForText(String text) async {
    await waitFor(find.text(text));
  }

  /// Waits for a specified duration (useful for simulated delays).
  Future<void> wait(int milliseconds) async {
    await tester.pump(Duration(milliseconds: milliseconds));
  }

  /// Opens the drawer if the hamburger menu is present (Mobile).
  Future<void> openDrawer() async {
    final tooltip = find.byTooltip('Open navigation menu');
    if (tester.any(tooltip)) {
      await tester.tap(tooltip);
      await tester.pumpAndSettle();
    }
  }
}
