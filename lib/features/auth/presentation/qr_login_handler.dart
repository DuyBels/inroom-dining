import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/services/qr_session_service.dart';

class QrLoginHandler extends ConsumerStatefulWidget {
  final String? roomNumber;
  final String? token;
  final String? expiresStr;

  const QrLoginHandler({
    super.key,
    this.roomNumber,
    this.token,
    this.expiresStr,
  });

  @override
  ConsumerState<QrLoginHandler> createState() => _QrLoginHandlerState();
}

class _QrLoginHandlerState extends ConsumerState<QrLoginHandler> {
  bool _isVerifying = true;
  bool _isValid = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _processQrLogin();
  }

  Future<void> _processQrLogin() async {
    final room = widget.roomNumber;
    final token = widget.token;
    final expiresMs = int.tryParse(widget.expiresStr ?? '');

    if (room == null || token == null || expiresMs == null) {
      setState(() {
        _isVerifying = false;
        _isValid = false;
        _errorMessage = 'Thông số mã QR không hợp lệ.';
      });
      return;
    }

    final qrService = ref.read(qrSessionServiceProvider);
    final isValid = await qrService.verifySession(
      roomNumber: room,
      token: token,
      expiresAtMs: expiresMs,
    );

    if (!mounted) return;

    if (isValid) {
      final session = QrSessionData(
        id: 'qr_$token',
        roomNumber: room,
        token: token,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresMs),
        createdAt: DateTime.now(),
        isActive: true,
      );

      // Lưu thông tin phiên QR vào Riverpod State
      ref.read(activeRoomQrSessionProvider.notifier).setSession(session);

      // Chuyển hướng trực tiếp vào giao diện phòng tương ứng
      context.go('/menu/$room');
    } else {
      setState(() {
        _isVerifying = false;
        _isValid = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);

    if (_isVerifying) {
      return Scaffold(
        backgroundColor: Colors.deepOrange,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                'Đang xác thực mã QR cho Phòng ${widget.roomNumber ?? ""}...',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isValid) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: Center(
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 16)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                  child: const Icon(Icons.timer_off_outlined, color: Colors.white, size: 48),
                ),
                const SizedBox(height: 20),
                Text(l10n.qrExpiredTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                const SizedBox(height: 12),
                Text(
                  _errorMessage ?? l10n.qrExpiredMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: () => context.go('/login'),
                  icon: const Icon(Icons.login),
                  label: const Text('Đăng nhập phòng (Thủ công)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
