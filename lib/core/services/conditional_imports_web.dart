// Web Stub Implementation
// Diese Datei wird nur für Web-Compilation verwendet
import 'dart:html';

dynamic createNativeSecureStorage() {
  throw UnsupportedError('FlutterSecureStorage wird auf Web-Plattformen nicht unterstützt');
}

String _getWebUserAgentInternal() {
  return window.navigator.userAgent;
}
