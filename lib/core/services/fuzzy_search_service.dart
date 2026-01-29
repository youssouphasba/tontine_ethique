/// Fuzzy Search Service
/// Handles typo-tolerant search for product and merchant discovery
/// 
/// Features:
/// - Levenshtein distance for typo tolerance
/// - Normalization (accents, case)
/// - Synonyms matching
/// - Partial word matching
library;

class FuzzySearchService {
  // Common synonyms for Senegalese/French context
  static const Map<String, List<String>> _synonyms = {
    'vetement': ['habits', 'tenue', 'fringues', 'mode'],
    'telephone': ['portable', 'mobile', 'phone', 'tel'],
    'nourriture': ['bouffe', 'repas', 'plat', 'manger', 'food'],
    'bijoux': ['or', 'argent', 'collier', 'bracelet'],
    'beaute': ['maquillage', 'soin', 'cosmetique'],
    'thieboudienne': ['thieb', 'riz', 'poisson'],
    'wax': ['tissu', 'pagne', 'africain'],
    'chaussure': ['shoes', 'basket', 'sandale'],
  };

  /// Normalize text: lowercase, remove accents
  static String normalize(String text) {
    const accents = 'àáâãäåèéêëìíîïòóôõöùúûüýÿñç';
    const normalized = 'aaaaaaeeeeiiiiooooouuuuyync';
    
    String result = text.toLowerCase().trim();
    for (int i = 0; i < accents.length; i++) {
      result = result.replaceAll(accents[i], normalized[i]);
    }
    return result;
  }

  /// Calculate Levenshtein distance between two strings
  static int levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;
    
    List<List<int>> matrix = List.generate(
      s1.length + 1,
      (i) => List.generate(s2.length + 1, (j) => 0),
    );
    
    for (int i = 0; i <= s1.length; i++) {
  matrix[i][0] = i;
}
    for (int j = 0; j <= s2.length; j++) {
  matrix[0][j] = j;
}
    
    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        int cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,       // deletion
          matrix[i][j - 1] + 1,       // insertion
          matrix[i - 1][j - 1] + cost // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }
    
    return matrix[s1.length][s2.length];
  }

  /// Calculate similarity score (0-1)
  static double similarity(String s1, String s2) {
    final normalized1 = normalize(s1);
    final normalized2 = normalize(s2);
    
    if (normalized1 == normalized2) return 1.0;
    if (normalized1.isEmpty || normalized2.isEmpty) return 0.0;
    
    // Check if one contains the other
    if (normalized1.contains(normalized2) || normalized2.contains(normalized1)) {
      return 0.9;
    }
    
    final distance = levenshteinDistance(normalized1, normalized2);
    final maxLength = normalized1.length > normalized2.length ? normalized1.length : normalized2.length;
    
    return 1 - (distance / maxLength);
  }

  /// Check if query matches text with fuzzy tolerance
  static bool fuzzyMatch(String query, String text, {double threshold = 0.6}) {
    final normalizedQuery = normalize(query);
    final normalizedText = normalize(text);
    
    // Exact match
    if (normalizedText.contains(normalizedQuery)) return true;
    
    // Word-by-word fuzzy match
    final queryWords = normalizedQuery.split(' ');
    final textWords = normalizedText.split(' ');
    
    for (final queryWord in queryWords) {
      if (queryWord.length < 2) continue;
      
      bool wordMatched = false;
      
      // Check against each text word
      for (final textWord in textWords) {
        if (similarity(queryWord, textWord) >= threshold) {
          wordMatched = true;
          break;
        }
      }
      
      // Check synonyms
      if (!wordMatched) {
        for (final entry in _synonyms.entries) {
          if (similarity(queryWord, entry.key) >= threshold ||
              entry.value.any((syn) => similarity(queryWord, syn) >= threshold)) {
            if (textWords.any((tw) => 
              similarity(tw, entry.key) >= threshold ||
              entry.value.any((syn) => similarity(tw, syn) >= threshold)
            )) {
              wordMatched = true;
              break;
            }
          }
        }
      }
      
      if (!wordMatched) return false;
    }
    
    return true;
  }

  /// Search products with fuzzy matching
  /// Returns products sorted by relevance score
  static List<T> searchWithScore<T>({
    required String query,
    required List<T> items,
    required String Function(T) getText,
    double threshold = 0.5,
  }) {
    if (query.trim().isEmpty) return items;
    
    final results = <(T, double)>[];
    
    for (final item in items) {
      final text = getText(item);
      
      // Calculate relevance score
      double score = 0;
      
      // Exact match in text
      if (normalize(text).contains(normalize(query))) {
        score = 1.0;
      } else {
        // Fuzzy match
        final queryWords = normalize(query).split(' ');
        double wordScore = 0;
        
        for (final word in queryWords) {
          if (word.length < 2) continue;
          
          double bestMatch = 0;
          for (final textWord in normalize(text).split(' ')) {
            final sim = similarity(word, textWord);
            if (sim > bestMatch) bestMatch = sim;
          }
          wordScore += bestMatch;
        }
        
        score = wordScore / queryWords.length;
      }
      
      if (score >= threshold) {
        results.add((item, score));
      }
    }
    
    // Sort by score descending
    results.sort((a, b) => b.$2.compareTo(a.$2));
    
    return results.map((r) => r.$1).toList();
  }
}
