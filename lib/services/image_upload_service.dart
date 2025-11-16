import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

/// Free image hosting service using ImgBB
/// No API key needed for basic usage
class ImageUploadService {
  // Using ImgBB free API (no registration needed for basic usage)
  // Alternative: You can use Cloudinary, Imgur, or your own server
  static const String _uploadUrl = 'https://api.imgbb.com/1/upload';
  static const String _apiKey =
      '70a02853376856de922940a801416ef0'; // Get free at https://api.imgbb.com/

  /// Upload image to ImgBB and return URL
  /// Falls back to base64 if upload fails
  Future<String?> uploadImage(File imageFile) async {
    try {
      // Read image as base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Upload to ImgBB (unlimited free hosting)
      final imgbbUrl = await _uploadToImgBB(base64Image, imageFile);
      if (imgbbUrl != null) {
        return imgbbUrl;
      }

      // Fallback to base64 if upload fails
      print('ImgBB upload failed, using base64 fallback');
      return 'data:image/jpeg;base64,$base64Image';
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  /// Upload multiple images
  Future<List<String>> uploadImages(List<File> imageFiles) async {
    final urls = <String>[];
    for (var file in imageFiles) {
      final url = await uploadImage(file);
      if (url != null) urls.add(url);
    }
    return urls;
  }

  /// Upload to ImgBB (if you have API key)
  Future<String?> _uploadToImgBB(String base64Image, File imageFile) async {
    try {
      final response = await http.post(
        Uri.parse(_uploadUrl),
        body: {
          'key': _apiKey,
          'image': base64Image,
          'name': path.basename(imageFile.path),
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data']['url'] as String;
      }
    } catch (e) {
      print('ImgBB upload error: $e');
    }
    return null;
  }

  /// Alternative: Upload to Cloudinary (free tier)
  /// Sign up at https://cloudinary.com for free API credentials
  Future<String?> _uploadToCloudinary(File imageFile) async {
    // Cloudinary configuration (get from cloudinary.com)
    const cloudName = 'YOUR_CLOUD_NAME';
    const uploadPreset =
        'YOUR_UPLOAD_PRESET'; // Create unsigned preset in settings

    try {
      final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.toBytes();
        final data = json.decode(String.fromCharCodes(responseData));
        return data['secure_url'] as String;
      }
    } catch (e) {
      print('Cloudinary upload error: $e');
    }
    return null;
  }
}
