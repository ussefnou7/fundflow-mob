import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_pagination.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_table.dart';
import '../../custody/domain/custody_models.dart' show shortDate;
import '../../custody/presentation/custody_widgets.dart';
import '../../scm/data/scm_repository.dart';
import '../../scm/domain/scm_models.dart';
import '../../scm/presentation/scm_screens.dart';
import '../data/workflow_repository.dart';
import '../domain/workflow_models.dart';

class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({
    super.key,
    required this.repository,
    required this.permissions,
    this.currentUserId,
    this.scm,
    this.onCountChanged,
  });

  final WorkflowRepository repository;
  final Set<String> permissions;
  final String? currentUserId;
  final ScmRepository? scm;
  final ValueChanged<WorkflowInboxCount>? onCountChanged;

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  WorkflowInbox? _inbox;
  int _page = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait([
        widget.repository.inbox(page: _page),
        widget.repository.count(),
      ]);
      if (!mounted) return;
      setState(() {
        _inbox = values[0] as WorkflowInbox;
      });
      widget.onCountChanged?.call(values[1] as WorkflowInboxCount);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(WorkflowInboxRow row) async {
    final scmKind = _scmKind(row.docType);
    if (scmKind != null && widget.scm != null) {
      final changed = await showScmDocumentDetail(
        context,
        repository: widget.scm!,
        kind: scmKind,
        id: row.docId,
        documentNo: row.number ?? '',
        permissions: widget.permissions,
        currentUserId: widget.currentUserId,
        workflow: widget.repository,
      );
      if (changed == true && mounted) await _load();
      return;
    }
    final changed = await showAppSheet<bool>(
      context,
      tall: true,
      builder: (_) =>
          _ApprovalDetailSheet(repository: widget.repository, row: row),
    );
    if (changed == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _inbox?.items ?? const <WorkflowInboxRow>[];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          PageHeader(
            title: 'طلبات الموافقة',
            subtitle: 'كل المستندات التي تنتظر موافقتك',
            action: IconButton(
              tooltip: 'تحديث',
              onPressed: _loading ? null : _load,
              icon: const Icon(LucideIcons.refreshCw),
            ),
          ),
          const SizedBox(height: 14),
          if (_loading && _inbox != null) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(minHeight: 2),
          ],
          const SizedBox(height: 12),
          if (_error != null)
            MessagePanel(message: _error!, onRetry: _load)
          else if (_loading && _inbox == null)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (rows.isEmpty)
            AppEmptyState(
              icon: LucideIcons.inbox,
              title: 'لا شيء ينتظر موافقتك',
              message: 'أي طلب يصل إليك سيظهر هنا ويصلك إشعار به.',
            )
          else ...[
            for (final row in rows) ...[
              _ApprovalCard(row: row, onTap: () => _open(row)),
              const SizedBox(height: 10),
            ],
            AppPagination(
              page: _page,
              size: _inbox!.size,
              total: _inbox!.total,
              disabled: _loading,
              onChanged: (page) {
                setState(() => _page = page);
                _load();
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({required this.row, required this.onTap});
  final WorkflowInboxRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: context.tokens.line),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.tokens.wash,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    LucideIcons.fileCheck2,
                    color: context.tokens.brandStrong,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${row.docTypeName}${row.number?.isNotEmpty == true ? ' ${row.number}' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      if (row.title?.isNotEmpty == true)
                        Text(
                          row.title!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.tokens.muted,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(LucideIcons.chevronLeft, size: 18),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (row.step?.isNotEmpty == true)
                  AppTag(row.step!, icon: LucideIcons.route),
                AppTag(row.submittedBy.name, icon: LucideIcons.user),
                AppTag(shortDate(row.submittedAt), icon: LucideIcons.calendar),
              ],
            ),
            if (row.amount != null) ...[
              const SizedBox(height: 10),
              AppMoney(row.amount!),
            ],
          ],
        ),
      ),
    ),
  );
}

class _ApprovalDetailSheet extends StatelessWidget {
  const _ApprovalDetailSheet({required this.repository, required this.row});
  final WorkflowRepository repository;
  final WorkflowInboxRow row;

  @override
  Widget build(BuildContext context) => AppSheetScaffold(
    title:
        '${row.docTypeName}${row.number?.isNotEmpty == true ? ' ${row.number}' : ''}',
    subtitle: row.title ?? 'تفاصيل دورة الموافقة',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Fact(label: 'مقدم الطلب', value: row.submittedBy.name),
        _Fact(label: 'تاريخ الإرسال', value: shortDate(row.submittedAt)),
        if (row.amount != null) _Fact(label: 'القيمة', value: row.amount!),
        const SizedBox(height: 14),
        const MessagePanel(
          message:
              'الموافقة متاحة من شاشة المستند الكاملة فقط، حتى تراجع كل بياناته قبل اتخاذ القرار.',
        ),
      ],
    ),
  );
}

ScmDocumentKind? _scmKind(String docType) => switch (docType) {
  'PURCHASE_REQUEST' => ScmDocumentKind.requests,
  'PURCHASE_ORDER' => ScmDocumentKind.orders,
  'RECEIPT' => ScmDocumentKind.receipts,
  'CASH_PURCHASE' => ScmDocumentKind.cashPurchases,
  _ => null,
};

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: TextStyle(color: context.tokens.muted)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}
