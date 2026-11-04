import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/widgets/app_table.dart';
import '../domain/hr_models.dart';

const _weekdays = [
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];

const hrMonths = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

String hrWeekday(DateTime day) => _weekdays[day.weekday - 1];

String two(int value) => value.toString().padLeft(2, '0');

String hrClock(DateTime? value) =>
    value == null ? '—' : '${two(value.hour)}:${two(value.minute)}';

String hrDate(String iso) {
  final day = DateTime.tryParse(iso);
  if (day == null) return iso;
  return '${two(day.day)}/${two(day.month)}/${day.year}';
}

String hrDayLabel(String iso) {
  final day = DateTime.tryParse(iso);
  if (day == null) return iso;
  return '${hrWeekday(day)} ${two(day.day)}/${two(day.month)}';
}

/// «08:30:00» from the API → «08:30».
String hrTime(String? value) =>
    value == null || value.length < 5 ? (value ?? '—') : value.substring(0, 5);

/// A from–to range of times or dates, isolated left-to-right so Arabic text
/// around it cannot flip it into «16:00 – 08:00».
String hrRange(String from, String to) => '\u2066$from – $to\u2069';

/// Minutes as hours and minutes: 95 → «1:35».
String hrDuration(int minutes) => '${minutes ~/ 60}:${two(minutes % 60)}';

String requestTypeLabel(String type) => switch (type) {
  'LEAVE' => 'إجازة',
  'PERMISSION' => 'إذن',
  'MISSION' => 'مأمورية',
  'ATTENDANCE_CORRECTION' => 'تصحيح حضور',
  _ => type,
};

IconData requestTypeIcon(String type) => switch (type) {
  'LEAVE' => LucideIcons.palmtree,
  'PERMISSION' => LucideIcons.clock,
  'MISSION' => LucideIcons.briefcase,
  'ATTENDANCE_CORRECTION' => LucideIcons.fingerprint,
  _ => LucideIcons.fileText,
};

AppTag requestStatusTag(String status) => switch (status) {
  'APPROVED' => const AppTag(
    'مقبول',
    tone: AppTone.success,
    icon: LucideIcons.check,
  ),
  'REJECTED' => const AppTag(
    'مرفوض',
    tone: AppTone.danger,
    icon: LucideIcons.x,
  ),
  'CANCELLED' => const AppTag('ملغى', icon: LucideIcons.ban),
  _ => const AppTag(
    'قيد المراجعة',
    tone: AppTone.warning,
    icon: LucideIcons.clock,
  ),
};

AppTag dayStatusTag(HrTimesheetDay day) {
  if (day.missingPunch) {
    return const AppTag('بصمة ناقصة', tone: AppTone.warning);
  }
  return switch (day.status) {
    'PRESENT' => const AppTag('حضور', tone: AppTone.success),
    'ABSENT' => const AppTag('غياب', tone: AppTone.danger),
    'LEAVE' => const AppTag('إجازة', tone: AppTone.info),
    'PERMISSION' => const AppTag('إذن', tone: AppTone.info),
    'MISSION' => const AppTag('مأمورية', tone: AppTone.info),
    'HOLIDAY' => const AppTag('عطلة رسمية'),
    'REST_DAY' => const AppTag('راحة'),
    _ => AppTag(day.status),
  };
}

String lineTypeLabel(String type) => switch (type) {
  'LATE' => 'تأخير',
  'EARLY_LEAVE' => 'انصراف مبكر',
  'ABSENCE' => 'غياب',
  'MISSING_PUNCH' => 'بصمة ناقصة',
  'OVERTIME' => 'وقت إضافي',
  _ => type,
};

String lineStatusLabel(String status) => switch (status) {
  'APPLIED' => 'مطبّق',
  'DRAFT' => 'بانتظار الموافقة',
  'REJECTED' => 'مرفوض',
  _ => status,
};

/// What the server noted about a punch; informational, never a block.
String trustFlagLabel(String flag) => switch (flag) {
  'OTHER_DEVICE' => 'من جهاز آخر',
  'NO_LOCATION' => 'بدون موقع',
  'OUT_OF_RANGE' => 'خارج النطاق',
  'LOW_ACCURACY' => 'دقة موقع ضعيفة',
  'MOCK_LOCATION' => 'موقع غير حقيقي',
  'BIOMETRIC_FAILED' => 'لم يتم التحقق بالبصمة',
  'OUTSIDE_WINDOW' => 'خارج مواعيد الوردية',
  'CLOCK_SKEW' => 'ساعة الجهاز غير مضبوطة',
  'SELFIE_MISSING' => 'بدون صورة',
  'LIVENESS_FAILED' => 'لم يكتمل التحقق الحي',
  'NO_FACE' => 'لا يظهر وجه في الصورة',
  'NO_FACE_TEMPLATE' => 'الوجه غير مسجّل',
  'FACE_MISMATCH' => 'الوجه غير مطابق',
  'FACE_UNCHECKED' => 'لم تُطابق الصورة',
  _ => flag,
};

String attendanceTypeLabel(String type) => switch (type) {
  'SINGLE' => 'موقع محدد',
  'MULTI' => 'مجموعة مواقع',
  'FREE' => 'من أي مكان',
  _ => type,
};

String contractTypeLabel(String type) => switch (type) {
  'PERMANENT' => 'دائم',
  'FIXED_TERM' => 'محدد المدة',
  'PART_TIME' => 'دوام جزئي',
  'DAILY' => 'يومية',
  _ => type,
};

String employeeStatusLabel(String status) => switch (status) {
  'ACTIVE' => 'على رأس العمل',
  'SUSPENDED' => 'موقوف',
  'TERMINATED' => 'منتهي الخدمة',
  _ => status,
};
