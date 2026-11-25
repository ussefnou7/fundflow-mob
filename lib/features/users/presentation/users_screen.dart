import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_pagination.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_table.dart';
import '../../custody/presentation/custody_widgets.dart';
import '../data/users_repository.dart';
import '../domain/user_models.dart';
import 'user_file_screen.dart';
import 'user_sheets.dart';

/// The company's users, as on the web: search, status and role filters, a
/// table, and the user's file one tap away.
class UsersScreen extends StatefulWidget {
  const UsersScreen({
    super.key,
    required this.repository,
    required this.currentUserId,
    required this.activeCompanyId,
    required this.canManage,
    this.currentRoleCode,
    this.permissions = const {},
  });

  final UsersRepository repository;
  final String currentUserId;
  final String? activeCompanyId;
  final String? currentRoleCode;

  /// USERS_MANAGE: add, edit, reset and memberships.
  final bool canManage;

  /// The signed-in user's permissions in the active company.
  final Set<String> permissions;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  UsersPage? _result;
  OrganizationOptions? _options;
  String _status = '';
  String _roleId = '';
  int _page = 0;
  bool _loading = true;
  String? _error;
  String? _openedId;

  @override
  void initState() {
    super.initState();
    _load();
    _loadOptions();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      final options = await widget.repository.options(
        activeCompanyId: widget.activeCompanyId,
        ownPermissions: widget.permissions,
        ownRoleCode: widget.currentRoleCode,
      );
      if (mounted) setState(() => _options = options);
    } catch (_) {
      // Without options the role filter and the add button stay hidden.
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.repository.list(
        query: _search.text,
        active: _status.isEmpty ? null : _status == 'true',
        roleId: _roleId,
        page: _page,
      );
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _page = 0;
      _load();
    });
    setState(() {});
  }

  Future<void> _create() async {
    final options = _options;
    if (options == null) return;
    final saved = await showAppSheet<AppUserRecord>(
      context,
      tall: true,
      dismissible: false,
      builder: (_) => UserSheet(
        repository: widget.repository,
        roles: options.rolesFor(widget.activeCompanyId),
      ),
    );
    if (saved == null || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تمت إضافة المستخدم')));
    setState(() => _openedId = saved.id);
  }

  @override
  Widget build(BuildContext context) {
    if (_openedId != null) {
      return UserFileScreen(
        key: ValueKey(_openedId),
        repository: widget.repository,
        userId: _openedId!,
        currentUserId: widget.currentUserId,
        currentRoleCode: widget.currentRoleCode,
        activeCompanyId: widget.activeCompanyId,
        canManage: widget.canManage,
        permissions: widget.permissions,
        onBack: () {
          setState(() => _openedId = null);
          _load();
        },
      );
    }
    final tokens = context.tokens;
    final rows = _result?.items ?? const <AppUserRecord>[];
    final roles = _options?.roles ?? const [];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          PageHeader(
            title: 'المستخدمون',
            subtitle: '${_result?.total ?? 0} مستخدم',
            action: widget.canManage && _options != null
                ? AppAddButton(label: 'مستخدم جديد', onPressed: _create)
                : null,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            textAlign: TextAlign.right,
            onChanged: _onSearch,
            decoration: InputDecoration(
              hintText: 'ابحث بالاسم أو الكود أو اسم الدخول…',
              fillColor: Colors.white,
              prefixIcon: const Icon(LucideIcons.search, size: 19),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: tokens.line),
              ),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'مسح البحث',
                      onPressed: () {
                        _search.clear();
                        _onSearch('');
                      },
                      icon: const Icon(LucideIcons.x, size: 18),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppSelect<String>(
                  compact: true,
                  label: 'الحالة',
                  value: _status,
                  options: const [
                    AppSelectOption(value: '', label: 'نشط وغير نشط'),
                    AppSelectOption(value: 'true', label: 'نشط'),
                    AppSelectOption(value: 'false', label: 'غير نشط'),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _status = value ?? '';
                      _page = 0;
                    });
                    _load();
                  },
                ),
              ),
              if (roles.isNotEmpty) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: AppSelect<String>(
                    compact: true,
                    label: 'الدور',
                    value: _roleId,
                    options: [
                      const AppSelectOption(value: '', label: 'كل الأدوار'),
                      for (final role in roles)
                        AppSelectOption(value: role.id, label: role.name),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _roleId = value ?? '';
                        _page = 0;
                      });
                      _load();
                    },
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (_error != null)
            MessagePanel(message: _error!, onRetry: _load)
          else
            AppDataTable<AppUserRecord>(
              loading: _loading,
              rows: rows,
              onTap: (user) => setState(() => _openedId = user.id),
              empty: const AppEmptyState(
                icon: LucideIcons.usersRound,
                title: 'لا يوجد مستخدمون مطابقون',
              ),
              columns: const [
                AppTableColumn('المستخدم', 170),
                AppTableColumn('الدور', 100),
                AppTableColumn('الحالة', 88),
              ],
              cells: (user) => [
                AppTableTitle(
                  title: user.name,
                  subtitle: '\u2066@${user.username}\u2069 · ${user.code}',
                ),
                Text(user.roleName ?? '—', maxLines: 2),
                AppTag(
                  user.active ? 'نشط' : 'غير نشط',
                  tone: user.active ? AppTone.success : AppTone.danger,
                ),
              ],
            ),
          if (_result != null && _result!.total > 0) ...[
            const SizedBox(height: 12),
            AppPagination(
              page: _page,
              size: _result!.size,
              total: _result!.total,
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
