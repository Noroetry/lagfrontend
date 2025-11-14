/// Helper functions for user-related data parsing.
/// Centralized utilities to avoid code duplication across UI widgets.
library;

/// Parses a dynamic value to a numeric value.
/// Handles int, double, and String representations.
/// Returns null if parsing fails.
/// 
/// This is commonly used for XP, coins, and other numeric user stats.
num? parseNum(Object? value) {
  try {
    if (value == null) return null;
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
  } catch (_) {}
  return null;
}

/// Calculates the XP progress ratio for a level.
/// 
/// Returns a value between 0.0 and 1.0 representing progress from minExp to nextReq.
/// If calculation fails or inputs are invalid, returns null.
double? calculateXpRatio({
  required num? totalExp,
  required num? minExp,
  required num? nextReq,
}) {
  try {
    if (totalExp != null && minExp != null && nextReq != null) {
      final denominator = nextReq.toDouble() - minExp.toDouble();
      if (denominator > 0) {
        return ((totalExp.toDouble() - minExp.toDouble()) / denominator).clamp(0.0, 1.0);
      } else {
        return 0.0;
      }
    } else if (totalExp != null && nextReq != null) {
      // Fallback: simple total / next
      if (nextReq.toDouble() > 0) {
        return (totalExp.toDouble() / nextReq.toDouble()).clamp(0.0, 1.0);
      }
    }
  } catch (_) {}
  return null;
}
