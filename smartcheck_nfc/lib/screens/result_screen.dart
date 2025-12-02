import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/attendance.dart';
import '../services/database_helper.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<Attendance> _allAttendance = [];
  List<Attendance> _filteredAttendance = [];
  List<String> _departments = ['Tất cả'];
  String _selectedDepartment = 'Tất cả';
  DateTimeRange? _selectedDateRange;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
    });

    // Load danh sách phòng ban
    final employees = await _dbHelper.getAllEmployees();
    final departments = employees
        .where((e) => e.department != null && e.department!.isNotEmpty)
        .map((e) => e.department!)
        .toSet()
        .toList();
    departments.sort();

    // Mặc định load dữ liệu 30 ngày gần nhất
    final endDate = DateTime.now();
    final startDate = endDate.subtract(const Duration(days: 30));

    setState(() {
      _departments = ['Tất cả', ...departments];
      _selectedDateRange = DateTimeRange(start: startDate, end: endDate);
    });

    await _loadAttendanceData();
  }

  Future<void> _loadAttendanceData() async {
    if (_selectedDateRange == null) return;

    setState(() {
      _isLoading = true;
    });

    final List<Attendance> allData = [];

    // Load dữ liệu cho từng ngày trong khoảng thời gian
    final startDate = DateTime(
      _selectedDateRange!.start.year,
      _selectedDateRange!.start.month,
      _selectedDateRange!.start.day,
    );
    final endDate = DateTime(
      _selectedDateRange!.end.year,
      _selectedDateRange!.end.month,
      _selectedDateRange!.end.day,
    );

    DateTime currentDate = startDate;
    while (currentDate.isBefore(endDate) ||
        currentDate.isAtSameMomentAs(endDate)) {
      final dayAttendance = await _dbHelper.getAttendanceByDate(currentDate);
      allData.addAll(dayAttendance);
      currentDate = DateTime(
        currentDate.year,
        currentDate.month,
        currentDate.day + 1,
      );
    }

    // Sắp xếp theo thời gian giảm dần
    allData.sort((a, b) => b.checkInTime.compareTo(a.checkInTime));

    setState(() {
      _allAttendance = allData;
      _isLoading = false;
    });

    _applyFilters();
  }

  void _applyFilters() async {
    List<Attendance> filtered = List.from(_allAttendance);

    // Lọc theo phòng ban
    if (_selectedDepartment != 'Tất cả') {
      final employees = await _dbHelper.getAllEmployees();
      final departmentEmployeeIds = employees
          .where((e) => e.department == _selectedDepartment)
          .map((e) => e.employeeId)
          .toSet();

      filtered = filtered
          .where((att) => departmentEmployeeIds.contains(att.employeeId))
          .toList();
    }

    setState(() {
      _filteredAttendance = filtered;
    });
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );

    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
      await _loadAttendanceData();
    }
  }

  Map<String, int> _getStatistics() {
    final total = _filteredAttendance.length;
    final onTime = _filteredAttendance
        .where((att) => att.status == 'Đi làm')
        .length;
    final late = total - onTime;

    return {'total': total, 'onTime': onTime, 'late': late};
  }

  String _getDateRangeText() {
    if (_selectedDateRange == null) return 'Chọn khoảng thời gian';
    final start = DateFormat('dd/MM/yyyy').format(_selectedDateRange!.start);
    final end = DateFormat('dd/MM/yyyy').format(_selectedDateRange!.end);
    return '$start - $end';
  }

  @override
  Widget build(BuildContext context) {
    final stats = _getStatistics();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Kết quả điểm danh',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filter Section
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
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
            child: Column(
              children: [
                // Date Range Picker
                InkWell(
                  onTap: _selectDateRange,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          color: Color(0xFF2196F3),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _getDateRangeText(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Department Filter
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.business,
                        color: Color(0xFF2196F3),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedDepartment,
                            isExpanded: true,
                            items: _departments.map((dept) {
                              return DropdownMenuItem(
                                value: dept,
                                child: Text(dept),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedDepartment = value;
                                });
                                _applyFilters();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Statistics Cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Tổng số',
                    stats['total'].toString(),
                    Icons.list_alt,
                    const Color(0xFF2196F3),
                    const Color(0xFFE3F2FD),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Đúng giờ',
                    stats['onTime'].toString(),
                    Icons.check_circle,
                    const Color(0xFF4CAF50),
                    const Color(0xFFE8F5E9),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Đi muộn',
                    stats['late'].toString(),
                    Icons.schedule,
                    const Color(0xFFFF9800),
                    const Color(0xFFFFF3E0),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Results List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredAttendance.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Không có dữ liệu',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadAttendanceData,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredAttendance.length,
                      itemBuilder: (context, index) {
                        final attendance = _filteredAttendance[index];
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
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Info
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
                                          color: Color(0xFF1A1A1A),
                                          letterSpacing: 0.15,
                                          height: 1.4,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.badge_outlined,
                                            size: 15,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            attendance.employeeId,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey[600],
                                              letterSpacing: 0.5,
                                              height: 1.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Date & Status
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      attendance.getFormattedDate(),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF757575),
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time_rounded,
                                          size: 16,
                                          color: isOnTime
                                              ? const Color(0xFF4CAF50)
                                              : const Color(0xFFFF9800),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          attendance.getFormattedTime(),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: isOnTime
                                                ? const Color(0xFF4CAF50)
                                                : const Color(0xFFFF9800),
                                            letterSpacing: 0.5,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
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
                                          letterSpacing: 0.3,
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
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color primaryColor,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: primaryColor, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
