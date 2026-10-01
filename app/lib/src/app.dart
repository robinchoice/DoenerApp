import 'package:doener_models/doener_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sembast/sembast.dart';

import 'core/api.dart';
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
import 'features/social/friends.dart';
import 'features/social/invite.dart';
import 'ui/widgets.dart';

class DoenerApp extends StatelessWidget {
  final bool onboardingDone;
  final bool invitePromptDone;

  /// Magic-link token from the URL (web only).
  final String? linkToken;

  /// Invite link that brought the user here and is not accepted yet.
  final String? inviteCode;

  const DoenerApp({super.key, required this.onboardingDone, required this.invitePromptDone, this.linkToken, this.inviteCode});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Döner App',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        locale: const Locale('de'),
        supportedLocales: const [Locale('de')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: _Root(
          onboardingDone: onboardingDone,
          invitePromptDone: invitePromptDone,
          linkToken: linkToken,
          inviteCode: inviteCode,
        ),
      );
}

class _Root extends StatefulWidget {
  final bool onboardingDone;
  final bool invitePromptDone;
  final String? linkToken;
  final String? inviteCode;
  const _Root({required this.onboardingDone, required this.invitePromptDone, this.linkToken, this.inviteCode});

  @override
  State<_Root> createState() => _RootState();
}

/// Onboarding, then login and a chosen name — the app needs an account.
/// Afterwards a pending invite is accepted and the user is asked once to
/// invite their own friends.
class _RootState extends State<_Root> {
  late bool _onboardingDone = widget.onboardingDone;
  late bool _invitePromptDone = widget.invitePromptDone;
  late String? _inviteCode = widget.inviteCode;
  bool _acceptingInvite = false;
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
      // Keep login token and invite code out of the browser's address bar.
      if (kIsWeb && Uri.base.hasQuery) SystemNavigator.routeInformationUpdated(uri: Uri.parse('/'));
      final token = widget.linkToken;
      if (token != null) await completeLinkLogin(context, token, inviteCode: _inviteCode);
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
  }

  Future<void> _finishInvitePrompt() async {
    await settingsStore.record('invitePromptDone').put(context.read<Database>(), true);
    setState(() => _invitePromptDone = true);
  }

  /// Offline (or on a server error) the invite stays pending for the next try;
  /// a reset link or the user's own link is dropped.
  Future<void> _acceptInvite(String code) async {
    if (_acceptingInvite) return;
    _acceptingInvite = true;
    final friends = context.read<Friends>();
    final db = context.read<Database>();
    try {
      final friendship = await friends.acceptInvite(code);
      if (mounted) showMessage(context, 'Du bist jetzt mit ${friendship.user.displayName} befreundet.');
    } on ApiException catch (e) {
      if (e.status != 400 && e.status != 404) return;
      if (mounted) showMessage(context, e.message);
    } on OfflineException {
      return;
    } finally {
      _acceptingInvite = false;
    }
    _inviteCode = null;
    await pendingInviteRecord.delete(db);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    if (!_onboardingDone) return WelcomeScreen(onDone: _finishOnboarding, inviteCode: _inviteCode);
    if (!session.isLoggedIn) {
      // Logged out or session expired: screens opened during the old session go away.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      });
      return LoginScreen(inviteCode: _inviteCode);
    }
    if (Validation.isGeneratedName(session.user!.displayName)) return const ChooseNameScreen();
    // Accepted only now, so the inviter's new friend shows up with a real name.
    final code = _inviteCode;
    if (code != null) WidgetsBinding.instance.addPostFrameCallback((_) => _acceptInvite(code));
    if (!_invitePromptDone) return InviteStepScreen(onDone: _finishInvitePrompt);
    return const HomeShell();
  }
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
