import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/location.dart';
import '../../ui/widgets.dart';

class WelcomeScreen extends StatefulWidget {
  final VoidCallback onDone;
  const WelcomeScreen({super.key, required this.onDone});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() => _page == 2
      ? widget.onDone()
      : _pages.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = context.watch<LocationService>();

    Widget page({required Widget top, required String title, required String text, Widget? extra}) => Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              top,
              const SizedBox(height: 32),
              Text(title, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(text, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.outline), textAlign: TextAlign.center),
              if (extra != null) ...[const SizedBox(height: 24), extra],
            ],
          ),
        );

    Widget step(IconData icon, String title, String text) => ListTile(
          leading: CircleAvatar(backgroundColor: doenerOrange.withValues(alpha: 0.15), child: Icon(icon, color: doenerOrange)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(text),
        );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pages,
                    onPageChanged: (p) => setState(() => _page = p),
                    children: [
                      page(
                        top: ClipOval(child: Image.asset('assets/logo.jpg', width: 140, height: 140, fit: BoxFit.cover)),
                        title: 'Döner App',
                        text: 'Finde, bewerte und sammle deine liebsten Döner-Läden.',
                      ),
                      page(
                        top: Icon(
                          location.position != null ? Icons.location_on : Icons.location_searching,
                          size: 96,
                          color: location.denied ? Colors.grey : doenerOrange,
                        ),
                        title: 'Dein Standort',
                        text: location.position != null
                            ? 'Standort freigegeben!'
                            : location.denied
                                ? 'Standort abgelehnt. Du kannst das später ändern – bis dahin nutzen wir Freiburg.'
                                : 'Damit wir dir Döner-Läden in deiner Nähe zeigen können.',
                        extra: location.position == null && !location.denied
                            ? OutlinedButton.icon(
                                onPressed: location.request,
                                icon: const Icon(Icons.my_location),
                                label: const Text('Standort freigeben'),
                              )
                            : null,
                      ),
                      ListView(
                        padding: const EdgeInsets.all(32),
                        children: [
                          const SizedBox(height: 40),
                          Text("So funktioniert's", style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                          const SizedBox(height: 24),
                          step(Icons.map, 'Entdecken', 'Die Karte zeigt Döner-Läden rund um dich.'),
                          step(Icons.check_circle, 'Einchecken', 'Sammle Stempel für jeden Besuch und steig im Rang auf.'),
                          step(Icons.restaurant, 'Bewerten', 'Soße, Fleisch, Brot – bewerte, was wirklich zählt.'),
                          step(Icons.group, 'Mit Freunden', 'Sieh, wo deine Freunde gerade essen.'),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
                  child: Row(
                    children: [
                      for (var i = 0; i < 3; i++)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          width: i == _page ? 20 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: i == _page ? doenerOrange : theme.colorScheme.outlineVariant,
                          ),
                        ),
                      const Spacer(),
                      FilledButton(onPressed: _next, child: Text(_page == 2 ? "Los geht's" : 'Weiter')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
