/// Base del Cloudflare Worker (subdominio de 3qbic). El Worker sirve /v1/* aquí.
const String kWorkerBaseUrl = 'https://cuandopagan.3qbic.com';

/// Días sin fecha futura ni publicación nueva tras los cuales el dato se considera desactualizado.
const int kUmbralStaleDias = 195;

/// Margen tras la última fecha cubierta del dataset para marcar desactualizado.
const int kMargenCoberturaDias = 14;

/// Días tras la fecha de pago durante los cuales el Home muestra el aviso
/// "debía pagarse el X" antes de pasar la página al siguiente evento.
const int kVentanaRecienPagadoDias = 6;

/// Ventana (en días) del anillo de progreso cuando el evento principal es el
/// décimo (que no tiene inicio_registro): el anillo se llena en los últimos
/// [kVentanaAnilloDecimoDias] días antes de la fecha.
const int kVentanaAnilloDecimoDias = 30;
