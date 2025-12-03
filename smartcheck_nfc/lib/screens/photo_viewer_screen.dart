import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Màn hình xem ảnh điểm danh
/// File con: lib/screens/photo_viewer_screen.dart
/// File mẹ: Được gọi từ lib/screens/home_screen.dart
class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen({super.key});

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  List<FileSystemEntity> _photos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  /// Tải danh sách ảnh từ thư mục attendance_photos
  Future<void> _loadPhotos() async {
    setState(() => _isLoading = true);

    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String imagesDir = path.join(appDir.path, 'attendance_photos');
      final Directory imagesDirObj = Directory(imagesDir);

      if (await imagesDirObj.exists()) {
        final List<FileSystemEntity> files = imagesDirObj
            .listSync()
            .where(
              (file) =>
                  file.path.endsWith('.jpg') || file.path.endsWith('.png'),
            )
            .toList();

        // Sắp xếp theo thời gian mới nhất
        files.sort((a, b) {
          final aStat = a.statSync();
          final bStat = b.statSync();
          return bStat.modified.compareTo(aStat.modified);
        });

        setState(() {
          _photos = files;
          _isLoading = false;
        });
      } else {
        setState(() {
          _photos = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Lỗi tải ảnh: $e');
      setState(() {
        _photos = [];
        _isLoading = false;
      });
    }
  }

  /// Xóa ảnh
  Future<void> _deletePhoto(String filePath) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc muốn xóa ảnh này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await File(filePath).delete();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('✅ Đã xóa ảnh')));
        _loadPhotos(); // Tải lại danh sách
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Lỗi xóa ảnh: $e')));
      }
    }
  }

  /// Hiển thị ảnh toàn màn hình
  void _viewFullScreen(String filePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              path.basename(filePath),
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  Navigator.pop(context);
                  _deletePhoto(filePath);
                },
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(child: Image.file(File(filePath))),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📸 Ảnh Điểm Danh'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPhotos,
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _photos.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có ảnh điểm danh nào',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Header với số lượng ảnh
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue[50],
                  child: Row(
                    children: [
                      Icon(Icons.collections, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Tổng số: ${_photos.length} ảnh',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                ),

                // Grid view ảnh
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: _photos.length,
                    itemBuilder: (context, index) {
                      final file = File(_photos[index].path);
                      final fileName = path.basename(file.path);
                      final fileStats = file.statSync();

                      // Parse tên file để lấy mã nhân viên
                      String employeeId = 'N/A';
                      try {
                        employeeId = fileName.split('_')[0];
                      } catch (e) {
                        // ignore
                      }

                      return GestureDetector(
                        onTap: () => _viewFullScreen(file.path),
                        onLongPress: () => _deletePhoto(file.path),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          child: Stack(
                            children: [
                              // Ảnh
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  file,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              ),

                              // Overlay thông tin
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                    horizontal: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        Colors.black.withOpacity(0.7),
                                        Colors.transparent,
                                      ],
                                    ),
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(8),
                                      bottomRight: Radius.circular(8),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        employeeId,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${fileStats.modified.day}/${fileStats.modified.month}/${fileStats.modified.year}',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
