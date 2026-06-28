# Brief para claude.ai/design — App "¿Cuándo Pagan?"

> Pegá esto en claude.ai/design. Cuando tengas el diseño que te guste, traé las pantallas (capturas o export) a Claude Code y se construye en Flutter.

---

Diseñá una **app móvil** llamada **"¿Cuándo Pagan?"** (Android / iOS / Web).

**Qué es:** app **independiente y NO oficial** que le muestra a funcionarios públicos y jubilados de Panamá **cuándo les pagan** (las fechas de pago del sector público que publica el MEF). NO representa al Gobierno ni a ninguna entidad.

**Dirección visual (IMPORTANTE):** **clara, limpia y confiable**. Fondo blanco / gris muy claro, mucho espacio en blanco, **un solo color de acento sobrio (azul o teal)**, tipografía **sans-serif** legible. Sensación de **app financiera / fintech moderna y seria**.
**EVITAR:** dark mode como base, colores neón o lima, tipografías serif editoriales, gradientes genéricos, el morado de Material Design, y cualquier **escudo, bandera o colores de la bandera de Panamá** (no debe parecer oficial del Gobierno).

**Pantallas a diseñar:**
1. **Home / Próximo pago** — muestra la institución elegida y su próximo pago: **fecha grande + contador "Faltan N días" + estado de la fecha**. Diseñá 3 variantes: (a) con dato, (b) "Pendiente" (el MEF aún no publica ese período), (c) "sin institución elegida" (con un botón claro para elegirla).
2. **Selector de institución** — un buscador (escribir "MIDES" debe encontrar "Min. de Desarrollo Social") + lista de instituciones.
3. **Calendario anual** — las quincenas del año por categoría, con su estado.
4. **Detalle de quincena** — la fecha de pago, su estado, y de dónde sale (**"Fuente pública: MEF"** con enlace para verificar).
5. **Acerca de** — el aviso de que la app es independiente y no oficial.

**Reglas no negociables (incluilas en el diseño):**
- Un **badge "No oficial"** visible **en todas las pantallas**.
- Junto a **cada fecha**, la atribución **"Fuente pública: MEF"**.
- El **estado de cada fecha** (Publicada / Pendiente / Modificada / Desactualizada) mostrado con **icono + texto + color** (nunca solo color — por accesibilidad).
- **Español de Panamá**, horas en formato **12h AM/PM**.
- **Accesible:** buen contraste, textos grandes y legibles (público incluye adultos mayores), áreas tocables amplias.

**Datos reales (para que los ejemplos cuadren):**
- Categorías de pago: **Jubilados, Gastos de representación, Grupo 1, Grupo 2, Grupo 3**.
- Ejemplo recurrente: **MIDES (Min. de Desarrollo Social) = Grupo 3**.
- Las fechas son del calendario del MEF (ej.: un pago el "23 de julio").
