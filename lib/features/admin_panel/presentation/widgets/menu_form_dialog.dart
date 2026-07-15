import '../../../../core/services/gemini_service.dart';
import '../../../../core/utils/l10n_utils.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../main.dart'; // import supabase
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
  final _nameController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _descController = TextEditingController();
  final _descEnController = TextEditingController();
  final _priceController = TextEditingController();
  final _prepTimeController = TextEditingController(text: '15');

  String? _selectedCategoryId;
  String? _selectedStationId;
  bool _isAvailable = true;

  // Quản lý Tags
  List<String> _selectedTagIds = [];

  // Quản lý Ảnh
  String? _currentImageUrl; // Link ảnh hiện tại trên DB
  Uint8List? _selectedImageBytes; // File ảnh mới vừa chọn (Dùng bytes cho Web)
  String? _selectedImageExt; // Đuôi file ảnh (.png, .jpg)

  bool _isLoading = false;
  bool _isLoadingTags = false;
  bool _isTranslatingName = false;
  bool _isTranslatingDesc = false;

  // Hàm dịch tự động bằng AI
  Future<void> _translateWithAI(String type) async {
    final gemini = ref.read(geminiServiceProvider);
    try {
      if (type == 'name') {
        if (_nameController.text.isEmpty) return;
        setState(() => _isTranslatingName = true);
        final result = await gemini.translate(_nameController.text);
        _nameEnController.text = result;
      } else {
        if (_descController.text.isEmpty) return;
        setState(() => _isTranslatingDesc = true);
        final result = await gemini.translate(_descController.text);
        _descEnController.text = result;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi dịch: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTranslatingName = false;
          _isTranslatingDesc = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      // Load thông tin cơ bản (Xử lý JSONB mới)
      final nameData = widget.item!['name'];
      final descData = widget.item!['description'];

      if (nameData is Map) {
        _nameController.text = nameData['vi']?.toString() ?? '';
        _nameEnController.text = nameData['en']?.toString() ?? '';
      } else {
        _nameController.text = nameData?.toString() ?? '';
      }

      if (descData is Map) {
        _descController.text = descData['vi']?.toString() ?? '';
        _descEnController.text = descData['en']?.toString() ?? '';
      } else {
        _descController.text = descData?.toString() ?? '';
      }

      _priceController.text = widget.item!['price']?.toString() ?? '0';
      _prepTimeController.text = widget.item!['prep_time_minutes']?.toString() ?? '15';
      _selectedCategoryId = widget.item!['category_id'];
      _selectedStationId = widget.item!['station_id'];
      _isAvailable = widget.item!['is_available'] ?? true;
      _currentImageUrl = widget.item!['image_url'];

      // Load danh sách thẻ từ bảng trung gian item_tags
      _fetchExistingTags();
    }
  }

  // Hàm gọi DB để lấy các thẻ cũ của món này
  Future<void> _fetchExistingTags() async {
    setState(() => _isLoadingTags = true);
    try {
      final response = await supabase
          .from('item_tags')
          .select('tag_id')
          .eq('item_id', widget.item!['id']);

      setState(() {
        _selectedTagIds = (response as List).map((e) => e['tag_id'].toString()).toList();
      });
    } catch (e) {
      debugPrint('Lỗi tải thẻ cũ: $e');
    } finally {
      setState(() => _isLoadingTags = false);
    }
  }

  // Hàm chọn ảnh từ máy tính/điện thoại
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final bytes = await image.readAsBytes();
      final ext = image.name.split('.').last; // Lấy đuôi file
      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageExt = ext;
      });
    }
  }

  // Luồng lưu dữ liệu 3 bước
  Future<void> _saveMenu() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      String? finalImageUrl = _currentImageUrl;

      // ==========================================
      // BƯỚC 1: UPLOAD ẢNH NẾU CÓ CHỌN ẢNH MỚI
      // ==========================================
      if (_selectedImageBytes != null) {
        final fileName = 'menu_${DateTime.now().millisecondsSinceEpoch}.$_selectedImageExt';

        await supabase.storage.from('menu_images').uploadBinary(
          fileName,
          _selectedImageBytes!,
          fileOptions: FileOptions(contentType: 'image/$_selectedImageExt', upsert: true),
        );
        // Lấy link public
        finalImageUrl = supabase.storage.from('menu_images').getPublicUrl(fileName);
      }

      // ==========================================
      // BƯỚC 2: LƯU THÔNG TIN MÓN ĂN VÀO menu_items
      // ==========================================
      // Xử lý giá tiền: Xóa bỏ các dấu chấm/phẩy nếu người dùng nhập tay để định dạng
      String cleanPrice = _priceController.text.trim().replaceAll('.', '').replaceAll(',', '');
      
      final menuData = {
        'name': {
          'vi': _nameController.text.trim(),
          'en': _nameEnController.text.trim(),
        },
        'description': {
          'vi': _descController.text.trim(),
          'en': _descEnController.text.trim(),
        },
        'price': double.tryParse(cleanPrice) ?? 0,
        'image_url': finalImageUrl,
        'prep_time_minutes': int.tryParse(_prepTimeController.text.trim()) ?? 15,
        'category_id': _selectedCategoryId,
        'station_id': _selectedStationId,
        'is_available': _isAvailable,
      };

      String menuItemId;

      if (widget.item == null) {
        // Luồng Thêm: Cần dùng select().single() để lấy ID món ăn vừa tạo trả về
        final response = await supabase.from('menu_items').insert(menuData).select('id').single();
        menuItemId = response['id'].toString();
      } else {
        // Luồng Sửa
        menuItemId = widget.item!['id'].toString();
        await supabase.from('menu_items').update(menuData).eq('id', menuItemId);
      }

      // ==========================================
      // BƯỚC 3: CẬP NHẬT BẢNG TRUNG GIAN item_tags
      // ==========================================
      // Xóa toàn bộ thẻ cũ của món này
      await supabase.from('item_tags').delete().eq('item_id', menuItemId);

      // Thêm lại danh sách thẻ mới (nếu có chọn)
      if (_selectedTagIds.isNotEmpty) {
        final List<Map<String, dynamic>> tagsToInsert = _selectedTagIds.map((tagId) {
          return {
            'item_id': menuItemId,
            'tag_id': tagId,
          };
        }).toList();

        await supabase.from('item_tags').insert(tagsToInsert);
      }

      // Xong xuôi -> Đóng
      if (mounted) {
        Navigator.pop(context);
        // Không cần invalidate vì menuItemsStreamProvider tự động cập nhật Realtime
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final stationsAsync = ref.watch(stationsStreamProvider);
    final tagsAsync = ref.watch(tagsStreamProvider);

    return AlertDialog(
      title: Text(widget.item == null ? 'Thêm Món Mới' : 'Sửa Món Ăn', style: const TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 700,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // CỘT TRÁI: ẢNH SẢN PHẨM
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[400]!),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _selectedImageBytes != null
                              ? Image.memory(_selectedImageBytes!, fit: BoxFit.cover) // Ảnh mới chọn
                              : (_currentImageUrl != null && _currentImageUrl!.isNotEmpty)
                              ? Image.network(_currentImageUrl!, fit: BoxFit.cover) // Ảnh cũ từ DB
                              : const Icon(Icons.add_photo_alternate, size: 64, color: Colors.grey), // Chưa có ảnh
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Chọn hình ảnh'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),

                // CỘT PHẢI: NHẬP LIỆU
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // TÊN MÓN ĂN - SONG NGỮ
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(labelText: 'Tên món ăn (VI)', border: OutlineInputBorder()),
                              validator: (val) => val == null || val.isEmpty ? 'Nhập tên' : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _isTranslatingName ? null : () => _translateWithAI('name'),
                            icon: _isTranslatingName 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.auto_awesome, color: Colors.purple),
                            tooltip: 'AI Dịch sang tiếng Anh',
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _nameEnController,
                              decoration: const InputDecoration(labelText: 'Tên món ăn (EN)', border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _priceController,
                        decoration: const InputDecoration(labelText: 'Giá tiền', border: OutlineInputBorder(), suffixText: 'đ'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: categoriesAsync.when(
                              loading: () => const CircularProgressIndicator(),
                              error: (e, st) => const Text('Lỗi'),
                              data: (cats) => DropdownButtonFormField<String>(
                                value: _selectedCategoryId,
                                decoration: const InputDecoration(labelText: 'Danh mục', border: OutlineInputBorder()),
                                items: cats.map((c) {
                                  final name = L10nUtils.getL10n(c['name'], 'vi');
                                  return DropdownMenuItem(value: c['id'].toString(), child: Text(name));
                                }).toList(),
                                onChanged: (val) => setState(() => _selectedCategoryId = val),
                                validator: (val) => val == null ? 'Chọn danh mục' : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: stationsAsync.when(
                              loading: () => const CircularProgressIndicator(),
                              error: (e, st) => const Text('Lỗi'),
                              data: (stations) => DropdownButtonFormField<String>(
                                value: _selectedStationId,
                                decoration: const InputDecoration(labelText: 'Trạm Bếp', border: OutlineInputBorder()),
                                items: stations.map((s) {
                                  final name = L10nUtils.getL10n(s['name'], 'vi');
                                  return DropdownMenuItem(value: s['id'].toString(), child: Text(name));
                                }).toList(),
                                onChanged: (val) => setState(() => _selectedStationId = val),
                                validator: (val) => val == null ? 'Chọn Bếp' : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _prepTimeController,
                        decoration: const InputDecoration(labelText: 'Thời gian nấu (phút)', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),

                      // MÔ TẢ - SONG NGỮ
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _descController,
                              decoration: const InputDecoration(labelText: 'Mô tả (VI)', border: OutlineInputBorder()),
                              maxLines: 2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _isTranslatingDesc ? null : () => _translateWithAI('description'),
                            icon: _isTranslatingDesc 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.auto_awesome, color: Colors.purple),
                            tooltip: 'AI Dịch sang tiếng Anh',
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _descEnController,
                              decoration: const InputDecoration(labelText: 'Mô tả (EN)', border: OutlineInputBorder()),
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // BỘ LỌC CHỌN THẺ
                      const Text('Gắn Thẻ (Dị ứng, Khẩu vị, ...):', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      _isLoadingTags
                          ? const CircularProgressIndicator()
                          : tagsAsync.when(
                        loading: () => const CircularProgressIndicator(),
                        error: (e, st) => const Text('Lỗi tải thẻ'),
                        data: (tags) {
                          if (tags.isEmpty) return const Text('Chưa có thẻ nào.', style: TextStyle(fontStyle: FontStyle.italic));
                          return Wrap(
                            spacing: 8.0,
                            runSpacing: 4.0,
                            children: tags.map((tag) {
                              final tagId = tag['id'].toString();
                              final isSelected = _selectedTagIds.contains(tagId);
                              final String tagName = L10nUtils.getL10n(tag['name'], 'vi');

                              return FilterChip(
                                label: Text(tagName),
                                selected: isSelected,
                                selectedColor: Colors.blue[100],
                                checkmarkColor: Colors.blue[800],
                                onSelected: (bool selected) {
                                  setState(() {
                                    if (selected) _selectedTagIds.add(tagId);
                                    else _selectedTagIds.remove(tagId);
                                  });
                                },
                              );
                            }).toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      SwitchListTile(
                        title: const Text('Trạng thái mở bán (Khả dụng)'),
                        value: _isAvailable,
                        onChanged: (val) => setState(() => _isAvailable = val),
                        contentPadding: EdgeInsets.zero,
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveMenu,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
          child: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Lưu Món Ăn'),
        ),
      ],
    );
  }
}