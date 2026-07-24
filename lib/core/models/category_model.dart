import '../utils/l10n_utils.dart';

class CategoryModel {
  final String id;
  final Map<String, dynamic> nameMap;
  final Map<String, dynamic> descriptionMap;

  CategoryModel({
    required this.id,
    required this.nameMap,
    required this.descriptionMap,
  });

  factory CategoryModel.fromSupabase(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id']?.toString() ?? '',
      nameMap: L10nUtils.decodeField(json['name']),
      descriptionMap: L10nUtils.decodeField(json['description']),
    );
  }

  String getName(String locale) => L10nUtils.getL10n(nameMap, locale);
}
