export 'web_isolation_stub.dart'
    if (dart.library.js_util) 'web_isolation_web.dart'
    if (dart.library.html) 'web_isolation_web.dart';
