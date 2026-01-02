import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class SettingsService {
  static final SettingsService instance = SettingsService._init();
  SharedPreferences? _prefs;

  SettingsService._init();

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // --- CẤU HÌNH CA LÀM VIỆC ---
  
  // Giờ bắt đầu ca (VD: 08:00)
  TimeOfDay get workStartTime {
    final hour = _prefs?.getInt('workStartHour') ?? 8;
    final minute = _prefs?.getInt('workStartMinute') ?? 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> setWorkStartTime(TimeOfDay time) async {
    await _prefs?.setInt('workStartHour', time.hour);
    await _prefs?.setInt('workStartMinute', time.minute);
  }

  // Phút cho phép đi muộn (Grace Period) (VD: 15 phút)
  int get gracePeriodMinutes => _prefs?.getInt('gracePeriodMinutes') ?? 15;
  
  Future<void> setGracePeriodMinutes(int minutes) async {
    await _prefs?.setInt('gracePeriodMinutes', minutes);
  }
  
  // Mức lương mặc định
  double get defaultSalary => _prefs?.getDouble('defaultSalary') ?? 50000.0;
  
  Future<void> setDefaultSalary(double salary) async {
    await _prefs?.setDouble('defaultSalary', salary);
  }

  // --- BẢO MẬT ADMIN ---

  // Mã PIN Admin (Mặc định 123456)
  String get adminPin => _prefs?.getString('adminPin') ?? '123456';

  Future<void> setAdminPin(String pin) async {
    await _prefs?.setString('adminPin', pin);
  }
}
