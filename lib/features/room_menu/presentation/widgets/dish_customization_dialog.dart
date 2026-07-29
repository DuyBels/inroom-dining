import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/models/menu_item_model.dart';
import '../../../../core/theme/admin_theme.dart';
import '../../../../core/utils/l10n_utils.dart';
import '../../providers/room_menu_provider.dart';

class DishCustomizationDialog extends ConsumerStatefulWidget {
  final MenuItemModel item;
  final List<SelectedModifier>? initialSelectedModifiers;
  final String? initialNotes;

  const DishCustomizationDialog({
    super.key,
    required this.item,
    this.initialSelectedModifiers,
    this.initialNotes,
  });

  @override
  ConsumerState<DishCustomizationDialog> createState() => _DishCustomizationDialogState();
}

class _DishCustomizationDialogState extends ConsumerState<DishCustomizationDialog> {
  final List<SelectedModifier> _selectedModifiers = [];
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialSelectedModifiers != null) {
      _selectedModifiers.addAll(widget.initialSelectedModifiers!);
    }
    if (widget.initialNotes != null && widget.initialNotes!.isNotEmpty) {
      _noteController.text = widget.initialNotes!;
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  bool _isSelectionValid(List<Map<String, dynamic>> groups) {
    for (var group in groups) {
      final int min = group['min_select'] ?? 0;
      final selectedInGroup = _selectedModifiers.where((m) => m.groupId == group['id']).length;
      if (selectedInGroup < min) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final locale = ref.watch(localeProvider);
    final modifiersAsync = ref.watch(itemModifiersProvider(widget.item.id));

    return Dialog(
      backgroundColor: AdminTheme.surfaceWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dialogWidth = constraints.maxWidth < 600 ? constraints.maxWidth * 0.95 : 550.0;
          return SizedBox(
            width: dialogWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    if (widget.item.imageUrl != null)
                      Image.network(widget.item.imageUrl!, height: 180, width: double.infinity, fit: BoxFit.cover)
                    else
                      Container(height: 100, color: AdminTheme.primaryWood),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: CircleAvatar(
                        backgroundColor: Colors.black38,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                          ),
                        ),
                        child: Text(
                          widget.item.getName(locale),
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                Flexible(
                  child: modifiersAsync.when(
                    data: (groups) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (groups.isNotEmpty) ...[
                              ...groups.map((group) => _buildModifierGroup(group, l10n, locale)),
                              const SizedBox(height: 12),
                            ],
                            Row(
                              children: [
                                const Icon(Icons.edit_note_rounded, size: 18, color: AdminTheme.primaryWood),
                                const SizedBox(width: 6),
                                Text(
                                  l10n.specialNotes,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AdminTheme.textDarkWood),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _noteController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                hintText: l10n.specialInstructions,
                                filled: true,
                                fillColor: AdminTheme.bgWarmWhite,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AdminTheme.borderWood),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AdminTheme.primaryWood, width: 1.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Padding(padding: const EdgeInsets.all(20), child: Text('${l10n.errorLoading}: $e')),
                  ),
                ),
                modifiersAsync.maybeWhen(
                  data: (groups) => _buildFooter(_isSelectionValid(groups), l10n),
                  orElse: () => const SizedBox(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildModifierGroup(Map<String, dynamic> group, AppDictionary l10n, String locale) {
    final List modifiers = group['modifiers'] ?? [];
    final int min = group['min_select'] ?? 0;
    final int max = group['max_select'] ?? 1;
    final String groupName = L10nUtils.getL10n(group['name'], locale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(groupName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AdminTheme.textDarkWood)),
            if (min > 0)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(4)),
                  child: Text(l10n.requiredLabel, style: const TextStyle(color: Color(0xFFC62828), fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ...modifiers.map((m) {
          final modName = L10nUtils.getL10n(m['name'], locale);
          final price = (m['price'] ?? 0).toDouble();
          final isSelected = _selectedModifiers.any((sm) => sm.modifierId == m['id']);
          return CheckboxListTile(
            title: Text(modName, style: const TextStyle(fontSize: 13, color: AdminTheme.textDarkWood)),
            subtitle: price > 0
                ? Text('+${NumberFormat('#,###', 'vi_VN').format(price)} VND', style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 12))
                : null,
            value: isSelected,
            activeColor: AdminTheme.primaryWood,
            dense: true,
            onChanged: (val) {
              setState(() {
                if (val!) {
                  if (_selectedModifiers.where((sm) => sm.groupId == group['id']).length < max) {
                    _selectedModifiers.add(SelectedModifier(
                      groupId: group['id'],
                      rawGroup: group['name'],
                      groupName: groupName,
                      modifierId: m['id'],
                      rawModifier: m['name'],
                      modifierName: modName,
                      price: price,
                    ));
                  }
                } else {
                  _selectedModifiers.removeWhere((sm) => sm.modifierId == m['id']);
                }
              });
            },
          );
        }).toList(),
        const Divider(height: 20, color: AdminTheme.borderWood),
      ],
    );
  }

  Widget _buildFooter(bool isValid, AppDictionary l10n) {
    final double totalPrice = widget.item.price + _selectedModifiers.fold(0.0, (sum, m) => sum + m.price);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AdminTheme.surfaceWhite,
        border: Border(top: BorderSide(color: AdminTheme.borderWood)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.total, style: const TextStyle(fontSize: 11, color: AdminTheme.textMutedWood)),
              Text(
                '${NumberFormat('#,###', 'vi_VN').format(totalPrice)} VND',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AdminTheme.accentAmber),
              ),
            ],
          ),
          SizedBox(
            height: 44,
            width: 180,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isValid ? AdminTheme.primaryWood : AdminTheme.borderWood,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isValid
                  ? () {
                      ref.read(cartProvider.notifier).addToCart(widget.item, _selectedModifiers, _noteController.text);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Đã thêm ${widget.item.getName(ref.read(localeProvider))} vào giỏ hàng!'),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  : null,
              child: Text(isValid ? l10n.orderNow : l10n.selectFullLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
