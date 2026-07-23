class TagModel {
  final String id;
  final Map<String, dynamic> nameMap;
  final String tagType;

  TagModel({
    required this.id,
    required this.nameMap,
    required this.tagType,
  });

  factory TagModel.fromSupabase(Map<String, dynamic> json) {
    return TagModel(
      id: json['id'],
      nameMap: json['name'] is Map ? json['name'] : {'vi': json['name'] ?? ''},
      tagType: json['tag_type'] ?? 'ALLERGY',
    );
  }

  String getName(String locale) {
    final val = nameMap[locale]?.toString();
    if (val != null && val.trim().isNotEmpty) return val;
    return nameMap['vi']?.toString() ?? '';
  }
}
