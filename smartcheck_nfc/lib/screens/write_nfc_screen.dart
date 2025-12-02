import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../services/database_helper.dart';
import '../services/nfc_service.dart';

class WriteNfcScreen extends StatefulWidget {
  const WriteNfcScreen({super.key});

  @override
  State<WriteNfcScreen> createState() => _WriteNfcScreenState();
}

class _WriteNfcScreenState extends State<WriteNfcScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  final NfcService _nfcService = NfcService();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  bool _isWriting = false;
  bool _isNfcAvailable = false;
  String _nextEmployeeId = '';
  String? _selectedDepartment;
  String? _selectedPosition;

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

  // Danh sách chức vụ
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
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    try {
      await _checkNfcAvailability();
    } catch (e) {
      print('Lỗi khi khởi tạo màn hình: $e');
      if (mounted) {
        setState(() {
          _isNfcAvailable = false;
        });
      }
    }
  }

  Future<void> _checkNfcAvailability() async {
    try {
      final available = await _nfcService.isNfcAvailable();
      if (mounted) {
        setState(() {
          _isNfcAvailable = available;
        });
      }
    } catch (e) {
      print('Lỗi kiểm tra NFC: $e');
      if (mounted) {
        setState(() {
          _isNfcAvailable = false;
        });
      }
    }
  }

  Future<void> _loadNextEmployeeId(String department) async {
    try {
      final prefix = _departmentPrefixes[department] ?? 'NV';
      final employees = await _dbHelper.getAllEmployees();

      // Lọc nhân viên theo phòng ban
      final departmentEmployees = employees
          .where((e) => e.department == department)
          .toList();

      if (departmentEmployees.isEmpty) {
        if (mounted) {
          setState(() {
            _nextEmployeeId = '${prefix}001';
          });
        }
      } else {
        // Tìm số lớn nhất từ các mã nhân viên cùng phòng ban
        int maxNumber = 0;
        for (var emp in departmentEmployees) {
          // Lấy phần số từ mã (bỏ chữ cái prefix)
          final numberPart = emp.employeeId.replaceAll(RegExp(r'[^0-9]'), '');
          if (numberPart.isNotEmpty) {
            final number = int.tryParse(numberPart) ?? 0;
            if (number > maxNumber) {
              maxNumber = number;
            }
          }
        }
        if (mounted) {
          setState(() {
            _nextEmployeeId =
                '$prefix${(maxNumber + 1).toString().padLeft(3, '0')}';
          });
        }
      }
    } catch (e) {
      print('Lỗi load employee ID: $e');
      if (mounted) {
        setState(() {
          _nextEmployeeId = '${_departmentPrefixes[department] ?? 'NV'}001';
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _writeToNfc() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_isNfcAvailable) {
      _showMessage('Thiết bị không hỗ trợ NFC', isError: true);
      return;
    }

    setState(() {
      _isWriting = true;
    });

    try {
      // Tạo object Employee
      final employee = Employee(
        employeeId: _nextEmployeeId,
        name: _nameController.text.trim(),
        department: _selectedDepartment,
        position: _selectedPosition,
      );

      // Kiểm tra nhân viên đã tồn tại chưa
      final existingEmployee = await _dbHelper.getEmployeeById(
        employee.employeeId,
      );

      if (existingEmployee != null) {
        _showMessage(
          'Mã nhân viên ${employee.employeeId} đã tồn tại. Vui lòng chọn phòng ban lại để tạo mã mới.',
          isError: true,
        );
        return;
      }

      // Hiển thị hướng dẫn
      _showMessage('Vui lòng đưa thẻ NFC đến điện thoại...', isInfo: true);

      // Ghi vào thẻ NFC TRƯỚC
      final success = await _nfcService.writeNfcTag(employee);

      if (success) {
        // CHỈ lưu vào database KHI ghi NFC thành công
        await _dbHelper.insertEmployee(employee);

        _showSuccessDialog(employee);
        _clearForm();
      } else {
        _showMessage('Ghi thẻ thất bại, vui lòng thử lại', isError: true);
      }
    } catch (e) {
      _showMessage('Lỗi: $e', isError: true);
    } finally {
      setState(() {
        _isWriting = false;
      });
    }
  }

  void _clearForm() {
    _nameController.clear();
    setState(() {
      _selectedDepartment = null;
      _selectedPosition = null;
      _nextEmployeeId = '';
    });
  }

  void _showSuccessDialog(Employee employee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        title: const Text('Ghi thẻ thành công!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mã NV: ${employee.employeeId}'),
            Text('Tên: ${employee.name}'),
            if (employee.department != null)
              Text('Phòng ban: ${employee.department}'),
            if (employee.position != null)
              Text('Chức vụ: ${employee.position}'),
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
        title: const Text('Ghi thẻ NFC'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hướng dẫn
              Card(
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
                      const Text('1. Điền đầy đủ thông tin nhân viên'),
                      const Text('2. Nhấn nút "GHI VÀO THẺ NFC"'),
                      const Text('3. Đưa thẻ NFC đến điện thoại'),
                      const Text(
                        '4. Giữ thẻ cho đến khi có thông báo thành công',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Hiển thị mã nhân viên tự động
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.badge, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mã nhân viên tự động',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _nextEmployeeId.isEmpty
                                ? 'Chọn phòng ban để tạo mã'
                                : '$_nextEmployeeId',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _nextEmployeeId.isEmpty
                                  ? Colors.grey.shade600
                                  : Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Form nhập liệu
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Tên nhân viên *',
                  hintText: 'VD: Nguyễn Văn A',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập tên nhân viên';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Dropdown phòng ban
              DropdownButtonFormField<String>(
                value: _selectedDepartment,
                decoration: const InputDecoration(
                  labelText: 'Phòng ban *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
                hint: const Text('Chọn phòng ban'),
                items: _departments.map((dept) {
                  return DropdownMenuItem(value: dept, child: Text(dept));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDepartment = value;
                    // Tự động tạo mã nhân viên khi chọn phòng ban
                    if (value != null) {
                      _loadNextEmployeeId(value);
                    }
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng chọn phòng ban';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Dropdown chức vụ
              DropdownButtonFormField<String>(
                value: _selectedPosition,
                decoration: const InputDecoration(
                  labelText: 'Chức vụ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.work),
                ),
                hint: const Text('Chọn chức vụ'),
                items: _positions.map((pos) {
                  return DropdownMenuItem(value: pos, child: Text(pos));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPosition = value;
                  });
                },
              ),

              const SizedBox(height: 32),

              // Nút ghi thẻ
              ElevatedButton.icon(
                onPressed: _isWriting ? null : _writeToNfc,
                icon: _isWriting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.nfc, size: 28),
                label: Text(
                  _isWriting ? 'ĐANG GHI...' : 'GHI VÀO THẺ NFC',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 60),
                ),
              ),

              const SizedBox(height: 16),

              // Nút xóa form
              OutlinedButton.icon(
                onPressed: _isWriting ? null : _clearForm,
                icon: const Icon(Icons.clear),
                label: const Text('XÓA FORM'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),

              if (!_isNfcAvailable) ...[
                const SizedBox(height: 16),
                Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Thiết bị không hỗ trợ NFC hoặc NFC chưa được bật',
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
