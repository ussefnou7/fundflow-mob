import 'package:dio/dio.dart';

class ApiError implements Exception {
  const ApiError(this.message);

  factory ApiError.fromResponse(Response<dynamic> response) {
    final data = response.data;
    if (data is Map && data['message'] is String) {
      final message = data['message'] as String;
      if (message.isNotEmpty) return ApiError(message);
    }
    return ApiError(switch (response.statusCode) {
      401 => 'انتهت جلسة الدخول. سجّل الدخول مرة أخرى.',
      403 => 'ليس لديك صلاحية لعرض هذه البيانات.',
      404 => 'لم يتم العثور على البيانات المطلوبة.',
      409 => 'تغيّرت البيانات. حدّث الصفحة وحاول مرة أخرى.',
      500 ||
      502 ||
      503 ||
      504 => 'السيرفر غير متاح حاليًا. حاول مرة أخرى بعد قليل.',
      _ => 'تعذر إتمام الطلب. حاول مرة أخرى.',
    });
  }

  final String message;

  @override
  String toString() => message;
}

Map<String, dynamic> requireMap(Response<dynamic> response) {
  if (response.statusCode == 200 || response.statusCode == 201) {
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
  }
  throw ApiError.fromResponse(response);
}

List<dynamic> requireList(Response<dynamic> response) {
  if (response.statusCode == 200 && response.data is List) {
    return response.data as List<dynamic>;
  }
  throw ApiError.fromResponse(response);
}
