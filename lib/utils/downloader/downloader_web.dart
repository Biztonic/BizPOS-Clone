// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter, unused_local_variable
import 'dart:html' as html;
import 'dart:convert';

void downloadFileWeb(String filename, String content) {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute("download", filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
