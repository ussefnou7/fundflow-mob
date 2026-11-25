class ScmRef {
  const ScmRef({required this.id, required this.name, this.code});

  factory ScmRef.fromJson(dynamic value) {
    final json = value is Map
        ? Map<String, dynamic>.from(value)
        : const <String, dynamic>{};
    return ScmRef(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '—',
      code: json['code']?.toString(),
    );
  }

  final String id, name;
  final String? code;
}

enum ScmDocumentKind { requests, orders, receipts, cashPurchases }

extension ScmDocumentKindApi on ScmDocumentKind {
  String get path => switch (this) {
    ScmDocumentKind.requests => '/scm/purchase-requests',
    ScmDocumentKind.orders => '/scm/purchase-orders',
    ScmDocumentKind.receipts => '/scm/receipts',
    ScmDocumentKind.cashPurchases => '/scm/cash-purchases',
  };
}

class ScmPage<T> {
  const ScmPage({
    required this.items,
    required this.total,
    required this.page,
    required this.size,
  });

  final List<T> items;
  final int total, page, size;
}

class ScmDocumentSummary {
  const ScmDocumentSummary({
    required this.id,
    required this.documentNo,
    required this.date,
    required this.status,
    required this.warehouse,
    this.party,
    this.total,
    this.transportCost,
    this.currency,
    this.lineCount,
  });

  factory ScmDocumentSummary.fromJson(Map<String, dynamic> json) {
    String? person(dynamic value) {
      if (value is Map) return value['name']?.toString();
      return value?.toString();
    }

    return ScmDocumentSummary(
      id: json['id']?.toString() ?? '',
      documentNo: json['documentNo']?.toString() ?? '—',
      date: json['dateTrx']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      warehouse: ScmRef.fromJson(json['warehouse']),
      party:
          person(json['supplier']) ??
          person(json['requestedBy']) ??
          person(json['receivedBy']) ??
          person(json['purchasedBy']),
      total: json['totalAmount']?.toString(),
      transportCost: json['transportCost']?.toString(),
      currency: json['currencyCode']?.toString(),
      lineCount: (json['lineCount'] as num?)?.toInt(),
    );
  }

  final String id, documentNo, date, status;
  final ScmRef warehouse;
  final String? party, total, transportCost, currency;
  final int? lineCount;
}

class ScmDocumentLine {
  const ScmDocumentLine({
    required this.id,
    required this.material,
    required this.unitRef,
    required this.description,
    required this.unit,
    this.requestLineId,
    this.quantity,
    this.approvedQuantity,
    this.receivedQuantity,
    this.unitPrice,
    this.total,
    this.notes,
  });

  factory ScmDocumentLine.fromJson(Map<String, dynamic> json) =>
      ScmDocumentLine(
        id: json['id']?.toString() ?? '',
        material: ScmRef.fromJson(json['material']),
        unitRef: ScmRef.fromJson(json['unit']),
        description: ScmRef.fromJson(json['material']).name,
        unit: ScmRef.fromJson(json['unit']).name,
        quantity:
            json['quantity']?.toString() ??
            json['orderedQuantity']?.toString() ??
            json['dueQuantity']?.toString(),
        approvedQuantity: json['approvedQuantity']?.toString(),
        receivedQuantity: json['receivedQuantity']?.toString(),
        unitPrice: json['unitPrice']?.toString(),
        total: json['lineTotal']?.toString(),
        notes: json['notes']?.toString(),
        requestLineId: json['requestLineId']?.toString(),
      );

  final String id, description, unit;
  final ScmRef material, unitRef;
  final String? requestLineId;
  final String? quantity, approvedQuantity, receivedQuantity, unitPrice, total;
  final String? notes;
}

class ScmDocumentDetail {
  const ScmDocumentDetail({
    required this.id,
    required this.documentNo,
    required this.date,
    required this.status,
    required this.warehouse,
    required this.lines,
    required this.version,
    this.party,
    this.notes,
    this.total,
    this.transportCost,
    this.currency,
    this.pricesVisible = false,
    this.needDate,
    this.deliveryDate,
    this.supplierDeliveryNo,
    this.supplier,
    this.receiver,
    this.requestedBy,
    this.receivedBy,
  });

  factory ScmDocumentDetail.fromJson(Map<String, dynamic> json) {
    String? person(dynamic value) {
      if (value is Map) return value['name']?.toString();
      return value?.toString();
    }

    return ScmDocumentDetail(
      id: json['id']?.toString() ?? '',
      documentNo: json['documentNo']?.toString() ?? '—',
      date: json['dateTrx']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      warehouse: ScmRef.fromJson(json['warehouse']),
      party:
          person(json['supplier']) ??
          person(json['requestedBy']) ??
          person(json['receivedBy']) ??
          person(json['purchasedBy']),
      notes: json['notes']?.toString(),
      total: json['totalAmount']?.toString(),
      transportCost: json['transportCost']?.toString(),
      currency: json['currencyCode']?.toString(),
      pricesVisible:
          json['pricesVisible'] == true || json['totalAmount'] != null,
      needDate: json['needDate']?.toString(),
      deliveryDate: json['deliveryDate']?.toString(),
      supplierDeliveryNo: json['supplierDeliveryNo']?.toString(),
      supplier: json['supplier'] == null
          ? null
          : ScmRef.fromJson(json['supplier']),
      receiver: json['receiver'] == null
          ? null
          : ScmRef.fromJson(json['receiver']),
      requestedBy: json['requestedBy'] == null
          ? null
          : ScmRef.fromJson(json['requestedBy']),
      receivedBy: json['receivedBy'] == null
          ? null
          : ScmRef.fromJson(json['receivedBy']),
      version: (json['version'] as num?)?.toInt() ?? 0,
      lines: (json['lines'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => ScmDocumentLine.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
    );
  }

  final String id, documentNo, date, status;
  final ScmRef warehouse;
  final List<ScmDocumentLine> lines;
  final int version;
  final String? party, notes, total, transportCost, currency;
  final String? needDate, deliveryDate, supplierDeliveryNo;
  final ScmRef? supplier, receiver, requestedBy, receivedBy;
  final bool pricesVisible;
}

class ScmMaterialUnit {
  const ScmMaterialUnit({required this.id, required this.name, this.code});

  factory ScmMaterialUnit.fromJson(Map<String, dynamic> json) =>
      ScmMaterialUnit(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '—',
        code: json['code']?.toString(),
      );

  final String id, name;
  final String? code;
}

class ScmMaterial {
  const ScmMaterial({
    required this.id,
    required this.name,
    required this.units,
    this.code,
    this.baseUnit,
  });

  factory ScmMaterial.fromJson(Map<String, dynamic> json) => ScmMaterial(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '—',
    code: json['code']?.toString(),
    baseUnit: json['baseUnit'] == null
        ? null
        : ScmRef.fromJson(json['baseUnit']),
    units: (json['units'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => ScmMaterialUnit.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false),
  );

  final String id, name;
  final String? code;
  final ScmRef? baseUnit;
  final List<ScmMaterialUnit> units;
}

class ScmMaterialConversion {
  const ScmMaterialConversion({
    required this.id,
    required this.unit,
    required this.conversionToBase,
    required this.version,
    this.purchaseIncrement,
    this.notes,
  });

  factory ScmMaterialConversion.fromJson(Map<String, dynamic> json) =>
      ScmMaterialConversion(
        id: json['id']?.toString() ?? '',
        unit: ScmRef.fromJson(json['unit']),
        conversionToBase: json['conversionToBase']?.toString() ?? '1',
        purchaseIncrement: json['purchaseIncrement']?.toString(),
        notes: json['notes']?.toString(),
        version: (json['version'] as num?)?.toInt() ?? 0,
      );

  final String id, conversionToBase;
  final ScmRef unit;
  final String? purchaseIncrement, notes;
  final int version;
}

class ScmCatalogMaterial {
  const ScmCatalogMaterial({
    required this.id,
    required this.code,
    required this.name,
    required this.baseUnit,
    required this.active,
    required this.conversions,
    required this.version,
    this.description,
  });

  factory ScmCatalogMaterial.fromJson(
    Map<String, dynamic> json,
  ) => ScmCatalogMaterial(
    id: json['id']?.toString() ?? '',
    code: json['code']?.toString() ?? '',
    name: json['name']?.toString() ?? '—',
    baseUnit: ScmRef.fromJson(json['unit'] ?? json['baseUnit']),
    description: json['description']?.toString(),
    active: json['active'] != false,
    conversions: (json['conversions'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              ScmMaterialConversion.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false),
    version: (json['version'] as num?)?.toInt() ?? 0,
  );

  factory ScmCatalogMaterial.fromOption(ScmMaterial value) =>
      ScmCatalogMaterial(
        id: value.id,
        code: value.code ?? '',
        name: value.name,
        baseUnit:
            value.baseUnit ??
            (value.units.isEmpty
                ? const ScmRef(id: '', name: '—')
                : ScmRef(
                    id: value.units.first.id,
                    code: value.units.first.code,
                    name: value.units.first.name,
                  )),
        active: true,
        conversions: [
          for (final unit in value.units)
            ScmMaterialConversion(
              id: unit.id,
              unit: ScmRef(id: unit.id, code: unit.code, name: unit.name),
              conversionToBase: '1',
              version: 0,
            ),
        ],
        version: 0,
      );

  final String id, code, name;
  final ScmRef baseUnit;
  final String? description;
  final bool active;
  final List<ScmMaterialConversion> conversions;
  final int version;
}

class ScmOptions {
  const ScmOptions({
    required this.warehouses,
    required this.materials,
    this.members = const [],
    this.suppliers = const [],
    this.expenseCategories = const [],
  });

  factory ScmOptions.fromJson(Map<String, dynamic> json) => ScmOptions(
    warehouses: (json['warehouses'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => ScmRef.fromJson(item))
        .toList(growable: false),
    materials: (json['materials'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => ScmMaterial.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false),
    members: _scmRefs(json['members']),
    suppliers: _scmRefs(json['suppliers']),
    expenseCategories: _scmRefs(json['expenseCategories']),
  );

  final List<ScmRef> warehouses;
  final List<ScmMaterial> materials;
  final List<ScmRef> members, suppliers, expenseCategories;
}

List<ScmRef> _scmRefs(dynamic value) => (value as List? ?? const [])
    .whereType<Map>()
    .map((item) => ScmRef.fromJson(item))
    .toList(growable: false);

class ScmStockBalance {
  const ScmStockBalance({
    required this.warehouse,
    required this.material,
    required this.unit,
    required this.quantity,
  });

  factory ScmStockBalance.fromJson(Map<String, dynamic> json) =>
      ScmStockBalance(
        warehouse: ScmRef.fromJson(json['warehouse']),
        material: ScmRef.fromJson(json['material']),
        unit: ScmRef.fromJson(json['baseUnit']),
        quantity: json['quantity']?.toString() ?? '0',
      );

  final ScmRef warehouse, material, unit;
  final String quantity;
}

enum ScmDirectoryKind { warehouses, suppliers }

class ScmDirectoryEntry {
  const ScmDirectoryEntry({
    required this.id,
    required this.code,
    required this.name,
    required this.active,
    this.subtitle,
  });

  factory ScmDirectoryEntry.fromJson(
    Map<String, dynamic> json,
    ScmDirectoryKind kind,
  ) {
    final costCenter = ScmRef.fromJson(json['costCenter']);
    final keeper = ScmRef.fromJson(json['keeper']);
    final details = kind == ScmDirectoryKind.warehouses
        ? [
            if (costCenter.id.isNotEmpty) costCenter.name,
            if (keeper.id.isNotEmpty) 'أمين المخزن: ${keeper.name}',
          ]
        : [
            if (json['contactName']?.toString().isNotEmpty == true)
              json['contactName'].toString(),
            if (json['phone']?.toString().isNotEmpty == true)
              json['phone'].toString(),
          ];
    return ScmDirectoryEntry(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '—',
      active: json['active'] != false,
      subtitle: details.isEmpty ? null : details.join(' · '),
    );
  }

  final String id, code, name;
  final bool active;
  final String? subtitle;
}
