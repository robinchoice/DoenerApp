import 'package:postgres/postgres.dart';

import 'config.dart';

Pool<void> openPool(Config config) => Pool.withEndpoints(
      [config.database],
      settings: PoolSettings(
        maxConnectionCount: 10,
        sslMode: config.databaseTls ? SslMode.require : SslMode.disable,
      ),
    );

/// Each entry is one migration; statements run in a single transaction.
/// Append only — never edit an entry that has shipped.
const migrations = <List<String>>[
  [
    '''CREATE TABLE places (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      google_place_id text NOT NULL UNIQUE,
      name text NOT NULL,
      latitude double precision NOT NULL,
      longitude double precision NOT NULL,
      address text,
      postal_code text,
      city text,
      opening_hours text,
      synced_at timestamptz NOT NULL DEFAULT now(),
      created_at timestamptz NOT NULL DEFAULT now()
    )''',
    'CREATE INDEX places_lat_lon ON places (latitude, longitude)',
    '''CREATE TABLE search_tiles (
      tile_key text PRIMARY KEY,
      searched_at timestamptz NOT NULL
    )''',
    '''CREATE TABLE users (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      email text NOT NULL UNIQUE,
      display_name text NOT NULL,
      live_place_id uuid REFERENCES places (id) ON DELETE SET NULL,
      live_until timestamptz,
      live_food_type text,
      created_at timestamptz NOT NULL DEFAULT now()
    )''',
    'CREATE UNIQUE INDEX users_display_name ON users (lower(display_name))',
    '''CREATE TABLE login_requests (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      email text NOT NULL,
      code_hash text NOT NULL,
      token_hash text NOT NULL UNIQUE,
      attempts int NOT NULL DEFAULT 0,
      expires_at timestamptz NOT NULL,
      used_at timestamptz,
      created_at timestamptz NOT NULL DEFAULT now()
    )''',
    'CREATE INDEX login_requests_email ON login_requests (email, created_at)',
    '''CREATE TABLE sessions (
      token_hash text PRIMARY KEY,
      user_id uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
      expires_at timestamptz NOT NULL,
      created_at timestamptz NOT NULL DEFAULT now()
    )''',
    '''CREATE TABLE reviews (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
      place_id uuid NOT NULL REFERENCES places (id) ON DELETE CASCADE,
      rating int NOT NULL CHECK (rating BETWEEN 1 AND 5),
      sauce_rating int CHECK (sauce_rating BETWEEN 1 AND 5),
      fleisch_rating int CHECK (fleisch_rating BETWEEN 1 AND 5),
      brot_rating int CHECK (brot_rating BETWEEN 1 AND 5),
      text text,
      special_note text,
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now(),
      UNIQUE (user_id, place_id)
    )''',
    'CREATE INDEX reviews_place ON reviews (place_id)',
    '''CREATE TABLE visits (
      id uuid PRIMARY KEY,
      user_id uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
      place_id uuid NOT NULL REFERENCES places (id) ON DELETE CASCADE,
      visited_at timestamptz NOT NULL,
      comment text,
      food_type text,
      created_at timestamptz NOT NULL DEFAULT now()
    )''',
    'CREATE INDEX visits_user ON visits (user_id, visited_at)',
    'CREATE INDEX visits_place ON visits (place_id)',
    '''CREATE TABLE friendships (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      requester_id uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
      addressee_id uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
      status text NOT NULL CHECK (status IN ('pending', 'accepted')),
      created_at timestamptz NOT NULL DEFAULT now(),
      CHECK (requester_id <> addressee_id)
    )''',
    // One friendship per pair, regardless of who asked first.
    '''CREATE UNIQUE INDEX friendships_pair ON friendships
      (LEAST(requester_id, addressee_id), GREATEST(requester_id, addressee_id))''',
    '''CREATE TABLE feedback (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id uuid REFERENCES users (id) ON DELETE SET NULL,
      message text NOT NULL,
      screenshot bytea,
      app_version text,
      build_number text,
      platform text,
      created_at timestamptz NOT NULL DEFAULT now()
    )''',
    '''CREATE TABLE shop_reports (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id uuid REFERENCES users (id) ON DELETE SET NULL,
      name text NOT NULL,
      hint text,
      latitude double precision,
      longitude double precision,
      note text,
      created_at timestamptz NOT NULL DEFAULT now()
    )''',
    // Community aggregates are computed on read — no denormalized counters to keep in sync.
    '''CREATE VIEW place_view AS
      SELECT p.*, s.avg_rating, COALESCE(s.review_count, 0) AS review_count, n.special_note
      FROM places p
      LEFT JOIN (
        SELECT place_id, avg(rating)::float8 AS avg_rating, count(*)::int AS review_count
        FROM reviews GROUP BY place_id
      ) s ON s.place_id = p.id
      LEFT JOIN LATERAL (
        SELECT special_note FROM reviews r
        WHERE r.place_id = p.id AND r.special_note IS NOT NULL
        ORDER BY r.updated_at DESC LIMIT 1
      ) n ON true''',
  ],
];

Future<void> migrate(Pool<void> db) async {
  await db.execute('CREATE TABLE IF NOT EXISTS schema_migrations '
      '(version int PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())');
  final applied = await db.execute('SELECT coalesce(max(version), 0) FROM schema_migrations');
  final current = applied.first.first as int;

  for (var version = current + 1; version <= migrations.length; version++) {
    await db.runTx((tx) async {
      for (final statement in migrations[version - 1]) {
        await tx.execute(statement);
      }
      await tx.execute(Sql.named('INSERT INTO schema_migrations (version) VALUES (@v)'), parameters: {'v': version});
    });
  }
}
