/// Helper functions for quest-related operations.
/// Centralized utilities to avoid code duplication across quest widgets and controllers.

/// Determines if a parameter field requires a value based on its needParam flag.
/// 
/// Handles various representations:
/// - bool: returns the value directly
/// - num: returns true if non-zero
/// - String: returns true if value is 'true', '1', 'yes', or 'y' (case-insensitive)
/// - null: returns false
bool needsParam(Object? value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes' || normalized == 'y';
  }
  return false;
}

/// Converts a dynamic value to a String ID, handling various input types.
/// Returns null if the value cannot be converted to a valid ID.
String? idAsString(dynamic value) {
  if (value == null) return null;
  final str = value.toString();
  if (str.isEmpty || str.toLowerCase() == 'null') return null;
  return str;
}

/// Extracts the state from a quest object safely.
/// Returns null if the quest doesn't have a valid state field.
String? getQuestState(dynamic quest) {
  try {
    return (quest is Map && quest['state'] != null) ? quest['state'].toString() : null;
  } catch (_) {
    return null;
  }
}

/// Extracts the ID from a quest object, trying multiple possible field names.
/// Returns null if no valid ID is found.
String? getQuestId(dynamic quest) {
  try {
    if (quest is Map) {
      if (quest['idQuestUser'] != null) return quest['idQuestUser'].toString();
      if (quest['id'] != null) return quest['id'].toString();
    }
    return null;
  } catch (_) {
    return null;
  }
}

/// Extracts the title from a quest object's header.
/// Returns the provided default title if no title is found.
String getQuestTitle(dynamic quest, {String defaultTitle = 'Misión'}) {
  try {
    if (quest is Map) {
      final header = quest['header'];
      if (header is Map && header['title'] != null) {
        return header['title'].toString();
      }
    }
  } catch (_) {}
  return defaultTitle;
}

/// Parses a dynamic value to a numeric value.
/// Handles int, double, and String representations.
/// Returns null if parsing fails.
num? parseNumeric(Object? value) {
  try {
    if (value == null) return null;
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
  } catch (_) {}
  return null;
}

/// Parses a dynamic value to a DateTime object.
/// Handles DateTime objects, ISO-8601 strings, and millisecond timestamps.
/// Returns null if parsing fails.
DateTime? parseDateTime(dynamic raw) {
  try {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.parse(raw);
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
  } catch (_) {}
  return null;
}
