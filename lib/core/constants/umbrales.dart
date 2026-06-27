/// Base del Cloudflare Worker existente. Reemplazar por la URL real tras `wrangler deploy`.
const String kWorkerBaseUrl = 'https://calendario-pago-pa.example.workers.dev';

/// Días sin fecha futura ni publicación nueva tras los cuales el dato se considera desactualizado.
const int kUmbralStaleDias = 195;

/// Margen tras la última fecha cubierta del dataset para marcar desactualizado.
const int kMargenCoberturaDias = 14;
