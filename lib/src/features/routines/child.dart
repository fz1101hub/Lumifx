/// A child of the family, with their own routines, stars and star shop.
class Child {
  const Child({required this.id, required this.name});

  /// Stable; the first child's is empty, so the stars earned before there
  /// were profiles become theirs.
  final String id;
  final String name;

  static const maxChildren = 6;
  static const maxName = 30;

  Map<String, Object?> toJson() => {'id': id, 'name': name};

  static Child? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final id = json['id'];
    final name = json['name'];
    if (id is! String ||
        id.length > 30 ||
        id.contains('|') ||
        name is! String ||
        name.trim().isEmpty) {
      return null;
    }
    final trimmed = name.trim();
    return Child(
      id: id,
      name: trimmed.length > maxName ? trimmed.substring(0, maxName) : trimmed,
    );
  }
}
