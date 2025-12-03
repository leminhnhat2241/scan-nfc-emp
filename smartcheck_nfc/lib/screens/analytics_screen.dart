import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/attendance.dart';
import '../models/employee.dart';
import '../services/database_helper.dart';
import '../widgets/stats_card.dart';
import '../widgets/attendance_chart.dart';

/// Màn hình Phân tích Thống kê Thông minh
/// File con: lib/screens/analytics_screen.dart
/// File mẹ: Được gọi từ lib/screens/home_screen.dart
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<Attendance> _todayAttendance = [];
  List<Employee> _allEmployees = [];
  Map<String, int> _last7DaysData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    // Load dữ liệu hôm nay
    final todayData = await _dbHelper.getAttendanceByDate(DateTime.now());

    // Load tất cả nhân viên
    final employees = await _dbHelper.getAllEmployees();

    // Load dữ liệu 7 ngày gần nhất
    final Map<String, int> dailyData = {};
    for (int i = 6; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dayAttendance = await _dbHelper.getAttendanceByDate(date);
      final dateKey = DateFormat('dd/MM').format(date);
      dailyData[dateKey] = dayAttendance.length;
    }

    setState(() {
      _todayAttendance = todayData;
      _allEmployees = employees;
      _last7DaysData = dailyData;
      _isLoading = false;
    });
  }

  int get _totalEmployees => _allEmployees.length;
  int get _presentToday => _todayAttendance.length;
  int get _absentToday => _totalEmployees - _presentToday;
  int get _onTimeCount =>
      _todayAttendance.where((a) => a.status == 'Đi làm').length;
  int get _lateCount =>
      _todayAttendance.where((a) => a.status == 'Đi muộn').length;

  double get _attendanceRate {
    if (_totalEmployees == 0) return 0;
    return (_presentToday / _totalEmployees) * 100;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Thống kê Thông minh',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tiêu đề ngày
                    _buildDateHeader(),
                    const SizedBox(height: 20),

                    // Thống kê tổng quan (4 thẻ)
                    _buildOverviewStats(),
                    const SizedBox(height: 24),

                    // Biểu đồ tròn: Phân bố trạng thái hôm nay
                    _buildSectionTitle('Phân bố trạng thái hôm nay'),
                    const SizedBox(height: 16),
                    _buildPieChartSection(),
                    const SizedBox(height: 24),

                    // Biểu đồ cột: xu hướng 7 ngày
                    _buildSectionTitle('Xu hướng 7 ngày gần nhất'),
                    const SizedBox(height: 16),
                    _buildBarChartSection(),
                    const SizedBox(height: 24),

                    // Top nhân viên đi muộn nhiều nhất (nếu có)
                    if (_lateCount > 0) ...[
                      _buildSectionTitle('⚠️ Nhân viên đi muộn hôm nay'),
                      const SizedBox(height: 16),
                      _buildLateEmployeesList(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDateHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat(
                  'EEEE, dd MMMM yyyy',
                  'vi_VN',
                ).format(DateTime.now()),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Cập nhật lúc ${DateFormat('HH:mm').format(DateTime.now())}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewStats() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        StatsCard(
          title: 'Sĩ số',
          value: '$_presentToday/$_totalEmployees',
          icon: Icons.people,
          color: Colors.blue,
          subtitle: 'Tỷ lệ: ${_attendanceRate.toStringAsFixed(1)}%',
        ),
        StatsCard(
          title: 'Vắng mặt',
          value: '$_absentToday',
          icon: Icons.person_off,
          color: Colors.red,
          subtitle: _absentToday == 0 ? 'Tuyệt vời!' : 'Cần kiểm tra',
        ),
        StatsCard(
          title: 'Đúng giờ',
          value: '$_onTimeCount',
          icon: Icons.check_circle,
          color: Colors.green,
          subtitle: 'Đi làm đúng giờ',
        ),
        StatsCard(
          title: 'Đi muộn',
          value: '$_lateCount',
          icon: Icons.access_time,
          color: Colors.orange,
          subtitle: _lateCount == 0 ? 'Không ai' : 'Sau 8:30',
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF2196F3),
      ),
    );
  }

  Widget _buildPieChartSection() {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: AttendancePieChart(
        onTimeCount: _onTimeCount,
        lateCount: _lateCount,
        absentCount: _absentToday,
      ),
    );
  }

  Widget _buildBarChartSection() {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: AttendanceBarChart(dailyData: _last7DaysData),
    );
  }

  Widget _buildLateEmployeesList() {
    final lateEmployees = _todayAttendance
        .where((a) => a.status == 'Đi muộn')
        .toList();
    lateEmployees.sort((a, b) => b.checkInTime.compareTo(a.checkInTime));

    return Container(
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
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: lateEmployees.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final attendance = lateEmployees[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange.shade100,
              child: Text(
                attendance.employeeName.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              attendance.employeeName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(attendance.employeeId),
            trailing: Text(
              DateFormat('HH:mm').format(attendance.checkInTime),
              style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          );
        },
      ),
    );
  }
}
