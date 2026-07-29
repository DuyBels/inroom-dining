import '../utils/l10n_utils.dart';

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
  final String? variantName; // Legacy
  final String? categoryVariantId; // Mới
  final List<String> tagIds;

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
    this.variantName,
    this.categoryVariantId,
    this.tagIds = const [],
  });

  factory MenuItemModel.fromSupabase(Map<String, dynamic> json, {List<String>? tags}) {
    return MenuItemModel(
      id: json['id']?.toString() ?? '',
      price: num.tryParse(json['price']?.toString() ?? '0')?.toDouble() ?? 0.0,
      nameMap: L10nUtils.decodeField(json['name']),
      descriptionMap: L10nUtils.decodeField(json['description']),
      imageUrl: json['image_url'],
      prepTime: int.tryParse(json['prep_time_minutes']?.toString() ?? '15') ?? 15,
      categoryId: json['category_id']?.toString() ?? '',
      stationId: json['station_id']?.toString() ?? '',
      isAvailable: json['is_available'] ?? true,
      variantName: json['variant_name']?.toString(),
      categoryVariantId: json['category_variant_id']?.toString(),
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
      variantName: variantName,
      categoryVariantId: categoryVariantId,
      tagIds: tagIds ?? this.tagIds,
    );
  }

  String getName(String locale) => L10nUtils.getL10n(nameMap, locale);
  String getDescription(String locale) => L10nUtils.getL10n(descriptionMap, locale);
}
