import 'dart:io';

void main() {
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    print('Error: lib directory not found.');
    exit(1);
  }

  // Exempt directories from styling checks
  final exemptDirs = ['lib/core/design'];

  bool hasViolations = false;

  final dartFiles = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));

  for (final file in dartFiles) {
    // Check if the file is in an exempt directory
    if (exemptDirs.any((dir) => file.path.replaceAll('\\', '/').startsWith(dir))) {
      continue;
    }

    final lines = file.readAsLinesSync();
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Exclude comments
      if (line.trim().startsWith('//')) {
        continue;
      }

      // Check for hardcoded EdgeInsets
      if (line.contains(RegExp(r'EdgeInsets\.(all|symmetric|only)\s*\('))) {
        // Warning: This catches legitimate uses but in a strict design system, 
        // you should be using AppSpacing tokens instead of raw numbers.
        // We'll look for raw numbers passed to EdgeInsets.
        if (line.contains(RegExp(r'EdgeInsets\.(all|symmetric|only)\s*\([^a-zA-Z]*[0-9]+(\.[0-9]+)?[^a-zA-Z]*\)'))) {
            print('Violation in ${file.path}:${i + 1}');
            print('  Found hardcoded EdgeInsets value: $line');
            print('  -> Use AppSpacing tokens instead.');
            hasViolations = true;
        }
      }

      // Check for hardcoded Colors (Colors.red, Color(0xFF...))
      if (line.contains(RegExp(r'Colors\.[a-z]')) || line.contains(RegExp(r'Color\(\s*0x'))) {
        print('Violation in ${file.path}:${i + 1}');
        print('  Found hardcoded Color value: $line');
        print('  -> Use Theme.of(context) or AppColors tokens instead.');
        hasViolations = true;
      }
    }
  }

  if (hasViolations) {
    print('\nDesign System Governance Failed: Found hardcoded styles outside of lib/core/design.');
    // In strict CI, uncomment the next line to fail the build:
    // exit(1);
  } else {
    print('Design System Governance Passed: No hardcoded styles detected.');
  }
}
