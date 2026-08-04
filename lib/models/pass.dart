import 'package:equatable/equatable.dart';

/// The category of a collected pass. Drives grouping in the wallet list.
enum PassType {
  eventTicket,
  smartAccess,
  membership;

  String get label => switch (this) {
        PassType.eventTicket => 'Event Ticket',
        PassType.smartAccess => 'Smart Access',
        PassType.membership => 'Membership',
      };
}

/// Lifecycle status of a pass. Never inferred ad-hoc from dates in the UI —
/// always computed centrally in [Pass.deriveStatus] so every screen agrees.
enum PassStatus {
  upcoming,
  active,
  expired,
  used;

  String get label => switch (this) {
        PassStatus.upcoming => 'Upcoming',
        PassStatus.active => 'Active',
        PassStatus.expired => 'Expired',
        PassStatus.used => 'Used',
      };

  bool get isLive => this == PassStatus.upcoming || this == PassStatus.active;
}

/// A single collected pass in the user's wallet.
///
/// This is the ONLY shape passes are represented in anywhere in the app —
/// there is no parallel "raw map" version used by the deep-link path vs.
/// the QR-scan path vs. persistence. All three funnel through this model.
class Pass extends Equatable {
  final String id;
  final PassType type;
  final String title;
  final String subtitle;
  final DateTime validFrom;
  final DateTime validTo;
  final bool redeemed;

  /// The raw token string this pass was claimed with. Kept only so the
  /// secure ticket view can re-render a scannable code; never logged.
  final String claimTokenId;

  const Pass({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.validFrom,
    required this.validTo,
    required this.claimTokenId,
    this.redeemed = false,
  });

  /// Central status computation. A pass is:
  /// - used: explicitly redeemed (e.g. scanned at the gate)
  /// - expired: validTo has passed
  /// - upcoming: validFrom is in the future
  /// - active: otherwise (within its validity window)
  PassStatus deriveStatus(DateTime now) {
    if (redeemed) return PassStatus.used;
    if (now.isAfter(validTo)) return PassStatus.expired;
    if (now.isBefore(validFrom)) return PassStatus.upcoming;
    return PassStatus.active;
  }

  Pass copyWith({bool? redeemed}) => Pass(
        id: id,
        type: type,
        title: title,
        subtitle: subtitle,
        validFrom: validFrom,
        validTo: validTo,
        claimTokenId: claimTokenId,
        redeemed: redeemed ?? this.redeemed,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'subtitle': subtitle,
        'validFrom': validFrom.toIso8601String(),
        'validTo': validTo.toIso8601String(),
        'claimTokenId': claimTokenId,
        'redeemed': redeemed,
      };

  factory Pass.fromJson(Map<String, Object?> json) => Pass(
        id: json['id'] as String,
        type: PassType.values.byName(json['type'] as String),
        title: json['title'] as String,
        subtitle: json['subtitle'] as String,
        validFrom: DateTime.parse(json['validFrom'] as String),
        validTo: DateTime.parse(json['validTo'] as String),
        claimTokenId: json['claimTokenId'] as String,
        redeemed: json['redeemed'] as bool,
      );

  @override
  List<Object?> get props =>
      [id, type, title, subtitle, validFrom, validTo, claimTokenId, redeemed];
}
