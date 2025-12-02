# Hướng dẫn Import File CSV/Excel

## 📁 Định dạng file

Ứng dụng hỗ trợ import danh sách nhân viên từ file **CSV** hoặc **Excel (XLSX/XLS)**.

### Cấu trúc file

File cần có **3 cột** theo thứ tự:

| Tên nhân viên | Phòng ban | Chức vụ   |
| ------------- | --------- | --------- |
| Nguyễn Văn A  | IT        | Nhân viên |
| Trần Thị B    | Kỹ thuật  | Kỹ sư     |

**Lưu ý:**

- Dòng đầu tiên là **header** (tiêu đề cột) - sẽ bị bỏ qua khi import
- **Cột 1** (bắt buộc): Tên nhân viên
- **Cột 2** (bắt buộc): Phòng ban
- **Cột 3** (tùy chọn): Chức vụ

### Danh sách phòng ban hợp lệ

- Kỹ thuật (mã: KT)
- Kinh doanh (mã: KD)
- Hành chính (mã: HC)
- Nhân sự (mã: NS)
- Kế toán (mã: KT)
- Marketing (mã: MK)
- IT (mã: IT)
- Sản xuất (mã: SX)

### Danh sách chức vụ

- Giám đốc
- Phó giám đốc
- Trưởng phòng
- Phó phòng
- Nhân viên
- Thực tập sinh
- Chuyên viên
- Kỹ sư

## 📝 Cách tạo file CSV

### Sử dụng Excel/Google Sheets:

1. Tạo file mới
2. Nhập dữ liệu theo định dạng trên
3. Lưu dưới dạng **CSV (UTF-8)** hoặc **Excel (.xlsx)**

### Sử dụng Notepad:

```csv
Tên nhân viên,Phòng ban,Chức vụ
Nguyễn Văn A,IT,Nhân viên
Trần Thị B,Kỹ thuật,Kỹ sư
Lê Văn C,Kinh doanh,Trưởng phòng
```

Lưu file với extension `.csv` và encoding **UTF-8**.

## 🚀 Cách sử dụng

1. Mở ứng dụng → **Ghi nhiều thẻ**
2. Nhấn nút **"Import từ CSV/Excel"**
3. Chọn file từ thiết bị
4. Ứng dụng sẽ tự động:
   - Đọc dữ liệu từ file
   - Tạo mã nhân viên tự động (VD: IT001, KT002,...)
   - Thêm vào danh sách chờ ghi
5. Nhấn **"BẮT ĐẦU GHI THẺ"**
6. Làm theo hướng dẫn để ghi từng thẻ NFC

## ✅ Ví dụ file mẫu

Xem file `mau_danh_sach_nhan_vien.csv` trong thư mục gốc.

## ⚠️ Lưu ý

- File phải có ít nhất **2 cột** (Tên, Phòng ban)
- Phòng ban phải khớp với danh sách phòng ban trong hệ thống
- Mã nhân viên sẽ được tự động tạo, không cần nhập
- File Excel hỗ trợ cả định dạng `.xlsx` và `.xls`
- Encoding khuyến nghị: **UTF-8** để hiển thị tiếng Việt đúng

## 🔧 Xử lý lỗi

**File không đọc được:**

- Kiểm tra định dạng file (.csv, .xlsx, .xls)
- Đảm bảo file không bị hỏng
- Thử mở file bằng Excel để kiểm tra

**Phòng ban không hợp lệ:**

- So sánh với danh sách phòng ban bên trên
- Viết đúng chính tả (có dấu)

**Dữ liệu bị lỗi font:**

- Lưu file CSV với encoding UTF-8
- Sử dụng Excel để mở và lưu lại file
