import 'package:mailer/mailer.dart' as m;
import 'package:mailer/smtp_server.dart';

import 'config.dart';

abstract interface class Mailer {
  Future<void> send({required String to, required String subject, required String text});
}

class SmtpMailer implements Mailer {
  final SmtpServer _server;
  final String _from;

  SmtpMailer(SmtpConfig config, this._from)
      : _server = SmtpServer(
          config.host,
          port: config.port,
          username: config.username,
          password: config.password,
          ssl: config.ssl,
        );

  @override
  Future<void> send({required String to, required String subject, required String text}) async {
    final message = m.Message()
      ..from = _parseAddress(_from)
      ..recipients.add(to)
      ..subject = subject
      ..text = text;
    await m.send(message, _server);
  }

  /// Accepts `Name <mail@host>` or a bare address.
  static m.Address _parseAddress(String value) {
    final match = RegExp(r'^(.*)<(.+)>$').firstMatch(value.trim());
    if (match == null) return m.Address(value.trim());
    return m.Address(match.group(2)!.trim(), match.group(1)!.trim());
  }
}

/// Development fallback when no SMTP server is configured: prints the mail.
class LogMailer implements Mailer {
  @override
  Future<void> send({required String to, required String subject, required String text}) async {
    print('--- mail to $to: $subject\n$text\n---');
  }
}
