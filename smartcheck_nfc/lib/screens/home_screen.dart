import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/attendance.dart';
import '../services/database_helper.dart';
import '../services/nfc_service.dart';
import '../services/tts_service.dart';
import '../services/camera_service.dart';
import '../services/google_sheets_service.dart';
import 'write_nfc_screen.dart';
import 'employee_list_screen.dart';
import 'result_screen.dart';
import 'analytics_screen.dart';
import 'photo_viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final NfcService _nfcService = NfcService();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final TtsService _ttsService = TtsService.instance;
  final CameraService _cameraService = CameraService.instance;
  final GoogleSheetsService _sheetsService = GoogleSheetsService.instance;

  List<Attendance> _todayAttendance = [];
  bool _isLoading = false;
  bool _isNfcAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkNfcAvailability();
    _loadTodayAttendance();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    // Khởi tạo camera ngầm để sẵn sàng chụp khi cần
    await _cameraService.initialize();
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

    // Hiển thị loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text(
                '🔍 Đang chờ thẻ NFC...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Vui lòng đưa thẻ gần camera sau điện thoại',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final employee = await _nfcService.readNfcTag().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          if (mounted) Navigator.pop(context);
          _showErrorDialog(
            'Hết thời gian chờ',
            'Không phát hiện thẻ NFC sau 30 giây.\n\nVui lòng thử lại và giữ thẻ gần điện thoại.',
          );
          return null;
        },
      );

      // Đóng loading dialog
      if (mounted) Navigator.pop(context);

      if (employee == null) {
        // Phát giọng nói thông báo thẻ không hợp lệ
        await _ttsService.speakError('invalid');

        _showErrorDialog(
          'Không đọc được thẻ',
          'Vui lòng thử lại và giữ thẻ gần điện thoại lâu hơn.',
        );
        return;
      }

      // Kiểm tra nhân viên có trong database không
      final existingEmployee = await _dbHelper.getEmployeeById(
        employee.employeeId,
      );
      if (existingEmployee == null) {
        // Tự động thêm nhân viên mới vào database
        await _dbHelper.insertEmployee(employee);
        print('✅ Đã tự động thêm nhân viên: ${employee.employeeId}');
      }

      // Kiểm tra đã điểm danh hôm nay chưa
      final hasCheckedIn = await _dbHelper.hasCheckedInToday(
        employee.employeeId,
      );
      if (hasCheckedIn) {
        // Phát giọng nói thông báo trùng
        await _ttsService.speakError('duplicate');

        _showWarningDialog(
          'Đã điểm danh',
          '${employee.name} đã điểm danh hôm nay rồi!\n\nKhông thể điểm danh lại.',
        );
        return;
      }

      // Lưu điểm danh
      final now = DateTime.now();

      // Chụp ảnh xác thực tự động (Anti-Fraud)
      String? capturedImagePath;
      try {
        capturedImagePath = await _cameraService.captureAntiSpoofingImage(
          employee.employeeId,
        );
        if (capturedImagePath != null) {
          print('📸 Đã chụp ảnh xác thực: $capturedImagePath');
        }
      } catch (e) {
        print('⚠️ Không chụp được ảnh: $e (Vẫn tiếp tục điểm danh)');
      }

      final attendance = Attendance(
        employeeId: employee.employeeId,
        employeeName: employee.name,
        checkInTime: now,
        status: _getAttendanceStatus(now),
        imagePath: capturedImagePath,
      );

      await _dbHelper.insertAttendance(attendance);

      // Reload danh sách
      await _loadTodayAttendance();

      // Đồng bộ lên Google Sheets (chạy nền, không chặn UI)
      _sheetsService.syncAttendance(attendance).then((success) {
        if (success) {
          print('✅ Đã đồng bộ Google Sheets');
        } else {
          print(
            '⚠️ Không đồng bộ được Google Sheets (không ảnh hưởng điểm danh)',
          );
        }
      });

      // Phát giọng nói thông báo điểm danh thành công
      await _ttsService.speakAttendanceSuccess(
        employee.name,
        _getAttendanceStatus(now),
      );

      // Hiển thị thông báo thành công
      _showSuccessDialog(employee.name, now, _getAttendanceStatus(now));
    } catch (e) {
      // Đóng loading dialog nếu có lỗi
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      _showErrorDialog('Lỗi hệ thống', 'Chi tiết: $e');
    }
  }

  String _getAttendanceStatus(DateTime checkInTime) {
    final hour = checkInTime.hour;
    final minute = checkInTime.minute;
    // Tùy chỉnh giờ làm việc
    // Quy định: đi làm trước 11:30 là đúng giờ, sau 11:30 là đi muộn
    if (hour < 11 || (hour == 11 && minute <= 30)) {
      return 'Đi làm';
    } else {
      return 'Đi muộn';
    }
  }

  void _showSuccessDialog(
    String employeeName,
    DateTime checkInTime,
    String status,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        title: const Text('✅ Điểm danh thành công!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              employeeName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: status == 'Đi làm'
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: status == 'Đi làm' ? Colors.green : Colors.orange,
                ),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: status == 'Đi làm'
                      ? Colors.green.shade700
                      : Colors.orange.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              DateFormat('HH:mm:ss').format(checkInTime),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              DateFormat('dd/MM/yyyy').format(checkInTime),
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: Colors.red, size: 60),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showWarningDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber, color: Colors.orange, size: 60),
        title: Text(title),
        content: Text(message),
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
            icon: const Icon(Icons.photo_library_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PhotoViewerScreen(),
                ),
              );
            },
            tooltip: 'Xem ảnh điểm danh',
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AnalyticsScreen(),
                ),
              );
            },
            tooltip: 'Thống kê',
          ),
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
