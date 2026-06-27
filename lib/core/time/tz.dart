import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Inicializa la base de zonas. Llamar una vez en bootstrap y en setUpAll de tests.
void initZonaPanama() {
  tzdata.initializeTimeZones();
}

/// Ubicación fija: Panamá (UTC-5, sin horario de verano).
tz.Location get panama => tz.getLocation('America/Panama');
