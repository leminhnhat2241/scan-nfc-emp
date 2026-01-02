import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/employee.dart';

class PdfService {
  static final PdfService instance = PdfService._init();
  PdfService._init();

  Future<File> generatePayslip(
    Employee employee,
    double totalHours,
    double totalSalary,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final pdf = pw.Document();
    
    // Load font tiếng Việt (nếu cần, ở đây dùng font mặc định)
    final font = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('CÔNG TY TNHH SMARTCHECK', style: pw.TextStyle(font: fontBold, fontSize: 20)),
                      pw.Text('Địa chỉ: 123 Đường ABC, Quận 1, TP.HCM', style: pw.TextStyle(font: font, fontSize: 12)),
                      pw.Text('Hotline: 1900 1234', style: pw.TextStyle(font: font, fontSize: 12)),
                    ],
                  ),
                  pw.Container(
                    width: 60,
                    height: 60,
                    decoration: pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      color: PdfColors.blue,
                    ),
                    child: pw.Center(child: pw.Text('LOGO', style: pw.TextStyle(color: PdfColors.white))),
                  ),
                ],
              ),
              pw.SizedBox(height: 40),
              
              // Title
              pw.Center(
                child: pw.Text('PHIẾU LƯƠNG NHÂN VIÊN', style: pw.TextStyle(font: fontBold, fontSize: 24, color: PdfColors.blue800)),
              ),
              pw.Center(
                child: pw.Text('Kỳ lương: ${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}', style: pw.TextStyle(font: font, fontSize: 14)),
              ),
              pw.SizedBox(height: 30),
              
              // Employee Info
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('Mã nhân viên:', employee.employeeId, font, fontBold),
                          pw.SizedBox(height: 5),
                          _buildInfoRow('Họ và tên:', employee.name, font, fontBold),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('Phòng ban:', employee.department ?? 'N/A', font, fontBold),
                          pw.SizedBox(height: 5),
                          _buildInfoRow('Chức vụ:', employee.position ?? 'N/A', font, fontBold),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              
              // Salary Table
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildTableCell('Khoản mục', fontBold, align: pw.TextAlign.center),
                      _buildTableCell('Số lượng', fontBold, align: pw.TextAlign.center),
                      _buildTableCell('Đơn giá', fontBold, align: pw.TextAlign.center),
                      _buildTableCell('Thành tiền (VNĐ)', fontBold, align: pw.TextAlign.center),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildTableCell('Giờ làm việc', font),
                      _buildTableCell('${totalHours.toStringAsFixed(2)} giờ', font, align: pw.TextAlign.right),
                      _buildTableCell('${NumberFormat("#,###").format(employee.salaryRate)}', font, align: pw.TextAlign.right),
                      _buildTableCell('${NumberFormat("#,###").format(totalSalary)}', fontBold, align: pw.TextAlign.right),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Tổng thực lĩnh: ${NumberFormat("#,###").format(totalSalary)} VNĐ',
                  style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.red),
                ),
              ),
              
              pw.Spacer(),
              
              // Footer
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Text('Người lập phiếu', style: pw.TextStyle(font: fontBold)),
                      pw.SizedBox(height: 50),
                      pw.Text('(Ký tên)', style: pw.TextStyle(font: font, fontStyle: pw.FontStyle.italic)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('Ngày ..... tháng ..... năm 20...', style: pw.TextStyle(font: font)),
                      pw.Text('Giám đốc', style: pw.TextStyle(font: fontBold)),
                      pw.SizedBox(height: 50),
                      pw.Text('(Ký tên, đóng dấu)', style: pw.TextStyle(font: font, fontStyle: pw.FontStyle.italic)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/payslip_${employee.employeeId}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  pw.Widget _buildInfoRow(String label, String value, pw.Font font, pw.Font fontBold) {
    return pw.Row(
      children: [
        pw.Text(label, style: pw.TextStyle(font: font)),
        pw.SizedBox(width: 5),
        pw.Text(value, style: pw.TextStyle(font: fontBold)),
      ],
    );
  }

  pw.Widget _buildTableCell(String text, pw.Font font, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text, style: pw.TextStyle(font: font), textAlign: align),
    );
  }
}
