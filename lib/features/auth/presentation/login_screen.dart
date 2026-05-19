import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _showDebugPanel = false; // Công tắc hiển thị debug

  // Hàm đăng nhập nhanh cho Debug
  Future<void> _quickSignIn(String email, String password) async {
    _emailController.text = email;
    _passwordController.text = password;
    await _signIn();
  }

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      // 1. Đăng nhập qua Supabase Auth
      await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. Nếu thành công, đẩy về Splash Screen để nó tự chia đường dựa trên Role
      if (mounted) context.go('/');

    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Đã xảy ra lỗi không xác định.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView( // Thêm để không bị tràn khi mở debug panel
          child: Container(
            width: 400, // Layout phù hợp cho Web
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.restaurant, size: 64, color: Colors.deepOrange),
                const SizedBox(height: 16),
                const Text('HỆ THỐNG GỌI MÓN TẠI PHÒNG', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),
          
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Tên đăng nhập', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
          
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Mật khẩu', border: OutlineInputBorder()),
                  onSubmitted: (_) => _signIn(), // Nhấn Enter để đăng nhập
                ),
                const SizedBox(height: 32),
          
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signIn,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('ĐĂNG NHẬP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 24),
                const Divider(),
                
                // CÔNG TẮC DEBUG
                SwitchListTile(
                  title: const Text('Chế độ Debug (Đăng nhập nhanh)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  value: _showDebugPanel,
                  onChanged: (val) => setState(() => _showDebugPanel = val),
                ),

                if (_showDebugPanel) ...[
                  const SizedBox(height: 8),
                  _buildDebugButton('QUẢN TRỊ (ADMIN)', 'admin@app.com', 'password123', Colors.red),
                  _buildDebugButton('PHÒNG 101 (KHÁCH)', 'room1@app.com', '123123', Colors.blue),
                  _buildDebugButton('BẾP Á', 'bepa@app.com', '123123', Colors.orange),
                  _buildDebugButton('BẾP ÂU', 'bepau@app.com', '123123', Colors.orange[900]!),
                  _buildDebugButton('NHÂN VIÊN (WAITER)', 'waiter@app.com', '123123', Colors.green),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget nút đăng nhập nhanh
  Widget _buildDebugButton(String label, String email, String password, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: _isLoading ? null : () => _quickSignIn(email, password),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ),
    );
  }
}
