// formatDate — the one place a date is rendered as a short m/d/yyyy
// string. Previously copied into several screens; keep it in one module.
String formatDate(DateTime d) {
  final local = d.toLocal();
  return '${local.month}/${local.day}/${local.year}';
}

// formatTime — 24h HH:MM wall-clock stamp for "last updated" indicators.
String formatTime(DateTime d) {
  final local = d.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}
