class CrmRef {
  const CrmRef({required this.id, required this.name, this.code});
  factory CrmRef.fromJson(dynamic value) {
    final json = value is Map
        ? Map<String, dynamic>.from(value)
        : const <String, dynamic>{};
    return CrmRef(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '—',
      code: json['code']?.toString(),
    );
  }
  final String id, name;
  final String? code;
}

String crmEnglishDateTime(String? raw) {
  if (raw == null || raw.isEmpty) return '—';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final value = parsed.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year} '
      '${two(value.hour)}:${two(value.minute)}';
}

String crmOffsetIso(DateTime value) => value.toUtc().toIso8601String();

enum CrmDashboardPeriod { today, week, month }

extension CrmDashboardPeriodApi on CrmDashboardPeriod {
  String get api => name.toUpperCase();
}

class CrmInspectionDashboard {
  const CrmInspectionDashboard({
    required this.period,
    required this.from,
    required this.to,
    required this.kpis,
    required this.today,
    required this.statuses,
    required this.engineers,
    required this.financial,
  });

  factory CrmInspectionDashboard.fromJson(Map<String, dynamic> json) =>
      CrmInspectionDashboard(
        period: CrmDashboardPeriod.values.firstWhere(
          (value) => value.api == json['period']?.toString(),
          orElse: () => CrmDashboardPeriod.today,
        ),
        from: json['from']?.toString() ?? '',
        to: json['to']?.toString() ?? '',
        kpis: CrmDashboardKpis.fromJson(json['kpis']),
        today: (json['today'] as List? ?? const [])
            .whereType<Map>()
            .map(CrmDashboardSchedule.fromJson)
            .toList(growable: false),
        statuses: (json['statuses'] as List? ?? const [])
            .whereType<Map>()
            .map(CrmDashboardStatus.fromJson)
            .toList(growable: false),
        engineers: (json['engineers'] as List? ?? const [])
            .whereType<Map>()
            .map(CrmEngineerPerformance.fromJson)
            .toList(growable: false),
        financial: CrmDashboardFinancial.fromJson(json['financial']),
      );

  final CrmDashboardPeriod period;
  final String from, to;
  final CrmDashboardKpis kpis;
  final List<CrmDashboardSchedule> today;
  final List<CrmDashboardStatus> statuses;
  final List<CrmEngineerPerformance> engineers;
  final CrmDashboardFinancial financial;
}

class CrmDashboardKpis {
  const CrmDashboardKpis({
    required this.total,
    required this.done,
    required this.overdue,
    required this.rescheduled,
    required this.collected,
  });
  factory CrmDashboardKpis.fromJson(dynamic value) {
    final json = value is Map ? value : const {};
    return CrmDashboardKpis(
      total: (json['total'] as num?)?.toInt() ?? 0,
      done: (json['done'] as num?)?.toInt() ?? 0,
      overdue: (json['overdue'] as num?)?.toInt() ?? 0,
      rescheduled: (json['rescheduled'] as num?)?.toInt() ?? 0,
      collected: json['collected']?.toString() ?? '0',
    );
  }
  final int total, done, overdue, rescheduled;
  final String collected;
}

class CrmDashboardSchedule {
  const CrmDashboardSchedule({
    required this.id,
    required this.scheduledAt,
    required this.leadId,
    required this.leadName,
    required this.inspectionType,
    required this.engineer,
    required this.agreedPrice,
    this.area,
  });
  factory CrmDashboardSchedule.fromJson(Map<dynamic, dynamic> json) =>
      CrmDashboardSchedule(
        id: json['id']?.toString() ?? '',
        scheduledAt: json['scheduledAt']?.toString() ?? '',
        leadId: json['leadId']?.toString() ?? '',
        leadName: json['leadName']?.toString() ?? '—',
        area: json['area']?.toString(),
        inspectionType: json['inspectionType']?.toString() ?? '—',
        engineer: json['engineer']?.toString() ?? '—',
        agreedPrice: json['agreedPrice']?.toString() ?? '0',
      );
  final String id, scheduledAt, leadId, leadName;
  final String? area;
  final String inspectionType, engineer, agreedPrice;
}

class CrmDashboardStatus {
  const CrmDashboardStatus({required this.status, required this.count});
  factory CrmDashboardStatus.fromJson(Map<dynamic, dynamic> json) =>
      CrmDashboardStatus(
        status: json['status']?.toString() ?? '',
        count: (json['count'] as num?)?.toInt() ?? 0,
      );
  final String status;
  final int count;
}

class CrmEngineerPerformance {
  const CrmEngineerPerformance({
    required this.engineerId,
    required this.engineer,
    required this.inspections,
    required this.done,
    required this.cancelledOrNoShow,
    required this.agreed,
    required this.collected,
  });
  factory CrmEngineerPerformance.fromJson(Map<dynamic, dynamic> json) =>
      CrmEngineerPerformance(
        engineerId: json['engineerId']?.toString() ?? '',
        engineer: json['engineer']?.toString() ?? '—',
        inspections: (json['inspections'] as num?)?.toInt() ?? 0,
        done: (json['done'] as num?)?.toInt() ?? 0,
        cancelledOrNoShow: (json['cancelledOrNoShow'] as num?)?.toInt() ?? 0,
        agreed: json['agreed']?.toString() ?? '0',
        collected: json['collected']?.toString() ?? '0',
      );
  final String engineerId, engineer, agreed, collected;
  final int inspections, done, cancelledOrNoShow;
}

class CrmDashboardFinancial {
  const CrmDashboardFinancial({
    required this.agreed,
    required this.collected,
    required this.expenses,
    required this.net,
  });
  factory CrmDashboardFinancial.fromJson(dynamic value) {
    final json = value is Map ? value : const {};
    return CrmDashboardFinancial(
      agreed: json['agreed']?.toString() ?? '0',
      collected: json['collected']?.toString() ?? '0',
      expenses: json['expenses']?.toString() ?? '0',
      net: json['net']?.toString() ?? '0',
    );
  }
  final String agreed, collected, expenses, net;
}

class CrmPage<T> {
  const CrmPage({
    required this.items,
    required this.total,
    required this.page,
    required this.size,
  });
  final List<T> items;
  final int total, page, size;
}

class CrmLeadSummary {
  const CrmLeadSummary({
    required this.id,
    required this.name,
    required this.mobile,
    required this.status,
    required this.version,
    this.altMobile,
    this.area,
    this.owner,
    this.source,
    this.nextFollowUpAt,
    this.lastContactAt,
    this.createdAt,
  });
  factory CrmLeadSummary.fromJson(Map<String, dynamic> json) => CrmLeadSummary(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '—',
    mobile: json['mobile']?.toString() ?? '',
    altMobile: json['altMobile']?.toString(),
    area: json['area']?.toString(),
    status: json['status']?.toString() ?? 'NEW',
    owner: json['owner'] == null ? null : CrmRef.fromJson(json['owner']),
    source: json['source'] == null ? null : CrmRef.fromJson(json['source']),
    nextFollowUpAt: json['nextFollowUpAt']?.toString(),
    lastContactAt: json['lastContactAt']?.toString(),
    createdAt: json['createdAt']?.toString(),
    version: (json['version'] as num?)?.toInt() ?? 0,
  );
  final String id, name, mobile, status;
  final String? altMobile, area, nextFollowUpAt, lastContactAt, createdAt;
  final CrmRef? owner, source;
  final int version;
}

class CrmBehaviour {
  const CrmBehaviour({
    required this.inspections,
    required this.clientCancellations,
    required this.clientReschedules,
    required this.companyCancellations,
    required this.noShows,
    required this.noAnswers,
  });
  factory CrmBehaviour.fromJson(dynamic value) {
    final json = value is Map ? value : const {};
    int count(String key) => (json[key] as num?)?.toInt() ?? 0;
    return CrmBehaviour(
      inspections: count('inspections'),
      clientCancellations: count('clientCancellations'),
      clientReschedules: count('clientReschedules'),
      companyCancellations: count('companyCancellations'),
      noShows: count('noShows'),
      noAnswers: count('noAnswers'),
    );
  }
  final int inspections,
      clientCancellations,
      clientReschedules,
      companyCancellations,
      noShows,
      noAnswers;
}

class CrmLeadDetail extends CrmLeadSummary {
  const CrmLeadDetail({
    required super.id,
    required super.name,
    required super.mobile,
    required super.status,
    required super.version,
    required this.behaviour,
    super.altMobile,
    super.area,
    super.owner,
    super.source,
    super.nextFollowUpAt,
    super.lastContactAt,
    super.createdAt,
    this.address,
    this.notes,
    this.lostReason,
  });
  factory CrmLeadDetail.fromJson(Map<String, dynamic> json) {
    final base = CrmLeadSummary.fromJson(json);
    return CrmLeadDetail(
      id: base.id,
      name: base.name,
      mobile: base.mobile,
      status: base.status,
      version: base.version,
      behaviour: CrmBehaviour.fromJson(json['behaviour']),
      altMobile: base.altMobile,
      area: base.area,
      owner: base.owner,
      source: base.source,
      nextFollowUpAt: base.nextFollowUpAt,
      lastContactAt: base.lastContactAt,
      createdAt: base.createdAt,
      address: json['address']?.toString(),
      notes: json['notes']?.toString(),
      lostReason: json['lostReason']?.toString(),
    );
  }
  final CrmBehaviour behaviour;
  final String? address, notes, lostReason;
}

class CrmInspection {
  const CrmInspection({
    required this.id,
    required this.lead,
    required this.scheduledAt,
    required this.engineer,
    required this.agreedPrice,
    required this.status,
    required this.expensesTotal,
    required this.version,
    this.address,
    this.latitude,
    this.longitude,
    this.collectedAmount,
    this.net,
    this.engineerReport,
    this.closedAt,
    this.expenses = const [],
  });
  factory CrmInspection.fromJson(Map<String, dynamic> json) => CrmInspection(
    id: json['id']?.toString() ?? '',
    lead: CrmLeadSummary.fromJson(
      Map<String, dynamic>.from(json['lead'] as Map? ?? const {}),
    ),
    scheduledAt: json['scheduledAt']?.toString() ?? '',
    address: json['address']?.toString(),
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    engineer: CrmRef.fromJson(json['engineer']),
    agreedPrice: json['agreedPrice']?.toString() ?? '0',
    status: json['status']?.toString() ?? '',
    collectedAmount: json['collectedAmount']?.toString(),
    expensesTotal: json['expensesTotal']?.toString() ?? '0',
    net: json['net']?.toString(),
    engineerReport: json['engineerReport']?.toString(),
    closedAt: json['closedAt']?.toString(),
    expenses: (json['expenses'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => CrmExpense.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false),
    version: (json['version'] as num?)?.toInt() ?? 0,
  );
  final String id, scheduledAt, agreedPrice, status, expensesTotal;
  final CrmLeadSummary lead;
  final CrmRef engineer;
  final String? address, collectedAmount, net, engineerReport, closedAt;
  final double? latitude, longitude;
  final List<CrmExpense> expenses;
  final int version;
}

class CrmExpense {
  const CrmExpense({
    required this.id,
    required this.expenseType,
    required this.amount,
    required this.version,
    this.note,
    this.attachmentName,
  });
  factory CrmExpense.fromJson(Map<String, dynamic> json) => CrmExpense(
    id: json['id']?.toString() ?? '',
    expenseType: json['expenseType']?.toString() ?? '—',
    amount: json['amount']?.toString() ?? '0',
    note: json['note']?.toString(),
    attachmentName: json['attachmentName']?.toString(),
    version: (json['version'] as num?)?.toInt() ?? 0,
  );
  final String id, expenseType, amount;
  final String? note, attachmentName;
  final int version;
}

class CrmFollowUp {
  const CrmFollowUp({
    required this.id,
    required this.channel,
    required this.occurredAt,
    required this.actor,
    this.outcome,
    this.note,
    this.nextFollowUpAt,
  });
  factory CrmFollowUp.fromJson(Map<String, dynamic> json) => CrmFollowUp(
    id: json['id']?.toString() ?? '',
    channel: json['channel']?.toString() ?? '',
    occurredAt: json['occurredAt']?.toString() ?? '',
    actor: CrmRef.fromJson(json['actor']),
    outcome: json['outcome']?.toString(),
    note: json['note']?.toString(),
    nextFollowUpAt: json['nextFollowUpAt']?.toString(),
  );
  final String id, channel, occurredAt;
  final CrmRef actor;
  final String? outcome, note, nextFollowUpAt;
}

const crmLeadStatusLabels = <String, String>{
  'NEW': 'جديد',
  'CONTACTED': 'تم التواصل',
  'INSPECTION_BOOKED': 'معاينة محجوزة',
  'INSPECTED': 'تمت المعاينة',
  'IN_MEETINGS': 'في الاجتماعات',
  'WON': 'تم الاتفاق',
  'LOST': 'مرفوض',
};
const crmInspectionStatusLabels = <String, String>{
  'BOOKED': 'محجوزة',
  'DONE': 'تمت المعاينة',
  'CANCELLED': 'ملغاة',
  'RESCHEDULED': 'مؤجلة',
  'NO_SHOW': 'لم يحضر',
};

const crmFollowUpChannelLabels = <String, String>{
  'CALL': 'اتصال',
  'WHATSAPP': 'واتساب',
  'VISIT': 'زيارة',
  'OTHER': 'أخرى',
  'SOURCE': 'ورد مجددًا من المصدر',
};

const crmFollowUpOutcomeLabels = <String, String>{
  'ANSWERED': 'تم الرد',
  'NO_ANSWER': 'لم يرد',
  'CALL_LATER': 'اتصال لاحقًا',
  'NOT_INTERESTED': 'غير مهتم',
};

const meetingTypeLabels = <String, String>{
  'IN_PERSON': 'حضوري',
  'ONLINE': 'أونلاين',
  'PHONE': 'هاتف',
};

const meetingStatusLabels = <String, String>{
  'SCHEDULED': 'مجدول',
  'DONE': 'تم',
  'CANCELLED': 'ملغى',
  'RESCHEDULED': 'أعيدت جدولته',
};
