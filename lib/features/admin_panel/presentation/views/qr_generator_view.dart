import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:inroom_dining/core/theme/admin_theme.dart';
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
  int _selectedDurationMinutes = 60;
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
      const SnackBar(content: Text('📋 Đã sao chép đường dẫn đăng nhập QR!'), backgroundColor: AdminTheme.primaryWood),
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
            const Icon(Icons.print, color: AdminTheme.primaryWood),
            const SizedBox(width: 8),
            Text('Thẻ QR Phòng ${session.roomNumber}', style: const TextStyle(fontSize: 18, color: AdminTheme.textDarkWood)),
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
                  border: Border.all(color: AdminTheme.borderWood, width: 2),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.restaurant, size: 36, color: AdminTheme.primaryWood),
                    const SizedBox(height: 4),
                    const Text('IN-ROOM DINING', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2, color: AdminTheme.textDarkWood)),
                    const Divider(height: 20, color: AdminTheme.borderWood),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(color: AdminTheme.lightWoodCream, borderRadius: BorderRadius.circular(20)),
                      child: Text('PHÒNG ${session.roomNumber}', style: const TextStyle(color: AdminTheme.primaryDarkWood, fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                    const SizedBox(height: 16),
                    QrImageView(
                      data: url,
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                    const SizedBox(height: 12),
                    const Text('Quét mã QR để đặt món trực tiếp', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AdminTheme.textDarkWood)),
                    const SizedBox(height: 6),
                    Text('Hạn sử dụng: $formattedTime', style: const TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng', style: TextStyle(color: AdminTheme.textMutedWood))),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Sao chép Link'),
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.primaryWood, foregroundColor: Colors.white),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        Widget formPanel = Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('1. Chọn Phòng & Thời gian', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AdminTheme.textDarkWood)),
                const SizedBox(height: 16),

                profilesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, s) => Text('Lỗi tải phòng: $e', style: const TextStyle(color: Colors.red)),
                  data: (profiles) {
                    final roomProfiles = profiles
                        .where((p) => p['role'] == 'ROOM' && p['room_number'] != null)
                        .toList();

                    return DropdownButtonFormField<String>(
                      value: _selectedRoomNumber,
                      decoration: InputDecoration(
                        labelText: l10n.selectRoom,
                        prefixIcon: const Icon(Icons.meeting_room, color: AdminTheme.primaryWood),
                      ),
                      items: roomProfiles.map((p) {
                        final roomNum = p['room_number'].toString();
                        return DropdownMenuItem(
                          value: roomNum,
                          child: Text('Phòng $roomNum (${p['display_name'] ?? ''})', style: const TextStyle(color: AdminTheme.textDarkWood)),
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
                    prefixIcon: const Icon(Icons.timer, color: AdminTheme.accentAmber),
                  ),
                  items: _durationOptions.map((opt) {
                    return DropdownMenuItem<int>(
                      value: opt['minutes'] as int,
                      child: Text(opt['label'].toString(), style: const TextStyle(color: AdminTheme.textDarkWood)),
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
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(l10n.generateQrBtn, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.primaryWood,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        Widget previewPanel = _generatedSession == null
            ? Card(
                child: SizedBox(
                  height: 300,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.qr_code_2, size: 64, color: AdminTheme.borderWood),
                        const SizedBox(height: 12),
                        Text('Vui lòng chọn phòng và nhấn "${l10n.generateQrBtn}"', style: const TextStyle(color: AdminTheme.textMutedWood, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              )
            : Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(color: AdminTheme.lightWoodCream, borderRadius: BorderRadius.circular(12)),
                            child: Text('PHÒNG ${_generatedSession!.roomNumber}', style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.primaryDarkWood)),
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
                        style: const TextStyle(fontSize: 11, color: AdminTheme.textMutedWood),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _showPrintDialog(_generatedSession!),
                            icon: const Icon(Icons.print, size: 18),
                            label: Text(l10n.printQr),
                            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.primaryWood, foregroundColor: Colors.white),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _copyLink(_generatedSession!),
                            icon: const Icon(Icons.copy, size: 18),
                            label: Text(l10n.copyQrLink),
                          ),
                          TextButton.icon(
                            onPressed: () => _revokeSession(_generatedSession!.token),
                            icon: const Icon(Icons.cancel, size: 18, color: Colors.redAccent),
                            label: Text(l10n.revokeQr, style: const TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 12.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AdminTheme.lightWoodCream, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.qr_code_2, size: 28, color: AdminTheme.primaryWood),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.generateQrTitle,
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      color: AdminTheme.textDarkWood,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Layout Responsive: Column on Mobile, Row on Tablet/Desktop
              if (isMobile) ...[
                formPanel,
                const SizedBox(height: 16),
                previewPanel,
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 4, child: formPanel),
                    const SizedBox(width: 20),
                    Expanded(flex: 5, child: previewPanel),
                  ],
                ),
              ],
              const SizedBox(height: 32),

              // DANH SÁCH MÃ QR ĐÃ TẠO VÀ TRẠNG THÁI
              const Text(
                'Danh sách mã QR đã cấp',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AdminTheme.textDarkWood),
              ),
              const SizedBox(height: 12),

              Card(
                child: _sessionsList.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(child: Text('Chưa có mã QR nào được tạo.', style: TextStyle(color: AdminTheme.textMutedWood))),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _sessionsList.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: AdminTheme.borderWood),
                        itemBuilder: (ctx, i) {
                          final s = _sessionsList[i];
                          final isValid = s.isValid;
                          final remaining = s.remainingTime;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isValid ? const Color(0xFFE8F5E9) : AdminTheme.lightWoodCream,
                              child: Icon(Icons.qr_code, color: isValid ? const Color(0xFF2E7D32) : AdminTheme.textMutedWood),
                            ),
                            title: Text('Phòng ${s.roomNumber}', style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.textDarkWood)),
                            subtitle: Text(
                              'Tạo lúc: ${DateFormat('HH:mm - dd/MM').format(s.createdAt)} | Hết hạn: ${DateFormat('HH:mm').format(s.expiresAt)}',
                              style: const TextStyle(color: AdminTheme.textMutedWood, fontSize: 12),
                            ),
                            trailing: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isValid ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: isValid ? const Color(0xFF2E7D32) : const Color(0xFFC62828)),
                                  ),
                                  child: Text(
                                    isValid
                                        ? '🟢 Còn ${remaining.inMinutes} phút'
                                        : '🔴 Hết hạn / Đã hủy',
                                    style: TextStyle(
                                      color: isValid ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                if (isValid)
                                  IconButton(
                                    icon: const Icon(Icons.print, color: AdminTheme.primaryWood),
                                    tooltip: l10n.printQr,
                                    onPressed: () => _showPrintDialog(s),
                                  ),
                                if (isValid)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    tooltip: l10n.revokeQr,
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
      },
    );
  }
}

