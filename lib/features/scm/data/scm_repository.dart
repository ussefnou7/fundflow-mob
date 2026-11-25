import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../domain/scm_models.dart';

class ScmRepository {
  const ScmRepository(this._client);

  final ApiClient _client;

  Future<ScmPage<ScmDocumentSummary>> documents(
    ScmDocumentKind kind, {
    int page = 0,
    int size = 20,
  }) async {
    final query = Uri(
      queryParameters: {'page': '$page', 'size': '$size'},
    ).query;
    final json = requireMap(await _client.get('${kind.path}?$query'));
    return ScmPage(
      items: (json['items'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                ScmDocumentSummary.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? page,
      size: (json['size'] as num?)?.toInt() ?? size,
    );
  }

  Future<ScmDocumentDetail> document(ScmDocumentKind kind, String id) async =>
      ScmDocumentDetail.fromJson(
        requireMap(await _client.get('${kind.path}/$id')),
      );

  Future<ScmOptions> options() async =>
      ScmOptions.fromJson(requireMap(await _client.get('/scm/options')));

  Future<List<ScmCatalogMaterial>> materials({
    required bool catalogAccess,
  }) async {
    if (!catalogAccess) {
      final values = await options();
      return values.materials
          .map(ScmCatalogMaterial.fromOption)
          .toList(growable: false);
    }
    return requireList(await _client.get('/settings/materials'))
        .whereType<Map>()
        .map(
          (item) =>
              ScmCatalogMaterial.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  /// Every active unit. The endpoint answers in pages of at most 100.
  Future<List<ScmRef>> units() async {
    final units = <ScmRef>[];
    for (var page = 0; ; page++) {
      final body = requireMap(
        await _client.get('/settings/units?active=true&page=$page&size=100'),
      );
      final items = (body['items'] as List? ?? const []).whereType<Map>();
      units.addAll(items.map(ScmRef.fromJson));
      final total = (body['total'] as num?)?.toInt() ?? units.length;
      if (items.isEmpty || units.length >= total) return units;
    }
  }

  Future<ScmCatalogMaterial> saveMaterial({
    ScmCatalogMaterial? material,
    required String code,
    required String name,
    required String unitId,
    String? description,
    required bool active,
  }) async {
    final body = {
      'code': code.trim(),
      'name': name.trim(),
      'unitId': unitId,
      if (description?.trim().isNotEmpty == true)
        'description': description!.trim(),
      'active': active,
      if (material != null) 'version': material.version,
    };
    final response = material == null
        ? await _client.postJson('/settings/materials', body)
        : await _client.putJson('/settings/materials/${material.id}', body);
    return ScmCatalogMaterial.fromJson(requireMap(response));
  }

  Future<ScmCatalogMaterial> saveMaterialConversion({
    required ScmCatalogMaterial material,
    ScmMaterialConversion? conversion,
    required String unitId,
    required String conversionToBase,
    String? purchaseIncrement,
    String? notes,
  }) async => ScmCatalogMaterial.fromJson(
    requireMap(
      await _client
          .putJson('/settings/materials/${material.id}/units/$unitId', {
            'conversionToBase': conversionToBase,
            if (purchaseIncrement?.trim().isNotEmpty == true)
              'purchaseIncrement': purchaseIncrement!.trim(),
            if (notes?.trim().isNotEmpty == true) 'notes': notes!.trim(),
            if (conversion != null) 'version': conversion.version,
          }),
    ),
  );

  Future<void> deleteMaterialConversion({
    required ScmCatalogMaterial material,
    required ScmMaterialConversion conversion,
  }) async {
    await _client.delete(
      '/settings/materials/${material.id}/units/${conversion.unit.id}'
      '?version=${conversion.version}',
    );
  }

  Future<ScmDocumentDetail> createRequest({
    required String warehouseId,
    required String date,
    String? needDate,
    String? notes,
    required List<Map<String, dynamic>> lines,
  }) async => ScmDocumentDetail.fromJson(
    requireMap(
      await _client.postJson('/scm/purchase-requests', {
        'warehouseId': warehouseId,
        'dateTrx': date,
        'needDate': ?needDate,
        if (notes?.trim().isNotEmpty == true) 'notes': notes!.trim(),
        'lines': lines,
      }),
    ),
  );

  Future<ScmDocumentDetail> updateRequest({
    required String id,
    required int version,
    required String warehouseId,
    required String date,
    String? needDate,
    String? notes,
    required List<Map<String, dynamic>> lines,
  }) async => ScmDocumentDetail.fromJson(
    requireMap(
      await _client.putJson('/scm/purchase-requests/$id', {
        'version': version,
        'warehouseId': warehouseId,
        'dateTrx': date,
        'needDate': ?needDate,
        if (notes?.trim().isNotEmpty == true) 'notes': notes!.trim(),
        'lines': lines,
      }),
    ),
  );

  Future<ScmDocumentDetail> submitRequest(String id, int version) async =>
      ScmDocumentDetail.fromJson(
        requireMap(
          await _client.postJson('/scm/purchase-requests/$id/submit', {
            'version': version,
          }),
        ),
      );

  Future<ScmDocumentDetail> createOrder({
    required String warehouseId,
    required String date,
    String? supplierId,
    String? receiverId,
    String? deliveryDate,
    String currencyCode = 'EGP',
    String transportCost = '0',
    String? notes,
    required List<Map<String, dynamic>> lines,
  }) async => ScmDocumentDetail.fromJson(
    requireMap(
      await _client.postJson('/scm/purchase-orders', {
        'warehouseId': warehouseId,
        'dateTrx': date,
        'supplierId': ?supplierId,
        'receiverId': ?receiverId,
        'deliveryDate': ?deliveryDate,
        'currencyCode': currencyCode,
        'transportCost': transportCost,
        if (notes?.trim().isNotEmpty == true) 'notes': notes!.trim(),
        'lines': lines,
      }),
    ),
  );

  Future<ScmDocumentDetail> updateOrder({
    required String id,
    required int version,
    required String warehouseId,
    required String date,
    String? supplierId,
    String? receiverId,
    String? deliveryDate,
    String currencyCode = 'EGP',
    String transportCost = '0',
    String? notes,
    required List<Map<String, dynamic>> lines,
  }) async => ScmDocumentDetail.fromJson(
    requireMap(
      await _client.putJson('/scm/purchase-orders/$id', {
        'version': version,
        'warehouseId': warehouseId,
        'dateTrx': date,
        'supplierId': ?supplierId,
        'receiverId': ?receiverId,
        'deliveryDate': ?deliveryDate,
        'currencyCode': currencyCode,
        'transportCost': transportCost,
        if (notes?.trim().isNotEmpty == true) 'notes': notes!.trim(),
        'lines': lines,
      }),
    ),
  );

  Future<ScmDocumentDetail> updateReceipt({
    required String id,
    required int version,
    required String date,
    String? supplierDeliveryNo,
    String? notes,
    required List<Map<String, dynamic>> lines,
  }) async => ScmDocumentDetail.fromJson(
    requireMap(
      await _client.putJson('/scm/receipts/$id', {
        'version': version,
        'dateTrx': date,
        if (supplierDeliveryNo?.trim().isNotEmpty == true)
          'supplierDeliveryNo': supplierDeliveryNo!.trim(),
        if (notes?.trim().isNotEmpty == true) 'notes': notes!.trim(),
        'lines': lines,
      }),
    ),
  );

  Future<ScmDocumentDetail> createCashPurchase({
    required String warehouseId,
    required String date,
    required String categoryId,
    String? supplierId,
    String? supplierName,
    String? invoiceNo,
    String transportCost = '0',
    String? notes,
    required List<Map<String, dynamic>> lines,
    List<String> imagePaths = const [],
  }) async => ScmDocumentDetail.fromJson(
    requireMap(
      await _client.postMultipartFiles(
        '/scm/cash-purchases',
        jsonPartName: 'purchase',
        filePartName: 'images',
        filePaths: imagePaths,
        json: {
          'warehouseId': warehouseId,
          'dateTrx': date,
          'categoryId': categoryId,
          'supplierId': ?supplierId,
          if (supplierName?.trim().isNotEmpty == true)
            'supplierName': supplierName!.trim(),
          if (invoiceNo?.trim().isNotEmpty == true)
            'invoiceNo': invoiceNo!.trim(),
          'transportCost': transportCost,
          if (notes?.trim().isNotEmpty == true) 'notes': notes!.trim(),
          'lines': lines,
        },
      ),
    ),
  );

  Future<ScmDocumentDetail> submitOrder(String id, int version) async =>
      ScmDocumentDetail.fromJson(
        requireMap(
          await _client.postJson('/scm/purchase-orders/$id/submit', {
            'version': version,
          }),
        ),
      );

  Future<ScmDocumentDetail> confirmReceipt(String id, int version) async =>
      ScmDocumentDetail.fromJson(
        requireMap(
          await _client.postJson('/scm/receipts/$id/confirm', {
            'version': version,
          }),
        ),
      );

  Future<List<ScmStockBalance>> stock() async =>
      requireList(await _client.get('/scm/stock'))
          .whereType<Map>()
          .map((item) {
            return ScmStockBalance.fromJson(Map<String, dynamic>.from(item));
          })
          .toList(growable: false);

  Future<List<ScmDirectoryEntry>> directory(ScmDirectoryKind kind) async {
    final path = kind == ScmDirectoryKind.warehouses
        ? '/scm/warehouses'
        : '/scm/suppliers';
    return requireList(await _client.get(path))
        .whereType<Map>()
        .map(
          (item) =>
              ScmDirectoryEntry.fromJson(Map<String, dynamic>.from(item), kind),
        )
        .toList(growable: false);
  }
}
