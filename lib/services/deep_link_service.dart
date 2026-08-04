import 'dart:async';
import 'package:app_links/app_links.dart';

/// Thin wrapper around `app_links`, which is what actually gives us the
/// three entry scenarios from section 3.1:
///
///  - cold start:  [getInitialLink] — the link that launched a fully
///                 terminated process.
///  - warm resume: an event on [linkStream] fired while the app was
///                 backgrounded and gets foregrounded by the OS handing
///                 back the link.
///  - foregrounded: an event on [linkStream] fired while the app was
///                 already open (OS link handoff, or a link tapped from
///                 within the app itself, e.g. a share sheet).
///
/// The consuming code (`DeepLinkController`) treats all three the same way
/// once it has a URI — the only difference is *how* the URI arrived, which
/// is exactly what this class exists to normalize away.
class DeepLinkService {
  final AppLinks _appLinks;
  DeepLinkService({AppLinks? appLinks}) : _appLinks = appLinks ?? AppLinks();

  /// Cold-start link, if the process was launched by tapping one. Null if
  /// the app was launched normally.
  Future<Uri?> getInitialLink() => _appLinks.getInitialLink();

  /// Fires for every link received while the process is already alive,
  /// whether it was backgrounded (warm resume) or foregrounded.
  Stream<Uri> get linkStream => _appLinks.uriLinkStream;
}
