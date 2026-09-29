import 'package:doener_models/doener_models.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/app_data.dart';
import '../../core/session.dart';
import '../../ui/widgets.dart';

/// Opens the login flow; resolves to true when the user is logged in.
Future<bool> showLogin(BuildContext context) async {
  final ok = await Navigator.of(context).push<bool>(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => const LoginScreen()),
  );
  return ok ?? false;
}

/// Makes sure there is a session before an account action; asks to log in otherwise.
Future<bool> ensureLoggedIn(BuildContext context) async {
  if (context.read<Session>().isLoggedIn) return true;
  return showLogin(context);
}

/// Logs in with a magic-link token (web: `/login?token=…`).
Future<void> completeLinkLogin(BuildContext context, String token) async {
  final session = context.read<Session>();
  final data = context.read<AppData>();
  try {
    final response = await session.verify(VerifyRequest(token: token));
    await data.onSignedIn(response.user.id);
    if (context.mounted) showMessage(context, 'Angemeldet als ${response.user.displayName}');
  } catch (e) {
    if (context.mounted) showMessage(context, e.toString());
  }
}

class LoginScreen extends StatefulWidget {
  final bool showSkip;
  const LoginScreen({super.key, this.showSkip = true});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } on OfflineException catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() => _run(() async {
        if (!Validation.isValidEmail(_email.text)) throw const ApiException(400, 'Bitte gib eine gültige E-Mail ein.');
        await context.read<Session>().requestCode(Validation.normalizeEmail(_email.text));
        setState(() => _codeSent = true);
      });

  Future<void> _verify() => _run(() async {
        final session = context.read<Session>();
        final data = context.read<AppData>();
        final response = await session.verify(
          VerifyRequest(email: Validation.normalizeEmail(_email.text), code: _code.text.trim()),
        );
        await data.onSignedIn(response.user.id);
        if (!mounted) return;
        if (response.isNewUser) {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChooseNameScreen()));
        }
        if (mounted) Navigator.of(context).pop(true);
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (widget.showSkip) TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Später')),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              children: [
                Center(
                  child: ClipOval(child: Image.asset('assets/logo.jpg', width: 96, height: 96, fit: BoxFit.cover)),
                ),
                const SizedBox(height: 20),
                Text('Anmelden', style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  _codeSent
                      ? 'Wir haben dir einen 6-stelligen Code geschickt. Du kannst auch einfach auf den Link in der Mail tippen.'
                      : 'Kein Passwort nötig – wir schicken dir einen Code per Mail. Damit kannst du Freunde hinzufügen und Erfolge sammeln.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _email,
                  enabled: !_codeSent && !_busy,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'E-Mail', prefixIcon: Icon(Icons.mail_outline)),
                  onSubmitted: (_) => _sendCode(),
                ),
                if (_codeSent) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _code,
                    enabled: !_busy,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    maxLength: 6,
                    decoration: const InputDecoration(labelText: 'Code', prefixIcon: Icon(Icons.pin_outlined)),
                    onSubmitted: (_) => _verify(),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: theme.colorScheme.error), textAlign: TextAlign.center),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : (_codeSent ? _verify : _sendCode),
                  child: _busy
                      ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_codeSent ? 'Anmelden' : 'Code schicken'),
                ),
                if (_codeSent)
                  TextButton(
                    onPressed: _busy ? null : () => setState(() => _codeSent = false),
                    child: const Text('Andere E-Mail / neuen Code'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown once after sign-up so the user replaces the generated name.
class ChooseNameScreen extends StatefulWidget {
  const ChooseNameScreen({super.key});

  @override
  State<ChooseNameScreen> createState() => _ChooseNameScreenState();
}

class _ChooseNameScreenState extends State<ChooseNameScreen> {
  final _name = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final error = Validation.displayNameError(_name.text);
    if (error != null) return setState(() => _error = error);
    setState(() => _busy = true);
    try {
      await context.read<Session>().updateDisplayName(_name.text.trim());
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = context.watch<Session>().user?.displayName ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wie heißt du?'),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Überspringen'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Unter diesem Namen finden dich deine Freunde. Aktuell: $current'),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: Validation.displayNameMax,
            decoration: InputDecoration(labelText: 'Anzeigename', errorText: _error),
            onSubmitted: (_) => _save(),
          ),
          FilledButton(onPressed: _busy ? null : _save, child: const Text('Speichern')),
        ],
      ),
    );
  }
}
