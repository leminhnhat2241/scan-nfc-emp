import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class BiometricService {
  static final BiometricService instance = BiometricService._init();
  final LocalAuthentication _auth = LocalAuthentication();

  BiometricService._init();

  /// Kiểm tra thiết bị có hỗ trợ sinh trắc học không
  Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } on PlatformException catch (e) {
      print('Lỗi kiểm tra sinh trắc học: $e');
      return false;
    }
  }

  /// Lấy danh sách các phương thức hỗ trợ (Vân tay, Khuôn mặt...)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      print('Lỗi lấy danh sách sinh trắc học: $e');
      return [];
    }
  }

  /// Thực hiện xác thực
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true, // Giữ session xác thực nếu app bị switch
          biometricOnly: true, // Chỉ dùng sinh trắc học (không dùng PIN/Pattern backup)
        ),
      );
    } on PlatformException catch (e) {
      print('Lỗi xác thực: $e');
      return false;
    }
  }
}
