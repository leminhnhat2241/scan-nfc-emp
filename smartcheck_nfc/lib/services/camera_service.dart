import 'dart:io';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Service quản lý camera để chụp ảnh xác thực chống gian lận
/// File con: lib/services/camera_service.dart
/// File mẹ: Được gọi từ lib/screens/home_screen.dart
class CameraService {
  static final CameraService instance = CameraService._init();
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;

  CameraService._init();

  /// Khởi tạo camera (sử dụng camera trước - front camera)
  Future<void> initialize() async {
    if (_isInitialized &&
        _controller != null &&
        _controller!.value.isInitialized) {
      return; // Đã khởi tạo rồi
    }

    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        print('❌ Không tìm thấy camera nào trên thiết bị');
        return;
      }

      // Tìm camera trước (front camera) để chụp ảnh người quét thẻ
      CameraDescription? frontCamera;
      for (var camera in _cameras!) {
        if (camera.lensDirection == CameraLensDirection.front) {
          frontCamera = camera;
          break;
        }
      }

      // Nếu không có camera trước, dùng camera đầu tiên
      frontCamera ??= _cameras!.first;

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.medium, // Chất lượng trung bình (tiết kiệm dung lượng)
        enableAudio: false, // Không cần âm thanh
      );

      await _controller!.initialize();
      _isInitialized = true;
      print('✅ Camera Service đã khởi tạo thành công (${frontCamera.name})');
    } catch (e) {
      print('❌ Lỗi khởi tạo camera: $e');
      _isInitialized = false;
    }
  }

  /// Chụp ảnh im lặng (Silent Capture) khi NFC được phát hiện
  /// Trả về đường dẫn file ảnh đã lưu
  Future<String?> captureAntiSpoofingImage(String employeeId) async {
    if (!_isInitialized ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      print('⚠️ Camera chưa sẵn sàng, bỏ qua chụp ảnh');
      return null;
    }

    try {
      // Tạo thư mục lưu ảnh
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String imagesDir = path.join(appDir.path, 'attendance_photos');
      final Directory imagesDirObj = Directory(imagesDir);

      if (!await imagesDirObj.exists()) {
        await imagesDirObj.create(recursive: true);
      }

      // Tạo tên file: employeeId_timestamp.jpg
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String fileName = '${employeeId}_$timestamp.jpg';
      final String filePath = path.join(imagesDir, fileName);

      // Chụp ảnh
      final XFile image = await _controller!.takePicture();

      // Di chuyển file từ temp sang thư mục của app
      await image.saveTo(filePath);

      print('📸 Đã chụp ảnh xác thực: $filePath');
      return filePath;
    } catch (e) {
      print('❌ Lỗi chụp ảnh: $e');
      return null;
    }
  }

  /// Xóa ảnh cũ (dọn dẹp bộ nhớ) - giữ lại ảnh trong 30 ngày
  Future<void> cleanupOldPhotos({int daysToKeep = 30}) async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String imagesDir = path.join(appDir.path, 'attendance_photos');
      final Directory imagesDirObj = Directory(imagesDir);

      if (!await imagesDirObj.exists()) return;

      final DateTime cutoffDate = DateTime.now().subtract(
        Duration(days: daysToKeep),
      );
      final List<FileSystemEntity> files = imagesDirObj.listSync();

      for (var file in files) {
        if (file is File) {
          final FileStat stat = await file.stat();
          if (stat.modified.isBefore(cutoffDate)) {
            await file.delete();
            print('🗑️ Đã xóa ảnh cũ: ${path.basename(file.path)}');
          }
        }
      }
    } catch (e) {
      print('❌ Lỗi dọn dẹp ảnh cũ: $e');
    }
  }

  /// Kiểm tra camera có sẵn sàng không
  bool get isReady =>
      _isInitialized && _controller != null && _controller!.value.isInitialized;

  /// Lấy CameraController (để hiển thị preview nếu cần)
  CameraController? get controller => _controller;

  /// Giải phóng tài nguyên
  Future<void> dispose() async {
    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
      _isInitialized = false;
      print('🔌 Camera Service đã giải phóng tài nguyên');
    }
  }
}
