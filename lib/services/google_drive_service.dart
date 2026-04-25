import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';

class GoogleDriveService {
  // Scopes required for the application
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveFileScope,
    ],
  );

  GoogleSignInAccount? _currentUser;
  bool get isLinked => _currentUser != null;

  Future<void> restoreSession() async {
    try {
      _currentUser = await _googleSignIn.signInSilently();
    } catch (_) { /* Error ignored */ }
  }

  /// Initiate the Google Sign-In flow
  Future<bool> linkAccount() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        _currentUser = account;
        return true;
      }
      return false; // User cancelled
    } catch (e) {

      rethrow;
    }
  }

  /// Sign out
  Future<void> unlinkAccount() async {
    try {
      await _googleSignIn.disconnect();
      _currentUser = null;
    } catch (e) { /* Error ignored */ }
  }

  /// Upload JSON content to Google Drive
  Future<bool> uploadBackup(String jsonData, {String filename = 'backup.json'}) async {
    if (_currentUser == null) return false;

    try {
      // Get authenticated HTTP client
      final httpClient = await _googleSignIn.authenticatedClient();
      if (httpClient == null) return false;

      final driveApi = drive.DriveApi(httpClient);

      // Create File Metadata
      var fileToUpload = drive.File();
      fileToUpload.name = filename;
      fileToUpload.mimeType = 'application/json';

      // Create Content
      final uploadMedia = drive.Media(
        Stream.value(utf8.encode(jsonData)),
        utf8.encode(jsonData).length,
      );

      // Upload
      await driveApi.files.create(
        fileToUpload,
        uploadMedia: uploadMedia,
      );

      return true;
    } catch (e) {

      return false;
    }
  }
}
