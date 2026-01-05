import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../models/attendance.dart';
import '../models/employee.dart';
import '../services/database_helper.dart';
import '../services/google_sheets_service.dart'; // Dùng service này thay vì email_service
import '../services/pdf_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final GoogleSheetsService _sheetsService = GoogleSheetsService.instance; // Mới
  final PdfService _pdfService = PdfService.instance;

  // Bộ lọc
  String _timeFilter = 'Tuần này';
  DateTimeRange? _dateRange;

  // Dữ liệu thống kê
  List<Attendance> _attendances = [];
  Map<String, double> _salaryMap = {};
  Map<String, double> _hoursMap = {};
  Map<String, Employee> _employeeMap = {};
  bool _isLoading = false;
  bool _isSendingMail = false; // Trạng thái gửi mail

  @override
  void initState() {
    super.initState();
    _setInitialDateRange();
    _loadData();
  }

  void _setInitialDateRange() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    _dateRange = DateTimeRange(start: startOfWeek, end: endOfWeek);
  }

  Future<void> _loadData() async {
    if (_dateRange == null) return;
    setState(() => _isLoading = true);

    try {
      final attendanceList = await _dbHelper.getAttendanceByRange(
        _dateRange!.start,
        _dateRange!.end,
      );

      final employees = await _dbHelper.getAllEmployees();
      final empMap = {for (var e in employees) e.employeeId: e};

      Map<String, double> salaryResult = {};
      Map<String, double> hoursResult = {};

      for (var att in attendanceList) {
        if (att.workHours != null && att.workHours! > 0) {
          final emp = empMap[att.employeeId];
          final rate = emp?.salaryRate ?? 0.0;
          
          hoursResult[att.employeeId] = (hoursResult[att.employeeId] ?? 0) + att.workHours!;
          salaryResult[att.employeeId] = (salaryResult[att.employeeId] ?? 0) + (att.workHours! * rate);
        }
      }

      setState(() {
        _attendances = attendanceList;
        _employeeMap = empMap;
        _salaryMap = salaryResult;
        _hoursMap = hoursResult;
        _isLoading = false;
      });
    } catch (e) {
      print('Lỗi thống kê: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDateRange() async {
    final newRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );

    if (newRange != null) {
      setState(() {
        _dateRange = newRange;
        _timeFilter = 'Tùy chọn';
      });
      _loadData();
    }
  }

  void _selectPreset(String preset) {
    final now = DateTime.now();
    DateTime start, end;

    if (preset == 'Tuần này') {
      start = now.subtract(Duration(days: now.weekday - 1));
      end = start.add(const Duration(days: 6));
    } else if (preset == 'Tháng này') {
      start = DateTime(now.year, now.month, 1);
      end = DateTime(now.year, now.month + 1, 0);
    } else {
      return;
    }

    setState(() {
      _timeFilter = preset;
      _dateRange = DateTimeRange(start: start, end: end);
    });
    _loadData();
  }
  
  // Gửi email qua Google Sheets (Server-side)
  Future<void> _sendEmailReport(String employeeId) async {
    final employee = _employeeMap[employeeId];
    if (employee == null) return;
    
    if (employee.email == null || employee.email!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhân viên này chưa cập nhật email!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSendingMail = true);
    
    // Hiện thông báo đang gửi
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đang gửi email tự động...'), duration: Duration(seconds: 2)),
    );

    final totalHours = _hoursMap[employeeId] ?? 0;
    final totalSalary = _salaryMap[employeeId] ?? 0;
    
    // Gọi Google Script để gửi mail
    final success = await _sheetsService.sendEmailReport(
      email: employee.email!,
      employeeId: employee.employeeId,
      employeeName: employee.name,
      totalHours: totalHours,
      salaryRate: employee.salaryRate ?? 0,
      totalSalary: totalSalary,
      startDate: _dateRange!.start,
      endDate: _dateRange!.end,
    );
    
    setState(() => _isSendingMail = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Đã gửi email thành công!'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Gửi thất bại. Kiểm tra kết nối mạng.'), backgroundColor: Colors.red),
      );
    }
  }

  // Xem trước và In PDF
  Future<void> _previewPdf(String employeeId) async {
    final employee = _employeeMap[employeeId];
    if (employee == null) return;

    final totalHours = _hoursMap[employeeId] ?? 0;
    final totalSalary = _salaryMap[employeeId] ?? 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final file = await _pdfService.generatePayslip(
        employee, 
        totalHours, 
        totalSalary, 
        _dateRange!.start, 
        _dateRange!.end
      );
      
      Navigator.pop(context);

      await Printing.layoutPdf(
        onLayout: (format) => file.readAsBytes(),
        name: 'PhieuLuong_${employee.employeeId}',
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tạo PDF: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo cáo & Tính lương'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _pickDateRange,
            tooltip: 'Chọn khoảng thời gian',
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Filter Bar
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: Colors.grey[200],
                child: Row(
                  children: [
                    _buildFilterChip('Tuần này'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Tháng này'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _dateRange != null
                            ? '${DateFormat('dd/MM').format(_dateRange!.start)} - ${DateFormat('dd/MM').format(_dateRange!.end)}'
                            : '',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),

              // Tổng quan
              if (!_isLoading) ...[
                 Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      _buildSummaryCard('Tổng giờ làm', _calculateTotalHours(), Colors.orange),
                      const SizedBox(width: 16),
                      _buildSummaryCard('Tổng lương chi', _calculateTotalSalary(), Colors.green),
                    ],
                  ),
                ),
              ],
              
              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(alignment: Alignment.centerLeft, child: Text('Chi tiết nhân viên', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              ),

              // List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _salaryMap.isEmpty
                        ? const Center(child: Text('Không có dữ liệu trong khoảng thời gian này'))
                        : ListView.builder(
                            itemCount: _salaryMap.length,
                            itemBuilder: (context, index) {
                              final empId = _salaryMap.keys.elementAt(index);
                              final totalSalary = _salaryMap[empId]!;
                              final totalHours = _hoursMap[empId] ?? 0;
                              final employee = _employeeMap[empId];
                              final name = employee?.name ?? 'Unknown';

                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    child: Text(name.isNotEmpty ? name[0] : '?'),
                                  ),
                                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('Giờ làm: ${totalHours.toStringAsFixed(1)}h'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${NumberFormat("#,###").format(totalSalary)}',
                                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      const SizedBox(width: 4),
                                      // Nút PDF
                                      IconButton(
                                        icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                                        onPressed: _isSendingMail ? null : () => _previewPdf(empId),
                                        tooltip: 'Xuất PDF',
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(8),
                                      ),
                                      // Nút Email (Tự động)
                                      IconButton(
                                        icon: const Icon(Icons.send, color: Colors.blue),
                                        onPressed: _isSendingMail ? null : () => _sendEmailReport(empId),
                                        tooltip: 'Gửi Email Tự động',
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(8),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
          
          // Overlay loading khi đang gửi mail
          if (_isSendingMail)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildFilterChip(String label) {
    final isSelected = _timeFilter == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) _selectPreset(label);
      },
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: color.withOpacity(0.8), fontSize: 12)),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
  
  String _calculateTotalSalary() {
    double total = 0;
    _salaryMap.values.forEach((v) => total += v);
    return '${NumberFormat.compact().format(total)} đ';
  }
  
  String _calculateTotalHours() {
    double total = 0;
    _hoursMap.values.forEach((v) => total += v);
    return '${total.toStringAsFixed(1)}h';
  }
}
