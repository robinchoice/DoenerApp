import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sembast/sembast.dart';

import 'core/app_data.dart';
import 'core/location.dart';
import 'core/session.dart';
import 'features/auth/login_screen.dart';
import 'features/discover/discover_screen.dart';
import 'features/feed/feed_screen.dart';
import 'features/map/map_screen.dart';
import 'features/onboarding/welcome_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/ranking/ranking_screen.dart';
import 'ui/widgets.dart';

class DoenerApp extends StatelessWidget {
  final bool onboardingDone;

  /// Magic-link token from the URL (web only).
  final String? linkToken;

  const DoenerApp({super.key, required this.onboardingDone, this.linkToken});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Döner App',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        locale: const Locale('de'),
        supportedLocales: const [Locale('de')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: _Root(onboardingDone: onboardingDone, linkToken: linkToken),
      );
}

class _Root extends StatefulWidget {
  final bool onboardingDone;
  final String? linkToken;
  const _Root({required this.onboardingDone, this.linkToken});

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  late bool _onboardingDone = widget.onboardingDone;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    final data = context.read<AppData>();
    _lifecycle = AppLifecycleListener(onResume: () {
      data.sync();
      data.refreshMine();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final token = widget.linkToken;
      if (token != null) {
        SystemNavigator.routeInformationUpdated(uri: Uri.parse('/'));
        await completeLinkLogin(context, token);
      }
      if (mounted && _onboardingDone) context.read<LocationService>().request();
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    await settingsStore.record('onboardingDone').put(context.read<Database>(), true);
    setState(() => _onboardingDone = true);
    if (mounted && !context.read<Session>().isLoggedIn) await showLogin(context);
  }

  @override
  Widget build(BuildContext context) =>
      _onboardingDone ? const HomeShell() : WelcomeScreen(onDone: _finishOnboarding);
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 2;

  @override
  Widget build(BuildContext context) {
    final pending = context.select<AppData, int>((d) => d.pendingCount);
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          const FeedScreen(),
          const RankingScreen(),
          DiscoverScreen(onOpenMap: () => setState(() => _tab = 3)),
          const MapScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.group_outlined), selectedIcon: Icon(Icons.group), label: 'Feed'),
          const NavigationDestination(icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events), label: 'Ranking'),
          NavigationDestination(
            icon: CircleAvatar(
              radius: 22,
              backgroundColor: doenerOrange,
              child: Icon(_tab == 2 ? Icons.travel_explore : Icons.search, color: Colors.white),
            ),
            label: 'Entdecken',
          ),
          const NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Karte'),
          NavigationDestination(
            icon: Badge(isLabelVisible: pending > 0, label: Text('$pending'), child: const Icon(Icons.account_circle_outlined)),
            selectedIcon: const Icon(Icons.account_circle),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
