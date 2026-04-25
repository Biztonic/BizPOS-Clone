class GoogleDriveHelper {
  /// Converts a Google Drive sharing link to a direct download link.
  /// Handles formats:
  /// - https://drive.google.com/file/d/FILE_ID/view?usp=sharing
  /// - https://drive.google.com/open?id=FILE_ID
  /// - https://drive.google.com/uc?id=FILE_ID
  static String? convertToDirectLink(String url) {
    if (!isGoogleDriveLink(url)) return url;

    try {
      String fileId = '';
      if (url.contains('/file/d/')) {
        fileId = url.split('/file/d/')[1].split('/')[0].split('?')[0];
      } else if (url.contains('id=')) {
        fileId = url.split('id=')[1].split('&')[0];
      }

      if (fileId.isNotEmpty) {
        return 'https://drive.google.com/uc?id=$fileId&export=download';
      }
    } catch (e) {
      // Return original if parsing fails
    }
    return url;
  }

  static bool isGoogleDriveLink(String url) {
    return url.contains('drive.google.com');
  }
}
