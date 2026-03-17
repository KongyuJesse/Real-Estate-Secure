class PageRequest {
  const PageRequest({this.page = 1, this.limit = 20});

  final int page;
  final int limit;

  int get offset => (page - 1) * limit;

  PageRequest clamp({int maxLimit = 100}) {
    final safePage = page < 1 ? 1 : page;
    final safeLimit = limit < 1 ? 1 : (limit > maxLimit ? maxLimit : limit);
    return PageRequest(page: safePage, limit: safeLimit);
  }

  static PageRequest fromQuery(
    Map<String, String> query, {
    int defaultPage = 1,
    int defaultLimit = 20,
  }) {
    final page = int.tryParse(query['page'] ?? '') ?? defaultPage;
    final limit = int.tryParse(query['limit'] ?? '') ?? defaultLimit;
    return PageRequest(page: page, limit: limit).clamp();
  }
}

class Page<T> {
  const Page({
    required this.items,
    required this.page,
    required this.limit,
    required this.totalItems,
  });

  final List<T> items;
  final int page;
  final int limit;
  final int totalItems;

  int get totalPages => totalItems == 0 ? 0 : ((totalItems - 1) ~/ limit) + 1;

  Map<String, dynamic> toJson(Object? Function(T value) encoder) => {
        'items': items.map(encoder).toList(),
        'page': page,
        'limit': limit,
        'total_items': totalItems,
        'total_pages': totalPages,
      };
}
