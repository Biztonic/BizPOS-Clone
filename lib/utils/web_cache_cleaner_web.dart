// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void clearWebBrowserStorage() {
  try {
    html.window.localStorage.clear();
    html.window.sessionStorage.clear();
  } catch (_) {}
}

void reloadWebPage() {
  try {
    html.window.location.reload();
  } catch (_) {}
}
