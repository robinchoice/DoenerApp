import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:doener_models/doener_models.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'deps.dart';
import 'http.dart';

const loginRequestTtl = Duration(minutes: 15);
const sessionTtl = Duration(days: 180);
const maxLoginRequestsPerHour = 5;
const maxCodeAttempts = 5;

final _random = Random.secure();

String hashToken(String value) => sha256.convert(utf8.encode(value)).toString();

String randomToken() =>
    base64Url.encode(List<int>.generate(32, (_) => _random.nextInt(256))).replaceAll('=', '');

String randomCode() => _random.nextInt(1000000).toString().padLeft(6, '0');

class AuthUser {
  final String id;
  final String displayName;
  const AuthUser(this.id, this.displayName);

  UserDto toDto() => UserDto(id: id, displayName: displayName);
}

Future<AuthUser> requireUser(Deps deps, Request request) async {
  final header = request.headers['authorization'];
  if (header == null || !header.startsWith('Bearer ')) throw const ApiException.unauthorized();
  final row = await queryOne(
    deps.db,
    'SELECT u.id, u.display_name FROM sessions s JOIN users u ON u.id = s.user_id '
    'WHERE s.token_hash = @hash AND s.expires_at > now()',
    {'hash': hashToken(header.substring(7).trim())},
  );
  if (row == null) throw const ApiException.unauthorized('Sitzung abgelaufen');
  return AuthUser(row['id'] as String, row['display_name'] as String);
}

void mountAuth(Router router, Deps deps) {
  router.post('/auth/login', (Request request) async {
    final body = await readBody(request, LoginRequest.fromJson);
    if (!Validation.isValidEmail(body.email)) throw const ApiException.badRequest('Ungültige E-Mail-Adresse');
    final email = Validation.normalizeEmail(body.email);

    await deps.db.execute("DELETE FROM login_requests WHERE created_at < now() - interval '1 day'");
    await deps.db.execute('DELETE FROM sessions WHERE expires_at < now()');

    final recent = await queryOne(
      deps.db,
      "SELECT count(*)::int AS n FROM login_requests WHERE email = @email AND created_at > now() - interval '1 hour'",
      {'email': email},
    );
    if ((recent!['n'] as int) >= maxLoginRequestsPerHour) {
      throw const ApiException(429, 'Zu viele Anfragen – bitte später erneut versuchen.');
    }

    final code = randomCode();
    final token = randomToken();
    await deps.db.execute(
      Sql.named('INSERT INTO login_requests (email, code_hash, token_hash, expires_at) '
          'VALUES (@email, @code, @token, @expires)'),
      parameters: {
        'email': email,
        'code': hashToken(code),
        'token': hashToken(token),
        'expires': DateTime.now().toUtc().add(loginRequestTtl),
      },
    );

    final publicUrl = deps.config.publicUrl;
    await deps.mailer.send(
      to: email,
      subject: 'Dein Login-Code: $code',
      text: 'Dein Code für die Döner App: $code\n\n'
          '${publicUrl == null ? '' : 'Oder direkt im Browser anmelden:\n$publicUrl/login?token=$token\n\n'}'
          'Der Code ist ${loginRequestTtl.inMinutes} Minuten gültig. '
          'Falls du das nicht angefordert hast, ignoriere diese Mail einfach.',
    );
    return noContent();
  });

  router.post('/auth/verify', (Request request) async {
    final body = await readBody(request, VerifyRequest.fromJson);
    final email = await _consumeLoginRequest(deps, body);

    var user = await queryOne(deps.db, 'SELECT id, display_name FROM users WHERE email = @email', {'email': email});
    final isNewUser = user == null;
    user ??= await _createUser(deps, email);

    final token = randomToken();
    await deps.db.execute(
      Sql.named('INSERT INTO sessions (token_hash, user_id, expires_at) VALUES (@hash, @user:uuid, @expires)'),
      parameters: {
        'hash': hashToken(token),
        'user': user['id'],
        'expires': DateTime.now().toUtc().add(sessionTtl),
      },
    );
    final dto = UserDto(id: user['id'] as String, displayName: user['display_name'] as String);
    return json(AuthResponse(token: token, user: dto, isNewUser: isNewUser).toJson());
  });

  router.get('/auth/me', (Request request) async {
    final user = await requireUser(deps, request);
    return json(user.toDto().toJson());
  });

  router.post('/auth/logout', (Request request) async {
    await requireUser(deps, request);
    final token = request.headers['authorization']!.substring(7).trim();
    await deps.db.execute(Sql.named('DELETE FROM sessions WHERE token_hash = @hash'), parameters: {'hash': hashToken(token)});
    return noContent();
  });

  router.patch('/users/me', (Request request) async {
    final user = await requireUser(deps, request);
    final body = await readBody(request, UpdateMeRequest.fromJson);
    final error = Validation.displayNameError(body.displayName);
    if (error != null) throw ApiException.badRequest(error);
    final name = body.displayName.trim();
    try {
      await deps.db.execute(
        Sql.named('UPDATE users SET display_name = @name WHERE id = @id:uuid'),
        parameters: {'name': name, 'id': user.id},
      );
    } on UniqueViolationException {
      throw const ApiException.conflict('Der Name ist schon vergeben.');
    }
    return json(UserDto(id: user.id, displayName: name).toJson());
  });

  // Account deletion — required by the App Store for apps with sign-up.
  router.delete('/users/me', (Request request) async {
    final user = await requireUser(deps, request);
    await deps.db.execute(Sql.named('DELETE FROM users WHERE id = @id:uuid'), parameters: {'id': user.id});
    return noContent();
  });
}

/// Validates a code or magic-link token and returns the verified email.
Future<String> _consumeLoginRequest(Deps deps, VerifyRequest body) async {
  final token = Validation.clean(body.token);
  if (token != null) {
    final row = await queryOne(
      deps.db,
      'UPDATE login_requests SET used_at = now() '
      'WHERE token_hash = @hash AND used_at IS NULL AND expires_at > now() RETURNING email',
      {'hash': hashToken(token)},
    );
    if (row == null) throw const ApiException.unauthorized('Link ungültig oder abgelaufen.');
    return row['email'] as String;
  }

  final email = body.email == null ? null : Validation.normalizeEmail(body.email!);
  final code = body.code?.trim();
  if (email == null || code == null) throw const ApiException.badRequest('E-Mail und Code oder Token erforderlich');

  const invalid = ApiException.unauthorized('Code ungültig oder abgelaufen.');
  final row = await queryOne(
    deps.db,
    'SELECT id, code_hash, attempts FROM login_requests '
    'WHERE email = @email AND used_at IS NULL AND expires_at > now() ORDER BY created_at DESC LIMIT 1',
    {'email': email},
  );
  if (row == null || (row['attempts'] as int) >= maxCodeAttempts) throw invalid;

  if (row['code_hash'] != hashToken(code)) {
    await deps.db.execute(
      Sql.named('UPDATE login_requests SET attempts = attempts + 1 WHERE id = @id:uuid'),
      parameters: {'id': row['id']},
    );
    throw invalid;
  }
  final used = await queryOne(
    deps.db,
    'UPDATE login_requests SET used_at = now() WHERE id = @id:uuid AND used_at IS NULL RETURNING id',
    {'id': row['id']},
  );
  if (used == null) throw invalid;
  return email;
}

/// New accounts get a random unique name; the app asks to change it afterwards.
Future<Map<String, dynamic>> _createUser(Deps deps, String email) async {
  for (var attempt = 0; attempt < 10; attempt++) {
    final name = 'Döner-Fan-${1000 + _random.nextInt(9000)}';
    try {
      return (await queryOne(
        deps.db,
        'INSERT INTO users (email, display_name) VALUES (@email, @name) RETURNING id, display_name',
        {'email': email, 'name': name},
      ))!;
    } on UniqueViolationException catch (e) {
      if (e.constraintName != 'users_display_name') rethrow;
    }
  }
  throw StateError('Could not generate a unique display name');
}
