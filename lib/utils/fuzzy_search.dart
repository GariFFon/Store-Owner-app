import 'dart:math';

/// A utility class for fuzzy string matching.
/// Supports partial prefix matching, subsequence matching,
/// and Levenshtein distance-based typo tolerance.
class FuzzySearch {
  /// Compute the Levenshtein edit distance between two strings.
  static int levenshteinDistance(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    // Use two rows instead of full matrix for memory efficiency
    List<int> previousRow = List.generate(b.length + 1, (i) => i);
    List<int> currentRow = List.filled(b.length + 1, 0);

    for (int i = 1; i <= a.length; i++) {
      currentRow[0] = i;
      for (int j = 1; j <= b.length; j++) {
        int cost = a[i - 1] == b[j - 1] ? 0 : 1;
        currentRow[j] = [
          currentRow[j - 1] + 1, // insertion
          previousRow[j] + 1, // deletion
          previousRow[j - 1] + cost, // substitution
        ].reduce(min);
      }
      // Swap rows
      final temp = previousRow;
      previousRow = currentRow;
      currentRow = temp;
    }
    return previousRow[b.length];
  }

  /// Compute minimum edit distance between query and any substring of target
  /// of the same length as query. This allows matching typos in partial input.
  static int minSubstringDistance(String query, String target) {
    if (query.isEmpty) return 0;
    if (target.isEmpty) return query.length;
    if (query.length > target.length) return levenshteinDistance(query, target);

    int minDist = query.length; // worst case
    for (int i = 0; i <= target.length - query.length; i++) {
      final substring = target.substring(i, i + query.length);
      final dist = levenshteinDistance(query, substring);
      if (dist < minDist) {
        minDist = dist;
        if (minDist == 0) return 0; // exact match found
      }
    }
    return minDist;
  }

  /// Check if query characters appear in order within the target (subsequence match).
  /// e.g. "crtn" matches "creatine" because c-r-t-n appear in order.
  static bool isSubsequence(String query, String target) {
    int qi = 0;
    for (int ti = 0; ti < target.length && qi < query.length; ti++) {
      if (query[qi] == target[ti]) {
        qi++;
      }
    }
    return qi == query.length;
  }

  /// Compute a fuzzy match score (0.0 = no match, 1.0 = perfect match).
  /// Higher is better.
  static double matchScore(String query, String target) {
    if (query.isEmpty || target.isEmpty) return 0.0;

    final q = query.toLowerCase().trim();
    final t = target.toLowerCase().trim();

    // 1. Exact match
    if (q == t) return 1.0;

    // 2. Target starts with query (prefix match) — best partial match
    if (t.startsWith(q)) return 0.95;

    // 3. Target contains query as substring
    if (t.contains(q)) return 0.90;

    // 4. Any word in target starts with query
    final words = t.split(RegExp(r'[\s\-_]+'));
    for (final word in words) {
      if (word.startsWith(q)) return 0.85;
    }

    // 5. Subsequence match (characters in order)
    if (isSubsequence(q, t)) return 0.70;

    // 6. Minimum substring distance (typo tolerance)
    final subDist = minSubstringDistance(q, t);
    final maxAllowedDist = _maxAllowedDistance(q.length);
    if (subDist <= maxAllowedDist) {
      // Scale from 0.65 (worst allowed) to 0.80 (best fuzzy)
      return 0.65 + (1 - subDist / max(1, q.length)) * 0.15;
    }

    // 7. Full Levenshtein distance as last resort
    final fullDist = levenshteinDistance(q, t);
    final fullMaxDist = (t.length * 0.5).ceil(); // allow up to 50% difference
    if (fullDist <= fullMaxDist) {
      return 0.30 + (1 - fullDist / max(1, t.length)) * 0.30;
    }

    return 0.0;
  }

  /// Determine maximum allowed edit distance based on query length.
  /// Shorter queries get less tolerance, longer queries get more.
  static int _maxAllowedDistance(int queryLength) {
    if (queryLength <= 2) return 0; // no typo tolerance for very short
    if (queryLength <= 4) return 1; // 1 typo allowed
    if (queryLength <= 7) return 2; // 2 typos allowed
    return 3; // up to 3 typos for long queries
  }

  /// Search a list of items with fuzzy matching.
  /// [items] - the list to search through
  /// [query] - the search query
  /// [getSearchableStrings] - function that extracts searchable strings from each item
  /// [minScore] - minimum match score to include in results (default 0.3)
  ///
  /// Returns items sorted by match score (best first).
  static List<T> search<T>({
    required List<T> items,
    required String query,
    required List<String> Function(T item) getSearchableStrings,
    double minScore = 0.3,
  }) {
    if (query.trim().isEmpty) return items;

    final scored = <_ScoredItem<T>>[];

    for (final item in items) {
      final searchableStrings = getSearchableStrings(item);
      double bestScore = 0.0;

      for (final str in searchableStrings) {
        final score = matchScore(query, str);
        if (score > bestScore) {
          bestScore = score;
        }
      }

      if (bestScore >= minScore) {
        scored.add(_ScoredItem(item: item, score: bestScore));
      }
    }

    // Sort by score descending
    scored.sort((a, b) => b.score.compareTo(a.score));

    return scored.map((s) => s.item).toList();
  }
}

class _ScoredItem<T> {
  final T item;
  final double score;

  _ScoredItem({required this.item, required this.score});
}
