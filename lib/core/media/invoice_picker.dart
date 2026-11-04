import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// Permission denial/cancellation must leave the financial form usable.
Future<List<XFile>> pickInvoiceImages(
  BuildContext context, {
  bool camera = false,
  bool single = false,
}) async {
  try {
    final picker = ImagePicker();
    final List<XFile> files;
    if (camera || single) {
      final file = await picker.pickImage(
        source: camera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 2400,
        maxHeight: 2400,
        requestFullMetadata: false,
      );
      files = file == null ? [] : [file];
    } else {
      files = await picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 2400,
        maxHeight: 2400,
        requestFullMetadata: false,
        limit: 10,
      );
    }
    var total = 0;
    for (final file in files) {
      final size = await file.length();
      total += size;
      if (size > 10 * 1024 * 1024 ||
          total > 50 * 1024 * 1024 ||
          files.length > 10) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'اختر حتى 10 صور؛ الحد 10 ميجابايت للصورة و50 ميجابايت إجمالًا.',
              ),
            ),
          );
        }
        return [];
      }
    }
    return files;
  } on PlatformException {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذر فتح الكاميرا أو الصور. راجع الإذن في إعدادات الجهاز ثم حاول مجددًا.',
          ),
        ),
      );
    }
    return [];
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر قراءة الصورة. اختر صورة أخرى أو أعد المحاولة.'),
        ),
      );
    }
    return [];
  }
}
