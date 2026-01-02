import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _pinController = TextEditingController();
  final _settings = SettingsService.instance;
  bool _isError = false;

  void _verifyPin() {
    if (_pinController.text == _settings.adminPin) {
      Navigator.pop(context, true); // Trả về true nếu đúng
    } else {
      setState(() {
        _isError = true;
        _pinController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mã PIN không đúng!'), backgroundColor: Colors.red),
      );
    }
  }

  void _onKeyTap(String value) {
    if (_pinController.text.length < 6) {
      setState(() {
        _isError = false;
        _pinController.text += value;
      });
    }
  }

  void _onBackspace() {
    if (_pinController.text.isNotEmpty) {
      setState(() {
        _isError = false;
        _pinController.text = _pinController.text.substring(0, _pinController.text.length - 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            const Icon(Icons.lock_outline, size: 60, color: Colors.blue),
            const SizedBox(height: 20),
            const Text('Khu vực Quản trị viên', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text('Nhập mã PIN để tiếp tục', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 40),
            
            // PIN Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < _pinController.text.length 
                        ? (_isError ? Colors.red : Colors.blue) 
                        : Colors.grey.shade300,
                  ),
                );
              }),
            ),
            
            const Spacer(),
            
            // Keypad
            _buildKeypad(),
            const SizedBox(height: 30),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy bỏ', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildKey('1'), _buildKey('2'), _buildKey('3'),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildKey('4'), _buildKey('5'), _buildKey('6'),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildKey('7'), _buildKey('8'), _buildKey('9'),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 70), // Empty space
              _buildKey('0'),
              _buildBackspaceKey(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKey(String val) {
    return GestureDetector(
      onTap: () {
        _onKeyTap(val);
        if (_pinController.text.length == 6) {
          Future.delayed(const Duration(milliseconds: 200), _verifyPin);
        }
      },
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.shade100,
        ),
        child: Center(
          child: Text(val, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildBackspaceKey() {
    return GestureDetector(
      onTap: _onBackspace,
      child: Container(
        width: 70,
        height: 70,
        color: Colors.transparent,
        child: const Center(
          child: Icon(Icons.backspace_outlined, size: 28),
        ),
      ),
    );
  }
}
