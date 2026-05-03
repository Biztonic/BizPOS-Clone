import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'widgetbook.directories.g.dart';

// This file configures Widgetbook to be an internal UI laboratory.
// Run `flutter pub run build_runner build -d` to generate the directories.
void main() {
  runApp(const WidgetbookApp());
}

@widgetbook.App()
class WidgetbookApp extends StatelessWidget {
  const WidgetbookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      directories: directories,
      addons: [
        ThemeAddon(
          themes: [
            WidgetbookTheme(
              name: 'Light',
              data: ThemeData.light(),
            ),
            WidgetbookTheme(
              name: 'Dark',
              data: ThemeData.dark(),
            ),
          ],
          themeBuilder: (context, theme, child) {
            return Theme(
              data: theme,
              child: child,
            );
          },
        ),
        DeviceFrameAddon(
          devices: [
            Devices.ios.iPhone13,
            Devices.ios.iPad,
            Devices.android.mediumPhone,
            Devices.android.largeTablet,
          ],
        ),
        TextScaleAddon(
          scales: [1.0, 1.25, 1.5, 2.0],
        ),
      ],
    );
  }
}
