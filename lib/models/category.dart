class Category {
  final String id;
  final String name;
  final String emoji;
  final String colorHex;
  final int sortOrder;

  Category({
    required this.id,
    required this.name,
    this.emoji = '📚',
    this.colorHex = '#D4AF37',
    this.sortOrder = 0,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '📚',
      colorHex: json['color_hex'] as String? ?? '#D4AF37',
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'color_hex': colorHex,
      'sort_order': sortOrder,
    };
  }
}
