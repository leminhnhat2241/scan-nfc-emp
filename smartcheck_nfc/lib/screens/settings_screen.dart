import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsService.instance;
  
  late TimeOfDay _workStart;
  late int _gracePeriod;
  late TextEditingController _pinController;
  late TextEditingController _salaryController;

  @override
  void initState() {
    super.initState();
    _workStart = _settings.workStartTime;
    _gracePeriod = _settings.gracePeriodMinutes;
    _pinController = TextEditingController(text: _settings.adminPin);
    _salaryController = TextEditingController(text: _settings.defaultSalary.toStringAsFixed(0));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt hệ thống'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Ca làm việc & Lương'),
          ListTile(
            title: const Text('Giờ bắt đầu làm việc'),
            subtitle: Text('${_workStart.format(context)}'),
            trailing: const Icon(Icons.access_time),
            onTap: () async {
              final picked = await showTimePicker(context: context, initialTime: _workStart);
              if (picked != null) {
                await _settings.setWorkStartTime(picked);
                setState(() => _workStart = picked);
              }
            },
          ),
          ListTile(
             title: const Text('Cho phép đi muộn (phút)'),
             subtitle: Text('$_gracePeriod phút'),
             trailing: const Icon(Icons.timer),
             onTap: () async {
               _showNumberEditDialog('Số phút cho phép trễ', _gracePeriod, (val) {
                 _settings.setGracePeriodMinutes(val);
                 setState(() => _gracePeriod = val);
               });
             },
          ),
          ListTile(
             title: const Text('Lương cơ bản mặc định'),
             subtitle: Text('${_salaryController.text} VNĐ/giờ'),
             trailing: const Icon(Icons.attach_money),
             onTap: () {
                _showTextEditDialog('Lương cơ bản', _salaryController, (val) {
                  final salary = double.tryParse(val) ?? 0;
                  _settings.setDefaultSalary(salary);
                  setState(() {});
                });
             },
          ),
          
          const Divider(height: 40),
          _buildSectionHeader('Bảo mật Admin'),
          ListTile(
            title: const Text('Đổi mã PIN Admin'),
            subtitle: const Text('Mặc định: 123456'),
            trailing: const Icon(Icons.lock),
            onTap: () {
               _showTextEditDialog('Nhập mã PIN mới (6 số)', _pinController, (val) {
                 if (val.length >= 4) {
                   _settings.setAdminPin(val);
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã đổi mã PIN')));
                 } else {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mã PIN quá ngắn'), backgroundColor: Colors.red));
                 }
               });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
    );
  }

  void _showNumberEditDialog(String title, int currentVal, Function(int) onSave) {
    final controller = TextEditingController(text: currentVal.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, keyboardType: TextInputType.number, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(onPressed: () {
            onSave(int.tryParse(controller.text) ?? 0);
            Navigator.pop(ctx);
          }, child: const Text('Lưu')),
        ],
      ),
    );
  }
  
  void _showTextEditDialog(String title, TextEditingController controller, Function(String) onSave) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, keyboardType: TextInputType.number, autofocus: true, obscureText: title.contains('PIN')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(onPressed: () {
            onSave(controller.text);
            Navigator.pop(ctx);
          }, child: const Text('Lưu')),
        ],
      ),
    );
  }
}
