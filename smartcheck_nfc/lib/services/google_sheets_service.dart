import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/attendance.dart';
import '../models/employee.dart';

/// Service đồng bộ dữ liệu điểm danh lên Google Sheets real-time
class GoogleSheetsService {
  static final GoogleSheetsService instance = GoogleSheetsService._init();

  GoogleSheetsService._init();

  // ⚠️ QUAN TRỌNG: Thay thế URL này bằng Google Apps Script Deployment URL của bạn
  // Nếu bạn đã có URL cũ, hãy dùng lại. Nếu chưa, hãy deploy lại script mới bên dưới.
  static const String SCRIPT_URL =
      'https://script.google.com/macros/s/AKfycbz6JVQ-aPLWH9QnRSjiOKG9L9oR-Y3AwoBXjSl919E2VD-nG0DwpNEzRXLGvP1U36X7/exec';

  /// Gửi bản ghi điểm danh lên Google Sheets (Hỗ trợ cả Check-in và Check-out)
  Future<bool> syncAttendance(Attendance attendance) async {
    if (SCRIPT_URL.contains('YOUR_GOOGLE_APPS_SCRIPT_URL')) {
      print('⚠️ Chưa cấu hình Google Sheets URL');
      return false;
    }

    try {
      final client = http.Client();
      
      // Xác định hành động: Check-in hay Check-out
      final isCheckout = attendance.checkOutTime != null;
      
      final body = {
        'action': 'logAttendance', // Dùng chung 1 action thông minh
        'data': {
          'employeeId': attendance.employeeId,
          'employeeName': attendance.employeeName,
          'date': _formatDate(attendance.checkInTime),
          
          // Dữ liệu Check-in
          'checkInTime': _formatTime(attendance.checkInTime),
          'status': attendance.status,
          
          // Dữ liệu Check-out (nếu có)
          'checkOutTime': attendance.checkOutTime != null ? _formatTime(attendance.checkOutTime!) : '',
          'workHours': attendance.workHours?.toString() ?? '',
          
          // Loại cập nhật
          'type': isCheckout ? 'checkout' : 'checkin'
        },
      };

      print('📤 Đang gửi dữ liệu lên Sheets: $body');

      final response = await client.post(
          Uri.parse(SCRIPT_URL),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body)
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 302) {
        print('✅ Đồng bộ thành công: ${attendance.employeeName}');
        return true;
      } else {
        print('❌ Lỗi HTTP ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Lỗi đồng bộ Google Sheets: $e');
      return false;
    }
  }

  /// Đồng bộ danh sách nhân viên (Kèm Email, Lương)
  Future<bool> syncEmployeeList(List<Employee> employees) async {
    if (SCRIPT_URL.contains('YOUR_GOOGLE_APPS_SCRIPT_URL')) return false;

    try {
      print('📤 Đang đồng bộ ${employees.length} nhân viên...');
      
      final body = {
        'action': 'syncEmployees',
        'data': employees.map((emp) => {
          'employeeId': emp.employeeId,
          'name': emp.name,
          'department': emp.department ?? '',
          'position': emp.position ?? '',
          'email': emp.email ?? '',
          'salaryRate': emp.salaryRate ?? 0,
          'isActive': emp.isActive
        }).toList(),
      };

      await http.post(
        Uri.parse(SCRIPT_URL),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));
      
      print('✅ Đã đồng bộ danh sách nhân viên');
      return true;
    } catch (e) {
      print('❌ Lỗi đồng bộ danh sách nhân viên: $e');
      return false;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }
}
