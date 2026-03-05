import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import 'web_file_picker.dart';

class MediaUploadResult {
  final String url;
  final String key;
  final String contentType;
  final int size;

  MediaUploadResult({
    required this.url,
    required this.key,
    required this.contentType,
    required this.size,
  });

  factory MediaUploadResult.fromJson(Map<String, dynamic> json) {
    return MediaUploadResult(
      url: json['url'] as String,
      key: json['key'] as String,
      contentType: json['content_type'] as String,
      size: (json['size'] as num).toInt(),
    );
  }
}

class MediaService {
  final Dio _dio;

  MediaService(this._dio);

  /// Upload a file picked via the web file picker.
  Future<MediaUploadResult> uploadWebFile(
    WebFilePickResult file, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        file.bytes,
        filename: file.name,
      ),
    });

    final response = await _dio.post(
      '${ApiConstants.baseUrl}/api/v1/media/upload',
      data: formData,
      onSendProgress: onProgress,
    );

    return MediaUploadResult.fromJson(response.data as Map<String, dynamic>);
  }
}
