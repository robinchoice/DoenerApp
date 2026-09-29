// Inserts a few Freiburg places so the map isn't empty when developing
// without GOOGLE_PLACES_API_KEY. Uses the same DB_* variables as the server:
//   dart run tool/seed_dev.dart
import 'dart:io';

import 'package:doener_server/doener_server.dart';
import 'package:postgres/postgres.dart';

const _places = [
  ('dev-1', 'Mustafas Döner', 47.9959, 7.8494, 'Bertoldstraße 12'),
  ('dev-2', 'Kebap Haus am Martinstor', 47.9934, 7.8474, 'Kaiser-Joseph-Straße 245'),
  ('dev-3', 'Dürüm Express', 47.9985, 7.8421, 'Rempartstraße 3'),
  ('dev-4', 'Bosporus Grill', 48.0012, 7.8531, 'Habsburgerstraße 7'),
  ('dev-5', 'Yufka Palast', 47.9901, 7.8558, 'Schwarzwaldstraße 20'),
];

Future<void> main() async {
  final db = openPool(Config.fromEnvironment(Platform.environment));
  await migrate(db);
  for (final (id, name, lat, lon, address) in _places) {
    await db.execute(
      Sql.named('INSERT INTO places (google_place_id, name, latitude, longitude, address, postal_code, city) '
          "VALUES (@id, @name, @lat, @lon, @address, '79098', 'Freiburg im Breisgau') ON CONFLICT DO NOTHING"),
      parameters: {'id': id, 'name': name, 'lat': lat, 'lon': lon, 'address': address},
    );
  }
  await db.close();
  print('Seeded ${_places.length} places.');
}
