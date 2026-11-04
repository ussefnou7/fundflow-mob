import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/format/arabic_search.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/application/auth_controller.dart';
import '../../custody/presentation/custody_screen.dart';
import '../../custody/presentation/custody_request_screen.dart';
import '../../custody/presentation/aggregate_custody_screen.dart';
import '../../custody/presentation/custody_widgets.dart';
import '../../custody/presentation/dashboard_screen.dart';
import '../../extracts/presentation/contractor_extract_screen.dart';
import '../../hr/presentation/attendance_log_screen.dart';
import '../../hr/presentation/employee_profile_screen.dart';
import '../../hr/presentation/hr_dashboard_screen.dart';
import '../../hr/presentation/hr_payslips_screen.dart';
import '../../hr/presentation/hr_requests_screen.dart';
import '../../notifications/data/notification_repository.dart';
import '../../notifications/application/push_notification_service.dart';
import '../../notifications/domain/notification_models.dart';
import '../../notifications/presentation/notification_sheet.dart';
import '../../settings/domain/settings_models.dart';
import '../../settings/presentation/reference_settings_screen.dart';
import '../../treasury/presentation/treasury_screen.dart';
import '../application/workspace_controller.dart';
import '../domain/workspace_context.dart';

class WorkspaceShell extends StatefulWidget {
  const WorkspaceShell({
    super.key,
    required this.auth,
    required this.workspace,
    this.pushNotifications,
  });
  final AuthController auth;
  final WorkspaceController workspace;
  final PushNotificationService? pushNotifications;

  @override
  State<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends State<WorkspaceShell>
    with WidgetsBindingObserver {
  int _index = 0;
  String? _selectedOwner;
  CustodyTab _custodyTab = CustodyTab.moves;
  int _notificationCount = 0;
  String? _pendingPushKind;
  PushEvent? _pendingPushEvent;
  OverlayEntry? _foregroundNotification;
  Timer? _foregroundNotificationTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.workspace.context == null && !widget.workspace.loading) {
      widget.workspace.initialize();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotifications();
      _onPushEvent();
    });
    widget.pushNotifications?.addListener(_onPushEvent);
    widget.pushNotifications?.bindAuthenticatedUser();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.pushNotifications?.removeListener(_onPushEvent);
    _dismissForegroundNotification();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.workspace,
      builder: (context, _) {
        if (widget.workspace.loading && widget.workspace.context == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (widget.workspace.error != null &&
            widget.workspace.context == null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.xl),
                child: MessagePanel(
                  message: widget.workspace.error!,
                  onRetry: widget.workspace.initialize,
                ),
              ),
            ),
          );
        }
        final workspace = widget.workspace.context!;
        final pendingPushEvent = _pendingPushEvent;
        if (pendingPushEvent != null) {
          _pendingPushEvent = null;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _openPushEvent(pendingPushEvent);
          });
        }
        final pages = <_ShellPage>[];
        if (workspace.permissions.contains('DASHBOARD_VIEW')) {
          pages.add(
            _ShellPage(
              'المتابعة',
              LucideIcons.layoutDashboard,
              () => DashboardScreen(
                repository: widget.workspace.custody,
                onOpenAggregate: () => _selectPage(pages, 'مجمع العهد'),
                onOpenCustody: (ownerId) {
                  setState(() => _selectedOwner = ownerId);
                  _selectPage(pages, 'العهدة');
                },
              ),
            ),
          );
        }
        // Employee self-service: each screen acts on the user's own record only.
        final hr = widget.workspace.hr;
        final sensors = widget.workspace.punchSensors;
        final approvals = widget.workspace.approvals;
        final canPunch = workspace.permissions.contains('HR_ATTENDANCE_PUNCH');
        final canAsk = workspace.permissions.contains('HR_REQUESTS_CREATE');
        final canReviewAttendance = workspace.permissions.contains(
          'HR_ATTENDANCE_REVIEW',
        );
        final canReviewRequests = workspace.permissions.contains(
          'HR_REQUESTS_APPROVE',
        );
        final canViewPayroll = workspace.permissions.contains(
          'HR_PAYROLL_VIEW',
        );
        final managesHr =
            approvals.decides ||
            canReviewAttendance ||
            canReviewRequests ||
            canViewPayroll;
        if (hr != null && managesHr) {
          pages.add(
            _ShellPage(
              'لوحة الموارد البشرية',
              LucideIcons.usersRound,
              () => HrDashboardScreen(
                repository: hr,
                companyWideAttendance: canReviewAttendance,
                companyWideRequests: canReviewRequests,
                canViewPayroll: canViewPayroll,
              ),
            ),
          );
        }
        if (hr != null && sensors != null && canPunch) {
          pages.add(
            _ShellPage(
              'الحضور',
              LucideIcons.fingerprint,
              () => AttendanceLogScreen(
                repository: hr,
                sensors: sensors,
                showTeam: managesHr,
                companyWide: canReviewAttendance,
                showApprovals: approvals.decides,
                onApprovalsChanged: widget.workspace.refreshApprovals,
              ),
              count: approvals.waiting,
            ),
          );
        }
        if (hr != null && (canAsk || managesHr)) {
          pages.add(
            _ShellPage(
              'الطلبات',
              LucideIcons.fileText,
              () => HrRequestsScreen(
                repository: hr,
                canCreate: canAsk,
                showTeam: managesHr,
                companyWide: canReviewRequests,
              ),
            ),
          );
        }
        if (hr != null && (canPunch || canAsk)) {
          pages.add(
            _ShellPage(
              'قسائم المرتب',
              LucideIcons.receiptText,
              () => HrPayslipsScreen(repository: hr),
            ),
          );
          pages.add(
            _ShellPage(
              'ملف الموظف',
              LucideIcons.idCard,
              () => EmployeeProfileScreen(repository: hr),
            ),
          );
        }
        if (workspace.permissions.contains('CUSTODY_SELF_VIEW') ||
            workspace.permissions.contains('CUSTODY_COMPANY_VIEW')) {
          pages.add(
            _ShellPage(
              'العهدة',
              LucideIcons.wallet,
              () => CustodyScreen(
                key: ValueKey('$_selectedOwner-$_custodyTab'),
                repository: widget.workspace.custody,
                ownerId: _selectedOwner ?? widget.auth.user!.id,
                currentUserId: widget.auth.user!.id,
                permissions: workspace.permissions,
                initialTab: _custodyTab,
              ),
            ),
          );
        }
        // Employees follow their own requests and transfers inside «العهدة»;
        // this screen is the company-wide review queue for managers.
        if (workspace.permissions.contains('CUSTODY_REQUEST_VIEW') ||
            workspace.permissions.contains('CUSTODY_REQUEST_APPROVE')) {
          pages.add(
            _ShellPage(
              'طلبات العهدة',
              LucideIcons.clipboardPlus,
              () => CustodyRequestScreen(
                repository: widget.workspace.custody,
                permissions: workspace.permissions,
                treasury: widget.workspace.treasury,
              ),
            ),
          );
        }
        if (workspace.permissions.contains('CUSTODY_COMPANY_VIEW')) {
          pages.add(
            _ShellPage(
              'مجمع العهد',
              LucideIcons.layers,
              () => AggregateCustodyScreen(
                repository: widget.workspace.custody,
                currentUserId: widget.auth.user!.id,
                permissions: workspace.permissions,
              ),
            ),
          );
        }
        if (workspace.permissions.contains('TREASURY_VIEW') &&
            widget.workspace.treasury != null) {
          pages.add(
            _ShellPage(
              'الخزن',
              LucideIcons.landmark,
              () => TreasuryScreen(
                repository: widget.workspace.treasury!,
                custody: widget.workspace.custody,
                permissions: workspace.permissions,
              ),
            ),
          );
        }
        if (workspace.permissions.contains('CONTRACTOR_EXTRACT_VIEW') &&
            widget.workspace.extracts != null) {
          pages.add(
            _ShellPage(
              'المستخلصات',
              LucideIcons.fileSpreadsheet,
              () => ContractorExtractScreen(
                repository: widget.workspace.extracts!,
                permissions: workspace.permissions,
              ),
            ),
          );
        }
        if (workspace.permissions.contains('SETTINGS_VIEW') &&
            widget.workspace.settings != null) {
          final canManage = workspace.permissions.contains('SETTINGS_MANAGE');
          for (final section in const [
            SettingsSection.expenseCategories,
            SettingsSection.units,
            SettingsSection.contractors,
            SettingsSection.costCenters,
          ]) {
            pages.add(
              _ShellPage(
                section.title,
                section.icon,
                () => ReferenceSettingsScreen(
                  repository: widget.workspace.settings!,
                  section: section,
                  canManage: canManage,
                ),
              ),
            );
          }
        }
        if (pages.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('لا توجد شاشات متاحة لهذا المستخدم')),
          );
        }
        if (_index >= pages.length) _index = 0;
        final selectedPage = pages[_index];
        final pendingPushKind = _pendingPushKind;
        if (pendingPushKind != null) {
          _pendingPushKind = null;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _openPushKind(pendingPushKind, pages);
          });
        }
        return Scaffold(
          // Keep the wide table viewport stable in landscape. Scrollable pages
          // add the keyboard inset themselves so focused fields remain reachable.
          resizeToAvoidBottomInset: false,
          drawer: _WorkspaceDrawer(
            workspace: workspace,
            tenantLogo: widget.workspace.tenantLogo,
            userName: widget.auth.user!.name,
            pages: pages,
            selectedIndex: _index,
            onSelectPage: (index) {
              Navigator.of(context).pop();
              setState(() {
                _index = index;
                if (pages[index].label != 'العهدة') _selectedOwner = null;
                _custodyTab = CustodyTab.moves;
              });
            },
            onLogout: widget.auth.submitting
                ? null
                : () async {
                    Navigator.of(context).pop();
                    final push = widget.pushNotifications;
                    final auth = widget.auth;
                    final workspace = widget.workspace;
                    final unbind = push?.unbindAuthenticatedUser();
                    final logout = auth.logout();
                    workspace.reset();
                    await Future.wait<void>([?unbind, logout]);
                  },
          ),
          body: SafeArea(
            top: true,
            child: Column(
              children: [
                Builder(
                  builder: (headerContext) => _CompanyHeader(
                    workspace: workspace,
                    switching: widget.workspace.switchingCompany,
                    notificationCount: _notificationCount,
                    onOpenMenu: () => Scaffold.of(headerContext).openDrawer(),
                    notificationRepository: widget.workspace.notifications,
                    onNotificationSelected: (notification) =>
                        _handleNotification(notification, pages),
                    onNotificationCountChanged: (count) {
                      if (mounted) setState(() => _notificationCount = count);
                    },
                    onSelectCompany: workspace.memberships.length > 1
                        ? _selectCompany
                        : null,
                  ),
                ),
                Expanded(
                  child: KeyedSubtree(
                    key: ValueKey(
                      '${workspace.activeCompanyId}-${selectedPage.label}',
                    ),
                    child: selectedPage.builder(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _selectPage(List<_ShellPage> pages, String label) {
    final index = pages.indexWhere((page) => page.label == label);
    if (index >= 0) setState(() => _index = index);
  }

  Future<void> _selectCompany(String companyId) async {
    if (!mounted) return;
    final changed = await widget.workspace.selectCompany(companyId);
    if (!mounted) return;
    if (changed) {
      setState(() {
        _index = 0;
        _selectedOwner = null;
      });
      _loadNotifications();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.workspace.error ?? 'تعذر تغيير الشركة. حاول مرة أخرى.',
        ),
      ),
    );
  }

  Future<void> _loadNotifications() async {
    final repository = widget.workspace.notifications;
    if (repository == null) return;
    try {
      final inbox = await repository.inbox(size: 1);
      if (mounted) setState(() => _notificationCount = inbox.unreadCount);
    } catch (_) {}
  }

  void _onPushEvent() {
    final event = widget.pushNotifications?.takeEvent();
    if (event == null || !mounted) return;
    _loadNotifications();
    if (event.opened) {
      _openPushEvent(event);
      return;
    }
    _showForegroundNotification(event);
  }

  void _showForegroundNotification(PushEvent event) {
    _dismissForegroundNotification();
    final overlay = Overlay.of(context, rootOverlay: true);
    final top = MediaQuery.viewPaddingOf(context).top + 62;
    final companyName = event.companyName?.trim();
    final prefix = companyName == null || companyName.isEmpty
        ? null
        : '$companyName — ';
    final title = prefix != null && event.title.startsWith(prefix)
        ? event.title.substring(prefix.length)
        : event.title;

    _foregroundNotification = OverlayEntry(
      builder: (overlayContext) => Positioned(
        top: top,
        left: 12,
        right: 12,
        child: SafeArea(
          top: false,
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: AppMotion.duration(overlayContext, AppMotion.enter),
              curve: AppMotion.curve,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, -18 * (1 - value)),
                  child: child,
                ),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Material(
                    color: Colors.white,
                    elevation: 16,
                    shadowColor: Colors.black.withValues(alpha: .22),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        _dismissForegroundNotification();
                        _openPushEvent(event);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(AppSpace.sm),
                        decoration: BoxDecoration(
                          border: Border.all(color: context.tokens.line),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: context.tokens.brandTint,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                              child: Icon(
                                LucideIcons.bell,
                                size: 19,
                                color: context.tokens.brand,
                              ),
                            ),
                            const SizedBox(width: AppSpace.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (companyName != null &&
                                      companyName.isNotEmpty)
                                    Text(
                                      companyName,
                                      style: TextStyle(
                                        color: context.tokens.brand,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if (event.message.isNotEmpty)
                                    Text(
                                      event.message,
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
                            IconButton(
                              tooltip: 'إغلاق',
                              visualDensity: VisualDensity.compact,
                              onPressed: _dismissForegroundNotification,
                              icon: const Icon(LucideIcons.x, size: 17),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_foregroundNotification!);
    _foregroundNotificationTimer = Timer(
      const Duration(seconds: 6),
      _dismissForegroundNotification,
    );
  }

  void _dismissForegroundNotification() {
    _foregroundNotificationTimer?.cancel();
    _foregroundNotificationTimer = null;
    _foregroundNotification?.remove();
    _foregroundNotification = null;
  }

  Future<void> _openPushEvent(PushEvent event) async {
    if (widget.workspace.context == null) {
      _pendingPushEvent = event;
      return;
    }
    if (!await _switchToNotificationCompany(event.companyId)) return;
    if (mounted) setState(() => _pendingPushKind = event.kind);
  }

  Future<bool> _switchToNotificationCompany(String? companyId) async {
    if (companyId == null || companyId.isEmpty) return true;
    final workspaceContext = widget.workspace.context;
    if (workspaceContext?.activeCompanyId == companyId) return true;
    final membership = workspaceContext?.memberships.any(
      (item) => item.companyId == companyId,
    );
    if (membership != true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لم تعد لديك صلاحية الوصول إلى شركة هذا الإشعار.'),
          ),
        );
      }
      return false;
    }
    final switched = await widget.workspace.selectCompany(companyId);
    if (!switched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.workspace.error ?? 'تعذر فتح شركة هذا الإشعار.'),
        ),
      );
    }
    return switched;
  }

  void _openPushKind(String kind, List<_ShellPage> pages) {
    if (kind == 'CUSTODY_REQUESTED' || kind.startsWith('CUSTODY_REQUEST_')) {
      if (kind == 'CUSTODY_REQUESTED' &&
          pages.any((page) => page.label == 'طلبات العهدة')) {
        _selectPage(pages, 'طلبات العهدة');
      } else {
        setState(() => _custodyTab = CustodyTab.requests);
        _selectPage(pages, 'العهدة');
      }
    } else if (kind.startsWith('CUSTODY_TRANSFER_')) {
      setState(() => _custodyTab = CustodyTab.transfers);
      _selectPage(pages, 'العهدة');
    } else if (kind.startsWith('TREASURY_') || kind == 'CUSTODY_RETURNED') {
      _selectPage(pages, 'الخزن');
    } else if (kind == 'HR_REQUEST_APPROVED' ||
        kind == 'HR_REQUEST_REJECTED' ||
        kind == 'HR_REQUEST_CANCELLED') {
      _selectPage(pages, 'الطلبات');
    } else if (kind == 'HR_TIMESHEET') {
      _selectPage(pages, 'سجل الحضور');
    } else if (kind == 'HR_DEVICE_PENDING' || kind == 'HR_PUNCH_PENDING') {
      const label = 'موافقات الحضور';
      if (pages.any((page) => page.label == label)) {
        _selectPage(pages, label);
        widget.workspace.refreshApprovals();
      } else {
        // The first item for a new manager: the screen shows once it is known.
        widget.workspace.refreshApprovals().then((_) {
          if (mounted && widget.workspace.approvals.decides) {
            setState(() => _pendingPushKind = kind);
          }
        });
      }
    } else if (kind == 'HR_DEVICE_APPROVED' ||
        kind == 'HR_DEVICE_REJECTED' ||
        kind == 'HR_DEVICE_REMOVED' ||
        kind == 'HR_PUNCH_APPROVED' ||
        kind == 'HR_PUNCH_REJECTED') {
      _selectPage(pages, 'الحضور والانصراف');
    } else if (kind.startsWith('CONTRACTOR_EXTRACT_')) {
      _selectPage(pages, 'المستخلصات');
    } else if (kind.startsWith('EXPENSE_') ||
        kind == 'SETTLED_EXPENSE_REJECTED') {
      final hasAggregate = pages.any((page) => page.label == 'مجمع العهد');
      _selectPage(pages, hasAggregate ? 'مجمع العهد' : 'العهدة');
    }
  }

  Future<bool> _handleNotification(
    AppNotification notification,
    List<_ShellPage> pages,
  ) async {
    if (!await _switchToNotificationCompany(notification.companyId)) {
      return false;
    }
    if (!mounted) return false;
    if (widget.workspace.context?.activeCompanyId != notification.companyId) {
      return false;
    }
    setState(() => _pendingPushKind = notification.kind);
    return true;
  }
}

class _HeaderControl extends StatelessWidget {
  const _HeaderControl({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.badge = 0,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            onPressed: onPressed,
            style: IconButton.styleFrom(
              foregroundColor: context.tokens.ink,
              backgroundColor: Colors.white,
              minimumSize: const Size(44, 44),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: context.tokens.line),
              ),
            ),
            icon: Icon(icon, size: 21),
          ),
          if (badge > 0)
            Positioned(
              top: 4,
              left: 5,
              child: Container(
                constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTokens.danger,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.2),
                ),
                child: Text(
                  badge > 99 ? '99+' : '$badge',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ShellPage {
  const _ShellPage(this.label, this.icon, this.builder, {this.count = 0});
  final String label;
  final IconData icon;
  final Widget Function() builder;

  /// What waits on this screen, shown beside it in the drawer.
  final int count;
}

class _CompanyHeader extends StatefulWidget {
  const _CompanyHeader({
    required this.workspace,
    required this.switching,
    required this.notificationCount,
    required this.onOpenMenu,
    required this.notificationRepository,
    required this.onNotificationSelected,
    required this.onNotificationCountChanged,
    required this.onSelectCompany,
  });

  final WorkspaceContext workspace;
  final bool switching;
  final int notificationCount;
  final VoidCallback onOpenMenu;
  final NotificationRepository? notificationRepository;
  final NotificationSelection onNotificationSelected;
  final ValueChanged<int> onNotificationCountChanged;
  final ValueChanged<String>? onSelectCompany;

  @override
  State<_CompanyHeader> createState() => _CompanyHeaderState();
}

class _CompanyHeaderState extends State<_CompanyHeader> {
  final LayerLink _companyLink = LayerLink();
  final LayerLink _notificationLink = LayerLink();
  OverlayEntry? _companyOverlay;
  OverlayEntry? _notificationOverlay;

  @override
  void didUpdateWidget(covariant _CompanyHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspace.activeCompanyId !=
            widget.workspace.activeCompanyId ||
        widget.switching) {
      _closeCompanies();
    }
  }

  @override
  void dispose() {
    _closeCompanies(notify: false);
    _closeNotifications(notify: false);
    super.dispose();
  }

  void _toggleCompanies() {
    if (_companyOverlay != null) {
      _closeCompanies();
      return;
    }
    if (widget.onSelectCompany == null || widget.switching) return;
    _closeNotifications();
    final width = math.min(MediaQuery.sizeOf(context).width - 24, 340.0);
    _companyOverlay = OverlayEntry(
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeCompanies,
              ),
            ),
            CompositedTransformFollower(
              link: _companyLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomCenter,
              followerAnchor: Alignment.topCenter,
              offset: const Offset(0, 5),
              child: SizedBox(
                width: width,
                child: _CompanyMenu(
                  workspace: widget.workspace,
                  onSelected: (companyId) {
                    _closeCompanies();
                    if (companyId != widget.workspace.activeCompanyId) {
                      widget.onSelectCompany?.call(companyId);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
    Overlay.of(context).insert(_companyOverlay!);
    setState(() {});
  }

  void _closeCompanies({bool notify = true}) {
    _companyOverlay?.remove();
    _companyOverlay = null;
    if (notify && mounted) setState(() {});
  }

  void _toggleNotifications() {
    if (_notificationOverlay != null) {
      _closeNotifications();
      return;
    }
    final repository = widget.notificationRepository;
    if (repository == null) return;
    _closeCompanies();
    final screen = MediaQuery.sizeOf(context);
    final width = math.min(screen.width - 24, 390.0);
    final height = math.min(screen.height - 90, 530.0);
    _notificationOverlay = OverlayEntry(
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeNotifications,
              ),
            ),
            CompositedTransformFollower(
              link: _notificationLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              offset: const Offset(0, 6),
              child: SizedBox(
                width: width,
                height: height,
                child: NotificationSheet(
                  repository: repository,
                  embedded: true,
                  onClose: _closeNotifications,
                  onCountChanged: widget.onNotificationCountChanged,
                  onSelected: (notification) async {
                    final opened = await widget.onNotificationSelected(
                      notification,
                    );
                    if (opened) _closeNotifications();
                    return opened;
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
    Overlay.of(context).insert(_notificationOverlay!);
    setState(() {});
  }

  void _closeNotifications({bool notify = true}) {
    _notificationOverlay?.remove();
    _notificationOverlay = null;
    if (notify && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final name = widget.workspace.companyName;
    return Material(
      color: tokens.canvas,
      shape: Border(bottom: BorderSide(color: tokens.line)),
      child: SizedBox(
        width: double.infinity,
        height: 64,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PositionedDirectional(
              start: 12,
              child: _HeaderControl(
                tooltip: 'فتح القائمة',
                icon: LucideIcons.menu,
                onPressed: widget.onOpenMenu,
              ),
            ),
            PositionedDirectional(
              end: 12,
              child: CompositedTransformTarget(
                link: _notificationLink,
                child: _HeaderControl(
                  tooltip: 'الإشعارات',
                  icon: LucideIcons.bell,
                  badge: widget.notificationCount,
                  onPressed: _toggleNotifications,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 64),
              child: widget.switching
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: tokens.brand,
                      ),
                    )
                  : CompositedTransformTarget(
                      link: _companyLink,
                      child: Material(
                        color: Colors.transparent,
                        child: SizedBox(
                          height: 50,
                          child: InkWell(
                            onTap: widget.onSelectCompany == null
                                ? null
                                : _toggleCompanies,
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: tokens.brandStrong,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      name.isEmpty ? '' : name.characters.first,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Flexible(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'الشركة الحالية',
                                          style: TextStyle(
                                            color: tokens.muted,
                                            fontSize: 10.5,
                                            height: 1.3,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: tokens.ink,
                                                  fontSize: 14,
                                                  height: 1.35,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            if (widget.onSelectCompany !=
                                                null) ...[
                                              const SizedBox(width: 4),
                                              Icon(
                                                LucideIcons.chevronDown,
                                                color: tokens.muted,
                                                size: 15,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceDrawer extends StatefulWidget {
  const _WorkspaceDrawer({
    required this.workspace,
    required this.tenantLogo,
    required this.userName,
    required this.pages,
    required this.selectedIndex,
    required this.onSelectPage,
    required this.onLogout,
  });

  final WorkspaceContext workspace;
  final Uint8List? tenantLogo;
  final String userName;
  final List<_ShellPage> pages;
  final int selectedIndex;
  final ValueChanged<int> onSelectPage;
  final VoidCallback? onLogout;

  @override
  State<_WorkspaceDrawer> createState() => _WorkspaceDrawerState();
}

class _WorkspaceDrawerState extends State<_WorkspaceDrawer> {
  static const _settingsLabels = {
    'بنود الصرف',
    'وحدات القياس',
    'المقاولون',
    'مراكز التكلفة',
  };
  static const _custodyLabels = {'العهدة', 'طلبات العهدة', 'مجمع العهد'};
  static const _financeLabels = {'الخزن', 'المستخلصات'};
  static const _hrLabels = {
    'لوحة الموارد البشرية',
    'الحضور',
    'الطلبات',
    'قسائم المرتب',
    'ملف الموظف',
  };

  String? _openGroup;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _openGroup = _initialGroup();
  }

  @override
  void didUpdateWidget(covariant _WorkspaceDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      final selectedGroup = _groupFor(widget.pages[widget.selectedIndex].label);
      if (selectedGroup != null) _openGroup = selectedGroup;
    }
  }

  String? _initialGroup() {
    final selected = _groupFor(widget.pages[widget.selectedIndex].label);
    if (selected != null) return selected;
    for (final page in widget.pages) {
      final group = _groupFor(page.label);
      if (group != null) return group;
    }
    return null;
  }

  String? _groupFor(String label) {
    if (_hrLabels.contains(label)) return 'hr';
    if (_custodyLabels.contains(label)) return 'custody';
    if (_financeLabels.contains(label)) return 'finance';
    if (_settingsLabels.contains(label)) return 'settings';
    return null;
  }

  List<Widget> _buildMenu(BuildContext context) {
    final query = normalizeArabic(_query);
    if (query.isNotEmpty) {
      final matches = [
        for (var index = 0; index < widget.pages.length; index++)
          if (normalizeArabic(widget.pages[index].label).contains(query)) index,
      ];
      if (matches.isEmpty) {
        return [
          Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Text(
              'مفيش قسم بالاسم ده',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.tokens.muted),
            ),
          ),
        ];
      }
      return [
        for (final index in matches) ...[
          _pageTile(context, index),
          const SizedBox(height: 4),
        ],
      ];
    }
    final children = <Widget>[];
    final emittedGroups = <String>{};
    for (var index = 0; index < widget.pages.length; index++) {
      final page = widget.pages[index];
      final group = _groupFor(page.label);
      if (group == null) {
        children.add(_pageTile(context, index));
        children.add(const SizedBox(height: 4));
        continue;
      }
      if (!emittedGroups.add(group)) continue;

      final groupIndexes = <int>[
        for (var itemIndex = 0; itemIndex < widget.pages.length; itemIndex++)
          if (_groupFor(widget.pages[itemIndex].label) == group) itemIndex,
      ];
      final (label, subtitle, icon) = switch (group) {
        'finance' => ('المالية', 'الحسابات والخزن', LucideIcons.landmark),
        'settings' => ('الإعدادات', 'البيانات الأساسية', LucideIcons.settings),
        'hr' => (
          'الموارد البشرية',
          'الخدمات الذاتية للموظف',
          LucideIcons.users,
        ),
        _ => ('العهد', 'إدارة العهد', LucideIcons.wallet),
      };
      final expanded = _openGroup == group;
      children.add(const SizedBox(height: AppSpace.xs));
      children.add(
        _DrawerGroupHeader(
          label: label,
          subtitle: subtitle,
          icon: icon,
          expanded: expanded,
          onTap: () => setState(() {
            _openGroup = expanded ? null : group;
          }),
        ),
      );
      children.add(
        AnimatedSize(
          duration: AppMotion.duration(context, AppMotion.expand),
          curve: AppMotion.curve,
          alignment: Alignment.topCenter,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.only(right: 8, top: 2),
                  child: Column(
                    children: [
                      for (final itemIndex in groupIndexes) ...[
                        _pageTile(context, itemIndex),
                        const SizedBox(height: 4),
                      ],
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      );
    }
    return children;
  }

  Widget _pageTile(BuildContext context, int index) {
    final tokens = context.tokens;
    final page = widget.pages[index];
    final selected = index == widget.selectedIndex;
    return Material(
      color: selected ? tokens.wash : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => widget.onSelectPage(index),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: selected ? tokens.brand : tokens.sunken,
                  borderRadius: BorderRadius.circular(11),
                  border: selected ? null : Border.all(color: tokens.line),
                ),
                child: Icon(
                  page.icon,
                  size: 18,
                  color: selected ? Colors.white : tokens.ink,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  page.label,
                  style: TextStyle(
                    color: selected ? tokens.brandStrong : tokens.ink,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              if (page.count > 0)
                Container(
                  constraints: const BoxConstraints(minWidth: 22),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTokens.warning,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${page.count}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final workspace = widget.workspace;
    final tenantLogo = widget.tenantLogo;
    final userName = widget.userName;
    final onLogout = widget.onLogout;
    final membership = workspace.activeMembership;
    return Drawer(
      width: (MediaQuery.sizeOf(context).width * .82)
          .clamp(270, 320)
          .toDouble(),
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Row(
                children: [
                  Text(
                    'Monetizer',
                    style: TextStyle(
                      color: tokens.brandStrong,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  if (tenantLogo != null)
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: Image.memory(tenantLogo, fit: BoxFit.contain),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  hintText: 'ابحث عن قسم…',
                  isDense: true,
                  fillColor: tokens.sunken,
                  prefixIcon: const Icon(LucideIcons.search, size: 18),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: tokens.line),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: _buildMenu(context),
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
              decoration: BoxDecoration(
                color: tokens.sunken,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tokens.line),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: tokens.washStrong,
                    foregroundColor: tokens.brandStrong,
                    child: Text(
                      userName.trim().isEmpty ? '؟' : userName[0],
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (membership?.roleName != null)
                          Text(
                            membership!.roleName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tokens.muted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'تسجيل الخروج',
                    onPressed: onLogout,
                    color: AppTokens.danger,
                    icon: const Icon(LucideIcons.logOut, size: 19),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerGroupHeader extends StatelessWidget {
  const _DrawerGroupHeader({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.expanded,
    required this.onTap,
  });
  final String label;
  final String subtitle;
  final IconData icon;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
          child: Row(
            children: [
              Icon(icon, color: tokens.muted, size: 17),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: tokens.ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: tokens.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedRotation(
                turns: expanded ? 0 : -.25,
                duration: AppMotion.duration(context, AppMotion.expand),
                child: Icon(
                  LucideIcons.chevronDown,
                  color: tokens.muted,
                  size: 17,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompanyMenu extends StatefulWidget {
  const _CompanyMenu({required this.workspace, required this.onSelected});

  final WorkspaceContext workspace;
  final ValueChanged<String> onSelected;

  @override
  State<_CompanyMenu> createState() => _CompanyMenuState();
}

class _CompanyMenuState extends State<_CompanyMenu> {
  static const _itemHeight = 58.0;
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final memberships = widget.workspace.memberships;
    final visibleRows = math.min(memberships.length, 5);
    final height =
        (visibleRows * _itemHeight) + math.max(0, visibleRows - 1).toDouble();
    return Material(
      color: Colors.white,
      elevation: 14,
      shadowColor: context.tokens.brandStrong.withValues(alpha: .24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: context.tokens.line),
      ),
      child: SizedBox(
        height: height,
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: memberships.length > 5,
          child: ListView.separated(
            controller: _scrollController,
            padding: EdgeInsets.zero,
            itemCount: memberships.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              indent: 12,
              endIndent: 12,
              color: context.tokens.line,
            ),
            itemBuilder: (context, index) {
              final membership = memberships[index];
              final selected =
                  membership.companyId == widget.workspace.activeCompanyId;
              return SizedBox(
                height: _itemHeight,
                child: InkWell(
                  onTap: () => widget.onSelected(membership.companyId),
                  child: Container(
                    color: selected
                        ? context.tokens.brandTint.withValues(alpha: .4)
                        : null,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.building2,
                          size: 19,
                          color: context.tokens.brandStrong,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                membership.companyName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                ),
                              ),
                              if (membership.subtitle != null)
                                Text(
                                  membership.subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: context.tokens.muted,
                                    fontSize: 10.5,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (selected)
                          Icon(
                            LucideIcons.check,
                            color: context.tokens.brand,
                            size: 18,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
