import 'package:flutter/foundation.dart';

import '../../custody/data/custody_repository.dart';
import '../../extracts/data/extract_repository.dart';
import '../../hr/application/punch_sensors.dart';
import '../../hr/data/hr_repository.dart';
import '../../hr/domain/hr_models.dart';
import '../../notifications/data/notification_repository.dart';
import '../../settings/data/settings_repository.dart';
import '../../treasury/data/treasury_repository.dart';
import '../data/workspace_repository.dart';
import '../domain/workspace_context.dart';

class WorkspaceController extends ChangeNotifier {
  WorkspaceController({
    required this.repository,
    required this.custody,
    this.settings,
    this.extracts,
    this.notifications,
    this.treasury,
    this.hr,
    this.punchSensors,
  });

  WorkspaceController.seeded({
    required this.custody,
    required this.context,
    this.settings,
    this.extracts,
    this.notifications,
    this.treasury,
    this.hr,
    this.punchSensors,
  }) : repository = null;

  final WorkspaceRepository? repository;
  final CustodyRepository custody;
  final SettingsRepository? settings;
  final ExtractRepository? extracts;
  final NotificationRepository? notifications;
  final TreasuryRepository? treasury;

  /// The employee's own HR self-service; null in builds without HR.
  final HrRepository? hr;
  final PunchSensors? punchSensors;

  /// Whether this user decides on phones or punches here, and how many wait.
  HrApprovalSummary approvals = const HrApprovalSummary();
  WorkspaceContext? context;
  int _generation = 0;
  bool loading = false;
  bool switchingCompany = false;
  String? error;
  Uint8List? tenantLogo;

  Future<void> initialize() async {
    final generation = ++_generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final loaded = await repository!.load();
      final logo = loaded.hasTenantLogo
          ? await repository!.loadTenantLogo()
          : null;
      if (generation != _generation) return;
      context = loaded;
      tenantLogo = logo;
      approvals = await _approvals();
    } catch (exception) {
      if (generation != _generation) return;
      error = exception.toString().replaceFirst('ApiError: ', '');
    } finally {
      if (generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> selectCompany(String companyId) async {
    if (context?.activeCompanyId == companyId || switchingCompany) return true;
    final generation = ++_generation;
    final source = repository;
    if (source == null) return false;
    switchingCompany = true;
    error = null;
    notifyListeners();
    try {
      final loaded = await source.selectCompany(companyId);
      if (generation != _generation) return false;
      context = loaded;
      approvals = await _approvals();
      return true;
    } catch (exception) {
      if (generation != _generation) return false;
      error = exception.toString().replaceFirst('ApiError: ', '');
      return false;
    } finally {
      if (generation == _generation) {
        switchingCompany = false;
        notifyListeners();
      }
    }
  }

  /// After a decision or a notification: the drawer's count follows.
  Future<void> refreshApprovals() async {
    approvals = await _approvals();
    notifyListeners();
  }

  /// Nothing to approve when it cannot tell: the screen just stays hidden.
  Future<HrApprovalSummary> _approvals() async {
    try {
      return await hr?.approvalSummary() ?? const HrApprovalSummary();
    } catch (_) {
      return const HrApprovalSummary();
    }
  }

  void reset() {
    _generation++;
    approvals = const HrApprovalSummary();
    loading = false;
    context = null;
    tenantLogo = null;
    error = null;
    switchingCompany = false;
    notifyListeners();
  }
}
