import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/format/exact_decimal.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_table.dart';
import '../../custody/presentation/custody_widgets.dart';
import '../data/users_repository.dart';
import '../domain/user_models.dart';
import 'user_sheets.dart';

enum _Tab { memberships, custodies, costCenters }

/// The user's file, as on the web: the account, then memberships, custodies
/// and cost centres. Edit, password reset and "log out everywhere" need
/// USERS_MANAGE; a tenant admin is changed only by another tenant admin.
class UserFileScreen extends StatefulWidget {
  const UserFileScreen({
    super.key,
    required this.repository,
    required this.userId,
    required this.currentUserId,
    required this.activeCompanyId,
    required this.canManage,
    required this.onBack,
    this.currentRoleCode,
    this.permissions = const {},
  });

  final UsersRepository repository;
  final String userId, currentUserId;
  final String? activeCompanyId, currentRoleCode;
  final bool canManage;

  /// The signed-in user's permissions in the active company.
  final Set<String> permissions;
  final VoidCallback onBack;

  @override
  State<UserFileScreen> createState() => _UserFileScreenState();
}

class _UserFileScreenState extends State<UserFileScreen> {
  UserProfile? _profile;
  OrganizationOptions? _options;
  _Tab _tab = _Tab.memberships;
  bool _loggingOut = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await widget.repository.profile(widget.userId);
      OrganizationOptions? options;
      if (widget.canManage) {
        try {
          options = await widget.repository.options(
            activeCompanyId: widget.activeCompanyId,
            ownPermissions: widget.permissions,
            ownRoleCode: widget.currentRoleCode,
          );
        } catch (_) {
          // Without options, memberships stay read-only.
        }
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _options = options;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  bool get _self => widget.userId == widget.currentUserId;

  bool _canEdit(AppUserRecord user) =>
      widget.canManage &&
      !(user.tenantAdmin && widget.currentRoleCode != 'TENANT_ADMIN');

  void _notify(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<T?> _sheet<T>(WidgetBuilder builder) => showAppSheet<T>(
    context,
    tall: true,
    dismissible: false,
    builder: builder,
  );

  /// Turning a user or a membership off does not settle a negative custody:
  /// the company still owes it, so ask before saving, as the web does.
  Future<bool> _confirmNegativeCustody(
    UserProfile profile, {
    String? companyId,
  }) async {
    final owed = [
      for (final custody in profile.custodies)
        if ((companyId == null || custody.companyId == companyId) &&
            (ExactDecimal.tryParse(custody.balance) ?? ExactDecimal.zero)
                    .compareTo(ExactDecimal.zero) <
                0)
          '${custody.companyName}: ${custody.balance} ${custody.currencyCode}',
    ];
    if (owed.isEmpty) return true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('عهدته بالسالب'),
        content: Text(
          'الشركة مدينة له:\n${owed.join('\n')}\n\n'
          'التعطيل لا يسوّي هذا المبلغ. هل تريد التعطيل؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تعطيل'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _edit(UserProfile profile) async {
    final saved = await _sheet<AppUserRecord>(
      (_) => UserSheet(
        repository: widget.repository,
        roles: _options?.rolesFor(widget.activeCompanyId) ?? const [],
        user: profile.user,
        self: _self,
        confirmDeactivate: () => _confirmNegativeCustody(profile),
      ),
    );
    if (saved == null || !mounted) return;
    _notify('تم تحديث بيانات المستخدم بنجاح');
    await _load();
  }

  Future<void> _resetPassword(AppUserRecord user) async {
    final saved = await _sheet<bool>(
      (_) => PasswordSheet(repository: widget.repository, user: user),
    );
    if (saved == true && mounted) {
      _notify('تم تحديث كلمة المرور بنجاح');
      await _load();
    }
  }

  Future<void> _logoutEverywhere(AppUserRecord user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج من كل الأجهزة؟'),
        content: Text(
          'سيحتاج ${user.name} إلى تسجيل الدخول مرة أخرى على كل أجهزته.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _loggingOut = true);
    try {
      await widget.repository.logoutEverywhere(user.id);
      if (mounted) _notify('تم تسجيل خروج ${user.name} من كل الأجهزة');
    } catch (error) {
      if (mounted) _notify(error.toString());
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  Future<void> _membership(UserProfile profile, [UserMembership? row]) async {
    final options = _options;
    if (options == null) return;
    final saved = await _sheet<bool>(
      (_) => MembershipSheet(
        repository: widget.repository,
        user: profile.user,
        options: options,
        membership: row,
        confirmDeactivate: row == null
            ? null
            : () => _confirmNegativeCustody(profile, companyId: row.companyId),
      ),
    );
    if (saved == true && mounted) {
      _notify('تم حفظ العضوية');
      await _load();
    }
  }

  Future<void> _costCenters(AppUserRecord user) async {
    if (user.roleId == null) {
      _notify(
        'لا يمكن تحديث المراكز قبل تعيين دور للمستخدم في الشركة الحالية.',
      );
      return;
    }
    final saved = await _sheet<AppUserRecord>(
      (_) => CostCentersSheet(repository: widget.repository, user: user),
    );
    if (saved != null && mounted) {
      _notify('تم تحديث مراكز التكلفة بنجاح');
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final back = Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        onPressed: widget.onBack,
        icon: const Icon(LucideIcons.arrowRight, size: 17),
        label: const Text('المستخدمون'),
      ),
    );
    if (profile == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          back,
          if (_error != null)
            MessagePanel(message: _error!, onRetry: _load)
          else
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      );
    }
    final user = profile.user;
    final canEdit = _canEdit(user);
    final options = _options;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          back,
          const SizedBox(height: 6),
          PageHeader(
            title: user.name,
            subtitle: '\u2066@${user.username}\u2069',
            action: canEdit
                ? AppEditButton(
                    tooltip: 'تعديل البيانات',
                    onPressed: () => _edit(profile),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          _AccountCard(user: user),
          if (canEdit) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('reset-password-button'),
                  onPressed: () => _resetPassword(user),
                  icon: const Icon(LucideIcons.keyRound, size: 17),
                  label: const Text('كلمة المرور'),
                ),
                if (!_self)
                  OutlinedButton.icon(
                    onPressed: _loggingOut
                        ? null
                        : () => _logoutEverywhere(user),
                    icon: const Icon(LucideIcons.logOut, size: 17),
                    label: const Text('خروج من كل الأجهزة'),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          LedgerTabs<_Tab>(
            value: _tab,
            tabs: [
              (_Tab.memberships, 'العضويات', profile.memberships.length),
              (_Tab.custodies, 'العهد', profile.custodies.length),
              (_Tab.costCenters, 'مراكز التكلفة', profile.costCenters.length),
            ],
            onChanged: (value) => setState(() => _tab = value),
          ),
          const SizedBox(height: 10),
          ...switch (_tab) {
            _Tab.memberships => [
              if (widget.canManage &&
                  options != null &&
                  options.membershipCompanyIds.isNotEmpty) ...[
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AppAddButton(
                    label: 'إضافة عضوية',
                    onPressed: () => _membership(profile),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              AppDataTable<UserMembership>(
                rows: profile.memberships,
                empty: const AppEmptyState(
                  icon: LucideIcons.building2,
                  title: 'لا توجد عضويات متاحة للعرض',
                ),
                columns: [
                  const AppTableColumn('الشركة', 130),
                  const AppTableColumn('الدور', 92),
                  const AppTableColumn('الحالة', 88),
                  if (widget.canManage && options != null)
                    const AppTableColumn('', 48),
                ],
                cells: (row) => [
                  AppTableTitle(
                    title: row.companyName,
                    subtitle: row.departmentName,
                  ),
                  Text(row.roleName, maxLines: 2),
                  _ActiveTag(row.active),
                  if (widget.canManage && options != null)
                    options.membershipCompanyIds.contains(row.companyId)
                        ? AppEditButton(
                            tooltip: 'تعديل عضوية ${row.companyName}',
                            onPressed: () => _membership(profile, row),
                          )
                        : const SizedBox.shrink(),
                ],
              ),
            ],
            _Tab.custodies => [
              AppDataTable<UserCustody>(
                rows: profile.custodies,
                empty: const AppEmptyState(
                  icon: LucideIcons.wallet,
                  title: 'لا توجد عهد لهذا المستخدم',
                ),
                columns: const [
                  AppTableColumn('الشركة', 110),
                  AppTableColumn('الرصيد', 100, numeric: true),
                  AppTableColumn('آخر تصفية', 86),
                  AppTableColumn('الحالة', 88),
                ],
                cells: (row) => [
                  Text(row.companyName, maxLines: 2),
                  Text(
                    '${(ExactDecimal.tryParse(row.balance) ?? ExactDecimal.zero).money()} ${row.currencyCode}',
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    row.lastSettledAt == null
                        ? 'لم تُصفَّ بعد'
                        : _date(row.lastSettledAt!),
                  ),
                  _ActiveTag(row.active),
                ],
              ),
            ],
            _Tab.costCenters => [
              if (canEdit) ...[
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AppAddButton(
                    label: 'إدارة مراكز التكلفة',
                    icon: LucideIcons.listChecks,
                    onPressed: () => _costCenters(user),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              AppDataTable<UserCostCenter>(
                rows: profile.costCenters,
                empty: const AppEmptyState(
                  icon: LucideIcons.folderKanban,
                  title: 'لا توجد مراكز تكلفة معيّنة',
                ),
                columns: const [
                  AppTableColumn('المركز', 180),
                  AppTableColumn('النوع', 80),
                  AppTableColumn('الحالة', 88),
                ],
                cells: (center) => [
                  AppTableTitle(title: center.name, subtitle: center.code),
                  Text(center.type == 'OFFICE' ? 'مكتب' : 'مشروع'),
                  _ActiveTag(center.active),
                ],
              ),
            ],
          },
        ],
      ),
    );
  }
}

String _date(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return value.isEmpty ? '—' : value;
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _ActiveTag extends StatelessWidget {
  const _ActiveTag(this.active);
  final bool active;

  @override
  Widget build(BuildContext context) => AppTag(
    active ? 'نشط' : 'غير نشط',
    tone: active ? AppTone.success : AppTone.danger,
  );
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.user});
  final AppUserRecord user;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final fields = <(String, String, bool)>[
      ('الكود الوظيفي', user.code, true),
      ('الدور في الشركة الحالية', user.roleName ?? 'لا توجد عضوية نشطة', false),
      ('الحالة', user.active ? 'نشط' : 'غير نشط', false),
      (
        'تفاصيل مراكز التكلفة',
        user.costDetailsEnabled ? 'مفعّلة' : 'غير مفعّلة',
        false,
      ),
      ('تاريخ الإضافة', _date(user.createdAt), false),
      ('آخر تحديث', _date(user.updatedAt), false),
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.line),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final half = (constraints.maxWidth - 8) / 2;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (label, value, ltr) in fields)
                Container(
                  width: half,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.canvas,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tokens.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: ltr ? TextDirection.ltr : null,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: label == 'الحالة'
                              ? (user.active
                                    ? AppTokens.success
                                    : AppTokens.danger)
                              : tokens.ink,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
