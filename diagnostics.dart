import 'dart:io';
import '../../services/network_settings.dart';
import 'net_client.dart';

class DiagStep {
  DiagStep(this.label, this.ok, this.detail);
  final String label;
  final bool ok;
  final String detail;
}

/// Diagnostic : DNS système, DNS sécurisé, TCP, HTTP.
class Diagnostics {
  static Future<List<DiagStep>> run(NetworkSettings s, String url) async {
    final steps = <DiagStep>[];
    final u = Uri.parse(url);
    final host = u.host;
    final port = u.hasPort ? u.port : (u.scheme == 'https' ? 443 : 80);
    final net = NetClient(s);
    String? ip;

    try {
      final r = await InternetAddress.lookup(host).timeout(const Duration(seconds: 6));
      ip = r.first.address;
      steps.add(DiagStep('DNS système', true, '$host → $ip'));
    } catch (_) {
      steps.add(DiagStep('DNS système', false, 'Résolution impossible'));
    }

    final doh = await net.resolveDoh(host);
    steps.add(DiagStep(
        'DNS sécurisé (DoH)',
        doh != null,
        doh != null
            ? '$host → $doh${s.dohEnabled ? '' : ' (option désactivée)'}'
            : 'Échec ou serveur DoH injoignable'));
    ip ??= doh;

    if (ip == null) {
      steps.add(DiagStep('TCP', false, 'Aucune adresse à tester'));
    } else {
      try {
        final sock = await Socket.connect(ip, port, timeout: const Duration(seconds: 6));
        sock.destroy();
        steps.add(DiagStep('TCP', true, '$ip:$port joignable'));
      } catch (_) {
        steps.add(DiagStep('TCP', false, '$ip:$port injoignable'));
      }
    }

    try {
      final code = await net.status(url);
      steps.add(DiagStep('HTTP', code < 400, 'Code $code'));
    } catch (_) {
      steps.add(DiagStep('HTTP', false, 'Aucune réponse'));
    }
    return steps;
  }
}
