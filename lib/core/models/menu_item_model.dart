class MenuItemModel {
  final String id;
  final double price;
  final Map<String, dynamic> nameMap;
  final Map<String, dynamic> descriptionMap;
  final String? imageUrl;
  final int prepTime;
  final String categoryId;
  final String stationId;
  final bool isAvailable;
  final List<String> tagIds; // Thêm tagIds vào model

  MenuItemModel({
    required this.id,
    required this.price,
    required this.nameMap,
    required this.descriptionMap,
    this.imageUrl,
    required this.prepTime,
    required this.categoryId,
    required this.stationId,
    required this.isAvailable,
    this.tagIds = const [],
  });

  factory MenuItemModel.fromSupabase(Map<String, dynamic> json, {List<String>? tags}) {
    return MenuItemModel(
      id: json['id'],
      price: num.tryParse(json['price'].toString())?.toDouble() ?? 0.0,
      nameMap: json['name'] is Map ? json['name'] : {'vi': json['name'] ?? ''},
      descriptionMap: json['description'] is Map ? json['description'] : {'vi': json['description'] ?? ''},
      imageUrl: json['image_url'],
      prepTime: json['prep_time_minutes'] ?? 15,
      categoryId: json['category_id'] ?? '',
      stationId: json['station_id'] ?? '',
      isAvailable: json['is_available'] ?? true,
      tagIds: tags ?? [],
    );
  }

  MenuItemModel copyWith({List<String>? tagIds}) {
    return MenuItemModel(
      id: id,
      price: price,
      nameMap: nameMap,
      descriptionMap: descriptionMap,
      imageUrl: imageUrl,
      prepTime: prepTime,
      categoryId: categoryId,
      stationId: stationId,
      isAvailable: isAvailable,
      tagIds: tagIds ?? this.tagIds,
    );
  }

  String getName(String locale) {
    final val = nameMap[locale]?.toString();
    if (val != null && val.trim().isNotEmpty) return val;
    return nameMap['vi']?.toString() ?? '';
  }

  String getDescription(String locale) {
    final val = descriptionMap[locale]?.toString();
    if (val != null && val.trim().isNotEmpty) return val;
    return descriptionMap['vi']?.toString() ?? '';
  }
}
