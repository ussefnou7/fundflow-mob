import 'dart:io' show HttpDate;

/// The server's wall clock, carried forward on the phone by a stopwatch, so
/// changing the phone's time never moves it. Unknown until a response syncs it.
class ServerClock {
  DateTime? _anchor;
  Duration? _zone;
  final _since = Stopwatch();

  bool get synced => _anchor != null;

  /// Now on the server's wall clock, or null before the first sync.
  DateTime? now() => _anchor?.add(_since.elapsed);

  /// [value] is an ISO timestamp the server sent with its own offset.
  void sync(String value) {
    final wall = serverWallTime(value);
    if (wall == null) return;
    _zone = _offsetOf(value) ?? _zone;
    _start(wall);
  }

  /// The HTTP `Date` header: whole seconds and no zone, so it only fills in
  /// until a timestamp from the server arrives. Until then the zone is the
  /// phone's, the time never is.
  void syncFromHeader(String? date) {
    if (synced || date == null) return;
    try {
      final utc = HttpDate.parse(date);
      _start(_wall(utc, _zone ?? DateTime.now().timeZoneOffset));
    } on FormatException {
      return;
    }
  }

  void _start(DateTime wall) {
    _anchor = wall;
    _since
      ..reset()
      ..start();
  }
}

/// «2026-10-28T08:04:00+03:00» → 08:04 on 28 October, the time as the server
/// wrote it, whatever zone the phone is set to.
DateTime? serverWallTime(Object? value) {
  if (value == null) return null;
  final text = value.toString();
  final parsed = DateTime.tryParse(text);
  if (parsed == null) return null;
  final offset = _offsetOf(text);
  return offset == null ? parsed : _wall(parsed.toUtc(), offset);
}

final _offsetPattern = RegExp(r'(Z|[+-]\d{2}:?\d{2})$');

Duration? _offsetOf(String text) {
  final match = _offsetPattern.firstMatch(text.trim());
  if (match == null) return null;
  final token = match.group(1)!;
  if (token == 'Z') return Duration.zero;
  final digits = token.replaceAll(':', '');
  final minutes =
      int.parse(digits.substring(1, 3)) * 60 + int.parse(digits.substring(3));
  return Duration(minutes: token.startsWith('-') ? -minutes : minutes);
}

DateTime _wall(DateTime utc, Duration offset) {
  final shifted = utc.add(offset);
  return DateTime(
    shifted.year,
    shifted.month,
    shifted.day,
    shifted.hour,
    shifted.minute,
    shifted.second,
    shifted.millisecond,
  );
}
