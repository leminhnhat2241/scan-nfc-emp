import 'package:flutter_tts/flutter_tts.dart';

/// Service quản lý phản hồi giọng nói (Text-to-Speech)
/// File con: lib/services/tts_service.dart
/// File mẹ: Được gọi từ lib/screens/home_screen.dart
class TtsService {
  static final TtsService instance = TtsService._init();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;

  TtsService._init();

  /// Khởi tạo cấu hình TTS
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Cấu hình ngôn ngữ tiếng Việt
      await _flutterTts.setLanguage("vi-VN");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setVolume(1.0);

      _isInitialized = true;
    } catch (e) {
      print('❌ Lỗi khởi tạo TTS: $e');
    }
  }

  /// Phát giọng nói thông báo điểm danh thành công (Check-in)
  Future<void> speakAttendanceSuccess(String employeeName, String status) async {
    await initialize();
    String message;
    if (status == 'Đi làm') {
      message = 'Xin chào $employeeName!';
    } else if (status == 'Đi muộn') {
      message = '$employeeName - Đi muộn!';
    } else {
      message = '$employeeName - Đã điểm danh!';
    }
    await speak(message);
  }

  /// Phát giọng nói thông báo ra về (Check-out)
  Future<void> speakCheckoutSuccess(String employeeName) async {
    await initialize();
    // Chọn câu chúc ngẫu nhiên hoặc cố định
    await speak('Tạm biệt $employeeName. Hẹn gặp lại!');
  }

  /// Phát giọng nói thông báo lỗi
  Future<void> speakError(String errorType) async {
    await initialize();
    String message;
    switch (errorType) {
      case 'duplicate':
        message = 'Bạn đã hoàn thành ca làm việc hôm nay!';
        break;
      case 'invalid':
        message = 'Thẻ không hợp lệ!';
        break;
      case 'empty':
        message = 'Thẻ rỗng, chưa có dữ liệu!';
        break;
      case 'locked':
        message = 'Tài khoản đã bị khóa!';
        break;
      default:
        message = 'Có lỗi xảy ra!';
    }
    await speak(message);
  }

  Future<void> speak(String text) async {
    await initialize();
    try {
      await _flutterTts.stop();
      await _flutterTts.speak(text);
    } catch (e) {
      print('❌ Lỗi phát giọng nói: $e');
    }
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
