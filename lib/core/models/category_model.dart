import 'package:flutter/material.dart';
import '../utils/l10n_utils.dart';
import '../utils/category_icon_utils.dart';

class CategoryModel {
  final String id;
  final Map<String, dynamic> nameMap;
  final Map<String, dynamic> descriptionMap;
  final String? iconName;

  CategoryModel({
    required this.id,
    required this.nameMap,
    required this.descriptionMap,
    this.iconName,
  });

  factory CategoryModel.fromSupabase(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id']?.toString() ?? '',
      nameMap: L10nUtils.decodeField(json['name']),
      descriptionMap: L10nUtils.decodeField(json['description']),
      iconName: json['icon_name']?.toString() ?? json['icon']?.toString(),
    );
  }

  String getName(String locale) => L10nUtils.getL10n(nameMap, locale);

  IconData get iconData => CategoryIconUtils.getIconData(iconName, getName('vi'));
}

