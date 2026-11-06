/// The first non-blank entry of [candidates], else [fallback]. Stored display
/// names may be empty (no English placeholder is stored), so UI picks a
/// translated fallback at render time.
String firstNonBlank(Iterable<String?> candidates, {required String fallback}) {
  for (final c in candidates) {
    if (c != null && c.trim().isNotEmpty) return c.trim();
  }
  return fallback;
}
