
import 'dart:io';
import 'package:sqflite/sqflite.dart'; // for getDatabasesPath
import 'package:path/path.dart';

Future<String> getDatabasePath(String dbName) async {
  // Native Init Logic
  if (Platform.isWindows) {
     final exeDir = File(Platform.resolvedExecutable).parent.path;
     final dataDir = join(exeDir, 'data');
     try {
       await Directory(dataDir).create(recursive: true);
     } catch (e) { /* Error ignored */ }
     return join(dataDir, dbName);
  } else {
     return join(await getDatabasesPath(), dbName);
  }
}

Future<void> ensureDbDirectory(String path) async {
   // Already handled in getDatabasePath for Windows, and Android handles it via getDatabasesPath usually.
}
