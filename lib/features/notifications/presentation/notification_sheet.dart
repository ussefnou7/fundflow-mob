import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_pagination.dart';
import '../../custody/presentation/custody_widgets.dart';
import '../data/notification_repository.dart';
import '../domain/notification_models.dart';

typedef NotificationSelection =
    Future<bool> Function(AppNotification notification);

class NotificationSheet extends StatefulWidget {
  const NotificationSheet({
    super.key,
    required this.repository,
    this.onCountChanged,
    this.onSelected,
    this.onClose,
    this.embedded = false,
  });

  final NotificationRepository repository;
  final ValueChanged<int>? onCountChanged;
  final NotificationSelection? onSelected;
  final VoidCallback? onClose;
  final bool embedded;

  @override
  State<NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends State<NotificationSheet> {
  NotificationInbox? _inbox;
  int _page = 0;
  bool _loading = true;
  bool _busy = false;
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
      final inbox = await widget.repository.inbox(page: _page);
      if (!mounted) return;
      setState(() => _inbox = inbox);
      widget.onCountChanged?.call(inbox.unreadCount);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _read(AppNotification notification) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (widget.onSelected != null &&
          !await widget.onSelected!(notification)) {
        return;
      }
      await widget.repository.read(notification.id);
      if (!mounted) return;
      final remaining = (_inbox?.unreadCount ?? 1) - 1;
      widget.onCountChanged?.call(remaining < 0 ? 0 : remaining);
      if (widget.onSelected == null) {
        Navigator.pop(context, notification);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _readAll() async {
    if (_busy || (_inbox?.unreadCount ?? 0) == 0) return;
    setState(() => _busy = true);
    try {
      await widget.repository.readAll();
      _page = 0;
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inbox = _inbox;
    final panel = Material(
      color: Colors.white,
      elevation: 10,
      shadowColor: context.tokens.brandStrong.withValues(alpha: .3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: context.tokens.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.md,
              AppSpace.sm,
              AppSpace.md,
              AppSpace.xs,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'الإشعارات',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: context.tokens.ink,
                        ),
                      ),
                    ),
                    if ((inbox?.unreadCount ?? 0) > 0)
                      _CountBadge(count: inbox!.unreadCount),
                    IconButton(
                      tooltip: 'قراءة الكل',
                      onPressed: _busy || (inbox?.unreadCount ?? 0) == 0
                          ? null
                          : _readAll,
                      icon: const Icon(LucideIcons.checkCheck, size: 17),
                    ),
                    IconButton(
                      tooltip: 'إغلاق',
                      onPressed: widget.onClose ?? () => Navigator.pop(context),
                      icon: const Icon(LucideIcons.x, size: 18),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'تظل الإشعارات هنا حتى قراءتها، ثم تُحذف.',
                    style: TextStyle(color: context.tokens.muted, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.tokens.line),
          Expanded(
            child: _error != null
                ? Center(
                    child: MessagePanel(message: _error!, onRetry: _load),
                  )
                : _loading && inbox == null
                ? const Center(child: CircularProgressIndicator())
                : inbox == null || inbox.items.isEmpty
                ? const _EmptyNotifications()
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(AppSpace.sm),
                      itemCount: inbox.items.length + 1,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpace.xs),
                      itemBuilder: (context, index) {
                        if (index == inbox.items.length) {
                          return AppPagination(
                            page: _page,
                            size: inbox.size,
                            total: inbox.total,
                            disabled: _loading || _busy,
                            onChanged: (page) {
                              setState(() => _page = page);
                              _load();
                            },
                          );
                        }
                        final notification = inbox.items[index];
                        return RepaintBoundary(
                          child: _NotificationTile(
                            notification: notification,
                            disabled: _busy,
                            onTap: () => _read(notification),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
    if (widget.embedded) {
      return Directionality(textDirection: TextDirection.rtl, child: panel);
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width - 32,
                height: MediaQuery.sizeOf(context).height * .7,
                child: panel,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.disabled,
    required this.onTap,
  });

  final AppNotification notification;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kind = notification.kind;
    final (icon, color, tint) = kind.contains('REJECTED')
        ? (LucideIcons.x, AppTokens.danger, AppTokens.dangerTint)
        : kind.contains('APPROVED') || kind.contains('RECEIVED')
        ? (LucideIcons.circleCheck, AppTokens.success, AppTokens.successTint)
        : kind.startsWith('CUSTODY_TRANSFER')
        ? (LucideIcons.arrowLeftRight, AppTokens.info, AppTokens.infoTint)
        : (
            LucideIcons.filePlus2,
            context.tokens.brand,
            context.tokens.washStrong,
          );
    // The inbox only holds unread items; reading one removes it.
    return Material(
      color: context.tokens.wash,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(AppSpace.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.companyName,
                      style: TextStyle(
                        color: context.tokens.brand,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: context.tokens.brand,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.6,
                        color: context.tokens.ink.withValues(alpha: .8),
                      ),
                    ),
                    if (notification.dateMismatch)
                      Text(
                        'تنبيه: تاريخ الإنشاء ${notification.creationDate ?? '—'} يختلف عن تاريخ المصروف ${notification.expenseDate ?? '—'}',
                        style: const TextStyle(
                          color: AppTokens.warning,
                          fontSize: 11,
                        ),
                      ),
                    Text(
                      _displayDate(notification.createdAt),
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        color: context.tokens.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: context.tokens.brand,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      '$count',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(LucideIcons.checkCheck, size: 34, color: AppTokens.success),
        const SizedBox(height: AppSpace.sm),
        const Text(
          'لا توجد إشعارات حتى الآن',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        Text(
          'ستظهر هنا تحديثات البنود والموافقات',
          style: TextStyle(color: context.tokens.muted, fontSize: 12),
        ),
      ],
    ),
  );
}

String _displayDate(String value) =>
    value.length >= 16 ? value.substring(0, 16).replaceFirst('T', ' ') : value;
