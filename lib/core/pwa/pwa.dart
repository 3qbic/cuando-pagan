/// Estado de instalación de la PWA. En web lo resuelve `pwa_web.dart` (JS en
/// web/index.html); en VM/tests y móvil nativo, `pwa_stub.dart` dice "otro".
library;

export 'pwa_stub.dart' if (dart.library.js_interop) 'pwa_web.dart';

/// standalone: ya instalada · androidPrompt: Chrome Android ofrece instalar ·
/// android: Android sin prompt (otro navegador) · ios: iPhone/iPad Safari · otro: escritorio.
enum EstadoPwa { standalone, androidPrompt, android, ios, otro }
