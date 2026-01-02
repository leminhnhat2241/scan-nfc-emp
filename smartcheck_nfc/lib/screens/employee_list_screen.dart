import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Đã chuyển lên đây
import '../models/employee.dart';
import '../services/database_helper.dart';
import 'write_nfc_screen.dart';

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Employee> _employees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    final employees = await _dbHelper.getAllEmployees(); // Lấy tất cả (kể cả đã khóa)
    setState(() {
      _employees = employees;
      _isLoading = false;
    });
  }

  Future<void> _toggleStatus(Employee employee) async {
    final newStatus = !employee.isActive;
    final action = newStatus ? 'Mở khóa' : 'Khóa';
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xác nhận $action'),
        content: Text('Bạn có chắc muốn $action tài khoản ${employee.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: Text(action, style: TextStyle(color: newStatus ? Colors.green : Colors.red))
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dbHelper.toggleEmployeeStatus(employee.employeeId, newStatus);
      _loadEmployees();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã $action tài khoản thành công')));
    }
  }

  Future<void> _editEmployee(Employee employee) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WriteNfcScreen(employeeToEdit: employee),
      ),
    );

    if (result == true) {
      _loadEmployees();
    }
  }
  
  Future<void> _deleteEmployee(String id) async {
     final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa vĩnh viễn?'),
        content: const Text('Hành động này không thể hoàn tác. Dữ liệu điểm danh của nhân viên này cũng sẽ mất.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('XÓA', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await _dbHelper.deleteEmployee(id);
      _loadEmployees();
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
              ? const Center(child: Text('Chưa có nhân viên nào'))
              : ListView.builder(
                  itemCount: _employees.length,
                  itemBuilder: (context, index) {
                    final emp = _employees[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      color: emp.isActive ? Colors.white : Colors.grey.shade200,
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: emp.isActive ? Colors.blue : Colors.grey,
                          child: Text(emp.name[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                        ),
                        title: Text(
                          emp.name, 
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: emp.isActive ? null : TextDecoration.lineThrough,
                            color: emp.isActive ? Colors.black : Colors.grey
                          )
                        ),
                        subtitle: Text('${emp.employeeId} - ${emp.department ?? "N/A"}'),
                        trailing: emp.isActive 
                          ? const Icon(Icons.check_circle, color: Colors.green, size: 16)
                          : const Icon(Icons.lock, color: Colors.red, size: 16),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _infoRow(Icons.email, 'Email: ${emp.email ?? "Chưa cập nhật"}'),
                                const SizedBox(height: 8),
                                _infoRow(Icons.monetization_on, 'Lương/giờ: ${emp.salaryRate != null ? NumberFormat("#,###").format(emp.salaryRate) + " đ" : "Chưa cập nhật"}'),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      icon: Icon(emp.isActive ? Icons.lock : Icons.lock_open, 
                                        color: emp.isActive ? Colors.orange : Colors.green),
                                      label: Text(emp.isActive ? 'KHÓA' : 'MỞ KHÓA'),
                                      onPressed: () => _toggleStatus(emp),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      label: const Text('SỬA'),
                                      onPressed: () => _editEmployee(emp),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      label: const Text('XÓA'),
                                      onPressed: () => _deleteEmployee(emp.employeeId),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const WriteNfcScreen()),
          );
          if (result == true) _loadEmployees();
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(children: [Icon(icon, size: 16, color: Colors.grey), const SizedBox(width: 8), Text(text)]);
  }
}
