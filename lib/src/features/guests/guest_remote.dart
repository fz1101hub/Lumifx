import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

/// Something a guest may pick: an effect, a colour, or stop.
class GuestPick {
  const GuestPick.effect(String this.effectId)
      : color = null,
        stop = false;
  const GuestPick.color(String this.color)
      : effectId = null,
        stop = false;
  const GuestPick.stop()
      : effectId = null,
        color = null,
        stop = true;

  final String? effectId;
  final String? color;
  final bool stop;
}

/// The words on the guests' page, in the phone's language.
class GuestPageText {
  const GuestPageText({
    required this.title,
    required this.colours,
    required this.effects,
    required this.stop,
    required this.done,
    required this.wrongCode,
    required this.language,
  });

  final String title;
  final String colours;
  final String effects;
  final String stop;
  final String done;
  final String wrongCode;
  final String language;
}

/// A remote for guests: a small page served on the home Wi-Fi while the
/// phone shows it, to pick a colour or an effect from a safe list. Every
/// request needs the code shown on the phone (in the QR code's link); the
/// server listens only on the phone's own address on the local network,
/// and stops when the screen closes.
class GuestRemote {
  GuestRemote({
    required this.effects,
    required this.colors,
    required this.text,
    required this.onPick,
    math.Random? random,
    DateTime Function()? clock,
  })  : code = _newCode(random ?? math.Random.secure()),
        _clock = clock ?? DateTime.now;

  /// The effects offered: id and name, all without rapid flashes.
  final List<({String id, String name})> effects;

  /// The colours offered: `#RRGGBB` and name.
  final List<({String hex, String name})> colors;
  final GuestPageText text;
  final void Function(GuestPick pick) onPick;
  final DateTime Function() _clock;

  /// The code every request must carry.
  final String code;

  /// A guest's picks are this far apart at least.
  static const gap = Duration(milliseconds: 1500);

  HttpServer? _server;
  DateTime? _lastPick;

  static String _newCode(math.Random random) =>
      List.generate(6, (_) => random.nextInt(10)).join();

  bool get isRunning => _server != null;

  /// Starts serving at [address]; the link guests open (code included).
  Future<Uri> start(InternetAddress address, {int port = 0}) async {
    await stop();
    final server = await HttpServer.bind(address, port);
    _server = server;
    server.listen(_handle, onError: (Object _) {});
    return Uri(
      scheme: 'http',
      host: address.address,
      port: server.port,
      path: '/',
      queryParameters: {'c': code},
    );
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    response.headers
      ..set('cache-control', 'no-store')
      ..set('x-content-type-options', 'nosniff');
    try {
      final query = request.uri.queryParameters;
      if (query['c'] != code) {
        response.statusCode = HttpStatus.forbidden;
        response.headers.contentType = ContentType.html;
        response.write(_page(text.wrongCode, body: ''));
        return;
      }
      switch ((request.method, request.uri.path)) {
        case ('GET', '/'):
          response.headers.contentType = ContentType.html;
          response.write(_remotePage());
        case ('POST', '/pick'):
          final pick = _pickOf(query);
          if (pick == null) {
            response.statusCode = HttpStatus.badRequest;
            return;
          }
          final now = _clock();
          final last = _lastPick;
          if (last != null && now.difference(last) < gap) {
            response.statusCode = HttpStatus.tooManyRequests;
            return;
          }
          _lastPick = now;
          onPick(pick);
          response.statusCode = HttpStatus.noContent;
        default:
          response.statusCode = HttpStatus.notFound;
      }
    } finally {
      await response.close();
    }
  }

  /// Only what the list offers.
  GuestPick? _pickOf(Map<String, String> query) {
    if (query['stop'] == '1') {
      return const GuestPick.stop();
    }
    final effect = query['effect'];
    if (effect != null && effects.any((e) => e.id == effect)) {
      return GuestPick.effect(effect);
    }
    final color = query['color'];
    if (color != null && colors.any((c) => c.hex == color)) {
      return GuestPick.color(color);
    }
    return null;
  }

  static final _escape = const HtmlEscape();

  String _page(String title, {required String body}) => '''<!doctype html>
<html lang="${_escape.convert(text.language)}"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${_escape.convert(title)}</title>
<style>
body{font-family:system-ui,sans-serif;background:#12121a;color:#f4f4f8;margin:0;padding:16px;max-width:640px;margin:auto}
h1{font-size:1.4em}h2{font-size:1.1em;margin-top:24px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(84px,1fr));gap:10px}
button{border:0;border-radius:16px;padding:14px 8px;font-size:1em;color:#fff;background:#2a2a3a;min-height:56px}
button.c{color:#000;font-weight:600}
#stop{width:100%;margin-top:24px;background:#555}
#done{position:fixed;left:16px;right:16px;bottom:16px;padding:12px;border-radius:12px;background:#3ddc84;color:#000;text-align:center;display:none}
</style></head><body><h1>${_escape.convert(title)}</h1>$body</body></html>''';

  String _remotePage() {
    final codeJs = jsonEncode(code);
    final buttons = StringBuffer()
      ..write('<h2>${_escape.convert(text.colours)}</h2><div class="grid">');
    for (final c in colors) {
      buttons.write('<button class="c" style="background:${c.hex}" '
          'data-k="color" data-v="${_escape.convert(c.hex)}">'
          '${_escape.convert(c.name)}</button>');
    }
    buttons.write('</div><h2>${_escape.convert(text.effects)}</h2>'
        '<div class="grid">');
    for (final e in effects) {
      buttons.write('<button data-k="effect" data-v="${_escape.convert(e.id)}">'
          '${_escape.convert(e.name)}</button>');
    }
    buttons
      ..write('</div><button id="stop" data-k="stop" data-v="1">'
          '${_escape.convert(text.stop)}</button>')
      ..write('<div id="done">${_escape.convert(text.done)}</div>')
      ..write('<script>'
          'const code=$codeJs;'
          'document.querySelectorAll("button").forEach(b=>b.onclick=()=>{'
          'const p=new URLSearchParams({c:code});p.set(b.dataset.k,b.dataset.v);'
          'fetch("/pick?"+p,{method:"POST"}).then(r=>{if(r.ok){'
          'const d=document.getElementById("done");d.style.display="block";'
          'setTimeout(()=>d.style.display="none",1500);}});});'
          '</script>');
    return _page(text.title, body: buttons.toString());
  }

  /// The phone's address on the home network (a private IPv4 one), if
  /// any.
  static Future<InternetAddress?> lanAddress() async {
    try {
      for (final interface
          in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
        for (final address in interface.addresses) {
          if (isPrivate(address)) {
            return address;
          }
        }
      }
    } on Object {
      // No network: nothing to serve on.
    }
    return null;
  }

  /// 10/8, 172.16/12 or 192.168/16: a home network, never the internet.
  static bool isPrivate(InternetAddress address) {
    final b = address.rawAddress;
    if (address.type != InternetAddressType.IPv4 || b.length != 4) {
      return false;
    }
    return b[0] == 10 ||
        (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
        (b[0] == 192 && b[1] == 168);
  }
}
