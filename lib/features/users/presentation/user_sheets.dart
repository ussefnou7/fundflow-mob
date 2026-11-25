import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/format/arabic_search.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_table.dart';
import '../../settings/domain/settings_models.dart';
import '../data/users_repository.dart';
import '../domain/user_models.dart';

class _SheetError extends StatelessWidget {
  const _SheetError(this.message);
  final String? message;

  @override
  Widget build(BuildContext context) => message == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            message!,
            style: const TextStyle(color: AppTokens.danger),
          ),
        );
}

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : null;

/// Adds a user (with a first password) or edits one. The role is the user's
/// role in the active company; cost centres have their own sheet.
class UserSheet extends StatefulWidget {
  const UserSheet({
    super.key,
    required this.repository,
    required this.roles,
    this.user,
    this.self = false,
    this.confirmDeactivate,
  });

  final UsersRepository repository;
  final List<OrgRef> roles;
  final AppUserRecord? user;

  /// Asked before saving an active user as inactive; false stops the save.
  final Future<bool> Function()? confirmDeactivate;

  /// Nobody changes their own role.
  final bool self;

  @override
  State<UserSheet> createState() => _UserSheetState();
}

class _UserSheetState extends State<UserSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user?.name);
  late final _code = TextEditingController(text: widget.user?.code);
  late final _username = TextEditingController(text: widget.user?.username);
  final _password = TextEditingController();
  late String? _roleId = widget.user?.roleId;
  late bool _active = widget.user?.active ?? true;
  bool _busy = false;
  String? _error;

  bool get _editing => widget.user != null;

  @override
  void dispose() {
    for (final controller in [_name, _code, _username, _password]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (widget.user?.active == true &&
        !_active &&
        widget.confirmDeactivate != null &&
        !await widget.confirmDeactivate!()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await widget.repository.save(
        user: widget.user,
        code: _code.text,
        name: _name.text,
        username: _username.text,
        roleId: _roleId!,
        active: _active,
        password: _password.text,
      );
      if (mounted) Navigator.pop(context, saved);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roles = [
      ...widget.roles,
      // The user's current role always shows, even when this user may not
      // hand it out; the server refuses a change it does not allow.
      if (widget.user?.roleId != null &&
          !widget.roles.any((role) => role.id == widget.user!.roleId))
        (id: widget.user!.roleId!, name: widget.user!.roleName ?? '—'),
    ];
    return AppSheetScaffold(
      title: _editing ? 'تعديل المستخدم' : 'مستخدم جديد',
      subtitle: _editing
          ? '\u2066@${widget.user!.username}\u2069'
          : 'بيانات الدخول والدور',
      closeEnabled: !_busy,
      footer: AppSheetActions(
        primaryLabel: _editing ? 'حفظ التعديلات' : 'إضافة المستخدم',
        busy: _busy,
        onPrimary: _save,
        secondaryLabel: 'إلغاء',
        onSecondary: () => Navigator.pop(context),
      ),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetError(_error),
            TextFormField(
              controller: _name,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'الاسم *'),
              validator: _required,
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _code,
              maxLength: 50,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'الكود الوظيفي *',
                hintText: 'EMP-001',
              ),
              validator: _required,
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _username,
              textDirection: TextDirection.ltr,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'اسم الدخول *',
                helperText: 'حروف إنجليزية وأرقام و . _ - من 3 إلى 80 حرفًا',
              ),
              validator: (value) =>
                  RegExp(
                    r'^[a-zA-Z0-9._-]{3,80}$',
                  ).hasMatch(value?.trim() ?? '')
                  ? null
                  : 'اسم دخول غير صالح',
            ),
            const SizedBox(height: 12),
            AppSelect<String>(
              label: 'الدور في الشركة الحالية *',
              value: _roleId,
              enabled: !widget.self,
              options: [
                for (final role in roles)
                  AppSelectOption(value: role.id, label: role.name),
              ],
              validator: (value) => value == null ? 'اختر الدور' : null,
              onChanged: (value) => setState(() => _roleId = value),
            ),
            if (!_editing) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور *',
                  helperText: 'ثمانية أحرف على الأقل',
                ),
                validator: (value) => (value ?? '').length < 8
                    ? 'كلمة المرور ثمانية أحرف على الأقل'
                    : null,
              ),
            ],
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('المستخدم نشط'),
              subtitle: const Text('المستخدم غير النشط لا يستطيع الدخول'),
              value: _active,
              onChanged: widget.self
                  ? null
                  : (value) => setState(() => _active = value),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sets a new password; the user's sessions stay as the server decides.
class PasswordSheet extends StatefulWidget {
  const PasswordSheet({
    super.key,
    required this.repository,
    required this.user,
  });
  final UsersRepository repository;
  final AppUserRecord user;

  @override
  State<PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<PasswordSheet> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.resetPassword(widget.user, _password.text);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppSheetScaffold(
    title: 'إعادة تعيين كلمة المرور',
    subtitle: widget.user.name,
    closeEnabled: !_busy,
    footer: AppSheetActions(
      primaryLabel: 'حفظ كلمة المرور',
      busy: _busy,
      onPrimary: _save,
      secondaryLabel: 'إلغاء',
      onSecondary: () => Navigator.pop(context),
    ),
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetError(_error),
          TextFormField(
            controller: _password,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'كلمة المرور الجديدة *',
              helperText: 'ثمانية أحرف على الأقل',
            ),
            validator: (value) => (value ?? '').length < 8
                ? 'كلمة المرور ثمانية أحرف على الأقل'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirm,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور *'),
            validator: (value) =>
                value != _password.text ? 'كلمتا المرور غير متطابقتين' : null,
          ),
        ],
      ),
    ),
  );
}

/// Adds or edits a membership: company, department and role, each company
/// with its own role and permissions.
class MembershipSheet extends StatefulWidget {
  const MembershipSheet({
    super.key,
    required this.repository,
    required this.user,
    required this.options,
    this.membership,
    this.confirmDeactivate,
  });
  final UsersRepository repository;
  final AppUserRecord user;
  final OrganizationOptions options;
  final UserMembership? membership;

  /// Asked before saving an active membership as inactive.
  final Future<bool> Function()? confirmDeactivate;

  @override
  State<MembershipSheet> createState() => _MembershipSheetState();
}

class _MembershipSheetState extends State<MembershipSheet> {
  late String? _companyId;
  String? _departmentId;
  String? _roleId;
  late bool _active = widget.membership?.active ?? true;
  bool _busy = false;
  String? _error;

  List<OrgRef> get _companies => [
    for (final company in widget.options.companies)
      if (widget.options.membershipCompanyIds.contains(company.id)) company,
  ];

  List<OrgRef> get _departments => [
    for (final department in widget.options.departments)
      if (department.companyId == _companyId)
        (id: department.id, name: department.name),
  ];

  List<OrgRef> get _roles {
    final roles = widget.options.rolesFor(_companyId);
    final current = widget.membership;
    if (current != null &&
        current.companyId == _companyId &&
        !roles.any((role) => role.id == current.roleId)) {
      return [...roles, (id: current.roleId, name: current.roleName)];
    }
    return roles;
  }

  @override
  void initState() {
    super.initState();
    _companyId =
        widget.membership?.companyId ??
        (_companies.isEmpty ? null : _companies.first.id);
    _departmentId = widget.membership?.departmentId;
    _roleId = widget.membership?.roleId;
    _fit();
  }

  /// Department and role follow the company.
  void _fit() {
    final departments = _departments;
    if (!departments.any((item) => item.id == _departmentId)) {
      _departmentId = departments.isEmpty ? null : departments.first.id;
    }
    final roles = _roles;
    if (!roles.any((item) => item.id == _roleId)) {
      _roleId = roles.isEmpty ? null : roles.first.id;
    }
  }

  Future<void> _save() async {
    if (_companyId == null || _departmentId == null || _roleId == null) {
      setState(() => _error = 'اختر الشركة والإدارة والدور.');
      return;
    }
    if (widget.membership?.active == true &&
        !_active &&
        widget.confirmDeactivate != null &&
        !await widget.confirmDeactivate!()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.saveMembership(
        userId: widget.user.id,
        membership: widget.membership,
        companyId: _companyId!,
        departmentId: _departmentId!,
        roleId: _roleId!,
        active: _active,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppSheetScaffold(
    title: widget.membership == null ? 'إضافة عضوية' : 'تعديل العضوية',
    subtitle: widget.user.name,
    closeEnabled: !_busy,
    footer: AppSheetActions(
      primaryLabel: 'حفظ العضوية',
      busy: _busy,
      onPrimary: _save,
      secondaryLabel: 'إلغاء',
      onSecondary: () => Navigator.pop(context),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetError(_error),
        AppSelect<String>(
          label: 'الشركة *',
          value: _companyId,
          enabled: widget.membership == null,
          options: [
            for (final company in _companies)
              AppSelectOption(value: company.id, label: company.name),
          ],
          onChanged: (value) => setState(() {
            _companyId = value;
            _fit();
          }),
        ),
        const SizedBox(height: 12),
        AppSelect<String>(
          label: 'الإدارة *',
          value: _departmentId,
          options: [
            for (final department in _departments)
              AppSelectOption(value: department.id, label: department.name),
          ],
          onChanged: (value) => setState(() => _departmentId = value),
        ),
        const SizedBox(height: 12),
        AppSelect<String>(
          label: 'الدور *',
          value: _roleId,
          options: [
            for (final role in _roles)
              AppSelectOption(value: role.id, label: role.name),
          ],
          onChanged: (value) => setState(() => _roleId = value),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('العضوية نشطة'),
          value: _active,
          onChanged: (value) => setState(() => _active = value),
        ),
      ],
    ),
  );
}

/// Chooses the projects and offices the user works on.
class CostCentersSheet extends StatefulWidget {
  const CostCentersSheet({
    super.key,
    required this.repository,
    required this.user,
  });
  final UsersRepository repository;
  final AppUserRecord user;

  @override
  State<CostCentersSheet> createState() => _CostCentersSheetState();
}

class _CostCentersSheetState extends State<CostCentersSheet> {
  final _search = TextEditingController();
  late final Set<String> _selected = widget.user.costCenterIds.toSet();
  List<ReferenceRecord>? _centers;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final centers = await widget.repository.allCostCenters();
      if (mounted) setState(() => _centers = centers);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  /// Inactive centres stay listed only while the user still has them.
  List<ReferenceRecord> get _selectable => [
    for (final center in _centers ?? const <ReferenceRecord>[])
      if (center.active || widget.user.costCenterIds.contains(center.id))
        center,
  ];

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await widget.repository.saveCostCenters(
        widget.user,
        _selected.toList(),
      );
      if (mounted) Navigator.pop(context, saved);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final query = normalizeArabic(_search.text);
    final selectable = _selectable;
    final visible = [
      for (final center in selectable)
        if (query.isEmpty ||
            normalizeArabic('${center.name} ${center.code}').contains(query))
          center,
    ];
    final allSelected =
        selectable.isNotEmpty &&
        selectable.every((center) => _selected.contains(center.id));
    return AppSheetScaffold(
      title: 'إدارة مراكز التكلفة',
      subtitle: widget.user.name,
      closeEnabled: !_busy,
      footer: AppSheetActions(
        primaryLabel: 'حفظ التعيينات',
        busy: _busy,
        onPrimary: _centers == null ? null : _save,
        secondaryLabel: 'إلغاء',
        onSecondary: () => Navigator.pop(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetError(_error),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'ابحث بالاسم أو الكود…',
              prefixIcon: Icon(LucideIcons.search, size: 19),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_selected.length} محدد',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: _centers == null
                    ? null
                    : () => setState(() {
                        if (allSelected) {
                          _selected.clear();
                        } else {
                          _selected.addAll(selectable.map((c) => c.id));
                        }
                      }),
                child: Text(allSelected ? 'إلغاء تحديد الكل' : 'تحديد الكل'),
              ),
            ],
          ),
          if (_centers == null && _error == null)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (visible.isEmpty)
            const AppEmptyState(
              icon: LucideIcons.searchX,
              title: 'لا توجد مراكز تكلفة مطابقة',
            )
          else
            for (final center in visible)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _selected.contains(center.id),
                onChanged: (checked) => setState(() {
                  if (checked == true) {
                    _selected.add(center.id);
                  } else {
                    _selected.remove(center.id);
                  }
                }),
                title: Text(
                  center.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${center.code} · ${center.type == 'OFFICE' ? 'مكتب' : 'مشروع'}'
                  '${center.active ? '' : ' · غير نشط'}',
                  style: TextStyle(color: tokens.muted, fontSize: 12),
                ),
              ),
        ],
      ),
    );
  }
}
