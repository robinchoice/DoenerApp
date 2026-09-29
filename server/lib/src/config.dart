import 'package:postgres/postgres.dart';

class SmtpConfig {
  final String host;
  final int port;
  final String? username;
  final String? password;
  final bool ssl;
  const SmtpConfig({required this.host, required this.port, this.username, this.password, required this.ssl});
}

class Config {
  final Endpoint database;
  final bool databaseTls;
  final int port;

  /// Public base URL of this server, used for magic links (`$publicUrl/login?token=…`).
  final String publicUrl;
  final String? googlePlacesApiKey;
  final SmtpConfig? smtp;
  final String mailFrom;

  /// Directory with the Flutter web build; served at `/` when it exists.
  final String webDir;

  /// Allowed CORS origin for local web development (e.g. `http://localhost:5000`).
  final String? corsOrigin;

  const Config({
    required this.database,
    this.databaseTls = false,
    this.port = 8080,
    required this.publicUrl,
    this.googlePlacesApiKey,
    this.smtp,
    this.mailFrom = 'Döner App <noreply@localhost>',
    this.webDir = 'web',
    this.corsOrigin,
  });

  factory Config.fromEnvironment(Map<String, String> env) {
    String? get(String key) {
      final value = env[key]?.trim();
      return (value == null || value.isEmpty) ? null : value;
    }

    final smtpHost = get('SMTP_HOST');
    return Config(
      database: Endpoint(
        host: get('DB_HOST') ?? 'localhost',
        port: int.parse(get('DB_PORT') ?? '5432'),
        database: get('DB_NAME') ?? 'doener',
        username: get('DB_USER') ?? 'doener',
        password: get('DB_PASSWORD') ?? 'doener',
      ),
      databaseTls: get('DB_TLS') == 'require',
      port: int.parse(get('PORT') ?? '8080'),
      publicUrl: (get('PUBLIC_URL') ?? 'http://localhost:8080').replaceAll(RegExp(r'/+$'), ''),
      googlePlacesApiKey: get('GOOGLE_PLACES_API_KEY'),
      smtp: smtpHost == null
          ? null
          : SmtpConfig(
              host: smtpHost,
              port: int.parse(get('SMTP_PORT') ?? '587'),
              username: get('SMTP_USER'),
              password: get('SMTP_PASSWORD'),
              ssl: get('SMTP_SSL') == 'true',
            ),
      mailFrom: get('MAIL_FROM') ?? 'Döner App <noreply@localhost>',
      webDir: get('WEB_DIR') ?? 'web',
      corsOrigin: get('CORS_ORIGIN'),
    );
  }
}
