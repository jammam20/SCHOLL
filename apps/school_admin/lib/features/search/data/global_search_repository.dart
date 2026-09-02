import 'package:cloud_firestore/cloud_firestore.dart';

/// One result row, already resolved to a kind + id + label — the search
/// page renders these uniformly regardless of which collection they came
/// from.
enum SearchResultKind { student, parent, driver, bus, route }

class SearchResult {
  const SearchResult({
    required this.kind,
    required this.id,
    required this.title,
    this.subtitle,
  });

  final SearchResultKind kind;
  final String id;
  final String title;
  final String? subtitle;
}

/// Admin global search across students, parents, drivers, buses and
/// routes (Feature: Global search) — school-isolated (every query is
/// scoped under `schools/{schoolId}`, same as every other repository in
/// this app) and never loads a whole collection to search it: each
/// lookup is a real Firestore prefix-range query
/// (`orderBy(field).startAt([q]).endAt([q + ''])`) against the same
/// fields the existing list screens already `orderBy` on, so no new
/// composite index is required.
///
/// Honest limitation, not a bug: Firestore has no case-insensitive or
/// substring "contains" query, and this project stores no lowercase
/// search-index copy of these names (adding one would mean backfilling
/// every existing document, which isn't warranted for this). So this
/// matches from the *start* of a name, in the exact case it was typed —
/// "Ahmed" finds "Ahmed Mohamed", "ahmed" or "Mohamed" alone will not.
class GlobalSearchRepository {
  GlobalSearchRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _school(String schoolId) =>
      _firestore.collection('schools').doc(schoolId);

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _prefixQuery(
    Query<Map<String, dynamic>> collection,
    String field,
    String query, {
    int limit = 10,
  }) async {
    final snapshot = await collection
        .orderBy(field)
        .startAt([query])
        .endAt(['$query'])
        .limit(limit)
        .get();
    return snapshot.docs;
  }

  Future<List<SearchResult>> search(String schoolId, String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final results = await Future.wait([
      _prefixQuery(_school(schoolId).collection('students'), 'name', trimmed),
      _prefixQuery(
        _school(schoolId).collection('members').where('role', isEqualTo: 'parent'),
        'displayName',
        trimmed,
      ),
      _prefixQuery(
        _school(schoolId).collection('members').where('role', isEqualTo: 'driver'),
        'displayName',
        trimmed,
      ),
      _prefixQuery(_school(schoolId).collection('buses'), 'name', trimmed),
      _prefixQuery(
        _school(schoolId).collection('buses'),
        'plateNumber',
        trimmed,
      ),
      _prefixQuery(_school(schoolId).collection('routes'), 'name', trimmed),
    ]);

    final students = results[0];
    final parents = results[1];
    final drivers = results[2];
    final busesByName = results[3];
    final busesByPlate = results[4];
    final routes = results[5];

    final seenBusIds = <String>{};
    final busResults = <SearchResult>[
      for (final doc in [...busesByName, ...busesByPlate])
        if (seenBusIds.add(doc.id))
          SearchResult(
            kind: SearchResultKind.bus,
            id: doc.id,
            title: doc.data()['name']?.toString() ?? doc.id,
            subtitle: doc.data()['plateNumber']?.toString(),
          ),
    ];

    return [
      for (final doc in students)
        SearchResult(
          kind: SearchResultKind.student,
          id: doc.id,
          title: doc.data()['name']?.toString() ?? doc.id,
          subtitle: doc.data()['grade'] == null
              ? null
              : 'Grade ${doc.data()['grade']}',
        ),
      for (final doc in parents)
        SearchResult(
          kind: SearchResultKind.parent,
          id: doc.id,
          title: doc.data()['displayName']?.toString() ?? doc.id,
        ),
      for (final doc in drivers)
        SearchResult(
          kind: SearchResultKind.driver,
          id: doc.id,
          title: doc.data()['displayName']?.toString() ?? doc.id,
        ),
      ...busResults,
      for (final doc in routes)
        SearchResult(
          kind: SearchResultKind.route,
          id: doc.id,
          title: doc.data()['name']?.toString() ?? doc.id,
        ),
    ];
  }
}
