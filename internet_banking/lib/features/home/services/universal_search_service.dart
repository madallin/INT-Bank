enum SearchResultType {
  transaction,
  beneficiary,
  card,
  vault,
  setting,
  helpArticle,
}

abstract class SearchIndexEntry {
  const SearchIndexEntry();

  String get id;

  SearchResultType get type;

  String get title;

  String get subtitle;

  List<String> get keywords;

  String get stableKey => '${type.index}:$id';
}

class IndexedTransaction extends SearchIndexEntry {
  @override
  final String id;
  final String description;
  final String merchant;
  final String category;
  final double amount;
  final DateTime occurredAt;

  const IndexedTransaction({
    required this.id,
    required this.description,
    this.merchant = '',
    this.category = '',
    this.amount = 0.0,
    required this.occurredAt,
  });

  @override
  SearchResultType get type => SearchResultType.transaction;

  @override
  String get title => description;

  @override
  String get subtitle => merchant.isNotEmpty ? merchant : category;

  @override
  List<String> get keywords => <String>[
        if (merchant.isNotEmpty) merchant,
        if (category.isNotEmpty) category,
      ];
}

class IndexedBeneficiary extends SearchIndexEntry {
  @override
  final String id;
  final String name;
  final String iban;
  final String bankName;

  const IndexedBeneficiary({
    required this.id,
    required this.name,
    this.iban = '',
    this.bankName = '',
  });

  @override
  SearchResultType get type => SearchResultType.beneficiary;

  @override
  String get title => name;

  @override
  String get subtitle => bankName.isNotEmpty ? bankName : iban;

  @override
  List<String> get keywords => <String>[
        if (iban.isNotEmpty) iban,
        if (bankName.isNotEmpty) bankName,
      ];
}

class IndexedCard extends SearchIndexEntry {
  @override
  final String id;
  final String label;
  final String last4;
  final String network;
  final String kind;

  const IndexedCard({
    required this.id,
    required this.label,
    this.last4 = '',
    this.network = '',
    this.kind = '',
  });

  @override
  SearchResultType get type => SearchResultType.card;

  @override
  String get title => label;

  @override
  String get subtitle {
    final List<String> parts = <String>[
      if (network.isNotEmpty) network,
      if (last4.isNotEmpty) '****$last4',
    ];
    return parts.join(' ');
  }

  @override
  List<String> get keywords => <String>[
        if (kind.isNotEmpty) kind,
        if (last4.isNotEmpty) last4,
      ];
}

class IndexedVault extends SearchIndexEntry {
  @override
  final String id;
  final String name;
  final String currency;

  const IndexedVault({
    required this.id,
    required this.name,
    this.currency = '',
  });

  @override
  SearchResultType get type => SearchResultType.vault;

  @override
  String get title => name;

  @override
  String get subtitle => currency;

  @override
  List<String> get keywords => <String>[
        if (currency.isNotEmpty) currency,
      ];
}

class IndexedSetting extends SearchIndexEntry {
  @override
  final String id;
  final String label;
  final String section;

  const IndexedSetting({
    required this.id,
    required this.label,
    this.section = '',
  });

  @override
  SearchResultType get type => SearchResultType.setting;

  @override
  String get title => label;

  @override
  String get subtitle => section;

  @override
  List<String> get keywords => <String>[
        if (section.isNotEmpty) section,
      ];
}

class IndexedHelpArticle extends SearchIndexEntry {
  @override
  final String id;
  final String heading;
  final String body;
  final String category;

  const IndexedHelpArticle({
    required this.id,
    required this.heading,
    this.body = '',
    this.category = '',
  });

  @override
  SearchResultType get type => SearchResultType.helpArticle;

  @override
  String get title => heading;

  @override
  String get subtitle => category;

  @override
  List<String> get keywords => <String>[
        if (body.isNotEmpty) body,
        if (category.isNotEmpty) category,
      ];
}

class SearchIndex {
  final List<SearchIndexEntry> entries;

  const SearchIndex({this.entries = const <SearchIndexEntry>[]});

  List<SearchIndexEntry> get byType {
    final List<SearchIndexEntry> sorted = List<SearchIndexEntry>.of(entries);
    sorted.sort(
      (SearchIndexEntry a, SearchIndexEntry b) =>
          a.stableKey.compareTo(b.stableKey),
    );
    return List<SearchIndexEntry>.unmodifiable(sorted);
  }
}

class SearchResultItem {
  final String id;
  final SearchResultType type;
  final String title;
  final String subtitle;
  final double score;
  final SearchIndexEntry entry;

  const SearchResultItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.score,
    required this.entry,
  });

  String get stableKey => '${type.index}:$id';
}

abstract class SearchHistoryStore {
  List<String> load();

  void save(List<String> queries);
}

class InMemorySearchHistoryStore implements SearchHistoryStore {
  InMemorySearchHistoryStore([List<String> initial = const <String>[]])
      : _queries = List<String>.of(initial);

  List<String> _queries;

  @override
  List<String> load() => List<String>.of(_queries);

  @override
  void save(List<String> queries) {
    _queries = List<String>.of(queries);
  }
}

class _WeightedTokens {
  final List<String> tokens;
  final double weight;

  const _WeightedTokens(this.tokens, this.weight);
}

class UniversalSearchService {
  static final RegExp _tokenPattern = RegExp('[a-z0-9]+');

  final SearchIndex index;
  final SearchHistoryStore historyStore;
  final int maxHistoryEntries;
  final int maxResults;

  UniversalSearchService({
    SearchIndex? index,
    SearchHistoryStore? historyStore,
    this.maxHistoryEntries = 10,
    this.maxResults = 50,
  })  : index = index ?? const SearchIndex(),
        historyStore = historyStore ?? InMemorySearchHistoryStore(),
        assert(maxHistoryEntries > 0, 'maxHistoryEntries must be positive'),
        assert(maxResults > 0, 'maxResults must be positive');

  List<SearchResultItem> search(String query) {
    final List<String> queryTokens = _tokenize(query);
    if (queryTokens.isEmpty) {
      return const <SearchResultItem>[];
    }

    final List<SearchResultItem> results = <SearchResultItem>[];
    for (final SearchIndexEntry entry in index.entries) {
      final double? score = _scoreEntry(entry, queryTokens);
      if (score != null && score > 0.0) {
        results.add(
          SearchResultItem(
            id: entry.id,
            type: entry.type,
            title: entry.title,
            subtitle: entry.subtitle,
            score: score,
            entry: entry,
          ),
        );
      }
    }

    results.sort((SearchResultItem a, SearchResultItem b) {
      final int byScore = b.score.compareTo(a.score);
      if (byScore != 0) {
        return byScore;
      }
      return a.stableKey.compareTo(b.stableKey);
    });

    if (results.length > maxResults) {
      return List<SearchResultItem>.unmodifiable(
        results.sublist(0, maxResults),
      );
    }
    return List<SearchResultItem>.unmodifiable(results);
  }

  List<String> history() => List<String>.unmodifiable(historyStore.load());

  void recordQuery(String query) {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final String lower = trimmed.toLowerCase();
    final List<String> updated = <String>[trimmed];
    for (final String existing in historyStore.load()) {
      if (existing.toLowerCase() == lower) {
        continue;
      }
      updated.add(existing);
    }
    while (updated.length > maxHistoryEntries) {
      updated.removeLast();
    }
    historyStore.save(updated);
  }

  void clearHistory() {
    historyStore.save(const <String>[]);
  }

  List<String> historySuggestions(String query) {
    final List<String> entries = history();
    final String needle = query.trim().toLowerCase();
    if (needle.isEmpty) {
      return List<String>.unmodifiable(entries);
    }
    final List<String> matches = <String>[];
    for (final String entry in entries) {
      final String lower = entry.toLowerCase();
      if (lower.startsWith(needle) || lower.contains(needle)) {
        matches.add(entry);
      }
    }
    return List<String>.unmodifiable(matches);
  }

  List<String> _tokenize(String value) {
    return _tokenPattern
        .allMatches(value.toLowerCase())
        .map((RegExpMatch match) => match.group(0)!)
        .toList();
  }

  double? _scoreEntry(
    SearchIndexEntry entry,
    List<String> queryTokens,
  ) {
    final List<_WeightedTokens> fields = <_WeightedTokens>[
      _WeightedTokens(_tokenize(entry.title), 1.0),
    ];

    final List<String> subtitleTokens = _tokenize(entry.subtitle);
    if (subtitleTokens.isNotEmpty) {
      fields.add(_WeightedTokens(subtitleTokens, 0.7));
    }

    for (final String keyword in entry.keywords) {
      final List<String> keywordTokens = _tokenize(keyword);
      if (keywordTokens.isNotEmpty) {
        fields.add(_WeightedTokens(keywordTokens, 0.5));
      }
    }

    double total = 0.0;
    for (final String queryToken in queryTokens) {
      double best = 0.0;
      for (final _WeightedTokens field in fields) {
        for (final String docToken in field.tokens) {
          final double? tokenScore = _tokenScore(queryToken, docToken);
          if (tokenScore != null) {
            final double weighted = tokenScore * field.weight;
            if (weighted > best) {
              best = weighted;
            }
          }
        }
      }
      if (best <= 0.0) {
        return null;
      }
      total += best;
    }
    return total;
  }

  double? _tokenScore(String queryToken, String docToken) {
    if (queryToken == docToken) {
      return 1.0;
    }
    if (docToken.startsWith(queryToken)) {
      final double ratio = queryToken.length / docToken.length;
      return 0.7 + 0.2 * ratio;
    }
    final int distance = _levenshtein(queryToken, docToken);
    final int threshold = _typoThreshold(queryToken.length);
    if (distance > 0 && distance <= threshold) {
      return 0.6 - 0.1 * distance;
    }
    if (_isSubsequence(queryToken, docToken)) {
      return 0.3;
    }
    return null;
  }

  int _typoThreshold(int length) {
    if (length <= 2) {
      return 0;
    }
    if (length <= 4) {
      return 1;
    }
    if (length <= 7) {
      return 2;
    }
    return 3;
  }

  bool _isSubsequence(String queryToken, String docToken) {
    if (queryToken.isEmpty || queryToken.length > docToken.length) {
      return false;
    }
    int queryIndex = 0;
    for (int docIndex = 0;
        docIndex < docToken.length && queryIndex < queryToken.length;
        docIndex++) {
      if (docToken.codeUnitAt(docIndex) == queryToken.codeUnitAt(queryIndex)) {
        queryIndex++;
      }
    }
    return queryIndex == queryToken.length;
  }

  int _levenshtein(String a, String b) {
    if (a == b) {
      return 0;
    }
    if (a.isEmpty) {
      return b.length;
    }
    if (b.isEmpty) {
      return a.length;
    }

    final List<int> previous =
        List<int>.generate(b.length + 1, (int index) => index);
    final List<int> current = List<int>.filled(b.length + 1, 0);

    for (int i = 1; i <= a.length; i++) {
      current[0] = i;
      for (int j = 1; j <= b.length; j++) {
        final int cost =
            a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        final int deletion = previous[j] + 1;
        final int insertion = current[j - 1] + 1;
        final int substitution = previous[j - 1] + cost;
        current[j] = _min3(deletion, insertion, substitution);
      }
      for (int j = 0; j <= b.length; j++) {
        previous[j] = current[j];
      }
    }
    return previous[b.length];
  }

  int _min3(int x, int y, int z) {
    int minimum = x;
    if (y < minimum) {
      minimum = y;
    }
    if (z < minimum) {
      minimum = z;
    }
    return minimum;
  }
}
