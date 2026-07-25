import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/gemini_service.dart';
import '../../../../core/utils/l10n_utils.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../main.dart';
import '../../providers/category_provider.dart';

class CategoryFormDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? category;

  const CategoryFormDialog({super.key, this.category});

  @override
  ConsumerState<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends ConsumerState<CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _descController = TextEditingController();
  final _descEnController = TextEditingController();
  bool _isLoading = false;
  bool _isTranslating = false;

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      final nameMap = L10nUtils.decodeField(widget.category!['name']);
      final descMap = L10nUtils.decodeField(widget.category!['description']);

      _nameController.text = nameMap['vi']?.toString() ?? '';
      _nameEnController.text = nameMap['en']?.toString() ?? '';
      _descController.text = descMap['vi']?.toString() ?? '';
      _descEnController.text = descMap['en']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameEnController.dispose();
    _descController.dispose();
    _descEnController.dispose();
    super.dispose();
  }

  Future<void> _translateWithAI() async {
    if (_nameController.text.trim().isEmpty && _nameEnController.text.trim().isEmpty) return;
    final l10n = ref.read(l10nProvider);
    setState(() => _isTranslating = true);
    try {
      final gemini = ref.read(geminiServiceProvider);
      await gemini.autoTranslatePair(viController: _nameController, enController: _nameEnController, force: true);
      await gemini.autoTranslatePair(viController: _descController, enController: _descEnController, force: true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.errorTranslate}: $e')));
    } finally {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  Future<void> _saveCategory() async {
    final l10n = ref.read(l10nProvider);
    setState(() => _isLoading = true);

    try {
      final gemini = ref.read(geminiServiceProvider);
      await gemini.autoTranslatePair(viController: _nameController, enController: _nameEnController);
      await gemini.autoTranslatePair(viController: _descController, enController: _descEnController);

      if (!_formKey.currentState!.validate()) {
        setState(() => _isLoading = false);
        return;
      }

      final data = {
        'name': {
          'vi': _nameController.text.trim(),
          'en': _nameEnController.text.trim(),
        },
        'description': {
          'vi': _descController.text.trim(),
          'en': _descEnController.text.trim(),
        },
      };

      if (widget.category == null) {
        await supabase.from('categories').insert(data);
      } else {
        await supabase.from('categories').update(data).eq('id', widget.category!['id']);
      }

      if (mounted) {
        Navigator.pop(context);
        // Không cần invalidate vì categoriesStreamProvider tự động cập nhật Realtime
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.errorPrefix}: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    return AlertDialog(
      title: Text(widget.category == null ? l10n.addCategory : l10n.editCategory),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(labelText: '${l10n.categoryNameLang} (VI)', border: const OutlineInputBorder()),
                      validator: (val) => val == null || val.trim().isEmpty ? l10n.validName : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isTranslating ? null : _translateWithAI,
                    icon: _isTranslating 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome, color: Colors.purple),
                    tooltip: l10n.aiTranslateTooltip,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _nameEnController,
                      decoration: InputDecoration(labelText: '${l10n.categoryNameLang} (EN)', border: const OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _descController,
                      decoration: InputDecoration(labelText: '${l10n.descriptionLang} (VI)', border: const OutlineInputBorder()),
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(width: 48), // Chỉnh padding để khớp với nút dịch ở trên
                  Expanded(
                    child: TextFormField(
                      controller: _descEnController,
                      decoration: InputDecoration(labelText: '${l10n.descriptionLang} (EN)', border: const OutlineInputBorder()),
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveCategory,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
          child: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(l10n.save),
        ),
      ],
    );
  }
}