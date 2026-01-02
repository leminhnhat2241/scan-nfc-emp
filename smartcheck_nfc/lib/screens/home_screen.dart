import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import '../models/attendance.dart';
import '../models/employee.dart';
import '../services/database_helper.dart';
import '../services/nfc_service.dart';
import '../services/tts_service.dart';
import '../services/camera_service.dart';
import '../services/google_sheets_service.dart';
import '../services/biometric_service.dart';
import '../services/settings_service.dart'; // Mới
import 'write_nfc_screen.dart';
import 'employee_list_screen.dart';
import 'result_screen.dart';
import 'analytics_screen.dart';
import 'photo_viewer_screen.dart';
import 'manual_attendance_screen.dart';
import 'settings_screen.dart'; // Mới
import 'admin_login_screen.dart'; // Mới

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
  final BiometricService _biometricService = BiometricService.instance;

  List<Attendance> _todayAttendance = [];
  bool _isLoading = false;
  bool _isNfcAvailable = false;
  bool _isBiometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkAvailability();
    _loadTodayAttendance();
    _initializeCamera();
    SettingsService.instance.initialize(); // Khởi tạo settings
  }

  Future<void> _initializeCamera() async {
    await _cameraService.initialize();
  }

  Future<void> _checkAvailability() async {
    final nfc = await _nfcService.isNfcAvailable();
    final bio = await _biometricService.isBiometricAvailable();
    setState(() {
      _isNfcAvailable = nfc;
      _isBiometricAvailable = bio;
    });
  }

  Future<void> _loadTodayAttendance() async {
    setState(() => _isLoading = true);
    final attendance = await _dbHelper.getAttendanceByDate(DateTime.now());
    setState(() {
      _todayAttendance = attendance;
      _isLoading = false;
    });
  }

  Future<void> _processAttendance(Employee employee, {bool isBio = false}) async {
    try {
      if (!employee.isActive) {
         await _ttsService.speakError('locked');
         _showErrorDialog('Tài khoản bị khóa', 'Tài khoản nhân viên ${employee.name} đã bị khóa.');
         return;
      }

      final now = DateTime.now();
      final existingAttendance = await _dbHelper.getAttendanceByEmployeeAndDate(employee.employeeId, now);
      Attendance? attendanceToSync;

      if (existingAttendance == null) {
        // CHECK-IN
        String? capturedImagePath;
        try {
          capturedImagePath = await _cameraService.captureAntiSpoofingImage(employee.employeeId);
        } catch (e) {
          print('⚠️ Không chụp được ảnh: $e');
        }

        final attendance = Attendance(
          employeeId: employee.employeeId,
          employeeName: employee.name,
          checkInTime: now,
          status: _getAttendanceStatus(now),
          imagePath: capturedImagePath,
        );

        await _dbHelper.insertAttendance(attendance);
        await _ttsService.speakAttendanceSuccess(employee.name, attendance.status);
        _showSuccessDialog(employee.name, now, attendance.status, isCheckIn: true, method: isBio ? 'Sinh trắc học' : 'NFC');
        attendanceToSync = attendance;

      } else if (existingAttendance.checkOutTime == null) {
        // CHECK-OUT
        final workDuration = now.difference(existingAttendance.checkInTime);
        final workHours = workDuration.inMinutes / 60.0;
        
        final updatedAttendance = Attendance(
          id: existingAttendance.id,
          employeeId: existingAttendance.employeeId,
          employeeName: existingAttendance.employeeName,
          checkInTime: existingAttendance.checkInTime,
          status: existingAttendance.status,
          imagePath: existingAttendance.imagePath,
          checkOutTime: now,
          workHours: double.parse(workHours.toStringAsFixed(2)),
        );
        
        await _dbHelper.updateAttendance(updatedAttendance);
        await _ttsService.speakCheckoutSuccess(employee.name);
        _showSuccessDialog(employee.name, now, 'Hoàn thành', isCheckIn: false, workHours: workHours, method: isBio ? 'Sinh trắc học' : 'NFC');
        attendanceToSync = updatedAttendance;
        
      } else {
        await _ttsService.speakError('duplicate');
        _showWarningDialog('Đã hoàn thành', '${employee.name} đã hoàn thành ca làm việc hôm nay!');
      }

      await _loadTodayAttendance();
      if (attendanceToSync != null) {
        _sheetsService.syncAttendance(attendanceToSync);
      }
      
    } catch (e) {
      _showErrorDialog('Lỗi hệ thống', 'Chi tiết: $e');
    }
  }

  // --- LOGIC AUTH ---
  Future<void> _checkAdminAccess(VoidCallback onSuccess) async {
    // 1. Thử xác thực vân tay trước (Nếu máy có vân tay)
    if (_isBiometricAvailable) {
      final authenticated = await _biometricService.authenticate(
        reason: 'Quét vân tay Admin để truy cập',
      );
      if (authenticated) {
        onSuccess();
        return;
      }
    }

    // 2. Nếu vân tay thất bại hoặc không có -> Hiện màn hình nhập PIN
    if (!mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminLoginScreen()),
    );

    if (result == true) {
      onSuccess();
    }
  }

  // ... (Giữ nguyên các hàm _startBiometricAuth, _scanNfcCard cũ)
  
  Future<void> _startBiometricAuth() async {
    final employees = await _dbHelper.getAllEmployees(activeOnly: true);
    if (employees.isEmpty) {
      _showMessage('Chưa có nhân viên nào', isError: true);
      return;
    }
    if (!mounted) return;
    
    final selectedEmployee = await showDialog<Employee>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chọn nhân viên'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: employees.length,
            itemBuilder: (context, index) {
              final emp = employees[index];
              return ListTile(
                leading: CircleAvatar(child: Text(emp.name[0])),
                title: Text(emp.name),
                subtitle: Text(emp.employeeId),
                onTap: () => Navigator.pop(context, emp),
              );
            },
          ),
        ),
      ),
    );

    if (selectedEmployee == null) return;

    final isAuthenticated = await _biometricService.authenticate(
      reason: 'Xác thực để điểm danh cho ${selectedEmployee.name}',
    );

    if (isAuthenticated) {
      await _processAttendance(selectedEmployee, isBio: true);
    } else {
      _showMessage('Xác thực thất bại', isError: true);
    }
  }

  Future<void> _scanNfcCard() async {
    if (!_isNfcAvailable) {
      _showMessage('Thiết bị không hỗ trợ NFC', isError: true);
      return;
    }
     showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('🔍 Đang chờ thẻ NFC...'),
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
          return null;
        },
      );

      if (mounted) Navigator.pop(context);

      if (employee == null) {
        await _ttsService.speakError('invalid');
        _showErrorDialog('Lỗi đọc thẻ', 'Không đọc được thẻ hoặc hết thời gian.');
        return;
      }

      var dbEmployee = await _dbHelper.getEmployeeById(employee.employeeId);
      if (dbEmployee == null) {
        await _dbHelper.insertEmployee(employee);
        dbEmployee = employee;
      }

      await _processAttendance(dbEmployee);

    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showErrorDialog('Lỗi', e.toString());
    }
  }

  String _getAttendanceStatus(DateTime checkInTime) {
    // Lấy cấu hình từ Settings
    final workStart = SettingsService.instance.workStartTime;
    final graceMinutes = SettingsService.instance.gracePeriodMinutes;
    
    // So sánh thời gian
    final checkInMinute = checkInTime.hour * 60 + checkInTime.minute;
    final limitMinute = workStart.hour * 60 + workStart.minute + graceMinutes;
    
    if (checkInMinute <= limitMinute) return 'Đi làm';
    return 'Đi muộn';
  }

  // --- HELPER DIALOGS ---
  void _showSuccessDialog(String name, DateTime time, String status, {bool isCheckIn = true, double? workHours, String method = 'NFC'}) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Column(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 60),
          SizedBox(height: 10),
          Text(isCheckIn ? "Xin chào!" : "Tạm biệt!", style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: Text(
        "${isCheckIn ? 'Check-in' : 'Check-out'} thành công\n$name\n\n${DateFormat('HH:mm').format(time)}",
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Tuyệt vời"))],
    ));
  }
  
  void _showErrorDialog(String title, String msg) => showDialog(context: context, builder: (ctx) => AlertDialog(title: Text(title), content: Text(msg), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Đóng"))]));
  void _showWarningDialog(String title, String msg) => showDialog(context: context, builder: (ctx) => AlertDialog(title: Text(title), content: Text(msg), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Đóng"))]));
  void _showMessage(String msg, {bool isError = false}) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : Colors.green));

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2563EB);
    const bgColor = Color(0xFFF3F4F6);

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('SmartCheck', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 24)),
        centerTitle: false,
        actions: [
          _buildGlassIconButton(Icons.settings, () {
             // Bảo mật: Yêu cầu xác thực Admin trước khi mở menu
             _checkAdminAccess(() {
                _showAdminMenu();
             });
          }),
          const SizedBox(width: 16),
        ],
      ),
      body: Stack(
        children: [
          Container(
            height: 280,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
            ),
          ),
          
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat('EEEE, dd MMMM').format(DateTime.now()), style: TextStyle(color: Colors.white70, fontSize: 16)),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          _buildStatCard('Đã Check-in', '${_todayAttendance.length}', Icons.login, Colors.greenAccent),
                          const SizedBox(width: 16),
                          _buildStatCard('Đi Muộn', '${_todayAttendance.where((e) => e.status == 'Đi muộn').length}', Icons.timer, Colors.orangeAccent),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Hoạt động gần đây", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                            IconButton(
                                icon: Icon(Icons.refresh, color: primaryColor), 
                                onPressed: _loadTodayAttendance
                            )
                          ],
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: _todayAttendance.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                padding: EdgeInsets.only(bottom: 80),
                                itemCount: _todayAttendance.length,
                                itemBuilder: (context, index) {
                                  return _buildTimelineItem(_todayAttendance[index]);
                                },
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.extended(
              heroTag: "nfc",
              onPressed: _scanNfcCard,
              icon: Icon(Icons.nfc),
              label: Text("QUÉT THẺ"),
              backgroundColor: Color(0xFF2563EB),
            ),
            if (_isBiometricAvailable) ...[
              SizedBox(width: 16),
              FloatingActionButton.extended(
                heroTag: "bio",
                onPressed: _startBiometricAuth,
                icon: Icon(Icons.fingerprint),
                label: Text("VÂN TAY"),
                backgroundColor: Color(0xFF7C3AED),
              ),
            ]
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // ... (Giữ nguyên các hàm _buildGlassIconButton, _buildStatCard, _buildTimelineItem, _buildEmptyState, _buildAdminBtn cũ)
  
  // Update _showAdminMenu để thêm nút Settings
  void _showAdminMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            SizedBox(height: 20),
            Text("Quản trị viên", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAdminBtn(Icons.people, "Nhân sự", Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmployeeListScreen()))),
                _buildAdminBtn(Icons.bar_chart, "Thống kê", Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => AnalyticsScreen()))),
                _buildAdminBtn(Icons.edit_calendar, "Thủ công", Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => ManualAttendanceScreen()))),
                _buildAdminBtn(Icons.settings, "Cấu hình", Colors.grey, () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen()))), // Nút mới
              ],
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.nfc, color: Colors.teal),
              title: Text("Thêm NV & Ghi thẻ NFC"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => WriteNfcScreen()));
              },
            ),
            ListTile(
              leading: Icon(Icons.cloud_upload, color: Colors.green),
              title: Text("Đồng bộ danh sách NV lên Sheet"),
              onTap: () async {
                Navigator.pop(context);
                final emps = await _dbHelper.getAllEmployees();
                _sheetsService.syncEmployeeList(emps);
                _showMessage("Đang đồng bộ ngầm...");
              },
            ),
             ListTile(
              leading: Icon(Icons.photo_library, color: Colors.indigo),
              title: Text("Xem ảnh xác thực"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => PhotoViewerScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGlassIconButton(IconData icon, VoidCallback onTap) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: Colors.white.withOpacity(0.2),
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: onTap,
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            SizedBox(height: 12),
            Text(value, style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            Text(title, style: TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(Attendance item) {
    final isLate = item.status == 'Đi muộn';
    final hasCheckout = item.checkOutTime != null;
    
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Text(DateFormat('HH:mm').format(item.checkInTime), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              if (hasCheckout) 
                 Text(DateFormat('HH:mm').format(item.checkOutTime!), style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          SizedBox(width: 16),
          Column(
            children: [
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                  color: isLate ? Colors.orange : Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2)
                ),
              ),
              Container(width: 2, height: 50, color: Colors.grey[300]),
            ],
          ),
          SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.employeeName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isLate ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)
                        ),
                        child: Text(item.status, style: TextStyle(color: isLate ? Colors.orange : Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      if (hasCheckout) ...[
                        SizedBox(width: 8),
                         Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8)
                          ),
                          child: Text("${item.workHours}h", style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ]
                    ],
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 80, color: Colors.grey[300]),
          SizedBox(height: 16),
          Text("Chưa có dữ liệu hôm nay", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildAdminBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
          SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
