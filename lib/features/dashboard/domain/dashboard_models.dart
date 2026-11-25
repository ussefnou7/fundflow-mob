/// The follow-up board (لوحة المتابعة), as GET /api/dashboard returns it.
///
/// A section the viewer has no permission for comes back null and is not drawn.
/// Money stays a decimal string and is never added across currencies.
class FollowUpBoard {
  const FollowUpBoard({
    required this.today,
    required this.inbox,
    required this.liquidity,
    required this.alerts,
    required this.payables,
    required this.purchasing,
    required this.crm,
    required this.custodyExpenseTrend,
  });

  /// `yyyy-MM-dd` in the server's application zone.
  final String today;
  final List<InboxItem> inbox;
  final Liquidity? liquidity;
  final List<BoardAlert> alerts;
  final Payables? payables;
  final Purchasing? purchasing;
  final CrmSummary? crm;
  final List<MonthTotal>? custodyExpenseTrend;

  factory FollowUpBoard.fromJson(Map<String, dynamic> json) => FollowUpBoard(
    today: json['today'] as String? ?? '',
    inbox: _list(json['inbox'], InboxItem.fromJson),
    liquidity: _object(json['liquidity'], Liquidity.fromJson),
    alerts: _list(json['alerts'], BoardAlert.fromJson),
    payables: _object(json['payables'], Payables.fromJson),
    purchasing: _object(json['purchasing'], Purchasing.fromJson),
    crm: _object(json['crm'], CrmSummary.fromJson),
    custodyExpenseTrend: json['custodyExpenseTrend'] == null
        ? null
        : _list(json['custodyExpenseTrend'], MonthTotal.fromJson),
  );
}

class CurrencyAmount {
  const CurrencyAmount({
    required this.code,
    required this.arabicCode,
    required this.amount,
  });
  final String code;
  final String arabicCode;
  final String amount;

  factory CurrencyAmount.fromJson(Map<String, dynamic> json) => CurrencyAmount(
    code: json['currencyCode'] as String? ?? '',
    arabicCode:
        json['currencyCodeAr'] as String? ??
        json['currencyCode'] as String? ??
        '',
    amount: '${json['amount'] ?? '0'}',
  );
}

class InboxItem {
  const InboxItem({required this.kind, required this.count, this.amount});
  final String kind;
  final int count;
  final String? amount;

  factory InboxItem.fromJson(Map<String, dynamic> json) => InboxItem(
    kind: json['kind'] as String? ?? '',
    count: (json['count'] as num?)?.toInt() ?? 0,
    amount: json['amount'] as String?,
  );
}

class Liquidity {
  const Liquidity({
    required this.treasuries,
    required this.treasuryTotals,
    required this.custody,
    required this.monthCustodyExpenses,
    required this.previousMonthCustodyExpenses,
  });
  final List<TreasuryBalance>? treasuries;
  final List<CurrencyAmount>? treasuryTotals;
  final CustodyHoldings? custody;
  final List<CurrencyAmount>? monthCustodyExpenses;
  final List<CurrencyAmount>? previousMonthCustodyExpenses;

  factory Liquidity.fromJson(Map<String, dynamic> json) => Liquidity(
    treasuries: _nullableList(json['treasuries'], TreasuryBalance.fromJson),
    treasuryTotals: _nullableList(
      json['treasuryTotals'],
      CurrencyAmount.fromJson,
    ),
    custody: _object(json['custody'], CustodyHoldings.fromJson),
    monthCustodyExpenses: _nullableList(
      json['monthCustodyExpenses'],
      CurrencyAmount.fromJson,
    ),
    previousMonthCustodyExpenses: _nullableList(
      json['previousMonthCustodyExpenses'],
      CurrencyAmount.fromJson,
    ),
  );
}

class TreasuryBalance {
  const TreasuryBalance({
    required this.id,
    required this.name,
    required this.arabicCode,
    required this.balance,
  });
  final String id;
  final String name;
  final String arabicCode;
  final String balance;

  factory TreasuryBalance.fromJson(Map<String, dynamic> json) =>
      TreasuryBalance(
        id: '${json['id']}',
        name: json['name'] as String? ?? '',
        arabicCode:
            json['currencyCodeAr'] as String? ??
            json['currencyCode'] as String? ??
            '',
        balance: '${json['balance'] ?? '0'}',
      );
}

class CustodyHoldings {
  const CustodyHoldings({required this.holders, required this.balances});
  final int holders;
  final List<CurrencyAmount> balances;

  factory CustodyHoldings.fromJson(Map<String, dynamic> json) =>
      CustodyHoldings(
        holders: (json['holders'] as num?)?.toInt() ?? 0,
        balances: _list(json['balances'], CurrencyAmount.fromJson),
      );
}

class BoardAlert {
  const BoardAlert({
    required this.kind,
    required this.level,
    required this.count,
    this.subject,
    this.days,
    this.amount,
  });
  final String kind;
  final String level;
  final int count;
  final String? subject;
  final int? days;
  final String? amount;

  factory BoardAlert.fromJson(Map<String, dynamic> json) => BoardAlert(
    kind: json['kind'] as String? ?? '',
    level: json['level'] as String? ?? 'INFO',
    count: (json['count'] as num?)?.toInt() ?? 0,
    subject: json['subject'] as String?,
    days: (json['days'] as num?)?.toInt(),
    amount: json['amount'] as String?,
  );
}

class Payables {
  const Payables({
    required this.total,
    required this.extracts,
    required this.contractors,
    required this.aging,
  });
  final String total;
  final int extracts;
  final int contractors;
  final List<AgingBucket> aging;

  factory Payables.fromJson(Map<String, dynamic> json) => Payables(
    total: '${json['total'] ?? '0'}',
    extracts: (json['extracts'] as num?)?.toInt() ?? 0,
    contractors: (json['contractors'] as num?)?.toInt() ?? 0,
    aging: _list(json['aging'], AgingBucket.fromJson),
  );
}

class AgingBucket {
  const AgingBucket({
    required this.range,
    required this.extracts,
    required this.amount,
  });

  /// UNDER_30, FROM_30_TO_60 or OVER_60.
  final String range;
  final int extracts;
  final String amount;

  factory AgingBucket.fromJson(Map<String, dynamic> json) => AgingBucket(
    range: json['range'] as String? ?? '',
    extracts: (json['extracts'] as num?)?.toInt() ?? 0,
    amount: '${json['amount'] ?? '0'}',
  );
}

class Purchasing {
  const Purchasing({
    required this.openOrders,
    required this.ordersAwaitingApproval,
    this.monthCashPurchases,
  });

  /// Approved or partly received orders: the ones still waiting for goods.
  final int openOrders;
  final int ordersAwaitingApproval;
  final String? monthCashPurchases;

  factory Purchasing.fromJson(Map<String, dynamic> json) => Purchasing(
    openOrders: (json['openOrders'] as num?)?.toInt() ?? 0,
    ordersAwaitingApproval:
        (json['ordersAwaitingApproval'] as num?)?.toInt() ?? 0,
    monthCashPurchases: json['monthCashPurchases'] as String?,
  );
}

class CrmSummary {
  const CrmSummary({
    required this.newLeadsThisWeek,
    required this.upcomingInspections,
    required this.overdueFollowUps,
  });
  final int newLeadsThisWeek;
  final int upcomingInspections;
  final int overdueFollowUps;

  factory CrmSummary.fromJson(Map<String, dynamic> json) => CrmSummary(
    newLeadsThisWeek: (json['newLeadsThisWeek'] as num?)?.toInt() ?? 0,
    upcomingInspections: (json['upcomingInspections'] as num?)?.toInt() ?? 0,
    overdueFollowUps: (json['overdueFollowUps'] as num?)?.toInt() ?? 0,
  );
}

class MonthTotal {
  const MonthTotal({
    required this.year,
    required this.month,
    required this.totals,
  });
  final int year;
  final int month;
  final List<CurrencyAmount> totals;

  factory MonthTotal.fromJson(Map<String, dynamic> json) => MonthTotal(
    year: (json['year'] as num?)?.toInt() ?? 0,
    month: (json['month'] as num?)?.toInt() ?? 1,
    totals: _list(json['totals'], CurrencyAmount.fromJson),
  );
}

List<T> _list<T>(Object? value, T Function(Map<String, dynamic>) parse) =>
    value is List
    ? value.whereType<Map<String, dynamic>>().map(parse).toList()
    : <T>[];

List<T>? _nullableList<T>(
  Object? value,
  T Function(Map<String, dynamic>) parse,
) => value == null ? null : _list(value, parse);

T? _object<T>(Object? value, T Function(Map<String, dynamic>) parse) =>
    value is Map<String, dynamic> ? parse(value) : null;
