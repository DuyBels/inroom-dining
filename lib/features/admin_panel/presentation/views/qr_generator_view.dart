import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/services/qr_session_service.dart';
import '../../../../main.dart';
import '../../providers/admin_provider.dart';

class QrGeneratorView extends ConsumerStatefulWidget {
  const QrGeneratorView({super.key});

  @override
  ConsumerState<QrGeneratorView> createState() => _QrGeneratorViewState();
}

class _QrGeneratorViewState extends ConsumerState<QrGeneratorView> {
  String? _selectedRoomNumber;
  int _selectedDurationMinutes = 60; // Mặc định 1 tiếng (60 phút)
  QrSessionData? _generatedSession;
  bool _isGenerating = false;
  List<QrSessionData> _sessionsList = [];
  Timer? _timer;

  final List<Map<String, dynamic>> _durationOptions = [
    {'label': '30 Phút', 'minutes': 30},
    {'label': '1 Tiếng (Mặc định)', 'minutes': 60},
    {'label': '2 Tiếng', 'minutes': 120},
    {'label': '4 Tiếng', 'minutes': 240},
    {'label': '8 Tiếng', 'minutes': 480},
    {'label': '12 Tiếng', 'minutes': 720},
    {'label': '24 Tiếng', 'minutes': 1440},
  ];

  @override
  void initState() {
    super.initState();
    _loadSessions();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _loadSessions());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    final qrService = ref.read(qrSessionServiceProvider);
    final sessions = await qrService.getRecentSessions();
    if (mounted) {
      setState(() {
        _sessionsList = sessions;
      });
    }
  }

  Future<void> _generateQrCode() async {
    if (_selectedRoomNumber == null || _selectedRoomNumber!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Vui lòng chọn số phòng!'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final qrService = ref.read(qrSessionServiceProvider);
      final session = await qrService.createSession(
        roomNumber: _selectedRoomNumber!,
        duration: Duration(minutes: _selectedDurationMinutes),
      );

      setState(() {
        _generatedSession = session;
      });
      _loadSessions();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Đã tạo mã QR cho Phòng ${_selectedRoomNumber!} (${_selectedDurationMinutes ~/ 60 > 0 ? "${_selectedDurationMinutes ~/ 60} tiếng" : "$_selectedDurationMinutes phút"})'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Lỗi tạo QR: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  String _buildQrUrl(QrSessionData session) {
    final baseUrl = Uri.base.origin;
    return '$baseUrl/#/qr-login?room=${session.roomNumber}&token=${session.token}&expires=${session.expiresAt.millisecondsSinceEpoch}';
  }

  void _copyLink(QrSessionData session) {
    final url = _buildQrUrl(session);
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📋 Đã sao chép đường dẫn đăng nhập QR!'), backgroundColor: Colors.blue),
    );
  }

  Future<void> _revokeSession(String token) async {
    final qrService = ref.read(qrSessionServiceProvider);
    await qrService.revokeSession(token);
    _loadSessions();
    if (_generatedSession?.token == token) {
      setState(() => _generatedSession = null);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Đã vô hiệu hóa mã QR'), backgroundColor: Colors.grey),
      );
    }
  }

  void _showPrintDialog(QrSessionData session) {
    final url = _buildQrUrl(session);
    final formattedTime = DateFormat('HH:mm - dd/MM/yyyy').format(session.expiresAt);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.print, color: Colors.blue),
            const SizedBox(width: 8),
            Text('Thẻ QR Phòng ${session.roomNumber}'),
          ],
        ),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[300]!, width: 2),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.restaurant, size: 36, color: Colors.deepOrange),
                    const SizedBox(height: 4),
                    const Text('IN-ROOM DINING', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2)),
                    const Divider(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(20)),
                      child: Text('PHÒNG ${session.roomNumber}', style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                    const SizedBox(height: 16),
                    QrImageView(
                      data: url,
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                    const SizedBox(height: 12),
                    const Text('Quét mã QR để đặt món trực tiếp', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    Text('Hạn sử dụng: $formattedTime', style: const TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Sao chép Link'),
            onPressed: () {
              _copyLink(session);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final profilesAsync = ref.watch(profilesStreamProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_2, size: 32, color: Colors.blue),
              const SizedBox(width: 12),
              Text(l10n.generateQrTitle, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // BẢNG BÊN TRÁI: FORM CHỌN PHÒNG & THỜI GIAN
              Expanded(
                flex: 4,
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('1. Chọn Phòng & Thời gian', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 16),
                        
                        profilesAsync.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (e, s) => Text('Lỗi tải phòng: $e'),
                          data: (profiles) {
                            // Lọc lấy danh sách tài khoản phòng
                            final roomProfiles = profiles
                                .where((p) => p['role'] == 'ROOM' && p['room_number'] != null)
                                .toList();

                            return DropdownButtonFormField<String>(
                              value: _selectedRoomNumber,
                              decoration: InputDecoration(
                                labelText: l10n.selectRoom,
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.meeting_room, color: Colors.blue),
                              ),
                              items: roomProfiles.map((p) {
                                final roomNum = p['room_number'].toString();
                                return DropdownMenuItem(
                                  value: roomNum,
                                  child: Text('Phòng $roomNum (${p['display_name'] ?? ''})'),
                                );
                              }).toList(),
                              onChanged: (val) => setState(() => _selectedRoomNumber = val),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        DropdownButtonFormField<int>(
                          value: _selectedDurationMinutes,
                          decoration: InputDecoration(
                            labelText: l10n.selectDuration,
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.timer, color: Colors.orange),
                          ),
                          items: _durationOptions.map((opt) {
                            return DropdownMenuItem<int>(
                              value: opt['minutes'] as int,
                              child: Text(opt['label'].toString()),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedDurationMinutes = val!),
                        ),
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _isGenerating ? null : _generateQrCode,
                            icon: const Icon(Icons.qr_code),
                            label: _isGenerating
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Text(l10n.generateQrBtn, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[800],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // BẢNG BÊN PHẢI: HIỂN THỊ THẺ MA QR VỪA TẠO
              Expanded(
                flex: 5,
                child: _generatedSession == null
                    ? Container(
                        height: 320,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.qr_code_2, size: 64, color: Colors.grey),
                              SizedBox(height: 12),
                              Text('Vui lòng chọn phòng và nhấn "Tạo mã QR"', style: TextStyle(color: Colors.grey, fontSize: 15)),
                            ],
                          ),
                        ),
                      )
                    : Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.blue[100], borderRadius: BorderRadius.circular(12)),
                                    child: Text('PHÒNG ${_generatedSession!.roomNumber}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[900])),
                                  ),
                                  Text(
                                    'Hạn dùng: ${DateFormat('HH:mm').format(_generatedSession!.expiresAt)}',
                                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              QrImageView(
                                data: _buildQrUrl(_generatedSession!),
                                version: QrVersions.auto,
                                size: 180.0,
                              ),
                              const SizedBox(height: 12),

                              SelectableText(
                                _buildQrUrl(_generatedSession!),
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => _showPrintDialog(_generatedSession!),
                                    icon: const Icon(Icons.print, size: 18),
                                    label: Text(l10n.printQr),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: () => _copyLink(_generatedSession!),
                                    icon: const Icon(Icons.copy, size: 18),
                                    label: Text(l10n.copyQrLink),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: () => _revokeSession(_generatedSession!.token),
                                    icon: const Icon(Icons.cancel, size: 18, color: Colors.red),
                                    label: Text(l10n.revokeQr, style: const TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // DANH SÁCH MÃ QR ĐÃ TẠO VÀ TRẠNG THÁI
          const Text('Danh sách mã QR đã cấp', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: _sessionsList.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(child: Text('Chưa có mã QR nào được tạo.', style: TextStyle(color: Colors.grey))),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _sessionsList.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final s = _sessionsList[i];
                      final isValid = s.isValid;
                      final remaining = s.remainingTime;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isValid ? Colors.green[100] : Colors.grey[200],
                          child: Icon(Icons.qr_code, color: isValid ? Colors.green[800] : Colors.grey),
                        ),
                        title: Text('Phòng ${s.roomNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'Tạo lúc: ${DateFormat('HH:mm - dd/MM').format(s.createdAt)} | Hết hạn: ${DateFormat('HH:mm').format(s.expiresAt)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isValid ? Colors.green[50] : Colors.red[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isValid ? Colors.green : Colors.red),
                              ),
                              child: Text(
                                isValid
                                    ? '🟢 Còn ${remaining.inMinutes} phút'
                                    : '🔴 Hết hạn / Đã hủy',
                                style: TextStyle(
                                  color: isValid ? Colors.green[800] : Colors.red[800],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isValid)
                              IconButton(
                                icon: const Icon(Icons.print, color: Colors.indigo),
                                onPressed: () => _showPrintDialog(s),
                              ),
                            if (isValid)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _revokeSession(s.token),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
