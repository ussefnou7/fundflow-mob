import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_table.dart';
import '../../custody/domain/custody_models.dart' show shortDate;
import '../../custody/presentation/custody_widgets.dart';
import '../data/workflow_repository.dart';
import '../domain/workflow_models.dart';

/// A document-agnostic workflow surface. Any feature can attach it by passing
/// the workflow document type and id; permissions and available actions remain
/// server-driven through [WorkflowState.actions].
class WorkflowPanel extends StatefulWidget {
  const WorkflowPanel({
    super.key,
    required this.repository,
    required this.docType,
    required this.docId,
    this.onChanged,
  });

  final WorkflowRepository repository;
  final String docType;
  final String docId;
  final VoidCallback? onChanged;

  @override
  State<WorkflowPanel> createState() => _WorkflowPanelState();
}

class _WorkflowPanelState extends State<WorkflowPanel> {
  WorkflowState? _state;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant WorkflowPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.docType != widget.docType ||
        oldWidget.docId != widget.docId ||
        oldWidget.repository != widget.repository) {
      _state = null;
      _error = null;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final state = await widget.repository.state(widget.docType, widget.docId);
      if (mounted) {
        setState(() {
          _state = state;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _act(WorkflowAction action) async {
    final comment = await showAppSheet<String?>(
      context,
      builder: (_) => _WorkflowActionSheet(action: action),
    );
    if (comment == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final state = await widget.repository.act(
        docType: widget.docType,
        docId: widget.docId,
        action: action.code,
        comment: comment,
      );
      if (!mounted) return;
      setState(() => _state = state);
      widget.onChanged?.call();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: context.tokens.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: context.tokens.wash,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                LucideIcons.gitBranch,
                size: 18,
                color: context.tokens.brandStrong,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'مسار الموافقة',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  if (_state?.currentStep?.isNotEmpty == true)
                    Text(
                      _state!.currentStep!,
                      style: TextStyle(
                        color: context.tokens.muted,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (_state != null)
              AppTag(
                _statusLabel(_state!.status),
                icon: _statusIcon(_state!.status),
              ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          MessagePanel(message: _error!, onRetry: _load),
        ] else if (_state == null) ...[
          const SizedBox(height: 14),
          const Center(child: CircularProgressIndicator()),
        ] else ...[
          if (_state!.steps.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final step in _state!.steps) _WorkflowStepRow(step: step),
          ],
          if (_state!.history.isNotEmpty) ...[
            Divider(height: 24, color: context.tokens.line),
            const Text(
              'سجل القرارات',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            for (final decision in _state!.history)
              _DecisionRow(decision: decision),
          ],
          if (_state!.actions.isNotEmpty) ...[
            Divider(height: 24, color: context.tokens.line),
            Row(
              children: [
                for (
                  var index = 0;
                  index < _state!.actions.length;
                  index++
                ) ...[
                  Expanded(
                    flex: _state!.actions[index].code == 'WITHDRAW' ? 4 : 3,
                    child: _WorkflowActionButton(
                      action: _state!.actions[index],
                      busy: _busy,
                      onPressed: () => _act(_state!.actions[index]),
                    ),
                  ),
                  if (index != _state!.actions.length - 1)
                    const SizedBox(width: 8),
                ],
              ],
            ),
          ],
        ],
      ],
    ),
  );
}

class _WorkflowActionButton extends StatelessWidget {
  const _WorkflowActionButton({
    required this.action,
    required this.busy,
    required this.onPressed,
  });

  final WorkflowAction action;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final (foreground, background, border, icon) = switch (action.code) {
      'APPROVE' => (
        Colors.white,
        AppTokens.success,
        AppTokens.success,
        LucideIcons.check,
      ),
      'REJECT' => (
        Colors.white,
        AppTokens.danger,
        AppTokens.danger,
        LucideIcons.x,
      ),
      'WITHDRAW' => (
        const Color(0xFF7A4B00),
        AppTokens.warningTint,
        AppTokens.warning,
        LucideIcons.undo2,
      ),
      _ => (
        Colors.white,
        context.tokens.brand,
        context.tokens.brand,
        action.code == 'COMPLETE' ? LucideIcons.checkCheck : LucideIcons.send,
      ),
    };
    return FilledButton.icon(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
        padding: const EdgeInsets.symmetric(horizontal: 7),
        foregroundColor: foreground,
        backgroundColor: background,
        disabledBackgroundColor: background.withValues(alpha: .45),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
      icon: Icon(icon, size: 15),
      label: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(_actionButtonLabel(action), maxLines: 1),
      ),
    );
  }
}

class _WorkflowStepRow extends StatelessWidget {
  const _WorkflowStepRow({required this.step});

  final WorkflowStep step;

  @override
  Widget build(BuildContext context) {
    final done = step.status == 'DONE';
    final current = step.status == 'CURRENT';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            done
                ? LucideIcons.circleCheck
                : current
                ? LucideIcons.clock3
                : LucideIcons.circle,
            size: 19,
            color: done
                ? AppTokens.success
                : current
                ? AppTokens.warning
                : context.tokens.muted,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  step.waitingFor.isNotEmpty
                      ? 'بانتظار: ${step.waitingFor.map((item) => item.name).join('، ')}'
                      : step.approvers.join('، '),
                  style: TextStyle(color: context.tokens.muted, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DecisionRow extends StatelessWidget {
  const _DecisionRow({required this.decision});

  final WorkflowDecision decision;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(LucideIcons.history, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_actionLabel(decision.action)} · ${decision.actor.name}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                [
                  shortDate(decision.at),
                  if (decision.comment?.isNotEmpty == true) decision.comment!,
                ].join(' · '),
                style: TextStyle(color: context.tokens.muted, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _WorkflowActionSheet extends StatefulWidget {
  const _WorkflowActionSheet({required this.action});

  final WorkflowAction action;

  @override
  State<_WorkflowActionSheet> createState() => _WorkflowActionSheetState();
}

class _WorkflowActionSheetState extends State<_WorkflowActionSheet> {
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppSheetScaffold(
    title: _actionButtonLabel(widget.action),
    footer: AppSheetActions(
      primaryLabel: 'تأكيد ${_actionButtonLabel(widget.action)}',
      onPrimary: () {
        if (widget.action.commentRequired && _comment.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('اكتب سبب القرار أولًا')),
          );
          return;
        }
        Navigator.pop(context, _comment.text.trim());
      },
      secondaryLabel: 'إلغاء',
      onSecondary: () => Navigator.pop(context),
      destructive: widget.action.code == 'REJECT',
    ),
    child: TextField(
      controller: _comment,
      minLines: 3,
      maxLines: 5,
      decoration: InputDecoration(
        labelText: widget.action.commentRequired
            ? 'سبب القرار *'
            : 'تعليق اختياري',
      ),
    ),
  );
}

String _statusLabel(String value) => switch (value) {
  'PENDING' => 'قيد المراجعة',
  'APPROVED' => 'معتمد',
  'REJECTED' => 'مرفوض',
  'WITHDRAWN' => 'مسحوب',
  'COMPLETED' => 'مكتمل',
  _ => value,
};

IconData _statusIcon(String value) => switch (value) {
  'APPROVED' || 'COMPLETED' => LucideIcons.circleCheck,
  'REJECTED' => LucideIcons.circleX,
  'PENDING' => LucideIcons.clock3,
  _ => LucideIcons.gitBranch,
};

String _actionLabel(String value) => switch (value) {
  'APPROVE' => 'موافقة',
  'REJECT' => 'رفض',
  'WITHDRAW' => 'سحب',
  'COMPLETE' => 'تنفيذ',
  'SUBMIT' => 'إرسال',
  _ => value,
};

String _actionButtonLabel(WorkflowAction action) => switch (action.code) {
  'APPROVE' => 'موافقة',
  'REJECT' => 'رفض',
  'WITHDRAW' => 'سحب الطلب',
  'COMPLETE' => 'تنفيذ',
  'SUBMIT' => 'إرسال',
  _ => action.label,
};
