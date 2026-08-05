import '../models/pass.dart';

/// Simulates a backend lookup: "given a passId, what pass is this?"
///
/// In a real system this would be a network call made as part of (or right
/// after) the token exchange. Here it's an in-memory catalog seeded with a
/// few demo passes so the sample links in the deliverables resolve to
/// something real in the wallet.
class PassCatalogService {
  static final Map<String, Pass> _catalog = {
    'evt-synthwave-2026': Pass(
      id: 'evt-synthwave-2026',
      type: PassType.eventTicket,
      title: 'Synthwave Festival 2026',
      subtitle: 'General Admission · Gate B',
      validFrom: DateTime.now().add(const Duration(days: 2)),
      validTo: DateTime.now().add(const Duration(days: 2, hours: 8)),
      claimTokenId: '',
    ),
    'evt-jazz-night': Pass(
      id: 'evt-jazz-night',
      type: PassType.eventTicket,
      title: 'Late Night Jazz Session',
      subtitle: 'VIP Table · Blue Room',
      validFrom: DateTime.now().add(const Duration(days: 5)),
      validTo: DateTime.now().add(const Duration(days: 5, hours: 4)),
      claimTokenId: '',
    ),
    'evt-tech-conf': Pass(
      id: 'evt-tech-conf',
      type: PassType.eventTicket,
      title: 'DevSummit 2026',
      subtitle: 'All-Access · Hall C',
      validFrom: DateTime.now().add(const Duration(days: 14)),
      validTo: DateTime.now().add(const Duration(days: 16)),
      claimTokenId: '',
    ),
    'access-hq-floor4': Pass(
      id: 'access-hq-floor4',
      type: PassType.smartAccess,
      title: 'HQ — Floor 4 Access',
      subtitle: 'Badge 4B · Business hours',
      validFrom: DateTime.now().subtract(const Duration(days: 30)),
      validTo: DateTime.now().add(const Duration(days: 60)),
      claimTokenId: '',
    ),
    'access-garage-b2': Pass(
      id: 'access-garage-b2',
      type: PassType.smartAccess,
      title: 'Parking Garage — Level B2',
      subtitle: '24/7 Access · Spot 118',
      validFrom: DateTime.now().subtract(const Duration(days: 5)),
      validTo: DateTime.now().add(const Duration(days: 180)),
      claimTokenId: '',
    ),
    'member-studio-gold': Pass(
      id: 'member-studio-gold',
      type: PassType.membership,
      title: 'Studio Gold Membership',
      subtitle: 'Unlimited classes',
      validFrom: DateTime.now().subtract(const Duration(days: 10)),
      validTo: DateTime.now().add(const Duration(days: 355)),
      claimTokenId: '',
    ),
    'member-library-plus': Pass(
      id: 'member-library-plus',
      type: PassType.membership,
      title: 'City Library Plus',
      subtitle: 'Extended borrowing',
      validFrom: DateTime.now().subtract(const Duration(days: 2)),
      validTo: DateTime.now().add(const Duration(days: 400)),
      claimTokenId: '',
    ),
  };

  /// Looks up pass metadata for a passId, materializing it with the given
  /// claim token id. Returns null if the passId is unknown (treated as a
  /// failed exchange upstream).
  Pass? resolve(String passId, {required String claimTokenId}) {
    final template = _catalog[passId];
    if (template == null) return null;
    return Pass(
      id: template.id,
      type: template.type,
      title: template.title,
      subtitle: template.subtitle,
      validFrom: template.validFrom,
      validTo: template.validTo,
      claimTokenId: claimTokenId,
    );
  }

  List<String> get knownPassIds => _catalog.keys.toList();
}
