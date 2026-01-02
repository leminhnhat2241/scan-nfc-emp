import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/attendance.dart';
import '../models/employee.dart';
import '../services/database_helper.dart';

class ManualAttendanceScreen extends StatefulWidget {
  const ManualAttendanceScreen({super.key});

  @override
  State<ManualAttendanceScreen> createState() => _ManualAttendanceScreenState();
}

class _ManualAttendanceScreenState extends State<ManualAttendanceScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  
  List<Attendance> _attendanceList = [];
  List<Employee> _employees = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    // Load danh sách nhân viên (để chọn khi thêm mới)
    final employees = await _dbHelper.getAllEmployees();
    
    // Load dữ liệu điểm danh theo ngày chọn
    final attendance = await _dbHelper.getAttendanceByDate(_selectedDate);

    setState(() {
      _employees = employees;
      _attendanceList = attendance;
      _isLoading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  // Hiển thị Dialog Thêm/Sửa
  Future<void> _showEditDialog({Attendance? attendance}) async {
    final isEditing = attendance != null;
    
    // Biến tạm để lưu dữ liệu form
    String? selectedEmpId = isEditing ? attendance.employeeId : null;
    String? selectedEmpName = isEditing ? attendance.employeeName : null;
    
    // Mặc định giờ hiện tại hoặc giờ cũ
    TimeOfDay checkInTime = isEditing 
        ? TimeOfDay.fromDateTime(attendance.checkInTime)
        : const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay? checkOutTime = isEditing && attendance.checkOutTime != null
        ? TimeOfDay.fromDateTime(attendance.checkOutTime!)
        : null;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(isEditing ? 'Sửa điểm danh' : 'Chấm công thủ công'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Chọn nhân viên (Chỉ cho phép chọn khi Thêm mới)
                  if (!isEditing)
                    DropdownButtonFormField<String>(
                      value: selectedEmpId,
                      hint: const Text('Chọn nhân viên'),
                      items: _employees.map((e) => DropdownMenuItem(
                        value: e.employeeId,
                        child: Text(e.name),
                      )).toList(),
                      onChanged: (val) {
                        setStateDialog(() {
                          selectedEmpId = val;
                          selectedEmpName = _employees.firstWhere((e) => e.employeeId == val).name;
                        });
                      },
                    )
                  else
                    TextFormField(
                      initialValue: selectedEmpName,
                      enabled: false,
                      decoration: const InputDecoration(labelText: 'Nhân viên'),
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // Chọn Giờ vào
                  ListTile(
                    title: const Text('Giờ vào (Check-in)'),
                    trailing: Text(checkInTime.format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () async {
                      final t = await showTimePicker(context: context, initialTime: checkInTime);
                      if (t != null) setStateDialog(() => checkInTime = t);
                    },
                    tileColor: Colors.green.shade50,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  
                  const SizedBox(height: 8),

                  // Chọn Giờ ra
                  ListTile(
                    title: const Text('Giờ ra (Check-out)'),
                    trailing: Text(checkOutTime?.format(context) ?? '--:--', style: const TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context, 
                        initialTime: checkOutTime ?? const TimeOfDay(hour: 17, minute: 0)
                      );
                      if (t != null) setStateDialog(() => checkOutTime = t);
                    },
                    tileColor: Colors.orange.shade50,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  
                  if (checkOutTime != null)
                    TextButton(
                      onPressed: () => setStateDialog(() => checkOutTime = null),
                      child: const Text('Xóa giờ ra', style: TextStyle(color: Colors.red)),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
              ElevatedButton(
                onPressed: () async {
                  if (selectedEmpId == null) return;

                  // Kết hợp Ngày chọn + Giờ chọn
                  final inDateTime = DateTime(
                    _selectedDate.year, _selectedDate.month, _selectedDate.day,
                    checkInTime.hour, checkInTime.minute
                  );
                  
                  DateTime? outDateTime;
                  double? workHours;
                  
                  if (checkOutTime != null) {
                    outDateTime = DateTime(
                      _selectedDate.year, _selectedDate.month, _selectedDate.day,
                      checkOutTime!.hour, checkOutTime!.minute
                    );
                    
                    // Tính giờ làm
                    if (outDateTime.isAfter(inDateTime)) {
                      final duration = outDateTime.difference(inDateTime);
                      workHours = double.parse((duration.inMinutes / 60.0).toStringAsFixed(2));
                    }
                  }

                  // Logic trạng thái
                  String status = 'Đi làm';
                  if (checkInTime.hour > 8 || (checkInTime.hour == 8 && checkInTime.minute > 15)) {
                    status = 'Đi muộn';
                  }

                  final newAttendance = Attendance(
                    id: isEditing ? attendance!.id : null,
                    employeeId: selectedEmpId!,
                    employeeName: selectedEmpName!,
                    checkInTime: inDateTime,
                    checkOutTime: outDateTime,
                    status: status,
                    workHours: workHours,
                    imagePath: isEditing ? attendance!.imagePath : null, // Giữ ảnh cũ nếu có
                  );

                  if (isEditing) {
                    await _dbHelper.updateAttendance(newAttendance);
                  } else {
                    await _dbHelper.insertAttendance(newAttendance);
                  }

                  Navigator.pop(context);
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isEditing ? 'Đã cập nhật!' : 'Đã thêm mới!'))
                  );
                },
                child: const Text('Lưu'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteItem(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa dữ liệu?'),
        content: const Text('Bạn có chắc muốn xóa bản ghi điểm danh này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await _dbHelper.deleteAttendance(id);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý chấm công'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _pickDate,
          ),
        ],
      ),
      body: Column(
        children: [
          // Header ngày tháng
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[200],
            width: double.infinity,
            child: Text(
              'Ngày: ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _attendanceList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Không có dữ liệu ngày này'),
                            const SizedBox(height: 10),
                            ElevatedButton.icon(
                              onPressed: () => _showEditDialog(),
                              icon: const Icon(Icons.add),
                              label: const Text('Thêm thủ công'),
                            )
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _attendanceList.length,
                        itemBuilder: (context, index) {
                          final item = _attendanceList[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: item.status == 'Đi muộn' ? Colors.orange : Colors.blue,
                                child: Text(item.employeeName[0]),
                              ),
                              title: Text(item.employeeName),
                              subtitle: Text(
                                '${item.getFormattedTime()} - ${item.getFormattedOutTime()} (${item.workHours ?? 0}h)',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _showEditDialog(attendance: item),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteItem(item.id!),
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
      floatingActionButton: _attendanceList.isNotEmpty 
        ? FloatingActionButton(
            onPressed: () => _showEditDialog(),
            backgroundColor: Colors.blue,
            child: const Icon(Icons.add),
          )
        : null,
    );
  }
}
