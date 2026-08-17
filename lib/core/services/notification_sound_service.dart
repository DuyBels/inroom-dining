import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Service phát âm thanh thông báo "ting ting" cho Bếp và Nhân viên phục vụ.
/// Sử dụng Web Audio API để tạo âm thanh trực tiếp mà không cần file .mp3.
class NotificationSoundService {
  static NotificationSoundService? _instance;
  NotificationSoundService._();
  static NotificationSoundService get instance {
    _instance ??= NotificationSoundService._();
    return _instance!;
  }

  bool _userInteracted = false;

  /// Gọi hàm này khi user tương tác lần đầu (click/tap) để mở khóa audio trên trình duyệt.
  void markUserInteracted() {
    _userInteracted = true;
  }

  /// Phát âm thanh "ting" thông báo đơn mới cho Bếp (2 tiếng ting cao)
  void playKitchenAlert() {
    if (!_userInteracted) return;
    _playTingTing(frequency1: 880, frequency2: 1100, delayMs: 150);
  }

  /// Phát âm thanh "ting" thông báo cho Nhân viên phục vụ (2 tiếng ting thấp hơn, dịu hơn)
  void playWaiterAlert() {
    if (!_userInteracted) return;
    _playTingTing(frequency1: 660, frequency2: 880, delayMs: 200);
  }

  /// Tạo và phát 2 tiếng "ting ting" bằng Web Audio API
  void _playTingTing({
    required double frequency1,
    required double frequency2,
    required int delayMs,
  }) {
    try {
      // Ting thứ 1
      _playSingleTing(frequency1, 0);
      // Ting thứ 2 (sau delay)
      _playSingleTing(frequency2, delayMs / 1000.0);
    } catch (e) {
      // Không làm gì nếu lỗi audio, không ảnh hưởng app
    }
  }

  /// Phát 1 tiếng "ting" duy nhất bằng cách gọi JavaScript Web Audio API
  void _playSingleTing(double frequency, double delaySeconds) {
    // Sử dụng JavaScript interop để tạo AudioContext
    _evalJS('''
      (function() {
        try {
          var ctx = new (window.AudioContext || window.webkitAudioContext)();
          var t = ctx.currentTime + $delaySeconds;

          // Oscillator tạo sóng âm thanh
          var osc = ctx.createOscillator();
          osc.type = 'sine';
          osc.frequency.setValueAtTime($frequency, t);

          // Gain (âm lượng) - fade in nhanh rồi fade out mượt
          var gain = ctx.createGain();
          gain.gain.setValueAtTime(0, t);
          gain.gain.linearRampToValueAtTime(0.3, t + 0.01);
          gain.gain.exponentialRampToValueAtTime(0.001, t + 0.4);

          osc.connect(gain);
          gain.connect(ctx.destination);

          osc.start(t);
          osc.stop(t + 0.4);
        } catch(e) {}
      })();
    ''');
  }

  /// Chạy đoạn JavaScript trên trình duyệt
  void _evalJS(String code) {
    try {
      final script = web.document.createElement('script') as web.HTMLScriptElement;
      script.text = code;
      web.document.body?.appendChild(script);
      script.remove();
    } catch (e) {
      // Bỏ qua lỗi
    }
  }
}
