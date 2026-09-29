import 'package:doener_app/src/core/app_data.dart';
import 'package:doener_app/src/core/session.dart';
import 'package:doener_app/src/features/place/review_sheet.dart';
import 'package:doener_app/src/features/profile/profile_screen.dart';
import 'package:doener_models/doener_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sembast/sembast_memory.dart';

const _place = PlaceDto(placeId: 'p1', name: 'Kebap Haus', latitude: 48, longitude: 7.85);

Future<AppData> _appData() async {
  final db = await newDatabaseFactoryMemory().openDatabase('test.db');
  return AppData(db, Session(db))..places[_place.placeId] = _place;
}

void main() {
  test('map cache keeps places the user interacted with', () async {
    final data = await _appData();
    data.places['p2'] = const PlaceDto(placeId: 'p2', name: 'Anderer Laden', latitude: 48, longitude: 7.8);
    await data.toggleFavorite('p1');
    await data.clearMapCache();
    expect(data.places.keys, ['p1']);
  });

  test('food counts are sorted by frequency', () {
    VisitDto visit(String? food) => VisitDto(
          id: '$food${DateTime.now().microsecondsSinceEpoch}',
          userId: 'u',
          userName: 'U',
          placeId: 'p',
          placeName: 'P',
          visitedAt: DateTime.now(),
          foodType: food,
        );
    final counts = foodCounts([visit('falafel'), visit('doener'), visit('doener'), visit(null)]);
    expect(counts.map((c) => (c.$1.id, c.$2)), [('doener', 2), ('falafel', 1)]);
  });

  testWidgets('overall rating follows the dimension average', (tester) async {
    final data = await tester.runAsync(_appData);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: data!,
        child: const MaterialApp(home: Scaffold(body: ReviewSheet(place: _place))),
      ),
    );

    final empty = find.byIcon(Icons.restaurant_outlined);
    expect(empty, findsNWidgets(20)); // Soße, Fleisch, Brot, Gesamt
    await tester.tap(empty.at(3)); // Soße: 4
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.restaurant_outlined).at(2)); // Fleisch: 2
    await tester.pumpAndSettle();

    expect(find.text('Okay'), findsOneWidget); // (4 + 2) / 2 = 3
  });
}
