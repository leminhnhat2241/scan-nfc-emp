import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/attendance.dart';
import '../models/employee.dart';

class GoogleSheetsService {
  static final GoogleSheetsService instance = GoogleSheetsService._init();

  GoogleSheetsService._init();

  // URL Script của bạn
  static const String SCRIPT_URL =
      'https://script.google.com/macros/s/AKfycbzv3Ux3DwYvJiE030eu2pDOqXPPHg5oUbphC1JZ6p1QRlhOXdRghrRko6sbbXFVSUQ/exec';

  /// Helper function để gửi request an toàn
  Future<bool> _sendRequest(Map<String, dynamic> body) async {
    try {
      final client = http.Client();
      
      // Google Apps Script đôi khi redirect 302. 
      // Chúng ta sẽ chặn followRedirects tự động để kiểm soát.
      final request = http.Request('POST', Uri.parse(SCRIPT_URL))
        ..followRedirects = false // QUAN TRỌNG: Tắt tự động redirect
        ..persistentConnection = true
        ..headers['Content-Type'] = 'application/json'
        ..body = json.encode(body);

      final streamedResponse = await client.send(request).timeout(const Duration(seconds: 20));
      final response = await http.Response.fromStream(streamedResponse);
      client.close();
      
      print('🌐 Request Status: ${response.statusCode}');
      
      // Google Script trả về 302 nghĩa là đã nhận được lệnh và đang xử lý/redirect
      if (response.statusCode == 302 || response.statusCode == 200) {
        return true;
      } else {
        print('❌ Server Error: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Connection Error: $e');
      return false;
    }
  }

  Future<bool> syncAttendance(Attendance attendance) async {
    final isCheckout = attendance.checkOutTime != null;
    final body = {
      'action': 'logAttendance',
      'data': {
        'employeeId': attendance.employeeId,
        'employeeName': attendance.employeeName,
        'date': _formatDate(attendance.checkInTime),
        'checkInTime': _formatTime(attendance.checkInTime),
        'status': attendance.status,
        'checkOutTime': attendance.checkOutTime != null ? _formatTime(attendance.checkOutTime!) : '',
        'workHours': attendance.workHours?.toString() ?? '',
        'type': isCheckout ? 'checkout' : 'checkin'
      },
    };
    return _sendRequest(body);
  }

  Future<bool> syncEmployeeList(List<Employee> employees) async {
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
    return _sendRequest(body);
  }

  // --- HÀM GỬI EMAIL ---
  Future<bool> sendEmailReport({
    required String email,
    required String employeeId,
    required String employeeName,
    required double totalHours,
    required double salaryRate,
    required double totalSalary,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final formatCurrency = NumberFormat("#,###", "vi_VN");
    
    final body = {
      'action': 'sendEmail', 
      'data': {
        'email': email,
        'employeeId': employeeId,
        'employeeName': employeeName,
        'period': '${_formatDate(startDate)} - ${_formatDate(endDate)}',
        'totalHours': totalHours.toStringAsFixed(1),
        'salaryRate': formatCurrency.format(salaryRate),
        'totalSalary': formatCurrency.format(totalSalary),
      },
    };

    print('📧 Đang gửi email tới: $email');
    return _sendRequest(body);
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
  String _formatTime(DateTime time) => '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
}
