import '../models/climb_route.dart';

/// Duplicate suggestion (FR-4): routes whose names look like [name].
///
/// Names are compared without case, spacing or diacritics, so
/// "Dry spel", "dry spell" and "Dry Spéll" all match "Dry Spell".
List<ClimbRoute> similarRoutes(String name, Iterable<ClimbRoute> candidates) {
  final q = normalizeName(name);
  if (q.length < 3) return const [];
  final scored = <({ClimbRoute route, int distance})>[];
  for (final r in candidates) {
    final c = normalizeName(r.name);
    if (c.isEmpty) continue;
    final d = levenshtein(q, c);
    final allowed = q.length >= 8 ? 2 : 1;
    final contains = q.length >= 4 && (c.contains(q) || q.contains(c));
    if (d <= allowed || contains) scored.add((route: r, distance: d));
  }
  scored.sort((a, b) => a.distance.compareTo(b.distance));
  return scored.map((s) => s.route).toList();
}

const _folds = {
  'č': 'c', 'ć': 'c', 'š': 's', 'ž': 'z', 'đ': 'd',
  'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ñ': 'n', 'ß': 'ss',
};

String normalizeName(String s) {
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final f = _folds[ch] ?? ch;
    if (RegExp(r'[a-z0-9]').hasMatch(f)) b.write(f);
  }
  return b.toString();
}

int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0);
    cur[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      final del = prev[j] + 1;
      final ins = cur[j - 1] + 1;
      final sub = prev[j - 1] + cost;
      cur[j] = del < ins ? (del < sub ? del : sub) : (ins < sub ? ins : sub);
    }
    prev = cur;
  }
  return prev[b.length];
}
