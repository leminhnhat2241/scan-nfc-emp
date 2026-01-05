import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/employee.dart';
import 'package:intl/intl.dart';

class EmailService {
  static final EmailService instance = EmailService._init();
  EmailService._init();

  /// Soạn nội dung báo cáo lương
  String generateSalaryReport(
    Employee employee,
    double totalHours,
    double totalSalary,
    DateTime start,
    DateTime end,
  ) {
    final formatCurrency = NumberFormat("#,###", "vi_VN");
    final sb = StringBuffer();
    sb.writeln('BÁO CÁO LƯƠNG & GIỜ LÀM VIỆC');
    sb.writeln('--------------------------------');
    sb.writeln('Nhân viên: ${employee.name} (${employee.employeeId})');
    sb.writeln('Thời gian: ${_formatDate(start)} - ${_formatDate(end)}');
    sb.writeln('--------------------------------');
    sb.writeln('Tổng giờ làm: ${totalHours.toStringAsFixed(1)} giờ');
    sb.writeln('Mức lương: ${formatCurrency.format(employee.salaryRate ?? 0)} VNĐ/giờ');
    sb.writeln('TỔNG LƯƠNG: ${formatCurrency.format(totalSalary)} VNĐ');
    sb.writeln('--------------------------------');
    sb.writeln('Đây là email tự động từ hệ thống SmartCheck NFC.');
    return sb.toString();
  }

  /// Mở ứng dụng Email với nội dung soạn sẵn
  /// Trả về true nếu mở thành công
  Future<bool> sendEmail({
    required String toEmail,
    required String subject,
    required String body,
  }) async {
    // Sử dụng queryParameters để Dart tự encode an toàn
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: toEmail,
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );

    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
        return true;
      } else {
        print('Không tìm thấy ứng dụng hỗ trợ mailto');
        return false;
      }
    } catch (e) {
      print('Không thể mở app mail: $e');
      return false;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
