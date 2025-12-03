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

      // Tốc độ nói (0.0 - 1.0, mặc định 0.5)
      await _flutterTts.setSpeechRate(0.5);

      // Độ cao giọng nói (0.5 - 2.0, mặc định 1.0)
      await _flutterTts.setPitch(1.0);

      // Âm lượng (0.0 - 1.0, mặc định 1.0)
      await _flutterTts.setVolume(1.0);

      _isInitialized = true;
      print('✅ TTS Service đã khởi tạo thành công');
    } catch (e) {
      print('❌ Lỗi khởi tạo TTS: $e');
    }
  }

  /// Phát giọng nói thông báo điểm danh thành công
  /// [employeeName]: Tên nhân viên
  /// [status]: Trạng thái điểm danh ("Đi làm" hoặc "Đi muộn")
  Future<void> speakAttendanceSuccess(
    String employeeName,
    String status,
  ) async {
    await initialize();

    String message;
    if (status == 'Đi làm') {
      message = '$employeeName - Có mặt!';
    } else if (status == 'Đi muộn') {
      message = '$employeeName - Đi muộn!';
    } else {
      message = '$employeeName - Đã điểm danh!';
    }

    await speak(message);
  }

  /// Phát giọng nói thông báo lỗi
  /// [errorType]: Loại lỗi ("duplicate", "invalid", "empty")
  Future<void> speakError(String errorType) async {
    await initialize();

    String message;
    switch (errorType) {
      case 'duplicate':
        message = 'Thẻ đã điểm danh hôm nay rồi!';
        break;
      case 'invalid':
        message = 'Thẻ không hợp lệ!';
        break;
      case 'empty':
        message = 'Thẻ rỗng, chưa có dữ liệu!';
        break;
      default:
        message = 'Có lỗi xảy ra!';
    }

    await speak(message);
  }

  /// Phát giọng nói tùy chỉnh
  /// [text]: Nội dung cần đọc
  Future<void> speak(String text) async {
    await initialize();

    try {
      await _flutterTts.stop(); // Dừng giọng nói hiện tại (nếu có)
      await _flutterTts.speak(text);
      print('🔊 TTS: "$text"');
    } catch (e) {
      print('❌ Lỗi phát giọng nói: $e');
    }
  }

  /// Dừng giọng nói
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      print('❌ Lỗi dừng giọng nói: $e');
    }
  }

  /// Kiểm tra trạng thái đang phát
  Future<bool> isSpeaking() async {
    try {
      // Note: flutter_tts không có API trực tiếp, cần theo dõi qua callback
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Giải phóng tài nguyên
  void dispose() {
    _flutterTts.stop();
  }
}
