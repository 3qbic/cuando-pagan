/// Base del Cloudflare Worker (subdominio de 3qbic). El Worker sirve /v1/* aquí.
const String kWorkerBaseUrl = 'https://cuandopagan.3qbic.com';

/// Días sin fecha futura ni publicación nueva tras los cuales el dato se considera desactualizado.
const int kUmbralStaleDias = 195;

/// Margen tras la última fecha cubierta del dataset para marcar desactualizado.
const int kMargenCoberturaDias = 14;
