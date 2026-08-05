import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/claim_flow.dart';
import '../services/deep_link_controller.dart';

/// Camera-based claim flow (section 3.5). Whatever the QR code encodes —
/// a bare token, or a full https://omnipass.app/t/<token> link — this
/// screen extracts the raw token with the exact same [extractRawToken] /
/// [ClaimFlow.claim] used by the external deep-link path. There is no
/// second parser here.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  // One explicit controller, created once. Letting MobileScanner build its
  // own implicit controller (no `controller:` passed) is what was causing
  // the camera preview to open without the barcode analyzer ever actually
  // starting on some devices — a separate permission_handler.request()
  // running before the widget existed raced with the widget's own internal
  // camera/permission setup. The controller now owns permission + camera
  // lifecycle end to end, and errorBuilder below handles a denial.
  late final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _handledOne = false; // avoid double-claim from rapid repeat frames

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handledOne) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    final tokenString = _extractTokenFromScannedText(raw);
    if (tokenString == null) return;

    _handledOne = true;
    _controller.stop();

    final router = GoRouter.of(context);
    final claimFlow = ClaimFlow(ref.read, router);
    claimFlow.claim(tokenString).catchError((Object e, StackTrace st) {
    });
  }

  /// A scanned QR payload may be a bare "<payload>.<sig>" token, or a full
  /// URL. Either way, extraction funnels through [extractRawToken] — the
  /// exact function the external link handler uses — so both entry points
  /// share one implementation.
  String? _extractTokenFromScannedText(String raw) {
    final asUri = Uri.tryParse(raw);
    if (asUri != null &&
        (asUri.scheme == 'https' || asUri.scheme == 'omnipass')) {
      return extractRawToken(asUri);
    }
    // Bare token (no scheme) — still just handed to the same TokenService
    // via ClaimFlow.claim, which does the real structural validation.
    if (raw.contains('.')) return raw;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan a Pass')),
      body: MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
        errorBuilder: (context, error, child) {
          // Camera permission denial (3.5's "denied-permission state") and
          // any other camera failure both land here, with a path to
          // re-request or open system settings.
          final isPermissionIssue =
              error.errorCode == MobileScannerErrorCode.permissionDenied;
          return _PermissionMessage(
            message: isPermissionIssue
                ? 'Camera access is needed to scan a pass QR code.'
                : 'Could not start the camera (${error.errorCode.name}).',
            actionLabel: isPermissionIssue ? 'Open Settings' : 'Try again',
            onAction:
                isPermissionIssue ? openAppSettings : () => _controller.start(),
          );
        },
      ),
    );
  }
}

class _PermissionMessage extends StatelessWidget {
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _PermissionMessage({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined,
                size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
