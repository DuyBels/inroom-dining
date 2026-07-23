class CategoryModel {
  final String id;
  final Map<String, dynamic> nameMap;
  final Map<String, dynamic>? descriptionMap;

  CategoryModel({
    required this.id,
    required this.nameMap,
    this.descriptionMap,
  });

  factory CategoryModel.fromSupabase(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'],
      nameMap: json['name'] is Map ? json['name'] : {'vi': json['name'] ?? ''},
      descriptionMap: json['description'] is Map ? json['description'] : {'vi': json['description'] ?? ''},
    );
  }

  String getName(String locale) {
    final val = nameMap[locale]?.toString();
    if (val != null && val.trim().isNotEmpty) return val;
    return nameMap['vi']?.toString() ?? '';
  }
}
