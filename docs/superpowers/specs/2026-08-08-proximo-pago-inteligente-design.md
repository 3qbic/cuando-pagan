# Spec — Próximo pago inteligente (quincena + décimo unificados en el Home)

**Estado:** Diseño aprobado por el usuario (2026-08-08). Pendiente: plan de implementación.
**Contexto:** el 6 de agosto de 2026 se pagó el XIII Mes ANTES de la quincena de agosto, y el Home
de la app ni lo mencionó (el contador solo mira quincenas). El usuario, funcionario público, se
enteró por fuera de la app. Este spec corrige eso.

## 0. Ajuste de invariante (prevalece sobre §0.1 del spec maestro)

El spec maestro (`2026-06-26-app-cuando-pagan-design.md` §0.1) dice "XIII Mes bajo demanda
(solo al buscarlo)". **Este spec lo modifica:** el XIII entra al contador del Home cuando es el
evento de pago más cercano. La pestaña Décimo sigue existiendo tal cual. El resto de §0.1
(zona `America/Panamá` fija, `fecha_pago` verbatim, cero tracking, wire tolerante) queda intacto.

## 1. Qué hace (decisiones ya tomadas por el usuario)

1. **Home inteligente (contador único):** el hero del Home muestra el próximo dinero de
   CUALQUIER tipo — quincena de su categoría o décimo (universal, aplica a todas las
   categorías) — el que esté más cerca.
2. **Ventana "recién pagado":** cuando una fecha llega o acaba de pasar:
   - Día del pago (`diasRestantes == 0`): "¡Hoy te toca!" + etiqueta del tipo.
   - 1 a 6 días después: aviso "Debía pagarse el {fecha}. Si no te ha llegado, recuerda que la
     fecha es referencial; confírmalo con tu planilla o el MEF." y DEBAJO ya se muestra el
     siguiente evento futuro con su contador.
   - Día 7 en adelante: el aviso desaparece; solo el siguiente evento.
3. **Empate** (quincena y décimo el mismo día): se muestran ambas etiquetas en el hero.
4. La tarjeta **"Proceso del pago"** (Registro→Cierre→ACH→Pago) **solo aplica a quincenas**
   (el XIII no tiene ventana de registro en el dataset). Si el evento principal es décimo, se oculta.

## 2. Dominio (Dart puro, testeable headless)

### 2.1 Modelo nuevo — `lib/domain/entities/evento_pago.dart`

```dart
enum TipoEvento { quincena, decimo }

class EventoPago {
  final DateTime fecha;              // UTC 00:00, misma convención del resto del dominio
  final Set<TipoEvento> tipos;       // {quincena}, {decimo} o ambos si empatan
  final EntradaCalendario? entrada;  // non-null si incluye quincena (para el timeline/estado)
  final XiiiMes? xiii;               // non-null si incluye décimo
  final EstadoFecha estado;          // quincena → entrada.estado; solo décimo → publicada
  final int diasRestantes;           // negativo si ya pasó (p. ej. -3)
}

class ResultadoProximoEvento {
  final EventoPago? proximo;        // hoy o futuro más cercano; null si no hay
  final EventoPago? recienPasado;   // evento con fecha en [hoy-6, hoy-1]; null si no aplica
  final ProximoPago base;           // resultado actual de calcularProximoPago (fallback
                                    // Pendiente/Desactualizada y metadatos de manifest)
}
```

### 2.2 Lógica nueva — `lib/domain/logic/proximo_evento.dart`

```dart
ResultadoProximoEvento calcularProximoEvento({
  required List<EntradaCalendario> entradasDeCategoria,
  required List<XiiiMes> xiii,
  required Seleccion seleccion,
  required Manifest manifest,
  required int remoteDataVersion,
  DateTime? ahora,
});
```

Reglas:
1. `hoy = hoyPanama(ahora)` — SIEMPRE la zona fija de Panamá, nunca la del dispositivo.
2. Construir eventos: cada `EntradaCalendario` futura o en ventana → evento `quincena`;
   cada `XiiiMes` futura o en ventana → evento `decimo`. Fusionar por fecha exacta
   (mismo día ⇒ un evento con ambos tipos).
3. `proximo` = evento con `fecha >= hoy` más cercano (diasRestantes >= 0).
4. `recienPasado` = evento con fecha en `[hoy-kVentanaRecienPagadoDias, hoy-1]` más
   reciente; si el mismo día de hoy hay pago, NO hay recienPasado (hoy manda).
5. `base` = `calcularProximoPago(...)` actual, sin modificarlo — aporta el fallback
   Pendiente/Desactualizada (cuando `proximo == null`) y los metadatos (fuente, versión).
6. Estado del evento: si incluye quincena → `entrada.estado` (publicada/modificada/…);
   si es solo décimo → `EstadoFecha.publicada` (las fechas del XIII vienen del mismo
   calendario oficial del MEF; modelo v1 "solo fuente pública").
7. `fecha_pago` verbatim: cero corrimientos por fin de semana o feriado (invariante).

### 2.3 Constante nueva — `lib/core/constants/umbrales.dart`

```dart
/// Días tras la fecha de pago durante los cuales el Home muestra el aviso
/// "debía pagarse el X" antes de pasar la página al siguiente evento.
const int kVentanaRecienPagadoDias = 6;
```

(6 = mismo valor que usaba el aviso `_pagoReciente` del prototipo claro; cubre fin de semana
largo + días de acreditación bancaria lenta.)

## 3. UI (`lib/main.dart`, tema oscuro actual)

- **`HomeTab`** pasa a llamar `calcularProximoEvento` (en vez de `calcularProximoPago` directo).
- **`_HeroCard`**:
  - Etiqueta de tipo junto al overline "PRÓXIMO PAGO": chip `QUINCENA` (esmeralda) o
    `DÉCIMO` (dorado, con ícono de regalo); ambos si empatan.
  - `diasRestantes == 0` → el anillo muestra "HOY" (ya existe) y el overline cambia a
    "¡HOY TE TOCA!".
  - Anillo de progreso para décimo: ventana fija de 30 días antes de la fecha
    (el décimo no tiene `inicio_registro`); quincena sigue usando `_progreso` actual.
- **Aviso recién-pagado** (nuevo widget, estilo ámbar/dorado ya usado en la app):
  se muestra ENCIMA del hero cuando `recienPasado != null`. Texto:
  "Debía pagarse el {d 'de' MMMM}. Si no te ha llegado, recuerda que la fecha es
  referencial; confírmalo con tu planilla o el MEF." (+ etiqueta del tipo).
- **`_ProcesoCard`**: se renderiza solo si `proximo.entrada != null` (hay quincena).
- **Cross-link a «XIII Mes Panamá»** (app hermana del mismo autor, Google Play
  `com.amgd.xiiimespanama` — calcula CUÁNTO te toca; esta app dice CUÁNDO):
  - Tarjeta al final de la pestaña **Décimo**: "¿Quieres saber cuánto te toca? Calcúlalo
    con XIII Mes Panamá →" (abre la ficha de Play vía url_launcher; en iOS/Web abre la
    misma URL de Play, que funciona como página web).
  - Enlace secundario compacto en el Home cuando el evento principal es décimo.
  - Es un enlace externo simple: sin SDKs, sin tracking (invariante intacto). Se declara
    como app hermana "también independiente y no oficial" para no diluir el disclaimer.
- **Pestaña Calendario:** sin cambios en v1.
- Todos los textos en español neutral panameño (tuteo), 12h AM/PM donde aplique.

## 4. Datos

**Cero cambios.** El XIII ya viaja en `assets/seed/all.json` y en `/v1/all` (`xiii_mes`), y ya se
carga en `Dataset.xiii` ordenado. El pipeline no se toca.

## 5. Pruebas (headless, `test/domain/logic/proximo_evento_test.dart`)

Casos mínimos (con `ahora` inyectado, nunca reloj real):
1. Décimo más cercano que la quincena → gana décimo (caso 6-ago-2026 real).
2. Quincena más cercana → gana quincena.
3. Empate exacto de fechas → un evento con ambos tipos.
4. Hoy es día de pago → `diasRestantes == 0`, sin `recienPasado`.
5. Pago hace 1..6 días → `recienPasado` presente Y `proximo` apunta al siguiente.
6. Pago hace 7 días → `recienPasado == null`.
7. Sin eventos futuros → `proximo == null` y `base.estado` Pendiente/Desactualizada
   (delegado al `calcularProximoPago` existente, que ya tiene sus tests).
8. Estado: quincena modificada conserva su estado; décimo solo → publicada.
9. Zona horaria: resultados idénticos con `ahora` en UTC y con offset de dispositivo ≠ Panamá.

## 6. Fuera de alcance (v1)

- Notificaciones/recordatorios locales.
- Worker API (tiene spec propio: `2026-07-05-worker-api-deploy-spec.md`).
- "Agenda" de próximos N pagos (idea futura; el usuario eligió el Home inteligente).
- Mezclar el décimo dentro de la pestaña Calendario.
- Cambios de pipeline o de modelo de datos.

## 7. Riesgos

- **Off-by-one de fechas**: toda la lógica vive en dominio puro con `ahora` inyectable y
  zona fija — se cubre con los tests §5.
- **Confusión quincena/décimo en la UI**: mitigada con el chip de tipo siempre visible.
- **Mensaje "debía pagarse"**: riesgo de sonar a acusación al MEF → el copy siempre
  acompaña con "referencial" + "confírmalo con tu planilla o el MEF" (posicionamiento
  no-oficial intacto, Definition of Done).
