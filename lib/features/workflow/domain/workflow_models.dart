class WorkflowPerson {
  const WorkflowPerson({required this.id, required this.name});

  factory WorkflowPerson.fromJson(Map<String, dynamic> json) => WorkflowPerson(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '—',
  );

  final String id;
  final String name;
}

class WorkflowInboxRow {
  const WorkflowInboxRow({
    required this.docType,
    required this.docTypeName,
    required this.docId,
    required this.submittedBy,
    required this.submittedAt,
    required this.waitingSince,
    this.number,
    this.title,
    this.amount,
    this.step,
  });

  factory WorkflowInboxRow.fromJson(Map<String, dynamic> json) =>
      WorkflowInboxRow(
        docType: json['docType']?.toString() ?? '',
        docTypeName: json['docTypeName']?.toString() ?? 'طلب',
        docId: json['docId']?.toString() ?? '',
        number: json['number']?.toString(),
        title: json['title']?.toString(),
        amount: json['amount']?.toString(),
        step: json['step']?.toString(),
        submittedBy: WorkflowPerson.fromJson(
          Map<String, dynamic>.from(json['submittedBy'] as Map? ?? const {}),
        ),
        submittedAt: json['submittedAt']?.toString() ?? '',
        waitingSince: json['waitingSince']?.toString() ?? '',
      );

  final String docType, docTypeName, docId, submittedAt, waitingSince;
  final String? number, title, amount, step;
  final WorkflowPerson submittedBy;
}

class WorkflowInbox {
  const WorkflowInbox({
    required this.items,
    required this.total,
    required this.page,
    required this.size,
  });

  factory WorkflowInbox.fromJson(Map<String, dynamic> json) => WorkflowInbox(
    items: (json['items'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => WorkflowInboxRow.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false),
    total: (json['total'] as num?)?.toInt() ?? 0,
    page: (json['page'] as num?)?.toInt() ?? 0,
    size: (json['size'] as num?)?.toInt() ?? 20,
  );

  final List<WorkflowInboxRow> items;
  final int total, page, size;
}

class WorkflowInboxCount {
  const WorkflowInboxCount({this.count = 0, this.awaitingCompletion = 0});

  factory WorkflowInboxCount.fromJson(Map<String, dynamic> json) =>
      WorkflowInboxCount(
        count: (json['count'] as num?)?.toInt() ?? 0,
        awaitingCompletion: (json['awaitingCompletion'] as num?)?.toInt() ?? 0,
      );

  final int count, awaitingCompletion;
  int get total => count + awaitingCompletion;
}

class WorkflowAction {
  const WorkflowAction({
    required this.code,
    required this.label,
    required this.commentRequired,
  });

  factory WorkflowAction.fromJson(Map<String, dynamic> json) => WorkflowAction(
    code: json['code']?.toString() ?? '',
    label: json['label']?.toString() ?? '',
    commentRequired: json['commentRequired'] == true,
  );

  final String code, label;
  final bool commentRequired;
}

class WorkflowDecision {
  const WorkflowDecision({
    required this.action,
    required this.actor,
    required this.at,
    this.comment,
  });

  factory WorkflowDecision.fromJson(Map<String, dynamic> json) =>
      WorkflowDecision(
        action: json['action']?.toString() ?? '',
        actor: WorkflowPerson.fromJson(
          Map<String, dynamic>.from(json['actor'] as Map? ?? const {}),
        ),
        at: json['at']?.toString() ?? '',
        comment: json['comment']?.toString(),
      );

  final String action, at;
  final WorkflowPerson actor;
  final String? comment;
}

class WorkflowStep {
  const WorkflowStep({
    required this.name,
    required this.status,
    required this.approvers,
    required this.waitingFor,
  });

  factory WorkflowStep.fromJson(Map<String, dynamic> json) => WorkflowStep(
    name: json['name']?.toString() ?? '',
    status: json['status']?.toString() ?? '',
    approvers: (json['approvers'] as List? ?? const [])
        .map((item) => item.toString())
        .toList(growable: false),
    waitingFor: (json['waitingFor'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => WorkflowPerson.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false),
  );

  final String name, status;
  final List<String> approvers;
  final List<WorkflowPerson> waitingFor;
}

class WorkflowState {
  const WorkflowState({
    required this.status,
    required this.actions,
    required this.steps,
    required this.history,
    this.currentStep,
  });

  factory WorkflowState.fromJson(Map<String, dynamic> json) => WorkflowState(
    status: json['status']?.toString() ?? 'NONE',
    currentStep: json['currentStep']?.toString(),
    actions: (json['actions'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => WorkflowAction.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false),
    steps: (json['steps'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => WorkflowStep.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false),
    history: (json['history'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => WorkflowDecision.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false),
  );

  final String status;
  final String? currentStep;
  final List<WorkflowAction> actions;
  final List<WorkflowStep> steps;
  final List<WorkflowDecision> history;
}
