class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.message,
    required this.dateMismatch,
    required this.createdAt,
    required this.companyId,
    required this.companyName,
    this.custodyRequestId,
    this.planId,
    this.contractorExtractId,
    this.creationDate,
    this.expenseDate,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'].toString(),
        kind: json['kind']?.toString() ?? 'EXPENSE_CREATED',
        message: json['message']?.toString() ?? '',
        dateMismatch: json['dateMismatch'] == true,
        createdAt: json['createdAt']?.toString() ?? '',
        companyId: json['companyId']?.toString() ?? '',
        companyName: json['companyName']?.toString() ?? 'شركة',
        custodyRequestId: json['custodyRequestId']?.toString(),
        planId: json['planId']?.toString(),
        contractorExtractId: json['contractorExtractId']?.toString(),
        creationDate: json['creationDate']?.toString(),
        expenseDate: json['expenseDate']?.toString(),
      );

  final String id;
  final String kind;
  final String message;
  final bool dateMismatch;
  final String createdAt;
  final String companyId;
  final String companyName;
  final String? custodyRequestId;
  final String? planId;
  final String? contractorExtractId;
  final String? creationDate;
  final String? expenseDate;

  String get title => switch (kind) {
    'PLAN_ENGINEER_ASSIGNED' => 'إسناد مشروع',
    'PLAN_QC_ASSIGNED' => 'إسناد مراجعة مشروع',
    'PLAN_ITEM_SUBMITTED' => 'بند بانتظار المراجعة',
    'PLAN_ITEM_APPROVED' => 'تم قبول بند المشروع',
    'PLAN_ITEM_REJECTED' => 'تم رفض بند المشروع',
    'CUSTODY_REQUESTED' => 'طلب عهدة جديد',
    'CUSTODY_REQUEST_APPROVED' => 'تم قبول طلب العهدة',
    'CUSTODY_REQUEST_REJECTED' => 'تم رفض طلب العهدة',
    'TREASURY_REQUESTED' => 'حركة خزنة بانتظار الموافقة',
    'TREASURY_MOVEMENT_APPROVED' => 'تم اعتماد حركة الخزنة',
    'TREASURY_MOVEMENT_REJECTED' => 'تم رفض حركة الخزنة',
    'CUSTODY_RETURNED' => 'تم رد مبلغ إلى الخزنة',
    'CUSTODY_TRANSFER_REQUESTED' => 'تحويل عهدة بانتظار الاستلام',
    'CUSTODY_TRANSFER_RECEIVED' => 'تم استلام تحويل العهدة',
    'EXPENSE_APPROVED' => 'تم اعتماد المصروف',
    'EXPENSE_REJECTED' || 'SETTLED_EXPENSE_REJECTED' => 'تم رفض المصروف',
    'EXPENSE_UPDATED' => 'تم تعديل بند المصروف',
    'EXPENSE_CORRECTED' => 'تصحيح إداري لبند المصروف',
    'CONTRACTOR_EXTRACT_REQUESTED' => 'مستخلص بانتظار الاعتماد',
    'CONTRACTOR_EXTRACT_APPROVED' => 'تم اعتماد المستخلص',
    'CONTRACTOR_EXTRACT_REJECTED' => 'تم رفض المستخلص',
    'HR_REQUEST_SUBMITTED' => 'طلب موظف بانتظار القرار',
    'HR_REQUEST_APPROVED' => 'تم قبول الطلب',
    'HR_REQUEST_REJECTED' => 'تم رفض الطلب',
    'HR_REQUEST_CANCELLED' => 'تم إلغاء الطلب',
    'HR_OVERTIME_PENDING' => 'وقت إضافي بانتظار الموافقة',
    'HR_DEVICE_PENDING' => 'طلب ربط جهاز بانتظار الموافقة',
    'HR_DEVICE_APPROVED' => 'تم ربط الجهاز',
    'HR_DEVICE_REJECTED' => 'تم رفض ربط الجهاز',
    'HR_DEVICE_REMOVED' => 'تم ربط جهازك بحساب آخر',
    'HR_PUNCH_PENDING' => 'بصمة بانتظار الموافقة',
    'HR_PUNCH_APPROVED' => 'تم اعتماد البصمة',
    'HR_PUNCH_REJECTED' => 'تم رفض البصمة',
    _ => 'بند مصروف جديد',
  };
}

class NotificationInbox {
  const NotificationInbox({
    required this.items,
    required this.total,
    required this.unreadCount,
    required this.page,
    required this.size,
  });

  factory NotificationInbox.fromJson(Map<String, dynamic> json) =>
      NotificationInbox(
        items: (json['items'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (item) =>
                  AppNotification.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(growable: false),
        total: (json['total'] as num?)?.toInt() ?? 0,
        unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
        page: (json['page'] as num?)?.toInt() ?? 0,
        size: (json['size'] as num?)?.toInt() ?? 20,
      );

  final List<AppNotification> items;
  final int total;
  final int unreadCount;
  final int page;
  final int size;
}
