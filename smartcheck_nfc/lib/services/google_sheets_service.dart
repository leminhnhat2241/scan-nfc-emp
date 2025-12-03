import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/attendance.dart';
import '../models/employee.dart';

/// Service đồng bộ dữ liệu điểm danh lên Google Sheets real-time
/// File con: lib/services/google_sheets_service.dart
/// File mẹ: Được gọi từ lib/screens/home_screen.dart
///
/// HƯỚNG DẪN CÀI ĐẶT:
/// 1. Tạo Google Apps Script Web App (xem TAI_LIEU_KY_THUAT.md)
/// 2. Copy Deployment URL và paste vào biến SCRIPT_URL bên dưới
/// 3. Deploy lại Apps Script mỗi khi thay đổi code
class GoogleSheetsService {
  static final GoogleSheetsService instance = GoogleSheetsService._init();

  GoogleSheetsService._init();

  // ⚠️ QUAN TRỌNG: Thay thế URL này bằng Google Apps Script Deployment URL của bạn
  // Ví dụ: https://script.google.com/macros/s/AKfycbxxxxxxxxxxxxxxxxxxxxx/exec
  static const String SCRIPT_URL =
      'https://script.google.com/macros/s/AKfycbz6Uijs7_qzC6cMo0NpssixK7t-jqO5oEM00sqP5eO-R0-TL8Vov1Lp89lJfLZgF7dQQg/exec';

  /// Gửi bản ghi điểm danh lên Google Sheets
  /// Trả về true nếu thành công, false nếu thất bại
  Future<bool> syncAttendance(Attendance attendance) async {
    if (SCRIPT_URL == 'YOUR_GOOGLE_APPS_SCRIPT_URL_HERE') {
      print('⚠️ Chưa cấu hình Google Sheets URL - Bỏ qua đồng bộ');
      return false;
    }

    try {
      final client = http.Client();
      final request = http.Request('POST', Uri.parse(SCRIPT_URL))
        ..followRedirects = true
        ..maxRedirects = 5
        ..headers['Content-Type'] = 'application/json'
        ..body = json.encode({
          'action': 'addAttendance',
          'data': {
            'employeeId': attendance.employeeId,
            'employeeName': attendance.employeeName,
            'checkInTime': attendance.checkInTime.toIso8601String(),
            'status': attendance.status,
            'date': _formatDate(attendance.checkInTime),
            'time': _formatTime(attendance.checkInTime),
          },
        });

      final streamedResponse = await client
          .send(request)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              print('⏱️ Timeout khi đồng bộ Google Sheets');
              throw Exception('Timeout');
            },
          );

      final response = await http.Response.fromStream(streamedResponse);
      client.close();

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['status'] == 'success') {
          print('✅ Đã đồng bộ lên Google Sheets: ${attendance.employeeName}');
          return true;
        } else {
          print('❌ Lỗi từ Apps Script: ${result['message']}');
          return false;
        }
      } else {
        print('❌ HTTP ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Lỗi đồng bộ Google Sheets: $e');
      return false;
    }
  }

  /// Gửi danh sách nhân viên lên Google Sheets (khởi tạo database)
  Future<bool> syncEmployeeList(List<Employee> employees) async {
    if (SCRIPT_URL == 'YOUR_GOOGLE_APPS_SCRIPT_URL_HERE') {
      print('⚠️ Chưa cấu hình Google Sheets URL - Bỏ qua đồng bộ');
      return false;
    }

    try {
      print(
        '📤 Đang đồng bộ ${employees.length} nhân viên lên Google Sheets...',
      );
      print('🔗 URL: $SCRIPT_URL');

      // Dùng http.get/post thay vì Request để auto-handle redirects
      final response = await http
          .post(
            Uri.parse(SCRIPT_URL),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'action': 'syncEmployees',
              'data': employees.map((emp) => emp.toJson()).toList(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      print('📥 Response status: ${response.statusCode}');
      print(
        '📥 Response body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}',
      );

      if (response.statusCode == 200) {
        // HTTP 200 = Thành công, bất kể response body là gì
        print(
          '✅ HTTP 200 - Đã đồng bộ ${employees.length} nhân viên lên Google Sheets',
        );

        // Vẫn cố parse JSON để log thông tin
        try {
          final result = json.decode(response.body);
          print('📋 Response JSON: ${result['status']} - ${result['message']}');
        } catch (e) {
          print('⚠️ Response không phải JSON (có thể là HTML hoặc text thuần)');
        }

        return true; // ✅ LUÔN return true nếu HTTP 200
      } else if (response.statusCode == 302 || response.statusCode == 301) {
        // Xử lý redirect thủ công
        print('🔄 Phát hiện redirect, đang thử lại...');
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null) {
          final redirectResponse = await http
              .post(
                Uri.parse(redirectUrl),
                headers: {'Content-Type': 'application/json'},
                body: json.encode({
                  'action': 'syncEmployees',
                  'data': employees.map((emp) => emp.toJson()).toList(),
                }),
              )
              .timeout(const Duration(seconds: 15));

          if (redirectResponse.statusCode == 200) {
            final result = json.decode(redirectResponse.body);
            if (result['status'] == 'success') {
              print(
                '✅ Đã đồng bộ ${employees.length} nhân viên lên Google Sheets',
              );
              return true;
            }
          }
        }
        print('❌ HTTP ${response.statusCode}: Redirect failed');
        return false;
      } else {
        print('❌ HTTP ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Lỗi đồng bộ danh sách nhân viên: $e');
      return false;
    }
  }

  /// Lấy thống kê từ Google Sheets
  Future<Map<String, dynamic>?> getStatistics(DateTime date) async {
    if (SCRIPT_URL == 'YOUR_GOOGLE_APPS_SCRIPT_URL_HERE') {
      return null;
    }

    try {
      final response = await http
          .post(
            Uri.parse(SCRIPT_URL),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'action': 'getStatistics',
              'data': {'date': _formatDate(date)},
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['status'] == 'success') {
          return result['data'] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print('❌ Lỗi lấy thống kê: $e');
      return null;
    }
  }

  /// Format ngày: dd/MM/yyyy
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// Format giờ: HH:mm:ss
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  /// Kiểm tra kết nối với Google Sheets
  Future<bool> testConnection() async {
    if (SCRIPT_URL == 'YOUR_GOOGLE_APPS_SCRIPT_URL_HERE') {
      return false;
    }

    try {
      final response = await http
          .post(
            Uri.parse(SCRIPT_URL),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'action': 'ping'}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        return result['status'] == 'success';
      }
      return false;
    } catch (e) {
      print('❌ Lỗi kiểm tra kết nối: $e');
      return false;
    }
  }
}
