import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/attendance.dart';
import '../services/database_helper.dart';
import '../services/nfc_service.dart';
import 'write_nfc_screen.dart';
import 'employee_list_screen.dart';
import 'result_screen.dart';

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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'SmartCheck NFC',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ResultScreen()),
              );
            },
            tooltip: 'Kết quả',
          ),
          IconButton(
            icon: const Icon(Icons.people_outline),
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
            icon: const Icon(Icons.edit_note),
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
      body: RefreshIndicator(
        onRefresh: _loadTodayAttendance,
        child: Column(
          children: [
            // Header Card - Thông tin ngày & thống kê
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Hôm nay',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('dd/MM/yyyy').format(DateTime.now()),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.people,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_todayAttendance.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Nút quét NFC
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _scanNfcCard,
                    icon: const Icon(Icons.nfc, size: 28),
                    label: const Text(
                      'QUÉT THẺ ĐIỂM DANH',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF2196F3),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),

            // Section Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text(
                    'Danh sách điểm danh',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF424242),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('EEEE', 'vi_VN').format(DateTime.now()),
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Danh sách điểm danh
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _todayAttendance.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 80,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Chưa có ai điểm danh',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _todayAttendance.length,
                      itemBuilder: (context, index) {
                        final attendance = _todayAttendance[index];
                        final isOnTime = attendance.status == 'Đi làm';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Avatar
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isOnTime
                                          ? [
                                              const Color(0xFF4CAF50),
                                              const Color(0xFF66BB6A),
                                            ]
                                          : [
                                              const Color(0xFFFF9800),
                                              const Color(0xFFFFB74D),
                                            ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      attendance.employeeName[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Thông tin nhân viên
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        attendance.employeeName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF212121),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.badge_outlined,
                                            size: 14,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            attendance.employeeId,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Thời gian & trạng thái
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 16,
                                          color: isOnTime
                                              ? const Color(0xFF4CAF50)
                                              : const Color(0xFFFF9800),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          attendance.getFormattedTime(),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: isOnTime
                                                ? const Color(0xFF4CAF50)
                                                : const Color(0xFFFF9800),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isOnTime
                                            ? const Color(0xFFE8F5E9)
                                            : const Color(0xFFFFF3E0),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        attendance.status,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isOnTime
                                              ? const Color(0xFF4CAF50)
                                              : const Color(0xFFFF9800),
                                        ),
                                      ),
                                    ),
                                  ],
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
      ),
    );
  }
}
