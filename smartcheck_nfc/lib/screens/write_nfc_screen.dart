import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../services/database_helper.dart';
import '../services/nfc_service.dart';
import '../services/biometric_service.dart'; // Mới
import 'dart:async';

class WriteNfcScreen extends StatefulWidget {
  final Employee? employeeToEdit;
  const WriteNfcScreen({super.key, this.employeeToEdit});

  @override
  State<WriteNfcScreen> createState() => _WriteNfcScreenState();
}

class _WriteNfcScreenState extends State<WriteNfcScreen> {
  final _formKey = GlobalKey<FormState>();
  final _employeeIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _departmentController = TextEditingController();
  final _positionController = TextEditingController();
  final _emailController = TextEditingController();
  final _salaryController = TextEditingController();

  final NfcService _nfcService = NfcService();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final BiometricService _biometricService = BiometricService.instance; // Mới

  bool _isWriting = false;
  bool _isNfcAvailable = false;
  bool _isEditMode = false;
  bool _enableBiometric = true; // Mặc định cho phép vân tay

  @override
  void initState() {
    super.initState();
    _checkNfcAvailability();
    if (widget.employeeToEdit != null) {
      _isEditMode = true;
      _loadEmployeeData(widget.employeeToEdit!);
    }
  }

  void _loadEmployeeData(Employee emp) {
    _employeeIdController.text = emp.employeeId;
    _nameController.text = emp.name;
    _departmentController.text = emp.department ?? '';
    _positionController.text = emp.position ?? '';
    _emailController.text = emp.email ?? '';
    _salaryController.text = emp.salaryRate?.toString() ?? '';
    _enableBiometric = emp.isActive; // Tạm dùng field isActive để đại diện logic này
  }

  @override
  void dispose() {
    _employeeIdController.dispose();
    _nameController.dispose();
    _departmentController.dispose();
    _positionController.dispose();
    _emailController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  Future<void> _checkNfcAvailability() async {
    final available = await _nfcService.isNfcAvailable();
    setState(() {
      _isNfcAvailable = available;
    });
  }

  Future<void> _saveAndWrite() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 1. Nếu bật tính năng vân tay, yêu cầu xác thực Admin/Người dùng để confirm
    if (_enableBiometric) {
      final bioAuth = await _biometricService.authenticate(
        reason: 'Xác thực vân tay để cấp quyền cho nhân viên này',
      );
      
      if (!bioAuth) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Xác thực vân tay thất bại! Không thể lưu.'), backgroundColor: Colors.red),
        );
        return;
      }
    }
    
    _showActionChoice();
  }

  void _showActionChoice() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.save, color: Colors.blue),
            title: const Text('Chỉ Lưu vào Cơ sở dữ liệu'),
            subtitle: const Text('Dành cho nhân viên chỉ dùng Vân tay, không dùng Thẻ'),
            onTap: () {
              Navigator.pop(context);
              _saveToDatabase(onlySave: true);
            },
          ),
          if (_isNfcAvailable)
            ListTile(
              leading: const Icon(Icons.nfc, color: Colors.orange),
              title: const Text('Lưu và Ghi thẻ NFC'),
              subtitle: const Text('Cập nhật DB và ghi dữ liệu vào thẻ từ'),
              onTap: () {
                Navigator.pop(context);
                _saveToDatabase(onlySave: false);
              },
            ),
        ],
      ),
    );
  }

  Future<void> _saveToDatabase({required bool onlySave}) async {
    setState(() {
      _isWriting = true;
    });

    try {
      final salary = double.tryParse(_salaryController.text.trim());
      
      final employee = Employee(
        employeeId: _employeeIdController.text.trim(),
        name: _nameController.text.trim(),
        department: _departmentController.text.trim().isEmpty ? null : _departmentController.text.trim(),
        position: _positionController.text.trim().isEmpty ? null : _positionController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        salaryRate: salary,
        isActive: true,
      );

      if (_isEditMode) {
        await _dbHelper.updateEmployee(employee);
        _showMessage('Đã cập nhật thông tin nhân viên', isInfo: true);
      } else {
        await _dbHelper.insertEmployee(employee);
        _showMessage('Đã thêm nhân viên mới', isInfo: true);
      }

      if (!onlySave) {
        await _startNfcWrite(employee);
      } else {
        setState(() => _isWriting = false);
        if (_isEditMode) Navigator.pop(context, true);
        else _clearForm();
      }
    } catch (e) {
      _showMessage('Lỗi lưu dữ liệu: $e', isError: true);
      setState(() => _isWriting = false);
    }
  }

  Future<void> _startNfcWrite(Employee employee) async {
    final shouldContinue = await _showReadyDialog();
    if (!shouldContinue) {
      setState(() => _isWriting = false);
      return;
    }

    _showMessage('🔍 Đang chờ thẻ NFC...', isInfo: true);

    try {
      final result = await _nfcService.writeNfcTag(employee).timeout(
        const Duration(seconds: 30),
        onTimeout: () => NfcWriteResult(false, 'Hết thời gian chờ 30s'),
      );

      if (result.success) {
        _showSuccessDialog(employee);
        if (!_isEditMode) _clearForm();
      } else {
        _showMessage(result.message, isError: true);
      }
    } catch (e) {
      _showMessage('Lỗi ghi thẻ: $e', isError: true);
    } finally {
      setState(() => _isWriting = false);
    }
  }

  void _clearForm() {
    _employeeIdController.clear();
    _nameController.clear();
    _departmentController.clear();
    _positionController.clear();
    _emailController.clear();
    _salaryController.clear();
    setState(() {
      _isEditMode = false;
      _enableBiometric = true;
    });
  }

  Future<bool> _showReadyDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Chuẩn bị ghi thẻ'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.nfc, size: 50, color: Colors.blue),
            SizedBox(height: 16),
            Text('Đặt thẻ sát vào mặt sau điện thoại và giữ yên.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('HỦY')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('BẮT ĐẦU')),
        ],
      ),
    ) ?? false;
  }
  
  void _showSuccessDialog(Employee employee) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('✅ Thành công'),
      content: Text('Đã ghi thẻ NFC cho ${employee.name}.\n\nNhân viên này cũng đã được kích hoạt chấm công vân tay.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng'))],
    ));
  }
  
  void _showMessage(String msg, {bool isError = false, bool isInfo = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), 
      backgroundColor: isError ? Colors.red : (isInfo ? Colors.blue : Colors.green)
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Sửa Nhân Viên' : 'Thêm Nhân Viên Mới'),
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
              TextFormField(
                controller: _employeeIdController,
                enabled: !_isEditMode,
                decoration: const InputDecoration(labelText: 'Mã nhân viên *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.badge)),
                validator: (v) => v!.isEmpty ? 'Nhập mã NV' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Tên nhân viên *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                validator: (v) => v!.isEmpty ? 'Nhập tên NV' : null,
              ),
              const SizedBox(height: 16),
              // Hàng đôi: Phòng ban & Chức vụ
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _departmentController,
                      decoration: const InputDecoration(labelText: 'Phòng ban', border: OutlineInputBorder(), prefixIcon: Icon(Icons.business)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _positionController,
                      decoration: const InputDecoration(labelText: 'Chức vụ', border: OutlineInputBorder(), prefixIcon: Icon(Icons.work)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _salaryController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Lương/giờ (VNĐ)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money)),
              ),
              const SizedBox(height: 20),
              
              // Tùy chọn Sinh trắc học
              SwitchListTile(
                title: const Text('Kích hoạt Vân tay/Khuôn mặt'),
                subtitle: const Text('Cho phép nhân viên này dùng vân tay để chấm công'),
                value: _enableBiometric,
                activeColor: Colors.purple,
                secondary: const Icon(Icons.fingerprint, color: Colors.purple),
                onChanged: (val) {
                  setState(() => _enableBiometric = val);
                },
              ),

              const SizedBox(height: 30),
              
              ElevatedButton.icon(
                onPressed: _isWriting ? null : _saveAndWrite,
                icon: const Icon(Icons.save),
                label: Text(
                  _isWriting ? 'ĐANG XỬ LÝ...' : (_isEditMode ? 'CẬP NHẬT' : 'LƯU & THIẾT LẬP'),
                  style: const TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 60), 
                  backgroundColor: Colors.blue, 
                  foregroundColor: Colors.white,
                  elevation: 5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
