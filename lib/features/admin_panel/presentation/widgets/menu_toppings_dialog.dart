import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../main.dart';
import '../../providers/menu_provider.dart';

class MenuToppingsDialog extends StatefulWidget {
  final Map<String, dynamic> menuItem;
  const MenuToppingsDialog({super.key, required this.menuItem});

  @override
  State<MenuToppingsDialog> createState() => _MenuToppingsDialogState();
}

class _MenuToppingsDialogState extends State<MenuToppingsDialog> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _toppings = [];

  @override
  void initState() {
    super.initState();
    _fetchToppings();
  }

  Future<void> _fetchToppings() async {
    setState(() => _isLoading = true);
    try {
      final data = await supabase
          .from('menu_toppings')
          .select('*')
          .eq('menu_item_id', widget.menuItem['id'])
          .order('created_at', ascending: true);
      setState(() => _toppings = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      debugPrint('Lỗi tải topping: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addTopping() async {
    if (_nameController.text.isEmpty) return;
    
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;

    try {
      await supabase.from('menu_toppings').insert({
        'menu_item_id': widget.menuItem['id'],
        'name': name,
        'price': price,
      });
      _nameController.clear();
      _priceController.clear();
      _fetchToppings();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _deleteTopping(String id) async {
    try {
      await supabase.from('menu_toppings').delete().eq('id', id);
      _fetchToppings();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Quản lý Topping: ${widget.menuItem['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Form thêm topping mới
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Tên topping', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _priceController,
                    decoration: const InputDecoration(labelText: 'Giá', border: OutlineInputBorder(), suffixText: 'đ'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addTopping,
                  icon: const Icon(Icons.add),
                  style: IconButton.styleFrom(backgroundColor: Colors.blue),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 10),
            
            // Danh sách topping hiện tại
            _isLoading 
              ? const CircularProgressIndicator()
              : Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: _toppings.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text('Chưa có topping nào.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                      )
                    : Scrollbar(
                        thumbVisibility: true,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _toppings.length,
                          itemBuilder: (context, index) {
                            final t = _toppings[index];
                            return Card(
                              elevation: 0,
                              color: Colors.grey[50],
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: Colors.grey[200]!),
                              ),
                              child: ListTile(
                                title: Text(t['name'], style: const TextStyle(fontWeight: FontWeight.w500)),
                                subtitle: Text('${t['price']} đ', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _deleteTopping(t['id']),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
      ],
    );
  }
}
