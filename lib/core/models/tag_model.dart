import '../utils/l10n_utils.dart';

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
      id: json['id']?.toString() ?? '',
      nameMap: L10nUtils.decodeField(json['name']),
      tagType: json['tag_type'] ?? 'ALLERGY',
    );
  }

  String getName(String locale) => L10nUtils.getL10n(nameMap, locale);
}
