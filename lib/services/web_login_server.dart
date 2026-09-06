import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 登录页内置的局域网 Web Server：手机浏览器打开后可填写登录信息，
/// 提交后由 App 直接完成登录（复用现有 TV 登录逻辑）。
///
/// 仅在登录页存活期间运行：initState 启动、dispose 停止。
/// 绑定 0.0.0.0（局域网全设备可达，无鉴权）——家庭 Wi-Fi 下使用。
class WebLoginServer {
  static HttpServer? _server;
  static String? lanIp;

  /// 监听端口（默认 8080，便于记忆）。
  static int port = 8080;

  /// 启动单例 Server。已运行时直接返回当前 LAN IP。
  /// [onSubmit] 收到手机提交的表单字段（x-www-form-urlencoded）。
  /// [getDefaults] 返回当前 App 中的配置，用于预填表单。
  static Future<String?> start({
    required void Function(Map<String, String>) onSubmit,
    Map<String, String> Function()? getDefaults,
  }) async {
    if (_server != null) return lanIp;
    lanIp = await _getLanIp();
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server!.listen((req) => _handleRequest(req, onSubmit, getDefaults));
    return lanIp;
  }

  /// 停止 Server。
  static Future<void> stop() async {
    final s = _server;
    _server = null;
    await s?.close(force: true);
  }

  /// 探测局域网 IPv4 地址（跳过回环与链路本地）。
  static Future<String?> _getLanIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final a = addr.address;
          if (a.startsWith('127.') || a.startsWith('169.254.')) continue;
          return a;
        }
      }
    } catch (_) {
      // 忽略：拿不到就返回 null，UI 不展示地址
    }
    return null;
  }

  static Future<void> _handleRequest(
    HttpRequest req,
    void Function(Map<String, String>) onSubmit,
    Map<String, String> Function()? getDefaults,
  ) async {
    try {
      if (req.method == 'GET') {
        final defaults = getDefaults?.call() ?? <String, String>{};
        await _sendHtml(req, _formHtml(defaults));
      } else if (req.method == 'POST') {
        final body = await utf8.decoder.bind(req).join();
        final fields = Uri.splitQueryString(body);
        onSubmit(fields);
        await _sendHtml(req, _successHtml());
      } else {
        req.response
          ..statusCode = HttpStatus.methodNotAllowed
          ..close();
      }
    } catch (_) {
      try {
        req.response
          ..statusCode = HttpStatus.internalServerError
          ..close();
      } catch (_) {
        // 已无法回复，忽略
      }
    }
  }

  static Future<void> _sendHtml(
    HttpRequest req,
    String html, {
    int status = HttpStatus.ok,
  }) async {
    req.response
      ..statusCode = status
      ..headers.contentType = ContentType.parse('text/html; charset=utf-8')
      ..write(html);
    await req.response.close();
  }

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  static String _formHtml(Map<String, String> d) {
    final protocol = _esc(d['protocol'] ?? 'http');
    final host = _esc(d['host'] ?? '');
    final port = _esc(d['port'] ?? '');
    final username = _esc(d['username'] ?? '');
    final password = _esc(d['password'] ?? '');
    final subscription = _esc(d['subscriptionUrl'] ?? '');
    final localChecked = (d['mode'] ?? 'server') == 'local' ? 'checked' : '';
    final serverChecked = (d['mode'] ?? 'server') == 'local' ? '' : 'checked';
    return '''<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>Selene 登录配置</title>
<style>
  :root { --p:#2c3e50; --g:#27ae60; }
  * { box-sizing: border-box; }
  body { margin:0; font-family:-apple-system,BlinkMacSystemFont,"PingFang SC","Microsoft YaHei",sans-serif;
         background:#f2f5f7; color:var(--p); padding:16px; }
  .card { max-width:480px; margin:0 auto; background:#fff; border-radius:14px; padding:20px;
          box-shadow:0 2px 12px rgba(0,0,0,.06); }
  h1 { font-size:20px; margin:0 0 4px; }
  .sub { font-size:13px; color:#7f8c8d; margin:0 0 18px; }
  label { display:block; font-size:13px; margin:14px 0 6px; color:#34495e; }
  input, select { width:100%; padding:12px 14px; font-size:16px; border:1px solid #dfe6e9;
          border-radius:10px; background:#fff; color:var(--p); }
  input:focus, select:focus { outline:none; border-color:var(--g); }
  .row { display:flex; gap:8px; }
  .row select { flex:0 0 92px; }
  .row input { flex:1; }
  .modes { display:flex; gap:10px; margin-bottom:4px; }
  .modes label { flex:1; margin:0; padding:12px; text-align:center; border:1px solid #dfe6e9;
          border-radius:10px; cursor:pointer; background:#fff; }
  .modes input { display:none; }
  .modes label.active { border-color:var(--g); background:#eafaf1; color:var(--g); font-weight:600; }
  .sec { display:none; }
  .sec.show { display:block; }
  button { width:100%; margin-top:22px; padding:15px; font-size:16px; font-weight:600;
          color:#fff; background:var(--p); border:none; border-radius:10px; cursor:pointer; }
  button:active { background:#1f2d3a; }
</style>
</head>
<body>
  <form id="f" method="post" action="/">
    <div class="card">
      <h1>Selene 登录配置</h1>
      <p class="sub">在与电视同一 Wi-Fi 下填写，提交后电视将自动登录。</p>
      <div class="modes">
        <label id="lbl-server" class="$serverChecked active"><input type="radio" name="mode" value="server" $serverChecked onchange="switchMode()">服务器模式</label>
        <label id="lbl-local" class="$localChecked"><input type="radio" name="mode" value="local" $localChecked onchange="switchMode()">本地模式</label>
      </div>

      <div id="sec-server" class="sec ${serverChecked.isNotEmpty ? 'show' : ''}">
        <label>服务器地址</label>
        <div class="row">
          <select name="protocol">
            <option value="http" ${protocol == 'http' ? 'selected' : ''}>http</option>
            <option value="https" ${protocol == 'https' ? 'selected' : ''}>https</option>
          </select>
          <input name="host" placeholder="主机 / IP" value="$host">
        </div>
        <label>端口</label>
        <input name="port" placeholder="端口，如 8096" value="$port">
        <label>用户名</label>
        <input name="username" placeholder="用户名" value="$username" autocomplete="username">
        <label>密码</label>
        <input name="password" type="password" placeholder="密码" value="$password" autocomplete="current-password">
      </div>

      <div id="sec-local" class="sec $localChecked">
        <label>订阅链接</label>
        <input name="subscriptionUrl" placeholder="https://.../sub" value="$subscription">
      </div>

      <button type="submit">提交并登录</button>
    </div>
  </form>
  <script>
    function switchMode() {
      var m = document.querySelector('input[name=mode]:checked').value;
      document.getElementById('sec-server').classList.toggle('show', m === 'server');
      document.getElementById('sec-local').classList.toggle('show', m === 'local');
      document.getElementById('lbl-server').classList.toggle('active', m === 'server');
      document.getElementById('lbl-local').classList.toggle('active', m === 'local');
    }
    switchMode();
  </script>
</body>
</html>''';
  }

  static String _successHtml() => '''<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>已提交</title>
<style>
  body { margin:0; font-family:-apple-system,"PingFang SC","Microsoft YaHei",sans-serif;
         background:#f2f5f7; color:#2c3e50; display:flex; min-height:100vh;
         align-items:center; justify-content:center; }
  .card { background:#fff; border-radius:14px; padding:28px 32px; text-align:center;
          box-shadow:0 2px 12px rgba(0,0,0,.06); }
  .ok { color:#27ae60; font-size:40px; margin-bottom:8px; }
  p { margin:6px 0; font-size:15px; color:#7f8c8d; }
</style>
</head>
<body>
  <div class="card">
    <div class="ok">✓</div>
    <p>已提交，请在电视上查看登录结果。</p>
  </div>
</body>
</html>''';
}
