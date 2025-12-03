import 'dart:async';
import 'dart:convert';
import 'package:nfc_manager/nfc_manager.dart';
import '../models/employee.dart';

class NfcWriteResult {
  final bool success;
  final String message;
  NfcWriteResult(this.success, this.message);
}

class NfcService {
  // Kiểm tra thiết bị có hỗ trợ NFC không
  Future<bool> isNfcAvailable() async {
    return await NfcManager.instance.isAvailable();
  }

  // Đọc dữ liệu từ thẻ NFC
  Future<Employee?> readNfcTag() async {
    final completer = Completer<Employee?>();

    try {
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            // Lấy dữ liệu NDEF từ thẻ
            final ndef = Ndef.from(tag);
            if (ndef == null) {
              print('❌ Tag không hỗ trợ NDEF');
              await NfcManager.instance.stopSession(
                errorMessage: 'Thẻ không hỗ trợ NDEF',
              );
              completer.complete(null);
              return;
            }

            // Đọc các NDEF records
            final cachedMessage = ndef.cachedMessage;
            if (cachedMessage == null || cachedMessage.records.isEmpty) {
              print('❌ Không có dữ liệu trên thẻ');
              await NfcManager.instance.stopSession(
                errorMessage: 'Không có dữ liệu trên thẻ',
              );
              completer.complete(null);
              return;
            }

            // Lấy record đầu tiên
            final record = cachedMessage.records.first;

            // Debug: In chi tiết record
            print('📋 Record Type: ${record.typeNameFormat}');
            print('📋 Record Type (value): ${record.typeNameFormat.index}');
            print('📋 Record payload length: ${record.payload.length}');
            print('📋 Record type: ${record.type}');

            String jsonString;
            // Xử lý đúng chuẩn theo loại record
            if (record.typeNameFormat == NdefTypeNameFormat.nfcWellknown) {
              // Khả năng là Text Record (TNF Well-known, type 'T')
              final payloadBytes = record.payload;
              if (payloadBytes.isEmpty) {
                throw Exception('Payload rỗng');
              }
              final status = payloadBytes.first;
              final langLen = status & 0x3F; // 6 bit dưới là độ dài mã ngôn ngữ
              if (1 + langLen > payloadBytes.length) {
                throw Exception('Payload không hợp lệ');
              }
              final jsonUtf8 = payloadBytes.sublist(1 + langLen);
              jsonString = utf8.decode(jsonUtf8);
            } else if (record.typeNameFormat == NdefTypeNameFormat.media) {
              // MIME record, ví dụ 'application/json'
              jsonString = utf8.decode(record.payload);
            } else if (record.typeNameFormat == NdefTypeNameFormat.empty) {
              // Thẻ đã erase nhưng chưa ghi dữ liệu
              print('❌ Thẻ rỗng - chưa có dữ liệu nhân viên');
              await NfcManager.instance.stopSession(
                errorMessage: 'Thẻ chưa có dữ liệu',
              );
              completer.completeError(
                Exception(
                  '⚠️ THẺ RỖNG!\n\n'
                  'Thẻ này đã được xóa sạch nhưng chưa ghi thông tin nhân viên.\n\n'
                  'CÁCH GHI DỮ LIỆU:\n'
                  '1. Vào menu "Danh sách nhân viên"\n'
                  '2. Chọn nhân viên cần ghi thẻ\n'
                  '3. Nhấn nút "Ghi thẻ NFC"\n'
                  '4. Đưa thẻ gần điện thoại và giữ ổn định',
                ),
              );
              return;
            } else {
              // Các loại record khác - thử đọc trực tiếp payload
              print('⚠️ Record type không chuẩn: ${record.typeNameFormat}');
              print('🔍 Thử đọc trực tiếp payload...');

              if (record.payload.isEmpty) {
                throw Exception('Thẻ không có dữ liệu');
              }

              // Thử decode trực tiếp
              try {
                jsonString = utf8.decode(record.payload);
                print('✅ Decode trực tiếp thành công');
              } catch (e) {
                throw Exception(
                  'Record type ${record.typeNameFormat} không được hỗ trợ',
                );
              }
            }

            print('📝 Dữ liệu đọc được: $jsonString');

            // Parse JSON
            try {
              final data = json.decode(jsonString);
              final employee = Employee.fromJson(data);
              print(
                '✅ Parse JSON thành công: ${employee.employeeId} - ${employee.name}',
              );

              await NfcManager.instance.stopSession();
              completer.complete(employee);
            } catch (parseError) {
              // Lỗi parse JSON - thẻ có dữ liệu nhưng không đúng định dạng
              print('❌ Dữ liệu không phải JSON hợp lệ: $parseError');
              await NfcManager.instance.stopSession(
                errorMessage: 'Dữ liệu thẻ không đúng định dạng',
              );
              completer.completeError(
                Exception(
                  '⚠️ THẺ CHỨA DỮ LIỆU KHÔNG HỢP LỆ!\n\n'
                  'Dữ liệu đọc được: "$jsonString"\n\n'
                  'Thẻ này có dữ liệu nhưng không phải là thông tin nhân viên.\n\n'
                  'CÁCH SỬA:\n'
                  '1. Mở app "NFC Tools"\n'
                  '2. Chọn tab "OTHER" → "Erase tag"\n'
                  '3. Quét thẻ để xóa dữ liệu cũ\n'
                  '4. Quay lại app này\n'
                  '5. Vào "Danh sách NV" → chọn nhân viên → "Ghi thẻ"',
                ),
              );
              return;
            }
          } catch (e) {
            print('❌ Lỗi khi đọc thẻ: $e');
            await NfcManager.instance.stopSession(errorMessage: e.toString());
            completer.completeError(e);
          }
        },
      );

      return await completer.future;
    } catch (e) {
      print('❌ Lỗi NFC service: $e');
      rethrow;
    }
  }

  // Ghi dữ liệu lên thẻ NFC
  Future<NfcWriteResult> writeNfcTag(Employee employee) async {
    final completer = Completer<NfcWriteResult>();

    try {
      print('=== BẮT ĐẦU GHI THẺ NFC ===');
      print('📝 Employee: ${employee.employeeId} - ${employee.name}');
      print('📝 Department: ${employee.department ?? "N/A"}');
      print('📝 Position: ${employee.position ?? "N/A"}');

      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
        onDiscovered: (NfcTag tag) async {
          print('✅ ĐÃ PHÁT HIỆN THẺ NFC!');
          print('📋 Tag data: ${tag.data}');

          try {
            var ndef = Ndef.from(tag);
            print('📋 NDEF instance: ${ndef != null ? "OK" : "NULL"}');

            // Nếu thẻ chưa có NDEF, cần format
            if (ndef == null) {
              print('⚠️ Thẻ chưa có định dạng NDEF');

              final canFormat = tag.data.containsKey('ndefformatable');
              print('📋 Có thể format: $canFormat');

              String errorMsg;
              if (canFormat) {
                errorMsg =
                    '⚠️ THẺ CHƯA ĐƯỢC ĐỊNH DẠNG!\n\n'
                    'Thẻ NFC này chưa có định dạng NDEF.\n\n'
                    'CÁCH XỬ LÝ:\n'
                    '1. Tải app "NFC Tools" từ Play Store\n'
                    '2. Mở app → chọn tab "OTHER"\n'
                    '3. Chọn "Format tag as..." → "Empty tag"\n'
                    '4. Quét thẻ để format\n'
                    '5. Quay lại app này và thử lại';
              } else {
                errorMsg =
                    '❌ Thẻ không hỗ trợ NDEF!\n\n'
                    'Loại thẻ này không tương thích với ứng dụng.';
              }

              await NfcManager.instance.stopSession(errorMessage: errorMsg);
              completer.complete(NfcWriteResult(false, errorMsg));
              return;
            }

            // Kiểm tra thẻ có thể ghi không
            print('📋 Writable: ${ndef.isWritable}');
            print('📋 Max size: ${ndef.maxSize} bytes');

            if (!ndef.isWritable) {
              const errorMsg =
                  '❌ Thẻ bị khóa (read-only)!\n\n'
                  'Thẻ này không thể ghi dữ liệu.\n'
                  'Vui lòng sử dụng thẻ khác.';
              await NfcManager.instance.stopSession(errorMessage: errorMsg);
              completer.complete(NfcWriteResult(false, errorMsg));
              return;
            }

            // Chuyển employee thành JSON
            final jsonString = json.encode(employee.toJson());
            print('📝 JSON data: $jsonString');
            print('📏 JSON length: ${jsonString.length} bytes');

            // Tạo NDEF message với MIME type
            final ndefMessage = NdefMessage([
              NdefRecord.createMime(
                'application/json',
                utf8.encode(jsonString),
              ),
            ]);

            final size = ndefMessage.byteLength;
            print('💾 NDEF message size: $size bytes');

            if (size > ndef.maxSize) {
              final errorMsg =
                  '❌ Dữ liệu quá lớn!\n\n'
                  'Kích thước: $size bytes\n'
                  'Thẻ chỉ có: ${ndef.maxSize} bytes\n\n'
                  'Vui lòng rút ngắn thông tin nhân viên.';
              await NfcManager.instance.stopSession(errorMessage: errorMsg);
              completer.complete(NfcWriteResult(false, errorMsg));
              return;
            }

            // Ghi dữ liệu
            print('✍️ Đang ghi dữ liệu vào thẻ...');
            await ndef.write(ndefMessage);
            print('✅ GHI THẺ THÀNH CÔNG!');

            await NfcManager.instance.stopSession();
            completer.complete(NfcWriteResult(true, 'Ghi thẻ thành công!'));
          } catch (e) {
            print('❌ Lỗi trong onDiscovered: $e');
            await NfcManager.instance.stopSession(errorMessage: e.toString());
            completer.complete(NfcWriteResult(false, 'Lỗi khi ghi thẻ: $e'));
          }
        },
      );

      return await completer.future;
    } catch (e) {
      print('❌ Lỗi NFC service: $e');
      return NfcWriteResult(false, 'Lỗi NFC: $e');
    }
  }

  // Dừng session NFC
  Future<void> stopSession({String? message}) async {
    try {
      if (message != null && message.isNotEmpty) {
        await NfcManager.instance.stopSession(errorMessage: message);
      } else {
        await NfcManager.instance.stopSession();
      }
    } catch (e) {
      print('Lỗi khi dừng session: $e');
    }
  }
}
