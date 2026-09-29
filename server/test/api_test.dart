@Tags(['db'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:doener_models/doener_models.dart';
import 'package:doener_server/doener_server.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// Runs against a real Postgres. Set TEST_DB_PORT (and optionally
/// TEST_DB_HOST / TEST_DB_USER / TEST_DB_PASSWORD); the database
/// `doener_test` is recreated on every run.
class CapturingMailer implements Mailer {
  final sent = <({String to, String text})>[];
  @override
  Future<void> send({required String to, required String subject, required String text}) async =>
      sent.add((to: to, text: text));
}

void main() {
  final env = Platform.environment;
  final port = int.tryParse(env['TEST_DB_PORT'] ?? '');
  if (port == null) {
    test('api tests', () {}, skip: 'TEST_DB_PORT not set');
    return;
  }

  late Handler handler;
  late Deps deps;
  late Pool<void> db;
  final mailer = CapturingMailer();
  var googleCalls = 0;

  setUpAll(() async {
    Endpoint endpoint(String database) => Endpoint(
          host: env['TEST_DB_HOST'] ?? 'localhost',
          port: port,
          database: database,
          username: env['TEST_DB_USER'] ?? 'postgres',
          password: env['TEST_DB_PASSWORD'],
        );
    final admin = await Connection.open(endpoint('postgres'), settings: const ConnectionSettings(sslMode: SslMode.disable));
    await admin.execute('DROP DATABASE IF EXISTS doener_test WITH (FORCE)');
    await admin.execute('CREATE DATABASE doener_test');
    await admin.close();

    final config = Config(
      database: endpoint('doener_test'),
      publicUrl: 'https://doener.test',
      googlePlacesApiKey: 'fake-key',
      webDir: '/nonexistent',
    );
    db = openPool(config);
    // Leftovers of the Vapor backend, as in production — same names as the new tables.
    await db.execute('CREATE TABLE _fluent_migrations (id uuid PRIMARY KEY)');
    await db.execute('CREATE TABLE users (id uuid PRIMARY KEY, apple_user_id text UNIQUE, display_name text UNIQUE)');
    await db.execute("INSERT INTO users VALUES (gen_random_uuid(), 'apple-1', 'Alter Tester')");
    await migrate(db);
    await migrate(db); // idempotent

    final google = MockClient((request) async {
      googleCalls++;
      if (request.method == 'GET') {
        // Place Details refresh.
        return http.Response(
          jsonEncode({
            'id': request.url.pathSegments.last,
            'displayName': {'text': 'Kebap Haus'},
            'location': {'latitude': 48.0, 'longitude': 7.85},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final low = body['locationRestriction']['rectangle']['low'] as Map<String, dynamic>;
      // Only the tile containing Freiburg's centre has shops.
      final hasShops = (low['latitude'] as num) <= 48.0 && (low['latitude'] as num) + 0.03 > 48.0 &&
          (low['longitude'] as num) <= 7.85 && (low['longitude'] as num) + 0.03 > 7.85;
      final places = hasShops
          ? [
              {
                'id': 'place-kebap',
                'displayName': {'text': 'Kebap Haus'},
                'location': {'latitude': 48.0, 'longitude': 7.85},
                'types': ['restaurant'],
                'addressComponents': [
                  {'longText': 'Berlin', 'types': ['locality']},
                ],
              },
              {
                'id': 'place-pizza',
                'displayName': {'text': 'Pizzeria Roma'},
                'location': {'latitude': 48.001, 'longitude': 7.851},
                'types': ['italian_restaurant'],
              },
              {
                'id': 'place-closed',
                'displayName': {'text': 'Alter Döner'},
                'location': {'latitude': 48.002, 'longitude': 7.852},
                'businessStatus': 'CLOSED_PERMANENTLY',
              },
            ]
          : [];
      return http.Response(jsonEncode({'places': places}), 200, headers: {'content-type': 'application/json'});
    });

    deps = Deps(db: db, config: config, mailer: mailer, httpClient: google);
    handler = buildHandler(deps);
  });

  tearDownAll(() => db.close());

  Future<(int, dynamic)> call(String method, String path, {Object? body, String? token}) async {
    final response = await handler(Request(
      method,
      Uri.parse('http://localhost/api/v1$path'),
      body: body == null ? null : jsonEncode(body),
      headers: {
        'content-type': 'application/json',
        if (token != null) 'authorization': 'Bearer $token',
      },
    ));
    final text = await response.readAsString();
    return (response.statusCode, text.isEmpty ? null : jsonDecode(text));
  }

  String lastCode() => RegExp(r'Döner App: (\d{6})').firstMatch(mailer.sent.last.text)!.group(1)!;
  String lastLinkToken() => RegExp(r'login\?token=([\w-]+)').firstMatch(mailer.sent.last.text)!.group(1)!;

  Future<(String, UserDto)> signUp(String email, String name) async {
    expect((await call('POST', '/auth/login', body: {'email': email})).$1, 204);
    final (status, body) = await call('POST', '/auth/verify', body: {'email': email, 'code': lastCode()});
    expect(status, 200);
    final auth = AuthResponse.fromJson(body as Map<String, dynamic>);
    final (patched, user) = await call('PATCH', '/users/me', body: {'displayName': name}, token: auth.token);
    expect(patched, 200);
    return (auth.token, UserDto.fromJson(user as Map<String, dynamic>));
  }

  test('old Vapor tables are kept in the legacy schema', () async {
    final rows = await db.execute('SELECT display_name FROM legacy_vapor.users');
    expect(rows.single.single, 'Alter Tester');
    final moved = await db.execute("SELECT count(*)::int FROM pg_tables WHERE schemaname = 'legacy_vapor'");
    expect(moved.single.single, 2);
  });

  group('auth', () {
    test('magic link code flow', () async {
      expect((await call('POST', '/auth/login', body: {'email': 'kaputt'})).$1, 400);
      expect((await call('POST', '/auth/login', body: {'email': ' Anna@Example.org '})).$1, 204);
      expect(mailer.sent.last.to, 'anna@example.org');
      final code = lastCode();

      final wrong = code == '000000' ? '111111' : '000000';
      expect((await call('POST', '/auth/verify', body: {'email': 'anna@example.org', 'code': wrong})).$1, 401);

      final (status, body) = await call('POST', '/auth/verify', body: {'email': 'ANNA@example.org', 'code': code});
      expect(status, 200);
      final auth = AuthResponse.fromJson(body as Map<String, dynamic>);
      expect(auth.isNewUser, isTrue);
      expect(auth.user.displayName, startsWith('Döner-Fan-'));

      // Codes are single-use.
      expect((await call('POST', '/auth/verify', body: {'email': 'anna@example.org', 'code': code})).$1, 401);

      final (meStatus, me) = await call('GET', '/auth/me', token: auth.token);
      expect(meStatus, 200);
      expect(me['id'], auth.user.id);

      expect((await call('POST', '/auth/logout', token: auth.token)).$1, 204);
      expect((await call('GET', '/auth/me', token: auth.token)).$1, 401);
    });

    test('magic link token logs into the existing account', () async {
      await call('POST', '/auth/login', body: {'email': 'anna@example.org'});
      final (status, body) = await call('POST', '/auth/verify', body: {'token': lastLinkToken()});
      expect(status, 200);
      expect(body['isNewUser'], isFalse);
    });

    test('code is locked after too many wrong attempts', () async {
      await call('POST', '/auth/login', body: {'email': 'brute@example.org'});
      final code = lastCode();
      final wrong = code == '000000' ? '111111' : '000000';
      for (var i = 0; i < 5; i++) {
        await call('POST', '/auth/verify', body: {'email': 'brute@example.org', 'code': wrong});
      }
      expect((await call('POST', '/auth/verify', body: {'email': 'brute@example.org', 'code': code})).$1, 401);
    });

    test('login requests are rate limited', () async {
      for (var i = 0; i < 5; i++) {
        expect((await call('POST', '/auth/login', body: {'email': 'spam@example.org'})).$1, 204);
      }
      expect((await call('POST', '/auth/login', body: {'email': 'spam@example.org'})).$1, 429);
    });

    test('display names are unique case-insensitively', () async {
      final (token, _) = await signUp('bert@example.org', 'Bert');
      await signUp('bert2@example.org', 'Bert2');
      final (status, _) = await call('PATCH', '/users/me', body: {'displayName': 'bert2'}, token: token);
      expect(status, 409);
    });
  });

  group('places, visits, reviews, social', () {
    late String anna;
    late String bob;
    late UserDto bobUser;
    late UserDto annaUser;

    setUpAll(() async {
      (anna, annaUser) = await signUp('anna2@example.org', 'Anna');
      (bob, bobUser) = await signUp('bob@example.org', 'Bob');
    });

    test('map area sync filters and caches Google results', () async {
      const bbox = '/places?minLat=47.99&minLon=7.84&maxLat=48.01&maxLon=7.86';
      final (status, body) = await call('GET', bbox);
      expect(status, 200);
      expect((body as List).map((p) => p['placeId']), ['place-kebap']);
      expect(body.single['city'], 'Berlin');
      final callsAfterFirst = googleCalls;
      expect(callsAfterFirst, greaterThan(0));

      await call('GET', bbox);
      expect(googleCalls, callsAfterFirst, reason: 'tiles are cached, including empty ones');

      expect((await call('GET', '/places?minLat=10&minLon=10&maxLat=5&maxLon=11')).$1, 400);
      expect((await call('GET', '/places/unknown')).$1, 404);
    });

    test('visits are idempotent and only fresh ones go live', () async {
      const id = '11111111-2222-4333-8444-555555555555';
      final visit = {'id': id, 'visitedAt': DateTime.now().toUtc().toIso8601String(), 'foodType': 'yufka'};
      final (created, body) = await call('POST', '/places/place-kebap/visits', body: visit, token: anna);
      expect(created, 201);
      expect(body['placeName'], 'Kebap Haus');
      expect((await call('POST', '/places/place-kebap/visits', body: visit, token: anna)).$1, 200);
      expect((await call('POST', '/places/place-kebap/visits', body: visit, token: bob)).$1, 409);

      final (_, mine) = await call('GET', '/me/visits', token: anna);
      expect(mine, hasLength(1));

      expect(
        (await call('POST', '/places/place-kebap/visits',
                body: {'id': '11111111-2222-4333-8444-555555555556', 'visitedAt': '2020-01-01T12:00:00Z', 'foodType': 'sushi'},
                token: anna))
            .$1,
        400,
      );
      expect(
        (await call('POST', '/places/place-pizza/visits',
                body: {'id': '11111111-2222-4333-8444-555555555557', 'visitedAt': '2020-01-01T12:00:00Z'}, token: anna))
            .$1,
        404,
        reason: 'filtered places were never stored',
      );
      expect((await call('POST', '/places/place-kebap/visits', body: visit)).$1, 401);
    });

    test('friendship: asking back accepts', () async {
      final (_, found) = await call('GET', '/users/search?q=bo', token: anna);
      expect((found as List).map((u) => u['displayName']), contains('Bob'));

      final (s1, f1) = await call('POST', '/friends/requests', body: {'userId': bobUser.id}, token: anna);
      expect(s1, 200);
      expect(f1['status'], 'pending');
      expect(f1['direction'], 'outgoing');

      final (_, bobList) = await call('GET', '/friends', token: bob);
      expect(bobList.single['direction'], 'incoming');

      final (_, f2) = await call('POST', '/friends/requests', body: {'userId': annaUser.id}, token: bob);
      expect(f2['status'], 'accepted');
      expect(f2['id'], f1['id']);

      final (_, live) = await call('GET', '/feed/live', token: bob);
      expect((live as List).single['placeName'], 'Kebap Haus');
      expect(live.single['foodType'], 'yufka');
    });

    test('reviews upsert and feed community data', () async {
      final review = {'rating': 4, 'sauceRating': 5, 'text': 'Top Soße', 'specialNote': ' Knoblauch '};
      expect((await call('PUT', '/places/place-kebap/review', body: review, token: anna)).$1, 200);
      final (_, updated) = await call('PUT', '/places/place-kebap/review', body: {...review, 'rating': 5}, token: anna);
      expect(updated['rating'], 5);
      expect(updated['specialNote'], 'Knoblauch');
      expect((await call('PUT', '/places/place-kebap/review', body: {'rating': 6}, token: anna)).$1, 400);

      final (_, place) = await call('GET', '/places/place-kebap');
      expect(place['reviewCount'], 1);
      expect(place['avgRating'], 5.0);
      expect(place['specialNote'], 'Knoblauch');

      final (_, summary) = await call('GET', '/places/place-kebap/summary');
      expect(summary['topDimension'], 'Soße');

      final (_, top) = await call('GET', '/places/top?lat=48&lon=7.85');
      expect((top as List).single['placeId'], 'place-kebap');
      final (_, trending) = await call('GET', '/places/trending');
      expect((trending as List).single['placeId'], 'place-kebap');
    });

    test('feed pages through many entries without gaps', () async {
      // 30 visits sharing one timestamp — the old feed stopped after 20 and
      // skipped same-second entries.
      final at = DateTime.utc(2026, 1, 1, 12).toIso8601String();
      for (var i = 0; i < 30; i++) {
        final id = '22222222-2222-4222-8222-${i.toString().padLeft(12, '0')}';
        await call('POST', '/places/place-kebap/visits', body: {'id': id, 'visitedAt': at}, token: anna);
      }

      final seen = <String>{};
      String? cursor;
      var pages = 0;
      do {
        final (status, body) = await call('GET', '/feed?limit=20${cursor == null ? '' : '&cursor=$cursor'}', token: bob);
        expect(status, 200);
        final page = FeedPage.fromJson(body as Map<String, dynamic>);
        seen.addAll(page.items.map((i) => i.id));
        cursor = page.cursor;
        pages++;
        expect(page.hasMore, cursor != null);
      } while (cursor != null);

      // 1 fresh visit + 30 backdated visits + 1 review.
      expect(seen, hasLength(32));
      expect(pages, 2);

      final (_, annaFeed) = await call('GET', '/feed', token: anna);
      expect(annaFeed['items'], isEmpty, reason: 'own activity is not in the friends feed');
    });

    test('feedback and shop reports', () async {
      final shot = base64.encode([1, 2, 3]);
      expect((await call('POST', '/feedback', body: {'message': 'Karte ruckelt', 'screenshotBase64': shot}, token: bob)).$1, 204);
      expect((await call('POST', '/feedback', body: {'message': 'x'}, token: bob)).$1, 400);
      expect((await call('POST', '/shop-reports', body: {'name': 'Erbil', 'latitude': 48.0}, token: bob)).$1, 204);
      final rows = await db.execute('SELECT count(*)::int FROM shop_reports');
      expect(rows.first.first, 1);
    });

    test('deleting the account removes the user data', () async {
      expect((await call('DELETE', '/users/me', token: anna)).$1, 204);
      expect((await call('GET', '/auth/me', token: anna)).$1, 401);
      final (_, place) = await call('GET', '/places/place-kebap');
      expect(place['reviewCount'], 0);
      final (_, friends) = await call('GET', '/friends', token: bob);
      expect(friends, isEmpty);
    });
  });

  test('place cache stays within Google\'s 30 days', () async {
    final (carla, _) = await signUp('carla@example.org', 'Carla');
    await call('POST', '/places/place-kebap/visits',
        body: {'id': '33333333-3333-4333-8333-333333333333', 'visitedAt': '2026-01-01T12:00:00Z'}, token: carla);
    await db.execute("INSERT INTO places (google_place_id, name, latitude, longitude) VALUES ('place-unused', 'Alt', 48, 7.85)");
    await db.execute("UPDATE places SET synced_at = now() - interval '31 days', name = 'Veraltet' "
        "WHERE google_place_id IN ('place-kebap', 'place-unused')");

    await maintainPlaceCache(deps);

    final (_, kept) = await call('GET', '/places/place-kebap');
    expect(kept['name'], 'Kebap Haus', reason: 'visited place is refreshed from Google');
    expect((await call('GET', '/places/place-unused')).$1, 404, reason: 'unused stale place is dropped');
  });
}
