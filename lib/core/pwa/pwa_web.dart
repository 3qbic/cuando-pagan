import 'dart:js_interop';

import 'pwa.dart';

@JS('cpPwaEstado')
external JSString? _estado();

@JS('cpPwaAlCambiar')
external void _alCambiar(JSFunction f);

/// Llama a [f] cuando Chrome habilita la instalación directa o la app se instala.
void alCambiarPwa(void Function() f) {
  try {
    _alCambiar(f.toJS);
  } catch (_) {}
}

@JS('cpPwaInstalar')
external JSPromise<JSBoolean>? _instalar();

EstadoPwa estadoPwa() {
  try {
    return switch (_estado()?.toDart) {
      'standalone' => EstadoPwa.standalone,
      'android-prompt' => EstadoPwa.androidPrompt,
      'android' => EstadoPwa.android,
      'ios' => EstadoPwa.ios,
      _ => EstadoPwa.otro,
    };
  } catch (_) {
    return EstadoPwa.otro;
  }
}

Future<bool> instalarPwa() async {
  try {
    final p = _instalar();
    if (p == null) return false;
    return (await p.toDart).toDart;
  } catch (_) {
    return false;
  }
}

@JS('cpRecargar')
external void _recargar();

/// Recarga la página para cargar la versión publicada.
void recargarApp() {
  try {
    _recargar();
  } catch (_) {}
}
