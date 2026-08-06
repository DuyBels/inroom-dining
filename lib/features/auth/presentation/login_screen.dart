import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../main.dart';

import '../../../core/widgets/language_selector.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _showDebugPanel = true; // Công tắc hiển thị debug

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
      _showError(ref.read(l10nProvider).unknownError);
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
    final l10n = ref.watch(l10nProvider);
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [
          LanguageSelector(color: Colors.white),
          SizedBox(width: 16),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2C3E50), // Đen xanh sang trọng
              Color(0xFFFD746C), // Cam ấm kích thích vị giác
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
              child: Container(
                width: 420, // Kích thước chuẩn cho form
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.96),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.restaurant_menu_rounded, size: 56, color: Colors.deepOrange),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.systemTitle, 
                      style: const TextStyle(
                        fontSize: 26, 
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: Color(0xFF2C3E50),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.pleaseLogin,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 40),
              
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: l10n.username,
                        prefixIcon: const Icon(Icons.email_outlined, color: Colors.deepOrange),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.deepOrange, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 20),
              
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: l10n.password,
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.deepOrange),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.deepOrange, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      onSubmitted: (_) => _signIn(), // Nhấn Enter để đăng nhập
                    ),
                    const SizedBox(height: 32),
              
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24, 
                                height: 24, 
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                              )
                            : Text(l10n.loginButton, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                      ),
                    ),

                    const SizedBox(height: 32),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(l10n.debugMode, style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Switch(
                      value: _showDebugPanel,
                      activeColor: Colors.deepOrange,
                      onChanged: (val) => setState(() => _showDebugPanel = val),
                    ),

                    if (_showDebugPanel) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildDebugButton('ADMIN', 'admin@app.com', 'password123', Colors.red),
                          _buildDebugButton('P.101', 'phong_101@app.com', '123123', Colors.blue),
                          _buildDebugButton('P.102', 'phong_102@app.com', '123123', Colors.blue),
                          _buildDebugButton('P.103', 'phong_103@app.com', '123123', Colors.blue),
                          _buildDebugButton('BẾP VIỆT', 'bep_viet@app.com', '123123', Colors.orange),
                          _buildDebugButton('QUẦY BAR', 'quay_bar@app.com', '123123', Colors.orange),
                          _buildDebugButton('Bếp Bánh', 'bep_banh@app.com', '123123', Colors.orange),
                          _buildDebugButton('BẾP NHẬT', 'bep_nhat@app.com', '123123', Colors.orange[900]!),
                          _buildDebugButton('WAITER 1', 'nhanvien_1@app.com', '123123', Colors.green),
                          _buildDebugButton('WAITER 2', 'nhanvien_2@app.com', '123123', Colors.green),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Widget nút đăng nhập nhanh dạng Chip
  Widget _buildDebugButton(String label, String email, String password, Color color) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      labelStyle: TextStyle(color: color),
      backgroundColor: color.withOpacity(0.05),
      side: BorderSide(color: color.withOpacity(0.4)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onPressed: _isLoading ? null : () => _quickSignIn(email, password),
    );
  }
}
