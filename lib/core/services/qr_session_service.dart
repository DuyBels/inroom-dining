import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';

class QrSessionData {
  final String id;
  final String roomNumber;
  final String token;
  final DateTime expiresAt;
  final DateTime createdAt;
  final bool isActive;

  QrSessionData({
    required this.id,
    required this.roomNumber,
    required this.token,
    required this.expiresAt,
    required this.createdAt,
    this.isActive = true,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isValid => isActive && !isExpired;

  Duration get remainingTime => isExpired ? Duration.zero : expiresAt.difference(DateTime.now());

  Map<String, dynamic> toJson() => {
    'id': id,
    'room_number': roomNumber,
    'token': token,
    'expires_at': expiresAt.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'is_active': isActive,
  };

  factory QrSessionData.fromJson(Map<String, dynamic> json) {
    return QrSessionData(
      id: json['id']?.toString() ?? '',
      roomNumber: json['room_number']?.toString() ?? '',
      token: json['token']?.toString() ?? '',
      expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? '') ?? DateTime.now(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      isActive: json['is_active'] ?? true,
    );
  }
}

class QrSessionService {
  // Bộ nhớ tạm thời cục bộ (để đảm bảo hoạt động cả khi chưa tạo bảng DB)
  static final List<QrSessionData> _localSessions = [];

  static String generateRandomToken() {
    final rand = Random.secure();
    final codeUnits = List.generate(16, (index) => rand.nextInt(256));
    return codeUnits.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Tạo mã QR mới cho phòng với thời hạn chỉ định
  Future<QrSessionData> createSession({
    required String roomNumber,
    required Duration duration,
  }) async {
    final now = DateTime.now();
    final expiresAt = now.add(duration);
    final token = generateRandomToken();
    final id = 'qr_${now.millisecondsSinceEpoch}_$roomNumber';

    final session = QrSessionData(
      id: id,
      roomNumber: roomNumber,
      token: token,
      expiresAt: expiresAt,
      createdAt: now,
      isActive: true,
    );

    _localSessions.insert(0, session);

    try {
      await supabase.from('qr_sessions').insert({
        'room_number': roomNumber,
        'token': token,
        'expires_at': expiresAt.toIso8601String(),
        'created_at': now.toIso8601String(),
        'is_active': true,
      });
    } catch (e) {
      debugPrint('Lưu DB qr_sessions: $e (dùng bộ nhớ tạm)');
    }

    return session;
  }

  /// Vô hiệu hóa tất cả QR của một phòng (Ví dụ khi trả phòng)
  Future<void> revokeRoomSessions(String roomNumber) async {
    for (var i = 0; i < _localSessions.length; i++) {
      if (_localSessions[i].roomNumber == roomNumber) {
        _localSessions[i] = QrSessionData(
          id: _localSessions[i].id,
          roomNumber: _localSessions[i].roomNumber,
          token: _localSessions[i].token,
          expiresAt: _localSessions[i].expiresAt,
          createdAt: _localSessions[i].createdAt,
          isActive: false,
        );
      }
    }

    try {
      await supabase.from('qr_sessions').update({'is_active': false}).eq('room_number', roomNumber);
    } catch (_) {}
  }

  /// Hủy một mã QR cụ thể
  Future<void> revokeSession(String token) async {
    for (var i = 0; i < _localSessions.length; i++) {
      if (_localSessions[i].token == token) {
        _localSessions[i] = QrSessionData(
          id: _localSessions[i].id,
          roomNumber: _localSessions[i].roomNumber,
          token: _localSessions[i].token,
          expiresAt: _localSessions[i].expiresAt,
          createdAt: _localSessions[i].createdAt,
          isActive: false,
        );
      }
    }

    try {
      await supabase.from('qr_sessions').update({'is_active': false}).eq('token', token);
    } catch (_) {}
  }

  /// Kiểm tra tính hợp lệ của mã QR
  Future<bool> verifySession({
    required String roomNumber,
    required String token,
    required int expiresAtMs,
  }) async {
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresAtMs);
    if (DateTime.now().isAfter(expiresAt)) return false;

    // Kiểm tra bộ nhớ cục bộ trước
    final localMatch = _localSessions.firstWhere(
      (s) => s.token == token && s.roomNumber == roomNumber,
      orElse: () => QrSessionData(
        id: '',
        roomNumber: roomNumber,
        token: token,
        expiresAt: expiresAt,
        createdAt: DateTime.now(),
        isActive: true,
      ),
    );

    if (!localMatch.isActive) return false;

    try {
      final res = await supabase
          .from('qr_sessions')
          .select('*')
          .eq('token', token)
          .eq('room_number', roomNumber)
          .maybeSingle();

      if (res != null) {
        final session = QrSessionData.fromJson(res);
        return session.isValid;
      }
    } catch (_) {}

    return true; // Nếu chưa kết nối DB, sử dụng kiểm tra thời gian làm chuẩn
  }

  /// Lấy danh sách mã QR đã tạo
  Future<List<QrSessionData>> getRecentSessions() async {
    try {
      final res = await supabase
          .from('qr_sessions')
          .select('*')
          .order('created_at', ascending: false)
          .limit(30);

      final list = (res as List).map((e) => QrSessionData.fromJson(e)).toList();
      return list;
    } catch (_) {
      return List.from(_localSessions);
    }
  }
}

final qrSessionServiceProvider = Provider((ref) => QrSessionService());

/// NotifierProvider lưu phiên làm việc QR hiện tại của phòng
class ActiveRoomQrNotifier extends Notifier<QrSessionData?> {
  @override
  QrSessionData? build() => null;

  void setSession(QrSessionData? session) => state = session;
}

final activeRoomQrSessionProvider = NotifierProvider<ActiveRoomQrNotifier, QrSessionData?>(ActiveRoomQrNotifier.new);
