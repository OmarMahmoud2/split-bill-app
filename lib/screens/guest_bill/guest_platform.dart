/// Browser facts the guest page needs (user agent checks). Stubbed off web.
library;

export 'guest_platform_stub.dart'
    if (dart.library.js_interop) 'guest_platform_web.dart';
