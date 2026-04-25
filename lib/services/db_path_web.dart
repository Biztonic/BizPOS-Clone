
Future<String> getDatabasePath(String dbName) async {
  return 'biztonic_pos.db';
}

Future<void> ensureDbDirectory(String path) async {
  // No-op on web
}
