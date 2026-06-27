import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/prefs_usuario.dart';
import '../../domain/repositories/prefs_repository.dart';

class PrefsLocal implements PrefsRepository {
  PrefsLocal(this._sp);
  final SharedPreferences _sp;

  @override
  Future<PrefsUsuario> cargar() async => PrefsUsuario(
        seleccionFavorita: _sp.getString('favorita'),
        recordatoriosActivos: _sp.getBool('recordatorios') ?? false,
        diasAnticipacion: _sp.getInt('anticipacion') ?? 1,
        horaRecordatorioMin: _sp.getInt('horaMin') ?? 480,
        ocultarNombreInstitucion: _sp.getBool('ocultarNombre') ?? false,
        temaModo: TemaModo.values[_sp.getInt('tema') ?? 0],
        onboardingVisto: _sp.getBool('onboarding') ?? false,
        disclaimerAck: _sp.getBool('disclaimerAck') ?? false,
        ultimaDataVersion: _sp.getInt('ultimaVersion') ?? 0,
        ultimoChequeoIso: _sp.getString('ultimoChequeo'),
      );

  @override
  Future<void> guardar(PrefsUsuario p) async {
    await _sp.setBool('recordatorios', p.recordatoriosActivos);
    await _sp.setInt('anticipacion', p.diasAnticipacion);
    await _sp.setInt('horaMin', p.horaRecordatorioMin);
    await _sp.setBool('ocultarNombre', p.ocultarNombreInstitucion);
    await _sp.setInt('tema', p.temaModo.index);
    await _sp.setBool('onboarding', p.onboardingVisto);
    await _sp.setBool('disclaimerAck', p.disclaimerAck);
    await _sp.setInt('ultimaVersion', p.ultimaDataVersion);
    if (p.seleccionFavorita != null) await _sp.setString('favorita', p.seleccionFavorita!);
    if (p.ultimoChequeoIso != null) await _sp.setString('ultimoChequeo', p.ultimoChequeoIso!);
  }
}
