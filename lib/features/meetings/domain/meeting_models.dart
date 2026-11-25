import '../../crm/domain/crm_models.dart';

class MeetingAttendee {
  const MeetingAttendee({required this.id, this.user, this.name, this.phone});
  factory MeetingAttendee.fromJson(Map<String, dynamic> json) =>
      MeetingAttendee(
        id: json['id']?.toString() ?? '',
        user: json['user'] == null ? null : CrmRef.fromJson(json['user']),
        name: json['name']?.toString(),
        phone: json['phone']?.toString(),
      );
  final String id;
  final CrmRef? user;
  final String? name, phone;
  String get label => user?.name ?? name ?? '—';
}

class Meeting {
  const Meeting({
    required this.id,
    required this.ownerType,
    required this.ownerId,
    required this.ownerLabel,
    required this.title,
    required this.meetingType,
    required this.startAt,
    required this.organizer,
    required this.status,
    required this.remindBeforeMinutes,
    required this.attendees,
    required this.version,
    this.endAt,
    this.location,
    this.link,
    this.notes,
    this.outcome,
    this.cancelReason,
    this.replacesId,
  });
  factory Meeting.fromJson(Map<String, dynamic> json) => Meeting(
    id: json['id']?.toString() ?? '',
    ownerType: json['ownerType']?.toString() ?? '',
    ownerId: json['ownerId']?.toString() ?? '',
    ownerLabel: json['ownerLabel']?.toString() ?? '—',
    title: json['title']?.toString() ?? '—',
    meetingType: json['meetingType']?.toString() ?? '',
    startAt: json['startAt']?.toString() ?? '',
    endAt: json['endAt']?.toString(),
    location: json['location']?.toString(),
    link: json['link']?.toString(),
    notes: json['notes']?.toString(),
    organizer: CrmRef.fromJson(json['organizer']),
    status: json['status']?.toString() ?? '',
    outcome: json['outcome']?.toString(),
    cancelReason: json['cancelReason']?.toString(),
    replacesId: json['replacesId']?.toString(),
    remindBeforeMinutes: (json['remindBeforeMinutes'] as num?)?.toInt() ?? 60,
    attendees: (json['attendees'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => MeetingAttendee.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false),
    version: (json['version'] as num?)?.toInt() ?? 0,
  );
  final String id,
      ownerType,
      ownerId,
      ownerLabel,
      title,
      meetingType,
      startAt,
      status;
  final CrmRef organizer;
  final int remindBeforeMinutes, version;
  final List<MeetingAttendee> attendees;
  final String? endAt, location, link, notes, outcome, cancelReason, replacesId;
}
