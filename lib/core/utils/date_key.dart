/// Utilidad única de formato de fechas para claves de persistencia.
///
/// Devuelve la fecha canónica `YYYY-MM-DD` con ceros a la izquierda
/// (formato ISO-8601 de fecha), p. ej. `2026-09-06`.
///
/// Antes cada módulo generaba sus propias claves: macro_bridge usaba
/// sin ceros (`2026-9-6`) y el resto de la app usaba
/// `toIso8601String().split('T')[0]` (con ceros, `2026-09-06`). Dos formatos
/// para la misma cosa hacían que las claves nunca coincidieran.
///
/// TODA clave de persistencia que incluya una fecha debe pasar por aquí
/// (food_repository, macro_bridge, contadores diarios, etc.).
String formatDateKey(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
