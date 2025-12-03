import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../services/database_helper.dart';
import '../services/nfc_service.dart';
import 'dart:async';

class WriteNfcScreen extends StatefulWidget {
  const WriteNfcScreen({super.key});

  @override
  State<WriteNfcScreen> createState() => _WriteNfcScreenState();
}

class _WriteNfcScreenState extends State<WriteNfcScreen> {
  final _formKey = GlobalKey<FormState>();
  final _employeeIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _departmentController = TextEditingController();
  final _positionController = TextEditingController();

  final NfcService _nfcService = NfcService();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  bool _isWriting = false;
  bool _isNfcAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkNfcAvailability();
  }

  @override
  void dispose() {
    _employeeIdController.dispose();
    _nameController.dispose();
    _departmentController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  Future<void> _checkNfcAvailability() async {
    final available = await _nfcService.isNfcAvailable();
    setState(() {
      _isNfcAvailable = available;
    });
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
        employeeId: _employeeIdController.text.trim(),
        name: _nameController.text.trim(),
        department: _departmentController.text.trim().isEmpty
            ? null
            : _departmentController.text.trim(),
        position: _positionController.text.trim().isEmpty
            ? null
            : _positionController.text.trim(),
      );

      // Lưu vào database trước
      await _dbHelper.insertEmployee(employee);

      // Hiển thị dialog hướng dẫn và chờ người dùng sẵn sàng
      final shouldContinue = await _showReadyDialog();
      if (!shouldContinue) {
        setState(() {
          _isWriting = false;
        });
        return;
      }

      // Hiển thị trạng thái đang chờ thẻ
      _showMessage(
        '🔍 Đang chờ thẻ NFC... Hãy đưa thẻ gần camera sau và giữ yên!',
        isInfo: true,
      );

      // Ghi vào thẻ NFC với timeout
      final result = await _nfcService
          .writeNfcTag(employee)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              return NfcWriteResult(
                false,
                'Hết thời gian chờ 30 giây. Chưa phát hiện thẻ NFC. Vui lòng:\n• Kiểm tra NFC đã bật\n• Đặt thẻ sát vào lưng điện thoại\n• Thử lại',
              );
            },
          );

      if (result.success) {
        _showSuccessDialog(employee);
        _clearForm();
      } else {
        _showMessage(
          result.message.isNotEmpty
              ? result.message
              : 'Ghi thẻ thất bại, vui lòng thử lại',
          isError: true,
        );
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
    _employeeIdController.clear();
    _nameController.clear();
    _departmentController.clear();
    _positionController.clear();
  }

  Future<bool> _showReadyDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.nfc, color: Colors.blue, size: 60),
        title: const Text('Chuẩn bị ghi thẻ NFC'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hãy chuẩn bị thẻ NFC và làm theo hướng dẫn:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInstructionRow('1', 'Cầm thẻ NFC sẵn sàng'),
            _buildInstructionRow('2', 'Nhấn nút "BẮT ĐẦU GHI"'),
            _buildInstructionRow(
              '3',
              'Đặt thẻ sát vào lưng điện thoại (gần camera sau)',
            ),
            _buildInstructionRow(
              '4',
              'Giữ yên 3-5 giây cho đến khi thành công',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lưu ý: Không di chuyển thẻ khi đang ghi!',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('HỦY'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.play_arrow),
            label: const Text('BẮT ĐẦU GHI'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _buildInstructionRow(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
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
                      const Text('3. Chạm thẻ NFC gần camera sau điện thoại'),
                      const Text(
                        '4. Giữ thẻ ổn định cho đến khi có thông báo thành công (khoảng 3-5 giây)',
                      ),
                      const Text(
                        '5. Lưu ý: Vị trí anten NFC thường ở gần camera sau',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Form nhập liệu
              TextFormField(
                controller: _employeeIdController,
                decoration: const InputDecoration(
                  labelText: 'Mã nhân viên *',
                  hintText: 'VD: EMP001',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập mã nhân viên';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

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

              TextFormField(
                controller: _departmentController,
                decoration: const InputDecoration(
                  labelText: 'Phòng ban',
                  hintText: 'VD: Kỹ thuật',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _positionController,
                decoration: const InputDecoration(
                  labelText: 'Chức vụ',
                  hintText: 'VD: Lập trình viên',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.work),
                ),
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
