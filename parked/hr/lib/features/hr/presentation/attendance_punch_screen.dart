import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_refresh_page.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_table.dart';
import '../../custody/presentation/custody_widgets.dart';
import '../application/face_liveness.dart';
import '../application/punch_sensors.dart';
import '../data/hr_repository.dart';
import '../domain/hr_models.dart';
import 'hr_widgets.dart';

/// «الحضور والانصراف»: the employee's punch for today. Every time shown is
/// the server's; the phone's clock is only reported with the punch.
class AttendancePunchScreen extends StatefulWidget {
  const AttendancePunchScreen({
    super.key,
    required this.repository,
    required this.sensors,
  });

  final HrRepository repository;
  final PunchSensors sensors;

  @override
  State<AttendancePunchScreen> createState() => _AttendancePunchScreenState();
}

/// The nearest allowed place and how far the phone is from it.
class _Range {
  const _Range({required this.place, required this.distanceM});
  final HrPlace place;
  final int distanceM;
  bool get inside => distanceM <= place.radiusM;
}

class _AttendancePunchScreenState extends State<AttendancePunchScreen> {
  HrToday? _today;

  /// Today's row of the timesheet; null before any accepted punch.
  HrTimesheetDay? _day;
  PunchFix? _fix;
  String? _error;
  bool _loading = true;
  bool _locating = false;
  bool _punching = false;
  bool _punchInProgress = false;
  bool _enrolling = false;

  /// The punch the employee chose; null follows the expected next one.
  String? _type;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
    _ticker = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final today = await widget.repository.today(
        installationId: widget.sensors.installationId,
      );
      final day = await _dayOf(today);
      if (!mounted) return;
      setState(() {
        _today = today;
        _day = day;
        _type = null;
      });
      if (today.needsPlace && _fix == null) unawaited(_locate());
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// The summary is extra: without it the screen still punches.
  Future<HrTimesheetDay?> _dayOf(HrToday today) async {
    final date = DateTime.tryParse(today.dateTrx);
    if (date == null) return null;
    try {
      final days = await widget.repository.timesheet(from: date, to: date);
      return days.where((d) => d.workDate == today.dateTrx).firstOrNull;
    } catch (_) {
      return null;
    }
  }

  Future<PunchFix> _locate() async {
    setState(() => _locating = true);
    final fix = await widget.sensors.locate();
    if (mounted) {
      setState(() {
        _fix = fix;
        _locating = false;
      });
    }
    return fix;
  }

  _Range? _range(HrToday today, PunchFix? fix) {
    if (fix == null || !fix.located || today.places.isEmpty) return null;
    _Range? best;
    for (final place in today.places) {
      final distance = _distanceM(fix.lat!, fix.lng!, place.lat, place.lng);
      if (best == null || distance < best.distanceM) {
        best = _Range(place: place, distanceM: distance);
      }
    }
    return best;
  }

  String _punchType(HrToday today) => _type ?? today.nextPunch;

  Future<void> _punch() async {
    final today = _today;
    if (today == null || _punchInProgress || _locating || _enrolling) return;
    final punchType = _punchType(today);
    _punchInProgress = true;
    try {
      // Enrol before the first punch; cancelling or failing enrolment sends no punch.
      if (today.selfieRequired && !today.faceEnrolled) {
        if (!today.faceAvailable) {
          throw StateError(
            'خدمة بصمة الوجه غير متاحة حاليًا؛ تواصل مع الموارد البشرية',
          );
        }
        if (!today.mayEnrolFace) {
          throw StateError(
            'يجب ربط هذا الهاتف واعتماده قبل تسجيل الوجه لهذه الوردية',
          );
        }
        if (!await _enrol() || !mounted) return;
      }
      final current = _today ?? today;
      final fix = await _locate();
      final range = _range(today, fix);
      String? note;
      final doubtful =
          fix.mocked || (today.needsPlace && (range == null || !range.inside));
      if (doubtful) {
        if (!mounted) return;
        note = await showAppSheet<String>(
          context,
          builder: (context) =>
              _ConfirmSheet(punchType: punchType, fix: fix, range: range),
        );
        if (note == null) return;
      }
      var input = PunchInput(
        punchType: punchType,
        installationId: widget.sensors.installationId,
        // The phone's own clock, so the server can flag a skewed one.
        deviceTime: DateTime.now(),
        lat: fix.lat,
        lng: fix.lng,
        gpsAccuracyM: fix.accuracyM,
        mockLocation: fix.mocked,
        note: note,
      );
      if (current.takesSelfie) {
        // The server draws the action and checks its photo beside the front one.
        final challenge = current.faceAvailable
            ? await widget.repository.faceChallenge()
            : null;
        if (!mounted) return;
        final face = await widget.sensors.captureFace(
          context,
          action: challenge?.action,
        );
        if (face == null || !mounted) return;
        if (face.problem != null) throw StateError(face.problem!);
        if (face.path == null || !face.livenessOk) {
          throw StateError('يجب إكمال التحقق من الوجه لتسجيل البصمة');
        }
        input = input.withSelfie(
          face.path,
          livenessOk: face.livenessOk,
          actionPath: challenge == null
              ? null
              : face.of(poseFor(challenge.action)),
          challengeId: challenge?.id,
        );
      }
      // Busy only once the employee has committed, never behind the sheet.
      setState(() => _punching = true);
      final punch = await widget.repository.punch(input);
      if (!mounted) return;
      final label = punch.punchType == 'IN' ? 'الحضور' : 'الانصراف';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            punch.status == 'PENDING'
                ? 'تم تسجيل $label ${hrClock(punch.punchedAt)} · بانتظار موافقة مديرك'
                : 'تم تسجيل $label ${hrClock(punch.punchedAt)}',
          ),
        ),
      );
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_message(error))));
      }
    } finally {
      _punchInProgress = false;
      if (mounted) setState(() => _punching = false);
    }
  }

  /// Three photos after one live check; the server keeps the face from then.
  Future<bool> _enrol() async {
    if (_enrolling) return false;
    setState(() => _enrolling = true);
    try {
      final face = await widget.sensors.captureFace(context, enrol: true);
      if (face == null || !mounted) return false;
      if (face.problem != null) throw StateError(face.problem!);
      if (face.paths.isEmpty || !face.livenessOk) return false;
      await widget.repository.enrolFace(
        photoPaths: face.paths,
        installationId: widget.sensors.installationId,
        livenessOk: face.livenessOk,
      );
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تسجيل الوجه بنجاح')));
      await _load();
      return mounted && _today?.faceEnrolled == true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_message(error))));
      }
      return false;
    } finally {
      if (mounted) setState(() => _enrolling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = _today;
    final now = widget.repository.clock.now();
    return AppRefreshPage(
      onRefresh: () async {
        _fix = null;
        await _load();
      },
      children: [
        PageHeader(
          title: 'الحضور والانصراف',
          subtitle: now == null
              ? 'حسب توقيت الخادم'
              : '${hrWeekday(now)} ${two(now.day)} ${hrMonths[now.month - 1]} ${now.year}',
        ),
        const SizedBox(height: 14),
        if (_error != null && today == null)
          MessagePanel(message: _error!, onRetry: _load)
        else if (today == null)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          ..._notices(today),
          if (today.mayEnrolFace) ...[
            _FaceEnrolCard(
              busy: _enrolling || _punching,
              onEnrol: () async {
                await _enrol();
              },
            ),
            const SizedBox(height: 12),
          ],
          _PunchHero(
            today: today,
            now: now,
            punchType: _punchType(today),
            busy: _punching || _locating || _enrolling,
            onPunch: _canPunch(today) && !_enrolling ? _punch : null,
            onType: _canPunch(today) && !_punching && !_locating
                ? (type) => setState(() => _type = type)
                : null,
          ),
          const SizedBox(height: 12),
          _LocationCard(
            today: today,
            fix: _fix,
            range: _range(today, _fix),
            locating: _locating,
            onRefresh: _locating ? null : _locate,
          ),
          const SizedBox(height: 20),
          Text(
            'ملخص اليوم',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: context.tokens.ink,
            ),
          ),
          const SizedBox(height: 10),
          _DaySummary(
            day: _day,
            pending: today.punches.where((p) => p.status == 'PENDING').toList(),
          ),
        ],
      ],
    );
  }

  /// Any phone punches; one that is not the account's waits for the manager.
  /// Only the bound phone HR revoked is refused.
  bool _canPunch(HrToday today) =>
      !_loading && today.status == 'ACTIVE' && !_revokedHere(today);

  bool _revokedHere(HrToday today) =>
      today.deviceStatus == 'REVOKED' && today.onBoundPhone == true;

  List<Widget> _notices(HrToday today) {
    final (tone, icon, title, message) = switch (today) {
      _ when today.status != 'ACTIVE' => (
        AppTone.danger,
        LucideIcons.userX,
        'لا يمكن تسجيل البصمة',
        'حالتك الوظيفية: ${employeeStatusLabel(today.status)}.',
      ),
      _ when _revokedHere(today) => (
        AppTone.danger,
        LucideIcons.smartphone,
        'تم إلغاء اعتماد هذا الجهاز',
        'سجّل الدخول بكلمة المرور واربط الجهاز بحسابك من جديد.',
      ),
      _ when today.bindingRequested => (
        AppTone.info,
        LucideIcons.hourglass,
        'طلب ربط هذا الجهاز بانتظار موافقة مديرك',
        'يمكنك تسجيل الحضور والانصراف؛ تبقى البصمات معلقة حتى الموافقة على ربط الجهاز.',
      ),
      _ when today.onBoundPhone == false => (
        AppTone.warning,
        LucideIcons.smartphone,
        'هذا الجهاز غير مربوط بحسابك',
        'البصمة منه تُرسَل لمديرك المباشر للموافقة. لربطه بحسابك سجّل الدخول بكلمة المرور واختر «ربط الجهاز بحسابي».',
      ),
      _ when today.deviceStatus == 'PENDING' => (
        AppTone.info,
        LucideIcons.hourglass,
        'الجهاز بانتظار الاعتماد',
        'يمكنك تسجيل البصمات؛ تبقى معلقة حتى اعتماد الجهاز.',
      ),
      _ => (null, null, null, null),
    };
    if (tone == null) return const [];
    final (fg, bg) = switch (tone) {
      AppTone.danger => (AppTokens.danger, AppTokens.dangerTint),
      AppTone.warning => (AppTokens.warning, AppTokens.warningTint),
      _ => (AppTokens.info, AppTokens.infoTint),
    };
    return [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 19, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title!,
                    style: TextStyle(
                      color: fg,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    message!,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.7,
                      color: context.tokens.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
    ];
  }
}

/// Asks the employee to enrol their face once, from their approved phone.
class _FaceEnrolCard extends StatelessWidget {
  const _FaceEnrolCard({required this.busy, required this.onEnrol});
  final bool busy;
  final VoidCallback onEnrol;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.line),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tokens.brand.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(LucideIcons.scanFace, size: 19, color: tokens.brand),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تسجيل الوجه',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                Text(
                  'مرة واحدة: ثلاث صور لوجهك تُطابق عليها بصماتك على الخادم.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.6,
                    color: tokens.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: busy ? null : onEnrol,
            child: Text(busy ? 'جارٍ الإرسال…' : 'تسجيل'),
          ),
        ],
      ),
    );
  }
}

int _distanceM(double lat1, double lng1, double lat2, double lng2) {
  const earth = 6371000.0;
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return (earth * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))).round();
}

class _PunchHero extends StatelessWidget {
  const _PunchHero({
    required this.today,
    required this.now,
    required this.punchType,
    required this.busy,
    required this.onPunch,
    required this.onType,
  });

  final HrToday today;

  /// The server's time, null until it answered.
  final DateTime? now;
  final String punchType;
  final bool busy;
  final VoidCallback? onPunch;
  final ValueChanged<String>? onType;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    const soft = Color(0xB8FFFFFF);
    final shift = today.shift;
    final punchIn = punchType == 'IN';
    final elapsed = today.elapsedMinutes;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [tokens.brand, tokens.brandStrong, tokens.brandDeep],
          stops: const [0, .55, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: tokens.brandStrong.withValues(alpha: .35),
            blurRadius: 30,
            offset: const Offset(0, 14),
            spreadRadius: -16,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(LucideIcons.calendarClock, size: 17, color: soft),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  shift == null
                      ? 'لا توجد وردية اليوم'
                      : '${shift.name} · ${hrRange(hrTime(shift.startTime), hrTime(shift.endTime))}',
                  style: const TextStyle(
                    color: soft,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hrClock(now),
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 44,
              height: 1.2,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          if (shift?.punchFrom != null && shift?.punchTo != null)
            Text(
              'البصمة متاحة من ${hrClock(shift!.punchFrom)} إلى ${hrClock(shift.punchTo)}',
              style: const TextStyle(
                color: soft,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 14),
          _TypeSwitch(value: punchType, onChanged: onType),
          const SizedBox(height: 16),
          _FingerprintButton(
            label: punchIn ? 'تسجيل الحضور' : 'تسجيل الانصراف',
            busy: busy,
            onPunch: onPunch,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _HeroTile(
                  label: 'أول حضور',
                  value: hrClock(today.firstIn),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeroTile(
                  label: 'آخر انصراف',
                  value: hrClock(today.lastOut),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeroTile(
                  label: 'مدة التواجد',
                  value: elapsed == null ? '—' : hrDuration(elapsed),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// حضور | انصراف. Preselects the punch the day expects; the employee may
/// switch it, say to punch in again after a punch HR has not counted yet.
class _TypeSwitch extends StatelessWidget {
  const _TypeSwitch({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    Widget option(String type, String label, IconData icon) {
      final selected = value == type;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onChanged == null || selected
                ? null
                : () => onChanged!(type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              height: 34,
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 15,
                    color: selected
                        ? tokens.brandStrong
                        : const Color(0xCCFFFFFF),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? tokens.brandStrong
                          : const Color(0xCCFFFFFF),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 230,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .12)),
      ),
      child: Row(
        children: [
          option('IN', 'حضور', LucideIcons.logIn),
          option('OUT', 'انصراف', LucideIcons.logOut),
        ],
      ),
    );
  }
}

/// Hold to punch: the fingerprint fills from the bottom while the finger
/// stays on it and punches once full; letting go early drains it. While the
/// punch is on its way the print breathes.
class _FingerprintButton extends StatefulWidget {
  const _FingerprintButton({
    required this.label,
    required this.busy,
    required this.onPunch,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPunch;

  @override
  State<_FingerprintButton> createState() => _FingerprintButtonState();
}

class _FingerprintButtonState extends State<_FingerprintButton>
    with SingleTickerProviderStateMixin {
  static const _hold = Duration(milliseconds: 750);
  late final _fill = AnimationController(vsync: this, duration: _hold)
    ..addStatusListener(_filled);
  bool _holding = false;

  @override
  void initState() {
    super.initState();
    if (widget.busy) _breathe();
  }

  @override
  void didUpdateWidget(_FingerprintButton old) {
    super.didUpdateWidget(old);
    if (widget.busy && !old.busy) _breathe();
    if (!widget.busy && old.busy) _drain();
  }

  @override
  void dispose() {
    _fill.dispose();
    super.dispose();
  }

  bool get _enabled => widget.onPunch != null && !widget.busy;

  void _breathe() => _fill.repeat(
    min: .4,
    max: 1,
    reverse: true,
    period: const Duration(milliseconds: 900),
  );

  void _drain() => _fill.animateBack(
    0,
    duration: const Duration(milliseconds: 450),
    curve: Curves.easeOut,
  );

  void _filled(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_holding) return;
    _holding = false;
    _fire();
  }

  void _fire() {
    HapticFeedback.mediumImpact();
    widget.onPunch?.call();
    // Stays full while the punch is under way; drains if nothing started.
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        if (mounted && !widget.busy) _drain();
      })
      ..scheduleFrame();
  }

  void _press() {
    if (!_enabled) return;
    _holding = true;
    HapticFeedback.selectionClick();
    _fill.animateTo(
      1,
      duration: _hold * (1 - _fill.value),
      curve: Curves.linear,
    );
  }

  void _release() {
    if (!_holding) return;
    _holding = false;
    if (!widget.busy) _drain();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final enabled = widget.onPunch != null;
    final ink = enabled ? tokens.brandStrong : tokens.line;
    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      hint: 'اضغط مطولًا للتسجيل',
      onTap: _enabled ? _fire : null,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => _press(),
        onTapUp: (_) => _release(),
        onTapCancel: _release,
        child: AnimatedBuilder(
          animation: _fill,
          builder: (context, _) {
            final t = _fill.value;
            return CustomPaint(
              foregroundPainter: _Ring(t),
              child: Container(
                width: 172,
                height: 172,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .14),
                ),
                child: Container(
                  width: 156,
                  height: 156,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox.square(
                        dimension: 60,
                        child: Stack(
                          children: [
                            Icon(
                              LucideIcons.fingerprint,
                              size: 60,
                              color: enabled ? ink.withValues(alpha: .22) : ink,
                            ),
                            ClipRect(
                              clipper: _RisingFill(t),
                              child: Icon(
                                LucideIcons.fingerprint,
                                size: 60,
                                color: ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.busy ? 'جارٍ التسجيل…' : widget.label,
                        style: TextStyle(
                          color: enabled ? tokens.brandStrong : tokens.muted,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        enabled ? 'اضغط مطولًا' : 'غير متاح',
                        style: TextStyle(
                          color: tokens.muted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The halo around the button closing as the print fills.
class _Ring extends CustomPainter {
  const _Ring(this.fraction);
  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    if (fraction <= 0) return;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - 4,
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * fraction,
      false,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_Ring old) => old.fraction != fraction;
}

/// The lower [fraction] of the print, the part already "filled".
class _RisingFill extends CustomClipper<Rect> {
  const _RisingFill(this.fraction);
  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, size.height * (1 - fraction), size.width, size.height);

  @override
  bool shouldReclip(_RisingFill old) => old.fraction != fraction;
}

class _HeroTile extends StatelessWidget {
  const _HeroTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withValues(alpha: .09)),
    ),
    child: Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xB8FFFFFF),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          textDirection: TextDirection.ltr,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.today,
    required this.fix,
    required this.range,
    required this.locating,
    required this.onRefresh,
  });

  final HrToday today;
  final PunchFix? fix;
  final _Range? range;
  final bool locating;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final (
      IconData icon,
      Color color,
      String title,
      String detail,
      AppTag? tag,
    ) = switch (fix) {
      _ when !today.needsPlace => (
        LucideIcons.globe,
        tokens.brand,
        'الحضور من أي مكان',
        'لا يشترط موقع محدد لتسجيل البصمة',
        null,
      ),
      _ when locating => (
        LucideIcons.locateFixed,
        tokens.muted,
        'جارٍ تحديد موقعك…',
        'تأكد من تشغيل خدمة الموقع',
        null,
      ),
      final fix? when !fix.located => (
        LucideIcons.mapPinOff,
        AppTokens.warning,
        'الموقع غير متاح',
        fix.problem ?? 'تعذّر تحديد الموقع',
        const AppTag('بدون موقع', tone: AppTone.warning),
      ),
      final fix? when range != null => (
        range!.inside ? LucideIcons.mapPinCheck : LucideIcons.mapPin,
        range!.inside ? AppTokens.success : AppTokens.warning,
        range!.place.name,
        'تبعد ${range!.distanceM} م · النطاق ${range!.place.radiusM} م'
            '${fix.accuracyM == null ? '' : ' · دقة ${fix.accuracyM} م'}',
        fix.mocked
            ? const AppTag('موقع غير حقيقي', tone: AppTone.danger)
            : range!.inside
            ? const AppTag('داخل النطاق', tone: AppTone.success)
            : const AppTag('خارج النطاق', tone: AppTone.warning),
      ),
      _ => (
        LucideIcons.mapPin,
        tokens.muted,
        today.places.isEmpty ? 'لا توجد مواقع محددة' : 'لم يُحدَّد الموقع بعد',
        'اضغط تحديث لتحديد موقعك',
        null,
      ),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.line),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (tag != null) ...[const SizedBox(width: 6), tag],
                  ],
                ),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: tokens.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (today.needsPlace)
            IconButton(
              tooltip: 'تحديث الموقع',
              onPressed: onRefresh,
              icon: const Icon(LucideIcons.refreshCw, size: 18),
            ),
        ],
      ),
    );
  }
}

/// Today as the timesheet worked it out: check-in, check-out, hours and
/// what they made; held punches below it, as they count only once approved.
class _DaySummary extends StatelessWidget {
  const _DaySummary({required this.day, required this.pending});
  final HrTimesheetDay? day;
  final List<HrPunch> pending;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final day = this.day;
    final decoration = BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: tokens.line),
    );
    if (day == null && pending.isEmpty) {
      return Container(
        decoration: decoration,
        child: const AppEmptyState(
          icon: LucideIcons.fingerprint,
          title: 'لم تُسجَّل بصمات اليوم',
          message: 'يظهر هنا الحضور والانصراف وساعات العمل فور التسجيل.',
        ),
      );
    }
    final figures = day == null
        ? const <(String, String, Color?)>[]
        : [
            ('الحضور', hrClock(day.checkIn), null),
            ('الانصراف', hrClock(day.checkOut), null),
            (
              'ساعات العمل',
              day.checkIn == null || day.checkOut == null
                  ? '—'
                  : hrDuration(day.workedMinutes),
              null,
            ),
            if (day.lateMinutes > 0)
              ('التأخير', hrDuration(day.lateMinutes), AppTokens.warning),
            if (day.earlyLeaveMinutes > 0)
              (
                'الانصراف المبكر',
                hrDuration(day.earlyLeaveMinutes),
                AppTokens.warning,
              ),
            if (day.permissionMinutes > 0)
              ('الإذن', hrDuration(day.permissionMinutes), AppTokens.info),
            if (day.overtimeMinutes > 0)
              ('الإضافي', hrDuration(day.overtimeMinutes), AppTokens.success),
          ];
    return Container(
      decoration: decoration,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (day != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    day.shift?.name ?? 'الوردية',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: tokens.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                dayStatusTag(day),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (label, value, color) in figures)
                  _Figure(label: label, value: value, color: color),
              ],
            ),
            if (day.overtimeMinutes > day.approvedOvertimeMinutes &&
                day.lines.any(
                  (l) => l.lineType == 'OVERTIME' && l.status == 'DRAFT',
                )) ...[
              const SizedBox(height: 8),
              Text(
                'الوقت الإضافي بانتظار موافقة المدير',
                style: TextStyle(fontSize: 11.5, color: tokens.muted),
              ),
            ],
          ],
          for (final punch in pending) ...[
            if (day != null || punch != pending.first)
              Divider(height: 20, color: tokens.line),
            Row(
              children: [
                Icon(
                  punch.punchType == 'IN'
                      ? LucideIcons.logIn
                      : LucideIcons.logOut,
                  size: 17,
                  color: AppTokens.info,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${punch.punchType == 'IN' ? 'حضور' : 'انصراف'} ${hrClock(punch.punchedAt)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const AppTag(
                  'معلّقة للمراجعة',
                  tone: AppTone.info,
                  icon: LucideIcons.hourglass,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      width: 104,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.wash,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: tokens.muted)),
          const SizedBox(height: 2),
          Text(
            value,
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color ?? tokens.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when the phone is out of range, has no location or reports a fake
/// one. The punch still goes through; the employee may say why.
class _ConfirmSheet extends StatefulWidget {
  const _ConfirmSheet({
    required this.punchType,
    required this.fix,
    required this.range,
  });

  final String punchType;
  final PunchFix fix;
  final _Range? range;

  @override
  State<_ConfirmSheet> createState() => _ConfirmSheetState();
}

class _ConfirmSheetState extends State<_ConfirmSheet> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final range = widget.range;
    final reason = widget.fix.mocked
        ? 'الجهاز يُظهر موقعًا غير حقيقي.'
        : !widget.fix.located
        ? widget.fix.problem ?? 'تعذّر تحديد موقعك.'
        : range == null
        ? 'لا توجد مواقع محددة لحضورك.'
        : 'أنت على بعد ${range.distanceM} م من ${range.place.name}، والنطاق المسموح ${range.place.radiusM} م.';
    return AppSheetScaffold(
      title: widget.punchType == 'IN'
          ? 'تأكيد تسجيل الحضور'
          : 'تأكيد تسجيل الانصراف',
      subtitle: 'ستُسجَّل البصمة مع ملاحظة للموارد البشرية',
      footer: AppSheetActions(
        primaryLabel: 'تسجيل البصمة',
        primaryIcon: LucideIcons.fingerprint,
        onPrimary: () => Navigator.pop(context, _note.text.trim()),
        secondaryLabel: 'إلغاء',
        onSecondary: () => Navigator.pop(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTokens.warningTint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  LucideIcons.triangleAlert,
                  size: 18,
                  color: AppTokens.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    reason,
                    style: const TextStyle(fontSize: 13, height: 1.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _note,
            maxLength: 500,
            maxLines: 3,
            minLines: 2,
            decoration: const InputDecoration(
              labelText: 'ملاحظة (اختياري)',
              hintText: 'مثال: في موقع العميل بتكليف من المدير',
              alignLabelWithHint: true,
              counterText: '',
            ),
          ),
        ],
      ),
    );
  }
}

/// What the employee reads: a check that stopped the punch says why, without
/// Dart's "Bad state:" prefix; anything else as it describes itself.
String _message(Object error) =>
    error is StateError ? error.message : error.toString();
