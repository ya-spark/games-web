// The few browser calls the web product needs, behind one import so the rest compiles (and is tested) on the Dart VM:
// the web build uses web_platform_web.dart (package:web), tests and any other platform use the stub.
export 'web_platform_stub.dart' if (dart.library.js_interop) 'web_platform_web.dart';
