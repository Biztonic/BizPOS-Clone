import 'web_cache_cleaner_stub.dart'
    if (dart.library.html) 'web_cache_cleaner_web.dart';

void cleanBrowserStorage() => clearWebBrowserStorage();
void reloadAppPage() => reloadWebPage();
