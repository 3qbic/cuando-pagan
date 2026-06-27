enum TemaModo { sistema, claro, oscuro }

class PrefsUsuario {
  final String? seleccionFavorita; // token "cat:.." | "ent:.." | null
  final bool recordatoriosActivos;
  final int diasAnticipacion;
  final int horaRecordatorioMin;
  final bool ocultarNombreInstitucion;
  final TemaModo temaModo;
  final bool onboardingVisto;
  final bool disclaimerAck;
  final int ultimaDataVersion;
  final String? ultimoChequeoIso;

  const PrefsUsuario({
    this.seleccionFavorita, this.recordatoriosActivos = false,
    this.diasAnticipacion = 1, this.horaRecordatorioMin = 480,
    this.ocultarNombreInstitucion = false, this.temaModo = TemaModo.sistema,
    this.onboardingVisto = false, this.disclaimerAck = false,
    this.ultimaDataVersion = 0, this.ultimoChequeoIso,
  });

  PrefsUsuario copyWith({
    String? seleccionFavorita, bool? recordatoriosActivos, int? diasAnticipacion,
    int? horaRecordatorioMin, bool? ocultarNombreInstitucion, TemaModo? temaModo,
    bool? onboardingVisto, bool? disclaimerAck, int? ultimaDataVersion,
    String? ultimoChequeoIso,
  }) => PrefsUsuario(
        seleccionFavorita: seleccionFavorita ?? this.seleccionFavorita,
        recordatoriosActivos: recordatoriosActivos ?? this.recordatoriosActivos,
        diasAnticipacion: diasAnticipacion ?? this.diasAnticipacion,
        horaRecordatorioMin: horaRecordatorioMin ?? this.horaRecordatorioMin,
        ocultarNombreInstitucion: ocultarNombreInstitucion ?? this.ocultarNombreInstitucion,
        temaModo: temaModo ?? this.temaModo,
        onboardingVisto: onboardingVisto ?? this.onboardingVisto,
        disclaimerAck: disclaimerAck ?? this.disclaimerAck,
        ultimaDataVersion: ultimaDataVersion ?? this.ultimaDataVersion,
        ultimoChequeoIso: ultimoChequeoIso ?? this.ultimoChequeoIso,
      );
}
