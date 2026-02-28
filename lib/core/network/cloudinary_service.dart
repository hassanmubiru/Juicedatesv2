import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Cloudinary replaces Firebase Storage — zero egress fees, 25 GB free,
/// built-in CDN, and automatic image optimisation (WebP, smart cropping).
///
/// Setup (one-time, 2 minutes):
///   1. Create a free account at https://cloudinary.com
///   2. Dashboard → Settings → Upload → Add upload preset
///      • Signing mode: Unsigned
///      • Folder: juicedates/users
///      • Incoming transformations: resize to max 1200px, quality auto
///   3. Replace the two constants below with your values.
class CloudinaryService {
  // ── Configuration ─────────────────────────────────────────────────────────
  static const String _cloudName = 'dpqrxpf4c';       // e.g. 'dxyz123abc'
  static const String _uploadPreset = 'vhjumaay'; // e.g. 'juicedates_unsigned'

  static const String _uploadUrl =
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Uploads [file] and returns the permanent CDN URL.
  /// [publicId] is used as the filename in Cloudinary (e.g. "users/uid/photo_0").
  Future<String> uploadPhoto({
    required File file,
    required String publicId,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl))
      ..fields['upload_preset'] = _uploadPreset
      ..fields['public_id'] = publicId
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) {
      throw Exception('Cloudinary upload failed (${streamed.statusCode}): $body');
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    return json['secure_url'] as String;
  }

  /// Deletes a photo by its [publicId].
  /// NOTE: deletion requires a signed request or the Cloudinary Admin API.
  /// For most dating apps, simply orphaning the old asset is fine — storage
  /// is cheap and auto-cleanup can be scheduled in the Cloudinary dashboard.
  /// This is a no-op stub until you need it.
  Future<void> deletePhoto(String publicId) async {
    // Implement with Firebase Function + Admin API if needed
  }

  /// Builds a transformation URL from an existing Cloudinary URL —
  /// useful for generating thumbnails on the fly without re-uploading.
  static String thumbnail(String url, {int size = 200}) {
    // Insert transformation before the upload segment
    return url.replaceFirst(
      '/upload/',
      '/upload/w_$size,h_$size,c_fill,g_face,f_auto,q_auto:eco/',
    );
  }
}
