import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'services/deep_link_controller.dart';
import 'services/deep_link_service.dart';
import 'state/providers.dart';

void main() {
  runApp(const ProviderScope(child: OmniPassApp()));
}

class OmniPassApp extends ConsumerStatefulWidget {
  const OmniPassApp({super.key});

  @override
  ConsumerState<OmniPassApp> createState() => _OmniPassAppState();
}

class _OmniPassAppState extends ConsumerState<OmniPassApp> {
  DeepLinkController? _deepLinkController;

  @override
  void initState() {
    super.initState();
    // Deferred to right after the first frame so `context`/router are ready
    // and the cold-start link (section 3.1a) is handled before the user
    // sees the default wallet-home flash.
    WidgetsBinding.instance.addPostFrameCallback((_) => _wireDeepLinks());
  }

  Future<void> _wireDeepLinks() async {
    final router = ref.read(routerProvider);
    final claimFlow = ref.read(claimFlowProvider(router));
    final controller = DeepLinkController(
      linkService: ref.read(deepLinkServiceProvider),
      claimFlow: claimFlow,
    );
    _deepLinkController = controller;
    await controller.start();
  }

  @override
  void dispose() {
    _deepLinkController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'OmniPass',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
