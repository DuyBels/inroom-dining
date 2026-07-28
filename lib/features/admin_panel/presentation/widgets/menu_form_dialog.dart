import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/gemini_service.dart';
import '../../../../core/utils/l10n_utils.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/models/menu_item_model.dart';
import '../../../../main.dart';
import '../../providers/menu_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/admin_provider.dart';
import '../../providers/tag_provider.dart';

class MenuFormDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? item;
  const MenuFormDialog({super.key, this.item});

  @override
  ConsumerState<MenuFormDialog> createState() => _MenuFormDialogState();
}

class _MenuFormDialogState extends ConsumerState<MenuFormDialog> {
  final _formKey = GlobalKey<FormState>();
  
  // Dùng Map để quản lý động các Controller cho từng ngôn ngữ
  final Map<String, TextEditingController> _nameControllers = {};
  final Map<String, TextEditingController> _descControllers = {};
  
  final _priceController = TextEditingController();
  final _prepTimeController = TextEditingController(text: '15');
  final _variantController = TextEditingController();

  String? _selectedCategoryId;
  String? _selectedStationId;
  bool _isAvailable = true;
  List<String> _selectedTagIds = [];
  String? _currentImageUrl;
  Uint8List? _selectedImageBytes;
  String? _selectedImageExt;

  bool _isLoading = false;
  bool _isLoadingTags = false;
  final Map<String, bool> _isTranslating = {};

  @override
  void initState() {
    super.initState();
    // Khởi tạo controller cho tất cả ngôn ngữ được hỗ trợ
    for (var lang in L10nUtils.supportedLanguages) {
      final code = lang['code']!;
      _nameControllers[code] = TextEditingController();
      _descControllers[code] = TextEditingController();
      _isTranslating[code] = false;
    }

    if (widget.item != null) {
      final nameMap = L10nUtils.decodeField(widget.item!['name']);
      final descMap = L10nUtils.decodeField(widget.item!['description']);

      _nameControllers.forEach((code, controller) {
        controller.text = nameMap[code]?.toString() ?? '';
      });

      _descControllers.forEach((code, controller) {
        controller.text = descMap[code]?.toString() ?? '';
      });

      _priceController.text = widget.item!['price']?.toString() ?? '0';
      _prepTimeController.text = widget.item!['prep_time_minutes']?.toString() ?? '15';
      _variantController.text = widget.item!['variant_name']?.toString() ?? '';
      _selectedCategoryId = widget.item!['category_id'];
      _selectedStationId = widget.item!['station_id'];
      _isAvailable = widget.item!['is_available'] ?? true;
      _currentImageUrl = widget.item!['image_url'];
      _fetchExistingTags();
    }
  }

  @override
  void dispose() {
    _variantController.dispose();
    super.dispose();
  }

  Future<void> _fetchExistingTags() async {
    setState(() => _isLoadingTags = true);
    try {
      final response = await supabase.from('item_tags').select('tag_id').eq('item_id', widget.item!['id']);
      setState(() { _selectedTagIds = (response as List).map((e) => e['tag_id'].toString()).toList(); });
    } catch (e) { debugPrint('Lỗi thẻ: $e'); } finally { setState(() => _isLoadingTags = false); }
  }

  Future<void> _translateWithAI(String targetCode, String type) async {
    final l10n = ref.read(l10nProvider);
    final controllers = type == 'name' ? _nameControllers : _descControllers;

    String? sourceCode;
    String? sourceText;
    if (controllers['vi']?.text.trim().isNotEmpty == true) {
      sourceCode = 'vi';
      sourceText = controllers['vi']!.text.trim();
    } else {
      for (var entry in controllers.entries) {
        if (entry.value.text.trim().isNotEmpty) {
          sourceCode = entry.key;
          sourceText = entry.value.text.trim();
          break;
        }
      }
    }

    if (sourceText == null || sourceText.isEmpty) return;

    final sourceLangName = L10nUtils.supportedLanguages.firstWhere(
      (l) => l['code'] == sourceCode,
      orElse: () => {'name': sourceCode == 'vi' ? 'Vietnamese' : 'English'},
    )['name'];

    final targetLangName = L10nUtils.supportedLanguages.firstWhere((l) => l['code'] == targetCode)['name'];

    setState(() => _isTranslating[targetCode] = true);
    try {
      final result = await ref.read(geminiServiceProvider).translate(
        sourceText,
        sourceLanguage: sourceLangName!,
        targetLanguage: targetLangName!,
      );
      controllers[targetCode]!.text = result;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.errorTranslate}: $e')));
    } finally {
      if (mounted) setState(() => _isTranslating[targetCode] = false);
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() { _selectedImageBytes = bytes; _selectedImageExt = image.name.split('.').last; });
    }
  }

  Future<void> _saveMenu() async {
    final l10n = ref.read(l10nProvider);
    setState(() => _isLoading = true);

    try {
      final gemini = ref.read(geminiServiceProvider);
      await gemini.autoTranslateMap(_nameControllers);
      await gemini.autoTranslateMap(_descControllers);

      if (!_formKey.currentState!.validate()) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      String? finalImageUrl = _currentImageUrl;
      if (_selectedImageBytes != null) {
        final fileName = 'menu_${DateTime.now().millisecondsSinceEpoch}.$_selectedImageExt';
        await supabase.storage.from('menu_images').uploadBinary(fileName, _selectedImageBytes!, fileOptions: FileOptions(contentType: 'image/$_selectedImageExt', upsert: true));
        finalImageUrl = supabase.storage.from('menu_images').getPublicUrl(fileName);
      }

      // Gom tất cả các ngôn ngữ vào Map
      final Map<String, String> nameMap = {};
      _nameControllers.forEach((code, controller) => nameMap[code] = controller.text.trim());
      
      final Map<String, String> descMap = {};
      _descControllers.forEach((code, controller) => descMap[code] = controller.text.trim());

      final menuData = {
        'name': nameMap,
        'description': descMap,
        'price': double.tryParse(_priceController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0,
        'image_url': finalImageUrl,
        'prep_time_minutes': int.tryParse(_prepTimeController.text.trim()) ?? 15,
        'category_id': _selectedCategoryId,
        'station_id': _selectedStationId,
        'is_available': _isAvailable,
        'variant_name': _variantController.text.trim().isNotEmpty ? _variantController.text.trim() : null,
      };

      String menuItemId;
      if (widget.item == null) {
        final res = await supabase.from('menu_items').insert(menuData).select('id').single();
        menuItemId = res['id'].toString();
      } else {
        menuItemId = widget.item!['id'].toString();
        await supabase.from('menu_items').update(menuData).eq('id', menuItemId);
      }

      await supabase.from('item_tags').delete().eq('item_id', menuItemId);
      if (_selectedTagIds.isNotEmpty) {
        await supabase.from('item_tags').insert(_selectedTagIds.map((tagId) => {'item_id': menuItemId, 'tag_id': tagId}).toList());
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.errorPrefix}: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final locale = ref.watch(localeProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final stationsAsync = ref.watch(stationsStreamProvider);
    final tagsAsync = ref.watch(tagsStreamProvider);

    return AlertDialog(
      title: Text(widget.item == null ? l10n.addItemTitle : l10n.editItem),
      content: SizedBox(
        width: 800,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: Column(children: [
                  Container(height: 200, width: double.infinity, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: _selectedImageBytes != null ? Image.memory(_selectedImageBytes!, fit: BoxFit.cover) : (_currentImageUrl != null ? Image.network(_currentImageUrl!, fit: BoxFit.cover) : const Icon(Icons.add_photo_alternate, size: 64)))),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(onPressed: _pickImage, icon: const Icon(Icons.upload_file), label: Text(l10n.chooseImage))
                ])),
                const SizedBox(width: 24),
                Expanded(flex: 5, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // --- TỰ ĐỘNG SINH Ô NHẬP TÊN CHO TẤT CẢ NGÔN NGỮ ---
                  ...L10nUtils.supportedLanguages.map((lang) {
                    final code = lang['code']!;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _nameControllers[code],
                              decoration: InputDecoration(labelText: '${l10n.itemNameLang} (${lang['name']})', border: const OutlineInputBorder()),
                              validator: (val) {
                                if (code == 'vi' || code == 'en') {
                                  if (_nameControllers.values.every((c) => c.text.trim().isEmpty)) {
                                    return l10n.validName;
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                          if (code != 'vi') IconButton(onPressed: _isTranslating[code] == true ? null : () => _translateWithAI(code, 'name'), icon: _isTranslating[code] == true ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome, color: Colors.purple))
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _variantController,
                    decoration: InputDecoration(labelText: locale == 'vi' ? 'Tên biến thể (Tuỳ chọn, vd: Món nước)' : 'Variant Name (Optional)', border: const OutlineInputBorder()),
                  ),

                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        decoration: InputDecoration(labelText: l10n.priceLabel, border: const OutlineInputBorder(), suffixText: 'đ'),
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return locale == 'vi' ? 'Vui lòng nhập giá món ăn' : 'Please enter price';
                          }
                          final cleanVal = val.replaceAll('.', '').replaceAll(',', '');
                          final price = double.tryParse(cleanVal);
                          if (price == null || price < 0) {
                            return locale == 'vi' ? 'Giá tiền không hợp lệ' : 'Invalid price';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _prepTimeController,
                        decoration: InputDecoration(labelText: l10n.cookTimeLabel, border: const OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return locale == 'vi' ? 'Vui lòng nhập thời gian' : 'Please enter cook time';
                          }
                          final time = int.tryParse(val.trim());
                          if (time == null || time <= 0) {
                            return locale == 'vi' ? 'Thời gian chế biến phải > 0' : 'Prep time must be > 0';
                          }
                          return null;
                        },
                      ),
                    ),
                  ]),

                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: categoriesAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (e, s) => Text(l10n.errorPrefix),
                        data: (cats) => DropdownButtonFormField<String>(
                          value: cats.any((c) => c.id == _selectedCategoryId) ? _selectedCategoryId : null,
                          decoration: InputDecoration(labelText: l10n.categoryLabel, border: const OutlineInputBorder()),
                          items: cats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.getName(locale)))).toList(),
                          onChanged: (v) => setState(() => _selectedCategoryId = v),
                          validator: (v) => v == null || v.isEmpty ? (locale == 'vi' ? 'Vui lòng chọn danh mục' : 'Please select category') : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: stationsAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (e, s) => Text(l10n.errorPrefix),
                        data: (stats) => DropdownButtonFormField<String>(
                          value: stats.any((s) => s['id'].toString() == _selectedStationId) ? _selectedStationId : null,
                          decoration: InputDecoration(labelText: l10n.stationLabel, border: const OutlineInputBorder()),
                          items: stats.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(L10nUtils.getL10n(s['name'], locale)))).toList(),
                          onChanged: (v) => setState(() => _selectedStationId = v),
                          validator: (v) => v == null || v.isEmpty ? l10n.validStation : null,
                        ),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 16),
                  // --- TỰ ĐỘNG SINH Ô NHẬP MÔ TẢ ---
                  ...L10nUtils.supportedLanguages.map((lang) {
                    final code = lang['code']!;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          Expanded(child: TextFormField(controller: _descControllers[code], maxLines: 2, decoration: InputDecoration(labelText: '${l10n.descriptionFieldLang} (${lang['name']})', border: const OutlineInputBorder()))),
                          if (code != 'vi') IconButton(onPressed: _isTranslating[code] == true ? null : () => _translateWithAI(code, 'description'), icon: _isTranslating[code] == true ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome, color: Colors.purple))
                        ],
                      ),
                    );
                  }),

                  Text(l10n.attachTag, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  tagsAsync.when(loading: () => const CircularProgressIndicator(), error: (e, s) => Text(l10n.errorPrefix), data: (tags) => Wrap(spacing: 8, children: tags.map((t) => FilterChip(label: Text(t.getName(locale)), selected: _selectedTagIds.contains(t.id), onSelected: (v) => setState(() => v ? _selectedTagIds.add(t.id) : _selectedTagIds.remove(t.id)))).toList())),
                  SwitchListTile(title: Text(l10n.availabilityStatus), value: _isAvailable, onChanged: (v) => setState(() => _isAvailable = v), contentPadding: EdgeInsets.zero)
                ]))
              ],
            ),
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)), ElevatedButton(onPressed: _isLoading ? null : _saveMenu, child: _isLoading ? const CircularProgressIndicator() : Text(l10n.saveItem))],
    );
  }
}
