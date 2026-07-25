import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/gemini_service.dart';
import '../../../../core/utils/l10n_utils.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../main.dart';
import '../../providers/admin_provider.dart'; 

class StationFormDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? station;

  const StationFormDialog({super.key, this.station});

  @override
  ConsumerState<StationFormDialog> createState() => _StationFormDialogState();
}

class _StationFormDialogState extends ConsumerState<StationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameViController = TextEditingController();
  final _nameEnController = TextEditingController();
  bool _isLoading = false;
  bool _isTranslating = false;

  @override
  void initState() {
    super.initState();
    if (widget.station != null) {
      final nameMap = L10nUtils.decodeField(widget.station!['name']);
      _nameViController.text = nameMap['vi']?.toString() ?? '';
      _nameEnController.text = nameMap['en']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _nameViController.dispose();
    _nameEnController.dispose();
    super.dispose();
  }

  Future<void> _translateWithAI() async {
    if (_nameViController.text.trim().isEmpty && _nameEnController.text.trim().isEmpty) return;
    final l10n = ref.read(l10nProvider);
    setState(() => _isTranslating = true);
    try {
      final gemini = ref.read(geminiServiceProvider);
      await gemini.autoTranslatePair(viController: _nameViController, enController: _nameEnController, force: true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.errorTranslate}: $e')));
    } finally {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  Future<void> _saveStation() async {
    final l10n = ref.read(l10nProvider);
    setState(() => _isLoading = true);

    try {
      final gemini = ref.read(geminiServiceProvider);
      await gemini.autoTranslatePair(viController: _nameViController, enController: _nameEnController);

      if (!_formKey.currentState!.validate()) {
        setState(() => _isLoading = false);
        return;
      }

      final data = {
        'name': {
          'vi': _nameViController.text.trim(),
          'en': _nameEnController.text.trim(),
        },
      };

      if (widget.station == null) {
        // Thêm mới
        await supabase.from('kitchen_stations').insert(data);
      } else {
        // Cập nhật
        await supabase.from('kitchen_stations').update(data).eq('id', widget.station!['id']);
      }

      if (mounted) {
        Navigator.pop(context);
        // Đã xóa ref.invalidate vì stationsStreamProvider là StreamProvider, 
        // nó sẽ tự động cập nhật khi DB thay đổi (Realtime).
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.errorPrefix}: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    return AlertDialog(
      title: Text(widget.station == null ? l10n.addStation : l10n.editStation),
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
                      controller: _nameViController,
                      decoration: InputDecoration(labelText: '${l10n.stationNameLang} (VI)', border: const OutlineInputBorder()),
                      validator: (val) => val == null || val.trim().isEmpty ? l10n.validStationName : null,
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
                      decoration: InputDecoration(labelText: '${l10n.stationNameLang} (EN)', border: const OutlineInputBorder()),
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
          onPressed: _isLoading ? null : _saveStation,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
          child: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(l10n.save),
        ),
      ],
    );
  }
}