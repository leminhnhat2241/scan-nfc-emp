import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../services/database_helper.dart';
import '../services/nfc_service.dart';
import 'dart:async';

class WriteNfcScreen extends StatefulWidget {
  final Employee? employeeToEdit; // Cho phép sửa nhân viên
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
  final _emailController = TextEditingController(); // Mới
  final _salaryController = TextEditingController(); // Mới

  final NfcService _nfcService = NfcService();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  bool _isWriting = false;
  bool _isNfcAvailable = false;
  bool _isEditMode = false;

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
    
    // Nếu chỉ lưu DB mà không ghi thẻ (khi chỉnh sửa thông tin không cần đổi thẻ)
    // Hoặc người dùng chọn ghi thẻ sau
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
            title: const Text('Lưu vào Cơ sở dữ liệu'),
            subtitle: const Text('Chỉ cập nhật thông tin trong máy, không ghi thẻ'),
            onTap: () {
              Navigator.pop(context);
              _saveToDatabase(onlySave: true);
            },
          ),
          if (_isNfcAvailable)
            ListTile(
              leading: const Icon(Icons.nfc, color: Colors.orange),
              title: const Text('Lưu và Ghi thẻ NFC'),
              subtitle: const Text('Cập nhật DB và ghi đè dữ liệu lên thẻ'),
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
        isActive: true, // Mặc định true
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
        if (_isEditMode) Navigator.pop(context, true); // Trả về true để reload
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
    });
  }

  // ... (Giữ nguyên _showReadyDialog, _buildInstructionRow, _showSuccessDialog, _showMessage cũ)
  // Chỉ copy lại các hàm phụ trợ để đảm bảo code chạy được
  Future<bool> _showReadyDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Chuẩn bị ghi thẻ'),
        content: const Text('Đặt thẻ sát vào mặt sau điện thoại và giữ yên.'),
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
      content: Text('Đã ghi thẻ cho ${employee.name}'),
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
        title: Text(_isEditMode ? 'Sửa Nhân Viên' : 'Thêm Nhân Viên & Ghi Thẻ'),
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
                enabled: !_isEditMode, // Không sửa ID
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
              TextFormField(
                controller: _departmentController,
                decoration: const InputDecoration(labelText: 'Phòng ban', border: OutlineInputBorder(), prefixIcon: Icon(Icons.business)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _positionController,
                decoration: const InputDecoration(labelText: 'Chức vụ', border: OutlineInputBorder(), prefixIcon: Icon(Icons.work)),
              ),
              const SizedBox(height: 16),
              // Trường mới: Email
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email (nhận báo cáo)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
              ),
              const SizedBox(height: 16),
              // Trường mới: Lương
              TextFormField(
                controller: _salaryController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Lương theo giờ (VNĐ)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money)),
              ),
              const SizedBox(height: 32),
              
              ElevatedButton.icon(
                onPressed: _isWriting ? null : _saveAndWrite,
                icon: const Icon(Icons.save),
                label: Text(_isWriting ? 'ĐANG XỬ LÝ...' : (_isEditMode ? 'CẬP NHẬT' : 'LƯU & GHI THẺ')),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.blue, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
