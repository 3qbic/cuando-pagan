import 'dart:js_interop';

import 'pwa.dart';

@JS('cpPwaEstado')
external JSString? _estado();

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
