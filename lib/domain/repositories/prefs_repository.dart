import '../entities/prefs_usuario.dart';

abstract class PrefsRepository {
  Future<PrefsUsuario> cargar();
  Future<void> guardar(PrefsUsuario prefs);
}
