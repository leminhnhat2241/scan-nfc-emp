import 'dart:async';
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
      final completer = Completer<Employee?>();

      NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            // Lấy dữ liệu NDEF từ thẻ
            final ndef = Ndef.from(tag);
            if (ndef == null) {
              print('Tag không hỗ trợ NDEF');
              await NfcManager.instance.stopSession(
                errorMessage: 'Tag không hỗ trợ NDEF',
              );
              if (!completer.isCompleted) completer.complete(null);
              return;
            }

            // Đọc các NDEF records
            final cachedMessage = ndef.cachedMessage;
            if (cachedMessage == null || cachedMessage.records.isEmpty) {
              print('Không có dữ liệu trên thẻ');
              await NfcManager.instance.stopSession(
                errorMessage: 'Không có dữ liệu trên thẻ',
              );
              if (!completer.isCompleted) completer.complete(null);
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
            final employee = Employee.fromJson(data);

            await NfcManager.instance.stopSession(
              alertMessage: 'Đọc thẻ thành công!',
            );
            if (!completer.isCompleted) completer.complete(employee);
          } catch (e) {
            print('Lỗi khi đọc thẻ: $e');
            await NfcManager.instance.stopSession(errorMessage: 'Lỗi: $e');
            if (!completer.isCompleted) completer.complete(null);
          }
        },
      );

      // Đợi kết quả với timeout 30 giây
      return await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('Timeout khi đọc thẻ');
          NfcManager.instance.stopSession(errorMessage: 'Hết thời gian chờ');
          return null;
        },
      );
    } catch (e) {
      print('Lỗi NFC: $e');
      return null;
    }
  }

  // Ghi dữ liệu lên thẻ NFC
  Future<bool> writeNfcTag(Employee employee) async {
    try {
      print('=== BẮT ĐẦU GHI THẺ NFC ===');
      final completer = Completer<bool>();

      NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          print('📱 Đã phát hiện thẻ NFC');
          try {
            final ndef = Ndef.from(tag);
            if (ndef == null) {
              print('❌ Tag không hỗ trợ NDEF');
              await NfcManager.instance.stopSession(
                errorMessage: 'Thẻ không hỗ trợ NDEF',
              );
              if (!completer.isCompleted) {
                print('⚠️ Complete với false (không hỗ trợ NDEF)');
                completer.complete(false);
              }
              return;
            }

            // Kiểm tra thẻ có thể ghi không
            if (!ndef.isWritable) {
              print('❌ Thẻ không thể ghi');
              await NfcManager.instance.stopSession(
                errorMessage: 'Thẻ không thể ghi',
              );
              if (!completer.isCompleted) {
                print('⚠️ Complete với false (không thể ghi)');
                completer.complete(false);
              }
              return;
            }

            // Chuyển employee thành JSON string
            final jsonString = json.encode(employee.toJson());
            print('📝 Đang ghi dữ liệu: $jsonString');

            // Tạo NDEF message
            final ndefMessage = NdefMessage([
              NdefRecord.createText(jsonString),
            ]);

            // Kiểm tra kích thước
            final size = ndefMessage.byteLength;
            if (size > ndef.maxSize) {
              print('❌ Dữ liệu quá lớn: $size > ${ndef.maxSize}');
              await NfcManager.instance.stopSession(
                errorMessage: 'Dữ liệu quá lớn',
              );
              if (!completer.isCompleted) {
                print('⚠️ Complete với false (dữ liệu quá lớn)');
                completer.complete(false);
              }
              return;
            }

            // Ghi dữ liệu
            print('✍️ Đang ghi vào thẻ...');
            await ndef.write(ndefMessage);
            print('✅ Đã ghi dữ liệu thành công!');

            await NfcManager.instance.stopSession(
              alertMessage: 'Ghi thẻ thành công!',
            );

            if (!completer.isCompleted) {
              print('✅ Complete với TRUE');
              completer.complete(true);
            } else {
              print('⚠️ Completer đã được complete trước đó');
            }
          } catch (e) {
            print('❌ Lỗi khi ghi thẻ: $e');
            await NfcManager.instance.stopSession(errorMessage: 'Lỗi: $e');
            if (!completer.isCompleted) {
              print('⚠️ Complete với false (exception)');
              completer.complete(false);
            }
          }
        },
      );

      print('⏳ Đang chờ kết quả từ NFC session...');
      // Đợi kết quả với timeout 30 giây
      final result = await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('⏱️ TIMEOUT khi ghi thẻ');
          NfcManager.instance.stopSession(errorMessage: 'Hết thời gian chờ');
          return false;
        },
      );

      print('🏁 Kết quả cuối cùng: $result');
      return result;
    } catch (e) {
      print('❌ Lỗi NFC ngoài: $e');
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
