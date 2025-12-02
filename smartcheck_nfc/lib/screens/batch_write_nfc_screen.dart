import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import '../models/employee.dart';
import '../services/database_helper.dart';
import '../services/nfc_service.dart';

class BatchWriteNfcScreen extends StatefulWidget {
  const BatchWriteNfcScreen({super.key});

  @override
  State<BatchWriteNfcScreen> createState() => _BatchWriteNfcScreenState();
}

class _BatchWriteNfcScreenState extends State<BatchWriteNfcScreen> {
  final NfcService _nfcService = NfcService();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  bool _isNfcAvailable = false;
  bool _isWriting = false;
  int _currentIndex = 0;

  List<Map<String, dynamic>> _employeeList = [];

  // Map phòng ban với prefix mã
  final Map<String, String> _departmentPrefixes = {
    'Kỹ thuật': 'KT',
    'Kinh doanh': 'KD',
    'Hành chính': 'HC',
    'Nhân sự': 'NS',
    'Kế toán': 'KT',
    'Marketing': 'MK',
    'IT': 'IT',
    'Sản xuất': 'SX',
  };

  List<String> get _departments => _departmentPrefixes.keys.toList();

  final List<String> _positions = [
    'Giám đốc',
    'Phó giám đốc',
    'Trưởng phòng',
    'Phó phòng',
    'Nhân viên',
    'Thực tập sinh',
    'Chuyên viên',
    'Kỹ sư',
  ];

  @override
  void initState() {
    super.initState();
    _checkNfcAvailability();
  }

  Future<void> _checkNfcAvailability() async {
    final available = await _nfcService.isNfcAvailable();
    setState(() {
      _isNfcAvailable = available;
    });
  }

  Future<String> _generateEmployeeId(String department) async {
    final prefix = _departmentPrefixes[department] ?? 'NV';
    final employees = await _dbHelper.getAllEmployees();

    // Lọc nhân viên theo phòng ban
    final departmentEmployees = employees
        .where((e) => e.department == department)
        .toList();

    // Thêm các nhân viên đã tạo trong danh sách hiện tại
    final createdInList = _employeeList
        .where((e) => e['department'] == department && e['employeeId'] != null)
        .toList();

    int maxNumber = 0;

    // Tìm số lớn nhất từ database
    for (var emp in departmentEmployees) {
      final numberPart = emp.employeeId.replaceAll(RegExp(r'[^0-9]'), '');
      if (numberPart.isNotEmpty) {
        final number = int.tryParse(numberPart) ?? 0;
        if (number > maxNumber) {
          maxNumber = number;
        }
      }
    }

    // Tìm số lớn nhất từ danh sách đang tạo
    for (var emp in createdInList) {
      final empId = emp['employeeId'] as String;
      final numberPart = empId.replaceAll(RegExp(r'[^0-9]'), '');
      if (numberPart.isNotEmpty) {
        final number = int.tryParse(numberPart) ?? 0;
        if (number > maxNumber) {
          maxNumber = number;
        }
      }
    }

    return '$prefix${(maxNumber + 1).toString().padLeft(3, '0')}';
  }

  Future<void> _importFromFile() async {
    try {
      // Chọn file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
      );

      if (result == null || result.files.single.path == null) {
        return;
      }

      final filePath = result.files.single.path!;
      final extension = result.files.single.extension?.toLowerCase();

      List<Map<String, dynamic>> importedData = [];

      if (extension == 'csv') {
        importedData = await _parseCSV(filePath);
      } else if (extension == 'xlsx' || extension == 'xls') {
        importedData = await _parseExcel(filePath);
      }

      if (importedData.isEmpty) {
        _showMessage('File không có dữ liệu hợp lệ', isError: true);
        return;
      }

      // Tạo mã nhân viên cho từng người
      for (var data in importedData) {
        final employeeId = await _generateEmployeeId(data['department']);
        data['employeeId'] = employeeId;
        data['written'] = false;
      }

      setState(() {
        _employeeList.addAll(importedData);
      });

      _showMessage(
        'Đã import ${importedData.length} nhân viên',
        isError: false,
      );
    } catch (e) {
      _showMessage('Lỗi khi đọc file: $e', isError: true);
    }
  }

  Future<List<Map<String, dynamic>>> _parseCSV(String filePath) async {
    try {
      final input = File(filePath).readAsStringSync();
      final fields = const CsvToListConverter().convert(input);

      if (fields.length < 2) {
        return [];
      }

      // Bỏ qua dòng header (dòng đầu tiên)
      final dataRows = fields.skip(1);
      List<Map<String, dynamic>> result = [];

      for (var row in dataRows) {
        if (row.length >= 2) {
          result.add({
            'name': row[0].toString().trim(),
            'department': row.length > 1 ? row[1].toString().trim() : null,
            'position': row.length > 2 ? row[2].toString().trim() : null,
          });
        }
      }

      return result;
    } catch (e) {
      throw Exception('Lỗi đọc CSV: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _parseExcel(String filePath) async {
    try {
      final bytes = File(filePath).readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);

      List<Map<String, dynamic>> result = [];

      for (var table in excel.tables.keys) {
        final sheet = excel.tables[table];
        if (sheet == null || sheet.rows.length < 2) continue;

        // Bỏ qua dòng header
        for (var i = 1; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];
          if (row.isNotEmpty && row[0]?.value != null) {
            result.add({
              'name': row[0]?.value.toString().trim() ?? '',
              'department': row.length > 1 && row[1]?.value != null
                  ? row[1]!.value.toString().trim()
                  : null,
              'position': row.length > 2 && row[2]?.value != null
                  ? row[2]!.value.toString().trim()
                  : null,
            });
          }
        }
      }

      return result;
    } catch (e) {
      throw Exception('Lỗi đọc Excel: $e');
    }
  }

  void _showAddEmployeeDialog() {
    final nameController = TextEditingController();
    String? selectedDepartment;
    String? selectedPosition;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Thêm nhân viên'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên nhân viên *',
                    hintText: 'VD: Nguyễn Văn A',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedDepartment,
                  decoration: const InputDecoration(
                    labelText: 'Phòng ban *',
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('Chọn phòng ban'),
                  items: _departments.map((dept) {
                    return DropdownMenuItem(value: dept, child: Text(dept));
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedDepartment = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedPosition,
                  decoration: const InputDecoration(
                    labelText: 'Chức vụ',
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('Chọn chức vụ'),
                  items: _positions.map((pos) {
                    return DropdownMenuItem(value: pos, child: Text(pos));
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedPosition = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vui lòng nhập tên nhân viên'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                if (selectedDepartment == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vui lòng chọn phòng ban'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Tạo mã nhân viên tự động
                final employeeId = await _generateEmployeeId(
                  selectedDepartment!,
                );

                setState(() {
                  _employeeList.add({
                    'employeeId': employeeId,
                    'name': nameController.text.trim(),
                    'department': selectedDepartment,
                    'position': selectedPosition,
                    'written': false,
                  });
                });

                Navigator.pop(context);
              },
              child: const Text('Thêm'),
            ),
          ],
        ),
      ),
    );
  }

  void _removeEmployee(int index) {
    setState(() {
      _employeeList.removeAt(index);
    });
  }

  Future<void> _startBatchWrite() async {
    if (_employeeList.isEmpty) {
      _showMessage('Vui lòng thêm ít nhất 1 nhân viên', isError: true);
      return;
    }

    if (!_isNfcAvailable) {
      _showMessage('Thiết bị không hỗ trợ NFC', isError: true);
      return;
    }

    setState(() {
      _currentIndex = 0;
      _isWriting = true;
    });

    await _writeNextEmployee();
  }

  Future<void> _writeNextEmployee() async {
    if (_currentIndex >= _employeeList.length) {
      setState(() {
        _isWriting = false;
      });
      _showCompletionDialog();
      return;
    }

    final empData = _employeeList[_currentIndex];

    // Bỏ qua nếu đã ghi
    if (empData['written'] == true) {
      setState(() {
        _currentIndex++;
      });
      await _writeNextEmployee();
      return;
    }

    final employee = Employee(
      employeeId: empData['employeeId'],
      name: empData['name'],
      department: empData['department'],
      position: empData['position'],
    );

    // Hiển thị dialog hướng dẫn
    _showWriteDialog(employee);
  }

  void _showWriteDialog(Employee employee) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Ghi thẻ ${_currentIndex + 1}/${_employeeList.length}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mã NV: ${employee.employeeId}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Tên: ${employee.name}'),
            if (employee.department != null)
              Text('Phòng ban: ${employee.department}'),
            if (employee.position != null)
              Text('Chức vụ: ${employee.position}'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.nfc, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Vui lòng đưa thẻ NFC đến điện thoại...'),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isWriting = false;
              });
            },
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performWrite(employee);
            },
            child: const Text('Bắt đầu ghi'),
          ),
        ],
      ),
    );
  }

  Future<void> _performWrite(Employee employee) async {
    try {
      // Kiểm tra nhân viên đã tồn tại trong DB chưa (do có thể đã được thêm từ lần thử trước)
      final existingEmployee = await _dbHelper.getEmployeeById(
        employee.employeeId,
      );

      // Ghi vào thẻ NFC TRƯỚC
      final success = await _nfcService.writeNfcTag(employee);

      if (success) {
        // CHỈ lưu vào database KHI ghi NFC thành công VÀ chưa tồn tại
        if (existingEmployee == null) {
          await _dbHelper.insertEmployee(employee);
        }

        setState(() {
          _employeeList[_currentIndex]['written'] = true;
          _currentIndex++;
        });
        _showMessage('Ghi thẻ thành công: ${employee.name}', isError: false);

        // Delay 1 giây trước khi ghi thẻ tiếp theo
        await Future.delayed(const Duration(seconds: 1));
        await _writeNextEmployee();
      } else {
        _showRetryDialog(employee);
      }
    } catch (e) {
      _showMessage('Lỗi: $e', isError: true);
      _showRetryDialog(employee);
    }
  }

  void _showRetryDialog(Employee employee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.error, color: Colors.red, size: 60),
        title: const Text('Ghi thẻ thất bại'),
        content: Text('Không thể ghi thẻ cho ${employee.name}'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _currentIndex++;
              });
              _writeNextEmployee();
            },
            child: const Text('Bỏ qua'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _writeNextEmployee();
            },
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  void _showCompletionDialog() {
    final writtenCount = _employeeList
        .where((e) => e['written'] == true)
        .length;
    final totalCount = _employeeList.length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          writtenCount == totalCount ? Icons.check_circle : Icons.warning,
          color: writtenCount == totalCount ? Colors.green : Colors.orange,
          size: 60,
        ),
        title: const Text('Hoàn thành'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Đã ghi thành công: $writtenCount/$totalCount thẻ'),
            if (writtenCount < totalCount)
              Text(
                'Số thẻ thất bại: ${totalCount - writtenCount}',
                style: const TextStyle(color: Colors.red),
              ),
          ],
        ),
        actions: [
          if (writtenCount < totalCount)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _currentIndex = 0;
                });
                _startBatchWrite();
              },
              child: const Text('Ghi lại'),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (writtenCount == totalCount) {
                setState(() {
                  _employeeList.clear();
                });
              }
            },
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final writtenCount = _employeeList
        .where((e) => e['written'] == true)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ghi nhiều thẻ NFC'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Card hướng dẫn
          Card(
            margin: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Hướng dẫn',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('1. Thêm nhân viên thủ công hoặc import từ file'),
                  const Text('2. File CSV/Excel: Tên, Phòng ban, Chức vụ'),
                  const Text('3. Nhấn "BẮT ĐẦU GHI THẺ"'),
                  const Text('4. Ghi lần lượt từng thẻ theo hướng dẫn'),
                  const SizedBox(height: 12),
                  // Nút import file
                  OutlinedButton.icon(
                    onPressed: _isWriting ? null : _importFromFile,
                    icon: const Icon(Icons.upload_file, size: 20),
                    label: const Text('Import từ CSV/Excel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                      side: BorderSide(color: Colors.blue.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Thống kê
          if (_employeeList.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '${_employeeList.length}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('Tổng số'),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        '$writtenCount',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const Text('Đã ghi'),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        '${_employeeList.length - writtenCount}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const Text('Chưa ghi'),
                    ],
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Danh sách nhân viên
          Expanded(
            child: _employeeList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.list_alt,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Chưa có nhân viên nào',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text('Nhấn nút + để thêm nhân viên'),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _employeeList.length,
                    itemBuilder: (context, index) {
                      final emp = _employeeList[index];
                      final isWritten = emp['written'] == true;

                      return Card(
                        color: isWritten ? Colors.green.shade50 : Colors.white,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isWritten
                                ? Colors.green
                                : Colors.blue,
                            child: Icon(
                              isWritten ? Icons.check : Icons.person,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            emp['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Mã: ${emp['employeeId']}'),
                              Text('Phòng: ${emp['department'] ?? '-'}'),
                              if (emp['position'] != null)
                                Text('Chức vụ: ${emp['position']}'),
                            ],
                          ),
                          trailing: _isWriting
                              ? null
                              : IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _removeEmployee(index),
                                ),
                        ),
                      );
                    },
                  ),
          ),

          // Nút hành động
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: _isWriting ? null : _startBatchWrite,
                  icon: _isWriting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.nfc),
                  label: Text(
                    _isWriting
                        ? 'ĐANG GHI (${_currentIndex + 1}/${_employeeList.length})...'
                        : 'BẮT ĐẦU GHI THẺ',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 56),
                  ),
                ),
              ],
            ),
          ),

          if (!_isNfcAvailable)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              color: Colors.red.shade100,
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('NFC không khả dụng')),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: _isWriting
          ? null
          : FloatingActionButton(
              onPressed: _showAddEmployeeDialog,
              backgroundColor: Colors.blue,
              child: const Icon(Icons.add, color: Colors.white),
            ),
    );
  }
}
