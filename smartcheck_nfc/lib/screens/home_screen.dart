import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/attendance.dart';
import '../services/database_helper.dart';
import '../services/nfc_service.dart';
import 'write_nfc_screen.dart';
import 'employee_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final NfcService _nfcService = NfcService();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<Attendance> _todayAttendance = [];
  bool _isLoading = false;
  bool _isNfcAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkNfcAvailability();
    _loadTodayAttendance();
  }

  Future<void> _checkNfcAvailability() async {
    final available = await _nfcService.isNfcAvailable();
    setState(() {
      _isNfcAvailable = available;
    });
  }

  Future<void> _loadTodayAttendance() async {
    setState(() {
      _isLoading = true;
    });

    final attendance = await _dbHelper.getAttendanceByDate(DateTime.now());

    setState(() {
      _todayAttendance = attendance;
      _isLoading = false;
    });
  }

  Future<void> _scanNfcCard() async {
    if (!_isNfcAvailable) {
      _showMessage('Thiết bị không hỗ trợ NFC', isError: true);
      return;
    }

    _showMessage('Vui lòng đưa thẻ NFC đến điện thoại...', isInfo: true);

    try {
      final employee = await _nfcService.readNfcTag();

      if (employee == null) {
        _showMessage('Không đọc được thông tin từ thẻ', isError: true);
        return;
      }

      // Kiểm tra nhân viên có trong database không
      final existingEmployee = await _dbHelper.getEmployeeById(
        employee.employeeId,
      );
      if (existingEmployee == null) {
        _showMessage(
          'Nhân viên ${employee.employeeId} không tồn tại',
          isError: true,
        );
        return;
      }

      // Kiểm tra đã điểm danh hôm nay chưa
      final hasCheckedIn = await _dbHelper.hasCheckedInToday(
        employee.employeeId,
      );
      if (hasCheckedIn) {
        _showMessage(
          '${employee.name} đã điểm danh hôm nay rồi!',
          isError: true,
        );
        return;
      }

      // Lưu điểm danh
      final now = DateTime.now();
      final attendance = Attendance(
        employeeId: employee.employeeId,
        employeeName: employee.name,
        checkInTime: now,
        status: _getAttendanceStatus(now),
      );

      await _dbHelper.insertAttendance(attendance);

      // Reload danh sách
      await _loadTodayAttendance();

      // Hiển thị thông báo thành công
      _showSuccessDialog(employee.name, now);
    } catch (e) {
      _showMessage('Lỗi: $e', isError: true);
    }
  }

  String _getAttendanceStatus(DateTime checkInTime) {
    final hour = checkInTime.hour;
    final minute = checkInTime.minute;

    // Quy định: đi làm trước 8:30 là đúng giờ, sau 8:30 là đi muộn
    if (hour < 8 || (hour == 8 && minute <= 30)) {
      return 'Đi làm';
    } else {
      return 'Đi muộn';
    }
  }

  void _showSuccessDialog(String employeeName, DateTime checkInTime) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        title: const Text('Điểm danh thành công!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Xin chào: $employeeName',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Thời gian: ${DateFormat('HH:mm - dd/MM/yyyy').format(checkInTime)}',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showMessage(
    String message, {
    bool isError = false,
    bool isInfo = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Colors.red
            : isInfo
            ? Colors.blue
            : Colors.green,
        duration: Duration(seconds: isInfo ? 5 : 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartCheck - Điểm danh NFC'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EmployeeListScreen(),
                ),
              ).then((_) => _loadTodayAttendance());
            },
            tooltip: 'Danh sách nhân viên',
          ),
          IconButton(
            icon: const Icon(Icons.nfc),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const WriteNfcScreen()),
              );
            },
            tooltip: 'Ghi thẻ NFC',
          ),
        ],
      ),
      body: Column(
        children: [
          // Phần thông tin ngày
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              children: [
                Text(
                  DateFormat(
                    'EEEE, dd/MM/yyyy',
                    'vi_VN',
                  ).format(DateTime.now()),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tổng số người đã điểm danh: ${_todayAttendance.length}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),

          // Nút quét NFC
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _scanNfcCard,
              icon: const Icon(Icons.nfc, size: 32),
              label: const Text(
                'QUÉT THẺ NFC',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                minimumSize: const Size(double.infinity, 60),
              ),
            ),
          ),

          // Danh sách điểm danh hôm nay
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _todayAttendance.isEmpty
                ? const Center(
                    child: Text(
                      'Chưa có ai điểm danh hôm nay',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _todayAttendance.length,
                    itemBuilder: (context, index) {
                      final attendance = _todayAttendance[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: attendance.status == 'Đi làm'
                                ? Colors.green
                                : Colors.orange,
                            child: Text(
                              attendance.employeeName[0],
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            attendance.employeeName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('Mã NV: ${attendance.employeeId}'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                attendance.getFormattedTime(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                attendance.status,
                                style: TextStyle(
                                  color: attendance.status == 'Đi làm'
                                      ? Colors.green
                                      : Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _loadTodayAttendance,
        tooltip: 'Làm mới',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
