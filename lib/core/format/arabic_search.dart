/// Folds the spellings people mix up when searching Arabic names (أ/إ/آ, ى/ي, ة/ه, tashkeel).
String normalizeArabic(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[أإآ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll('ة', 'ه')
    .replaceAll(RegExp('[ً-ٟـ]'), '')
    .trim();
