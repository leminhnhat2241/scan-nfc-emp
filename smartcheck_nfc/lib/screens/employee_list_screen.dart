import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../models/attendance.dart';
import '../services/database_helper.dart';

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<Employee> _employees = [];
  Map<String, bool> _attendanceStatus = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    // Load danh sách nhân viên
    final employees = await _dbHelper.getAllEmployees();

    // Kiểm tra trạng thái điểm danh hôm nay
    final attendanceStatus = <String, bool>{};
    for (var employee in employees) {
      final hasCheckedIn = await _dbHelper.hasCheckedInToday(
        employee.employeeId,
      );
      attendanceStatus[employee.employeeId] = hasCheckedIn;
    }

    setState(() {
      _employees = employees;
      _attendanceStatus = attendanceStatus;
      _isLoading = false;
    });
  }

  Future<void> _showEmployeeDetails(Employee employee) async {
    // Lấy lịch sử điểm danh 7 ngày gần nhất
    final List<Attendance> recentAttendance = [];
    for (int i = 0; i < 7; i++) {
      final date = DateTime.now().subtract(Duration(days: i));
      final attendance = await _dbHelper.getAttendanceByEmployeeAndDate(
        employee.employeeId,
        date,
      );
      if (attendance != null) {
        recentAttendance.add(attendance);
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(employee.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Mã NV:', employee.employeeId),
              _buildInfoRow('Tên:', employee.name),
              if (employee.department != null)
                _buildInfoRow('Phòng ban:', employee.department!),
              if (employee.position != null)
                _buildInfoRow('Chức vụ:', employee.position!),

              const Divider(height: 32),

              const Text(
                'Lịch sử điểm danh (7 ngày gần nhất):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              if (recentAttendance.isEmpty)
                const Text(
                  'Chưa có lịch sử điểm danh',
                  style: TextStyle(color: Colors.grey),
                )
              else
                ...recentAttendance.map(
                  (att) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(att.getFormattedDate()),
                        Text(
                          '${att.getFormattedTime()} - ${att.status}',
                          style: TextStyle(
                            color: att.status == 'Đi làm'
                                ? Colors.green
                                : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _deleteEmployee(Employee employee) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa nhân viên ${employee.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dbHelper.deleteEmployee(employee.employeeId);
      _loadData();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã xóa nhân viên')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách nhân viên'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _employees.isEmpty
          ? const Center(
              child: Text(
                'Chưa có nhân viên nào',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : Column(
              children: [
                // Thống kê
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue.shade50,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard(
                        'Tổng số',
                        _employees.length.toString(),
                        Colors.blue,
                      ),
                      _buildStatCard(
                        'Đã điểm danh',
                        _attendanceStatus.values
                            .where((v) => v)
                            .length
                            .toString(),
                        Colors.green,
                      ),
                      _buildStatCard(
                        'Chưa điểm danh',
                        _attendanceStatus.values
                            .where((v) => !v)
                            .length
                            .toString(),
                        Colors.orange,
                      ),
                    ],
                  ),
                ),

                // Danh sách nhân viên
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.builder(
                      itemCount: _employees.length,
                      itemBuilder: (context, index) {
                        final employee = _employees[index];
                        final hasCheckedIn =
                            _attendanceStatus[employee.employeeId] ?? false;

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ListTile(
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  backgroundColor: hasCheckedIn
                                      ? Colors.green
                                      : Colors.grey,
                                  child: Text(
                                    employee.name[0],
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                if (hasCheckedIn)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check_circle,
                                        size: 16,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(
                              employee.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Mã NV: ${employee.employeeId}'),
                                if (employee.department != null)
                                  Text(employee.department!),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: hasCheckedIn
                                        ? Colors.green.shade50
                                        : Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    hasCheckedIn
                                        ? 'Đã điểm danh'
                                        : 'Chưa điểm danh',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: hasCheckedIn
                                          ? Colors.green.shade700
                                          : Colors.orange.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                PopupMenuButton(
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'details',
                                      child: Row(
                                        children: [
                                          Icon(Icons.info),
                                          SizedBox(width: 8),
                                          Text('Chi tiết'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text(
                                            'Xóa',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onSelected: (value) {
                                    if (value == 'details') {
                                      _showEmployeeDetails(employee);
                                    } else if (value == 'delete') {
                                      _deleteEmployee(employee);
                                    }
                                  },
                                ),
                              ],
                            ),
                            onTap: () => _showEmployeeDetails(employee),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadData,
        tooltip: 'Làm mới',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
        ),
      ],
    );
  }
}
