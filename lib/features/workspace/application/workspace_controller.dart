import 'package:flutter/foundation.dart';

import '../../custody/data/custody_repository.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../crm/data/crm_repository.dart';
import '../../extracts/data/extract_repository.dart';
import '../../notifications/data/notification_repository.dart';
import '../../meetings/data/meetings_repository.dart';
import '../../settings/data/settings_repository.dart';
import '../../scm/data/scm_repository.dart';
import '../../treasury/data/treasury_repository.dart';
import '../../users/data/users_repository.dart';
import '../../workflow/data/workflow_repository.dart';
import '../../workflow/domain/workflow_models.dart';
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
    this.scm,
    this.crm,
    this.meetings,
    this.workflow,
    this.users,
    this.dashboard,
  });

  WorkspaceController.seeded({
    required this.custody,
    required this.context,
    this.settings,
    this.extracts,
    this.notifications,
    this.treasury,
    this.scm,
    this.crm,
    this.meetings,
    this.workflow,
    this.users,
    this.dashboard,
  }) : repository = null;

  final WorkspaceRepository? repository;
  final CustodyRepository custody;
  final SettingsRepository? settings;
  final ExtractRepository? extracts;
  final NotificationRepository? notifications;
  final TreasuryRepository? treasury;
  final ScmRepository? scm;
  final CrmRepository? crm;
  final MeetingsRepository? meetings;
  final WorkflowRepository? workflow;
  final UsersRepository? users;
  final DashboardRepository? dashboard;

  WorkflowInboxCount workflowApprovals = const WorkflowInboxCount();
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
      workflowApprovals = await _workflowApprovals();
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
      workflowApprovals = await _workflowApprovals();
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
    workflowApprovals = await _workflowApprovals();
    notifyListeners();
  }

  void setWorkflowApprovals(WorkflowInboxCount value) {
    workflowApprovals = value;
    notifyListeners();
  }

  Future<WorkflowInboxCount> _workflowApprovals() async {
    try {
      return await workflow?.count() ?? const WorkflowInboxCount();
    } catch (_) {
      return const WorkflowInboxCount();
    }
  }

  void reset() {
    _generation++;
    workflowApprovals = const WorkflowInboxCount();
    loading = false;
    context = null;
    tenantLogo = null;
    error = null;
    switchingCompany = false;
    notifyListeners();
  }
}
