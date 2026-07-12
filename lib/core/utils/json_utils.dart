/// Lenient JSON coercion helpers shared by model `fromJson` factories.
///
/// Backup, snapshot and journal files are long-lived on disk and may have been
/// written by an older app version, so every field is parsed defensively: a
/// missing or malformed value must never throw and lose the rest of a record.
library;

DateTime? parseDateOrNull(dynamic value) {
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}

DateTime parseDate(dynamic value) => parseDateOrNull(value) ?? DateTime.fromMillisecondsSinceEpoch(0);

int parseInt(dynamic value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double parseDouble(dynamic value, {double fallback = 0.0}) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

double? parseDoubleOrNull(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

bool parseBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value.toLowerCase() == 'true';
  return fallback;
}

String parseString(dynamic value, {String fallback = ''}) {
  if (value is String) return value;
  if (value == null) return fallback;
  return value.toString();
}

List<String> parseStringList(dynamic value) {
  if (value is List) return value.map((e) => e.toString()).toList();
  return const [];
}

Map<String, dynamic> parseMap(dynamic value) {
  if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
  return const {};
}
