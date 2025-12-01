import 'dart:convert';
import 'package:nfc_manager/nfc_manager.dart';
import '../models/employee.dart';

class NfcService {
  // Kiểm tra thiết bị có hỗ trợ NFC không
  Future<bool> isNfcAvailable() async {
    return await NfcManager.instance.isAvailable();
  }

  // Đọc dữ liệu từ thẻ NFC
  Future<Employee?> readNfcTag() async {
    try {
      Employee? employee;

      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            // Lấy dữ liệu NDEF từ thẻ
            final ndef = Ndef.from(tag);
            if (ndef == null) {
              print('Tag không hỗ trợ NDEF');
              await NfcManager.instance.stopSession();
              return;
            }

            // Đọc các NDEF records
            final cachedMessage = ndef.cachedMessage;
            if (cachedMessage == null || cachedMessage.records.isEmpty) {
              print('Không có dữ liệu trên thẻ');
              await NfcManager.instance.stopSession();
              return;
            }

            // Lấy record đầu tiên
            final record = cachedMessage.records.first;

            // Chuyển đổi payload thành string
            final payload = String.fromCharCodes(record.payload);

            // Loại bỏ language code (3 bytes đầu nếu có)
            String jsonString = payload;
            if (payload.length > 3 && payload.codeUnitAt(0) < 32) {
              jsonString = payload.substring(3);
            }

            print('Dữ liệu đọc được: $jsonString');

            // Parse JSON
            final data = json.decode(jsonString);
            employee = Employee.fromJson(data);

            await NfcManager.instance.stopSession();
          } catch (e) {
            print('Lỗi khi đọc thẻ: $e');
            await NfcManager.instance.stopSession();
          }
        },
      );

      return employee;
    } catch (e) {
      print('Lỗi NFC: $e');
      return null;
    }
  }

  // Ghi dữ liệu lên thẻ NFC
  Future<bool> writeNfcTag(Employee employee) async {
    try {
      bool success = false;

      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            final ndef = Ndef.from(tag);
            if (ndef == null) {
              await NfcManager.instance.stopSession();
              return;
            }

            // Kiểm tra thẻ có thể ghi không
            if (!ndef.isWritable) {
              await NfcManager.instance.stopSession();
              return;
            }

            // Chuyển employee thành JSON string
            final jsonString = json.encode(employee.toJson());
            print('Đang ghi dữ liệu: $jsonString');

            // Tạo NDEF message
            final ndefMessage = NdefMessage([
              NdefRecord.createText(jsonString),
            ]);

            // Kiểm tra kích thước
            final size = ndefMessage.byteLength;
            if (size > ndef.maxSize) {
              await NfcManager.instance.stopSession();
              return;
            }

            // Ghi dữ liệu
            await ndef.write(ndefMessage);
            success = true;

            await NfcManager.instance.stopSession();
          } catch (e) {
            print('Lỗi khi ghi thẻ: $e');
            await NfcManager.instance.stopSession();
          }
        },
      );

      return success;
    } catch (e) {
      print('Lỗi NFC: $e');
      return false;
    }
  }

  // Dừng session NFC
  Future<void> stopSession({String? message}) async {
    try {
      await NfcManager.instance.stopSession();
    } catch (e) {
      print('Lỗi khi dừng session: $e');
    }
  }
}
