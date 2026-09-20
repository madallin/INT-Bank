import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/features/home/services/universal_search_service.dart';

SearchIndex buildIndex() {
  return SearchIndex(
    entries: <SearchIndexEntry>[
      IndexedTransaction(
        id: 'txn-netflix',
        description: 'Netflix subscription',
        merchant: 'Netflix',
        category: 'Entertainment',
        amount: 15.99,
        occurredAt: DateTime(2024, 1, 5),
      ),
      IndexedTransaction(
        id: 'txn-grocery',
        description: 'Grocery shopping',
        merchant: 'MegaMarket',
        category: 'Groceries',
        amount: 120.50,
        occurredAt: DateTime(2024, 2, 1),
      ),
      IndexedTransaction(
        id: 'txn-salary',
        description: 'Monthly salary',
        merchant: 'Acme Corp',
        category: 'Income',
        amount: 5000.0,
        occurredAt: DateTime(2024, 2, 28),
      ),
      IndexedTransaction(
        id: 'txn-cardiff',
        description: 'Cardiff trip',
        merchant: 'Trainline',
        category: 'Travel',
        amount: 89.0,
        occurredAt: DateTime(2024, 3, 12),
      ),
      IndexedBeneficiary(
        id: 'ben-mom',
        name: 'Mom',
        iban: 'RO49AAAA1B31007593840000',
        bankName: 'Banca Transilvania',
      ),
      IndexedBeneficiary(
        id: 'ben-john',
        name: 'John Smith',
        iban: 'GB29NWBK60161331926819',
        bankName: 'Revolut',
      ),
      IndexedCard(
        id: 'card-netflix',
        label: 'Netflix card',
        last4: '4321',
        network: 'Visa',
        kind: 'virtual',
      ),
      IndexedCard(
        id: 'card-travel',
        label: 'Travel card',
        last4: '8765',
        network: 'Mastercard',
        kind: 'physical',
      ),
      IndexedVault(
        id: 'vault-vacation',
        name: 'Vacation fund',
        currency: 'EUR',
      ),
      IndexedVault(
        id: 'vault-emergency',
        name: 'Emergency fund',
        currency: 'RON',
      ),
      IndexedSetting(
        id: 'set-pin',
        label: 'Change PIN',
        section: 'Security',
      ),
      IndexedSetting(
        id: 'set-travel',
        label: 'Travel notifications',
        section: 'Cards',
      ),
      IndexedHelpArticle(
        id: 'help-pin',
        heading: 'How to reset your PIN',
        body: 'Reset your card PIN from settings',
        category: 'Security',
      ),
      IndexedHelpArticle(
        id: 'help-abroad',
        heading: 'International transfers',
        body: 'Send money abroad with IBAN',
        category: 'Transfers',
      ),
    ],
  );
}

UniversalSearchService buildService({
  SearchIndex? index,
  SearchHistoryStore? historyStore,
  int maxHistoryEntries = 10,
  int maxResults = 50,
}) {
  return UniversalSearchService(
    index: index ?? buildIndex(),
    historyStore: historyStore,
    maxHistoryEntries: maxHistoryEntries,
    maxResults: maxResults,
  );
}

void main() {
  group('SearchResultType', () {
    test('declares the six supported entity kinds in order', () {
      expect(SearchResultType.values, hasLength(6));
      expect(SearchResultType.values[0], SearchResultType.transaction);
      expect(SearchResultType.values[1], SearchResultType.beneficiary);
      expect(SearchResultType.values[2], SearchResultType.card);
      expect(SearchResultType.values[3], SearchResultType.vault);
      expect(SearchResultType.values[4], SearchResultType.setting);
      expect(SearchResultType.values[5], SearchResultType.helpArticle);
    });
  });

  group('index entry typing', () {
    test('typed entries expose type, title, subtitle and keywords', () {
      final SearchIndexEntry entry = IndexedBeneficiary(
        id: 'b1',
        name: 'Mom',
        bankName: 'Banca Transilvania',
      );
      expect(entry.type, SearchResultType.beneficiary);
      expect(entry.title, 'Mom');
      expect(entry.subtitle, 'Banca Transilvania');
      expect(entry.stableKey, '1:b1');
    });

    test('card subtitle composes network and masked last4', () {
      const IndexedCard card = IndexedCard(
        id: 'c1',
        label: 'Netflix card',
        last4: '4321',
        network: 'Visa',
      );
      expect(card.subtitle, 'Visa ****4321');
    });
  });

  group('empty state', () {
    test('empty query returns no results', () {
      final UniversalSearchService service = buildService();
      expect(service.search(''), isEmpty);
    });

    test('whitespace-only query returns no results', () {
      final UniversalSearchService service = buildService();
      expect(service.search('   \t  '), isEmpty);
    });

    test('empty index returns no results for a real query', () {
      final UniversalSearchService service =
          buildService(index: const SearchIndex());
      expect(service.search('netflix'), isEmpty);
    });

    test('unknown term returns no results', () {
      final UniversalSearchService service = buildService();
      expect(service.search('zzzznomatch'), isEmpty);
    });
  });

  group('multi-index search', () {
    test('single query matches transaction and card indexes', () {
      final UniversalSearchService service = buildService();
      final List<SearchResultItem> results = service.search('netf');
      final Set<SearchResultType> types = results
          .map((SearchResultItem item) => item.type)
          .toSet();
      expect(types, contains(SearchResultType.transaction));
      expect(types, contains(SearchResultType.card));
      expect(
        results.any((SearchResultItem item) => item.id == 'txn-netflix'),
        isTrue,
      );
      expect(
        results.any((SearchResultItem item) => item.id == 'card-netflix'),
        isTrue,
      );
    });

    test('finds a result in every entity kind', () {
      final UniversalSearchService service = buildService();
      expect(
        service
            .search('grocery')
            .any((SearchResultItem i) => i.type == SearchResultType.transaction),
        isTrue,
      );
      expect(
        service
            .search('john')
            .any((SearchResultItem i) => i.type == SearchResultType.beneficiary),
        isTrue,
      );
      expect(
        service
            .search('mastercard')
            .any((SearchResultItem i) => i.type == SearchResultType.card),
        isTrue,
      );
      expect(
        service
            .search('vacation')
            .any((SearchResultItem i) => i.type == SearchResultType.vault),
        isTrue,
      );
      expect(
        service
            .search('notifications')
            .any((SearchResultItem i) => i.type == SearchResultType.setting),
        isTrue,
      );
      expect(
        service
            .search('abroad')
            .any((SearchResultItem i) => i.type == SearchResultType.helpArticle),
        isTrue,
      );
    });

    test('exact beneficiary name match resolves to Mom', () {
      final UniversalSearchService service = buildService();
      final List<SearchResultItem> results = service.search('mom');
      expect(results, isNotEmpty);
      expect(results.first.id, 'ben-mom');
      expect(results.first.type, SearchResultType.beneficiary);
    });
  });

  group('matching semantics', () {
    test('prefix matching resolves netf to Netflix entries', () {
      final UniversalSearchService service = buildService();
      final List<SearchResultItem> results = service.search('netf');
      expect(results, isNotEmpty);
      expect(
        results.every(
          (SearchResultItem item) => item.title.toLowerCase().contains('netflix'),
        ),
        isTrue,
      );
    });

    test('is case insensitive', () {
      final UniversalSearchService service = buildService();
      final List<String> lower = service
          .search('netflix')
          .map((SearchResultItem item) => item.id)
          .toList();
      final List<String> upper = service
          .search('NETFLIX')
          .map((SearchResultItem item) => item.id)
          .toList();
      expect(upper, lower);
    });

    test('tolerates a single character typo', () {
      final UniversalSearchService service = buildService();
      final List<SearchResultItem> results = service.search('netflx');
      expect(
        results.any((SearchResultItem item) => item.id == 'txn-netflix'),
        isTrue,
      );
      expect(
        results.any((SearchResultItem item) => item.id == 'card-netflix'),
        isTrue,
      );
    });

    test('matches subsequence tokens', () {
      final UniversalSearchService service = buildService();
      final List<SearchResultItem> results = service.search('nfx');
      expect(
        results.any((SearchResultItem item) => item.id == 'txn-netflix'),
        isTrue,
      );
    });

    test('multi-token query requires every token', () {
      final UniversalSearchService service = buildService();
      final List<SearchResultItem> both =
          service.search('netflix subscription');
      expect(both.first.id, 'txn-netflix');
      expect(service.search('netflix grocery'), isEmpty);
    });
  });

  group('relevance ranking', () {
    test('exact token outranks prefix match', () {
      final UniversalSearchService service = buildService();
      final List<SearchResultItem> results = service.search('card');
      final SearchResultItem exact = results.firstWhere(
        (SearchResultItem item) => item.title.toLowerCase() == 'netflix card',
      );
      final SearchResultItem prefixed = results.firstWhere(
        (SearchResultItem item) => item.id == 'txn-cardiff',
      );
      expect(exact.score, greaterThan(prefixed.score));
      expect(results.first.type, SearchResultType.card);
    });

    test('title field outweighs keyword field', () {
      final SearchIndex index = SearchIndex(
        entries: <SearchIndexEntry>[
          const IndexedSetting(id: 'set-title', label: 'Coffee'),
          const IndexedSetting(
            id: 'set-section',
            label: 'Preferences',
            section: 'Coffee',
          ),
        ],
      );
      final UniversalSearchService service = buildService(index: index);
      final List<SearchResultItem> results = service.search('coffee');
      expect(results, hasLength(2));
      expect(results.first.id, 'set-title');
      expect(results.first.score, greaterThan(results.last.score));
    });

    test('typo match ranks below exact match', () {
      final SearchIndex index = SearchIndex(
        entries: <SearchIndexEntry>[
          const IndexedSetting(id: 'set-exact', label: 'Coffee'),
          const IndexedSetting(id: 'set-typo', label: 'Cofee'),
        ],
      );
      final UniversalSearchService service = buildService(index: index);
      final List<SearchResultItem> results = service.search('coffee');
      expect(results, isNotEmpty);
      expect(results.first.id, 'set-exact');
      expect(results.last.id, 'set-typo');
      expect(results.first.score, greaterThan(results.last.score));
    });

    test('equal scores break ties by stable key', () {
      final SearchIndex index = SearchIndex(
        entries: <SearchIndexEntry>[
          const IndexedSetting(id: 'set-b', label: 'Alpha'),
          const IndexedSetting(id: 'set-a', label: 'Alpha'),
        ],
      );
      final UniversalSearchService service = buildService(index: index);
      final List<SearchResultItem> results = service.search('alpha');
      expect(results, hasLength(2));
      expect(results[0].id, 'set-a');
      expect(results[1].id, 'set-b');
      expect(results[0].score, results[1].score);
    });

    test('maxResults caps the ranked list', () {
      final SearchIndex index = SearchIndex(
        entries: <SearchIndexEntry>[
          const IndexedSetting(id: 'set-1', label: 'Alpha one'),
          const IndexedSetting(id: 'set-2', label: 'Alpha two'),
          const IndexedSetting(id: 'set-3', label: 'Alpha three'),
        ],
      );
      final UniversalSearchService service =
          buildService(index: index, maxResults: 2);
      final List<SearchResultItem> results = service.search('alpha');
      expect(results, hasLength(2));
      expect(results[0].id, 'set-1');
      expect(results[1].id, 'set-2');
    });

    test('SearchIndex.byType is sorted by stable key', () {
      final SearchIndexEntry first = IndexedSetting(id: 'z', label: 'Zed');
      final SearchIndexEntry second = IndexedSetting(id: 'a', label: 'Ay');
      final SearchIndex index =
          SearchIndex(entries: <SearchIndexEntry>[first, second]);
      final List<SearchIndexEntry> sorted = index.byType;
      expect(sorted.first.stableKey, '4:a');
      expect(sorted.last.stableKey, '4:z');
    });
  });

  group('search history', () {
    test('returns most recent query first', () {
      final UniversalSearchService service = buildService();
      service.recordQuery('netflix');
      service.recordQuery('mom');
      expect(service.history(), <String>['mom', 'netflix']);
    });

    test('dedupes case-insensitively and moves to front', () {
      final UniversalSearchService service = buildService();
      service.recordQuery('Netflix');
      service.recordQuery('mom');
      service.recordQuery('netflix');
      expect(service.history(), <String>['netflix', 'mom']);
    });

    test('ignores blank queries and trims whitespace', () {
      final UniversalSearchService service = buildService();
      service.recordQuery('   ');
      service.recordQuery('');
      service.recordQuery('  travel  ');
      expect(service.history(), <String>['travel']);
    });

    test('caps retained entries', () {
      final UniversalSearchService service =
          buildService(maxHistoryEntries: 3);
      service.recordQuery('a');
      service.recordQuery('b');
      service.recordQuery('c');
      service.recordQuery('d');
      expect(service.history(), <String>['d', 'c', 'b']);
    });

    test('clears instantly', () {
      final UniversalSearchService service = buildService();
      service.recordQuery('netflix');
      service.recordQuery('mom');
      service.clearHistory();
      expect(service.history(), isEmpty);
    });

    test('suggestions filter history by prefix or substring', () {
      final UniversalSearchService service = buildService();
      service.recordQuery('netflix');
      service.recordQuery('mom');
      service.recordQuery('grocery');
      expect(service.historySuggestions('ne'), <String>['netflix']);
      expect(service.historySuggestions('o'), <String>['grocery', 'mom']);
      expect(
        service.historySuggestions(''),
        <String>['grocery', 'mom', 'netflix'],
      );
    });

    test('uses an injectable persistent history adapter', () {
      final InMemorySearchHistoryStore store =
          InMemorySearchHistoryStore(<String>['saved query']);
      final UniversalSearchService service = buildService(historyStore: store);
      expect(service.history(), <String>['saved query']);
      service.recordQuery('fresh');
      expect(store.load(), <String>['fresh', 'saved query']);

      final UniversalSearchService reloaded =
          buildService(historyStore: store);
      expect(reloaded.history(), <String>['fresh', 'saved query']);
    });
  });
}
