// Başlık Tarayıcı - sürüm 6 (Format okuyucu eklendi: format.dart, kimya.dart)
// Bir forum sitesini gezer, sayfa başlıklarında, alt başlıklarında ve
// bağlantı yazılarında aranan kelime köklerini bulur, .txt dosyalarına yazar.
//
// Bölümler:
//   1) Yardımcı fonksiyonlar (harf düzeltme, eşleştirme)
//   2) Ayarlar ve Bulgu sınıfları
//   3) Tarayici sınıfı  -> gezme, bulma, limitler, ara kayıt, devam etme
//   4) Ekran (arayüz)

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'format.dart';
import 'hf.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

void main() => runApp(const UygulamaKok());

// ---------------------------------------------------------------------------
// ARKA PLANDA ÇALIŞMA
// Android'e "bu uygulama önemli bir iş yapıyor" diyen bir bildirim (ön plan
// servisi) açar. Böylece ekran kapansa bile tarama sürer ve telefon uykuya
// dalmaz. Ekranı kapatmak şarjı çok daha az harcar.
// ---------------------------------------------------------------------------

void arkaPlanHazirla() {
  try {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'tarama',
        channelName: 'Tarama',
        channelDescription: 'Tarama sürerken görünen bildirim',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  } catch (_) {}
}

int _arkaPlanSayac = 0;

Future<void> arkaPlanBaslat() async {
  _arkaPlanSayac++;
  try {
    await FlutterForegroundTask.requestNotificationPermission();
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
    if (await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.startService(
      serviceId: 777,
      notificationTitle: 'Başlık Tarayıcı',
      notificationText: 'Tarama sürüyor...',
    );
  } catch (_) {}
}

Future<void> arkaPlanYaz(String metin) async {
  try {
    await FlutterForegroundTask.updateService(notificationText: metin);
  } catch (_) {}
}

/// Kayıt klasörü: izin verilirse Download/ForumTarayici, verilmezse
/// uygulamanın kendi klasörü. (Forum ve HuggingFace taramaları paylaşır.)
Future<Directory> kayitKoku() async {
  if (Platform.isAndroid) {
    var st = await Permission.manageExternalStorage.status;
    if (!st.isGranted) st = await Permission.manageExternalStorage.request();
    if (st.isGranted) {
      final d = Directory('/storage/emulated/0/Download/ForumTarayici');
      try {
        await d.create(recursive: true);
        return d;
      } catch (_) {}
    }
    final ext = await getExternalStorageDirectory();
    if (ext != null) return ext;
  }
  return getApplicationDocumentsDirectory();
}

Future<void> arkaPlanDurdur() async {
  _arkaPlanSayac--;
  if (_arkaPlanSayac > 0) return; // başka bir tarama hâlâ sürüyor
  _arkaPlanSayac = 0;
  try {
    await FlutterForegroundTask.stopService();
  } catch (_) {}
}

// ---------------------------------------------------------------------------
// 1) YARDIMCI FONKSİYONLAR
// ---------------------------------------------------------------------------

/// Metni karşılaştırmaya hazırlar: küçük harfe çevirir, Türkçe harfleri
/// sadeleştirir (ı, İ, ş, ğ, ü, ö, ç -> i, i, s, g, u, o, c).
/// Böylece "Işık" ile "isik" ya da "GAS" ile "gas" aynı sayılır.
String katla(String s) {
  const harita = {
    'ı': 'i', 'İ': 'i', 'I': 'i', 'ş': 's', 'Ş': 's', 'ğ': 'g', 'Ğ': 'g',
    'ü': 'u', 'Ü': 'u', 'ö': 'o', 'Ö': 'o', 'ç': 'c', 'Ç': 'c',
  };
  final sb = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    sb.write(harita[ch] ?? ch);
  }
  return sb.toString().toLowerCase();
}

bool _harfMi(int c) =>
    (c >= 48 && c <= 57) || (c >= 97 && c <= 122) || c > 127;

/// [metin] içinde [kelime] geçiyor mu? (ikisi de "katla" ile hazırlanmış olmalı)
/// kelimeBasinda = true ise kelime, bir sözcüğün başında geçmeli.
bool esles(String metin, String kelime, bool kelimeBasinda) {
  var i = 0;
  while (true) {
    i = metin.indexOf(kelime, i);
    if (i < 0) return false;
    if (!kelimeBasinda) return true;
    if (i == 0 || !_harfMi(metin.codeUnitAt(i - 1))) return true;
    i++;
  }
}

String _temiz(String s) {
  var t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.length > 300) t = '${t.substring(0, 300)}...';
  return t;
}

List<String> _liste(String s) => s
    .split(RegExp(r'[,\n]'))
    .map((e) => e.trim().toLowerCase())
    .where((e) => e.isNotEmpty)
    .toList();

String _kok(String host) => host.startsWith('www.') ? host.substring(4) : host;

// ---------------------------------------------------------------------------
// 2) AYARLAR VE BULGU
// ---------------------------------------------------------------------------

class Ayarlar {
  String url = '';
  String kelimeler = '';
  bool kelimeBasinda = false;
  int maxSayfa = 300; // bu çalıştırmada en fazla kaç sayfa
  int maxMb = 50; // bu çalıştırmada en fazla kaç MB indirme
  int maxDakika = 30; // bu çalıştırmada en fazla kaç dakika
  int beklemeMs = 1000; // iki istek arası bekleme (milisaniye)
  int maxDerinlik = 20; // başlangıçtan en fazla kaç tık uzağa gidilsin
  int kaydetMb = 10; // her kaç MB indirmede bir ara kayıt
  String sadeceGez = ''; // boşsa her adres; doluysa sadece bunları içerenler
  String atla = ''; // bunları içeren adresler gezilmez
  bool robots = true; // sitenin robots.txt kurallarına uy
  bool icerikAl = true; // eşleşen başlığın içini (konu metnini) de kaydet
  int icerikMaxKarakter = 20000; // bir sayfadan en fazla kaç karakter
  int icerikKonuSayfa = 3; // bir konunun en fazla kaç sayfası alınsın
}

class Bulgu {
  Bulgu(this.tur, this.metin, this.adres, this.kaynak, this.kelime,
      {this.govde});
  final String tur;
  final String metin;
  final String adres;
  final String kaynak;
  final String kelime;
  final String? govde; // sayfanın içindeki yazı (sadece İÇERİK kayıtlarında)
}

class Gorev {
  Gorev(this.url, this.derinlik,
      {this.icerik = false,
      this.konuSayfa = 1,
      this.baslik = '',
      this.kelime = ''});
  final String url;
  final int derinlik;
  final bool icerik; // true: bu sayfanın yazısı kaydedilecek
  final int konuSayfa; // konunun kaçıncı sayfası
  final String baslik; // eşleşen başlık
  final String kelime; // eşleşen kelime
}

// ---------------------------------------------------------------------------
// 3) TARAYICI
// ---------------------------------------------------------------------------

class Tarayici {
  Tarayici(this.a, this.klasor, this.onGuncelle);

  final Ayarlar a;
  final Directory klasor;
  final void Function() onGuncelle;

  // Gezme durumu (devam etmek için diske yazılır)
  final ListQueue<Gorev> kuyruk = ListQueue<Gorev>();
  final Set<String> ziyaret = <String>{};
  final Set<String> gorulen = <String>{}; // ziyaret edilen + kuyrukta bekleyen
  final Set<String> bulunanAnahtar = <String>{};
  String baslangicUrl = '';
  int parca = 0; // toplam yazılan dosya sayısı
  final Map<String, int> kelimeParca = <String, int>{}; // kelime -> son dosya no
  int sayfa = 0;
  int bayt = 0;
  int bulunan = 0;
  int icerikSayisi = 0;
  int robotsEngel = 0; // robots.txt yüzünden alınmayan içerik sayfası sayısı
  final Set<String> icerikAlinan = <String>{};

  // Sadece ekranda gösterilenler
  final List<Bulgu> bekleyen = <Bulgu>[];
  final List<String> sonBulgular = <String>[];
  final List<String> log = <String>[];
  bool calisiyor = false;
  String durum = 'Hazır';

  bool _dur = false;
  int _kayitBayt = 0;
  int _kayitSayfa = 0;
  String _kokHost = '';
  int _robotsGecikmeMs = 0;
  List<String> _kelimeler = [];
  List<String> _orijinal = [];
  List<String> _sadece = [];
  List<String> _atla = [];
  final List<RegExp> _yasak = [];
  final http.Client _istemci = http.Client();

  static const Map<String, String> _bas = {
    'User-Agent': 'Mozilla/5.0 (Linux; Android 13) BaslikTarayici/1.0',
    'Accept': 'text/html,application/xhtml+xml',
    'Accept-Language': 'tr,en;q=0.8',
  };
  static const Set<String> _atlaEtiket = {
    'script', 'style', 'noscript', 'select', 'button', 'iframe', 'svg', 'head'
  };
  // Temiz içerik modunda ayrıca atlananlar (menü, alt bilgi, yan panel)
  static const Set<String> _atlaEtiketTemiz = {'nav', 'footer', 'aside'};
  static const Set<String> _atlaKimlik = {
    'footer', 'sidebar', 'mw-navigation', 'mw-head', 'mw-panel',
    'mw-page-base', 'mw-head-base', 'sitenotice', 'jump-to-nav', 'catlinks',
    'toc', 'printfooter'
  };
  static const Set<String> _atlaSinif = {
    'nav', 'navbar', 'navigation', 'menu', 'sidebar', 'breadcrumb',
    'breadcrumbs', 'footer', 'cookie', 'toolbar', 'printfooter', 'toc',
    'toctitle', 'mw-editsection', 'catlinks'
  };
  static const Set<String> _blokEtiket = {
    'p', 'div', 'tr', 'li', 'ul', 'ol', 'table', 'tbody', 'blockquote', 'pre',
    'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'section', 'article', 'hr', 'dd',
    'dt', 'dl', 'form', 'center'
  };
  static final RegExp _uzanti = RegExp(
      r'\.(jpe?g|png|gif|webp|svg|ico|pdf|zip|rar|7z|gz|mp3|mp4|avi|mkv|css|js|exe|apk|docx?|xlsx?|pptx?|odt|rtf|djvu?|epub|mobi|azw3?|fb2|tar|tgz|bz2|xz|iso|torrent|dmg|msi|bin|deb|rpm)$',
      caseSensitive: false);

  /// Kelimeyi dosya adına çevirir (özel karakterler ve boşluklar "_" olur).
  String _dosyaAdi(String k) {
    var s = k.trim().replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
    if (s.length > 40) s = s.substring(0, 40);
    return s.isEmpty ? 'kelime' : s;
  }

  void _log(String s) {
    final n = DateTime.now();
    String i(int x) => x.toString().padLeft(2, '0');
    log.insert(0, '${i(n.hour)}:${i(n.minute)}:${i(n.second)}  $s');
    if (log.length > 60) log.removeLast();
  }

  void durdur() {
    _dur = true;
    durum = 'Durduruluyor, kaydediliyor...';
    onGuncelle();
  }

  /// Yeni tarama: ilk adresi kuyruğa koyar.
  void baslat(String url) {
    baslangicUrl = url;
    gorulen.add(url);
    kuyruk.add(Gorev(url, 0));
  }

  // --- Diske kaydetme ve geri yükleme ------------------------------------

  Future<void> _kaydet() async {
    try {
      if (bekleyen.isNotEmpty) {
        // Sonuçları aranan kelimeye göre ayır: klor_1.txt, titan_1.txt ...
        final gruplar = <String, List<Bulgu>>{};
        final gorunen = <String, String>{};
        for (final b in bekleyen) {
          for (final k in b.kelime.split(', ')) {
            if (k.trim().isEmpty) continue;
            final ad = _dosyaAdi(k);
            gorunen.putIfAbsent(ad, () => k.trim());
            gruplar.putIfAbsent(ad, () => <Bulgu>[]).add(b);
          }
        }
        final yeniSayac = Map<String, int>.from(kelimeParca);
        for (final e in gruplar.entries) {
          final no = (yeniSayac[e.key] ?? 0) + 1;
          final dosya = '${e.key}_$no.txt';
          final sb = StringBuffer();
          sb.writeln('# Kelime: ${gorunen[e.key]}');
          sb.writeln('# Site: $baslangicUrl');
          sb.writeln('# Parça: $no   Tarih: ${DateTime.now()}');
          sb.writeln();
          for (final b in e.value) {
            sb.writeln('[${b.tur}] ${b.metin}');
            sb.writeln('  adres: ${b.adres}');
            if (b.kaynak != b.adres) sb.writeln('  bulunduğu sayfa: ${b.kaynak}');
            if (b.govde != null) {
              sb.writeln('  ---- içerik ----');
              sb.writeln(b.govde);
              sb.writeln('  ---- içerik sonu ----');
            }
            sb.writeln();
          }
          await File('${klasor.path}/$dosya')
              .writeAsString(sb.toString(), flush: true);
          yeniSayac[e.key] = no;
          parca++;
          _log('Kaydedildi: $dosya (${e.value.length} sonuç)');
        }
        kelimeParca
          ..clear()
          ..addAll(yeniSayac);
        bekleyen.clear();
      }
      final gecici = File('${klasor.path}/durum.json.tmp');
      await gecici.writeAsString(
          jsonEncode({
            'url': baslangicUrl,
            'parca': parca,
            'kelimeParca': kelimeParca,
            'sayfa': sayfa,
            'bayt': bayt,
            'bulunan': bulunan,
            'icerikSayisi': icerikSayisi,
            'icerikAlinan': icerikAlinan.toList(),
            'kuyruk': kuyruk
                .map((g) => [
                      g.url,
                      g.derinlik,
                      g.icerik ? 1 : 0,
                      g.konuSayfa,
                      g.baslik,
                      g.kelime
                    ])
                .toList(),
            'ziyaret': ziyaret.toList(),
            'bulunanAnahtar': bulunanAnahtar.toList(),
          }),
          flush: true);
      await gecici.rename('${klasor.path}/durum.json');
      _kayitBayt = bayt;
      _kayitSayfa = sayfa;
    } catch (e) {
      _log('Kaydetme hatası: $e');
    }
  }

  /// Önceki taramanın durumunu okur. Dosya yoksa false döner.
  Future<bool> yukle() async {
    try {
      final f = File('${klasor.path}/durum.json');
      if (!await f.exists()) return false;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      baslangicUrl = (j['url'] as String?) ?? a.url;
      parca = (j['parca'] as num?)?.toInt() ?? 0;
      kelimeParca.clear();
      ((j['kelimeParca'] as Map?) ?? const {}).forEach((k, v) {
        kelimeParca[k as String] = (v as num).toInt();
      });
      sayfa = (j['sayfa'] as num?)?.toInt() ?? 0;
      bayt = (j['bayt'] as num?)?.toInt() ?? 0;
      bulunan = (j['bulunan'] as num?)?.toInt() ?? 0;
      icerikSayisi = (j['icerikSayisi'] as num?)?.toInt() ?? 0;
      icerikAlinan
        ..clear()
        ..addAll(((j['icerikAlinan'] as List?) ?? const []).cast<String>());
      kuyruk.clear();
      for (final e in (j['kuyruk'] as List)) {
        final l = e as List;
        kuyruk.add(Gorev(l[0] as String, (l[1] as num).toInt(),
            icerik: l.length > 2 && (l[2] as num) == 1,
            konuSayfa: l.length > 3 ? (l[3] as num).toInt() : 1,
            baslik: l.length > 4 ? (l[4] as String) : '',
            kelime: l.length > 5 ? (l[5] as String) : ''));
      }
      ziyaret
        ..clear()
        ..addAll((j['ziyaret'] as List).cast<String>());
      bulunanAnahtar
        ..clear()
        ..addAll((j['bulunanAnahtar'] as List).cast<String>());
      gorulen
        ..clear()
        ..addAll(ziyaret)
        ..addAll(kuyruk.where((g) => !g.icerik).map((g) => g.url));
      _kayitBayt = bayt;
      _kayitSayfa = sayfa;
      _log('Önceki durum yüklendi: $sayfa sayfa, ${kuyruk.length} sırada');
      return true;
    } catch (e) {
      _log('Durum okunamadı: $e');
      return false;
    }
  }

  // --- robots.txt ---------------------------------------------------------

  RegExp _kuralRegex(String k) {
    var s = RegExp.escape(k).replaceAll(r'\*', '.*');
    if (s.endsWith(r'\$')) s = '${s.substring(0, s.length - 2)}\$';
    return RegExp('^$s');
  }

  Future<void> _robotsOku(Uri u) async {
    _yasak.clear();
    _robotsGecikmeMs = 0;
    if (!a.robots) return;
    try {
      final r = await _istemci
          .get(Uri.parse('${u.scheme}://${u.host}/robots.txt'), headers: _bas)
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return;
      var bizim = false;
      final metin = utf8.decode(r.bodyBytes, allowMalformed: true);
      for (final ham in const LineSplitter().convert(metin)) {
        final satir = ham.split('#').first.trim();
        final i = satir.indexOf(':');
        if (i < 0) continue;
        final k = satir.substring(0, i).trim().toLowerCase();
        final v = satir.substring(i + 1).trim();
        if (k == 'user-agent') {
          bizim = v == '*';
        } else if (bizim && k == 'disallow' && v.isNotEmpty) {
          _yasak.add(_kuralRegex(v));
        } else if (bizim && k == 'crawl-delay') {
          final s = double.tryParse(v);
          if (s != null) _robotsGecikmeMs = (s * 1000).round();
        }
      }
      _log('robots.txt okundu: ${_yasak.length} yasak kural');
    } catch (_) {
      _log('robots.txt okunamadı, kuralsız devam');
    }
  }

  // --- Ana döngü ------------------------------------------------------------

  void _hazirla() {
    _orijinal = a.kelimeler
        .split(RegExp(r'[,\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    _kelimeler = _orijinal.map(katla).toList();
    _sadece = _liste(a.sadeceGez);
    _atla = _liste(a.atla);
    _kokHost = _kok(Uri.parse(baslangicUrl).host);
  }

  Future<void> calis() async {
    if (calisiyor) return;
    calisiyor = true;
    _dur = false;
    _hazirla();
    durum = 'Çalışıyor';
    onGuncelle();

    final s0 = sayfa;
    final b0 = bayt;
    final sw = Stopwatch()..start();
    String? neden;
    try {
      await _robotsOku(Uri.parse(baslangicUrl));
      while (kuyruk.isNotEmpty) {
        if (_dur) {
          neden = 'Durduruldu. Her şey kaydedildi.';
          break;
        }
        if (sayfa - s0 >= a.maxSayfa) {
          neden = 'Sayfa sınırına ulaşıldı (${a.maxSayfa}).';
          break;
        }
        if (bayt - b0 >= a.maxMb * 1048576) {
          neden = 'İndirme sınırına ulaşıldı (${a.maxMb} MB).';
          break;
        }
        if (sw.elapsed.inMinutes >= a.maxDakika) {
          neden = 'Süre sınırına ulaşıldı (${a.maxDakika} dk).';
          break;
        }

        final g = kuyruk.removeFirst();
        if (!g.icerik) {
          // Zaten ziyaret edilmiş ya da içeriği ayrıca alınmışsa atla
          if (ziyaret.contains(g.url) || icerikAlinan.contains(g.url)) continue;
          ziyaret.add(g.url);
        }
        durum = g.icerik
            ? 'İçerik okunuyor: ${g.url}'
            : 'Okunuyor: ${g.url}';
        onGuncelle();

        final tamam = await _isle(g);
        if (!tamam) {
          // Bağlantı sorunu: sayfayı sıraya geri koy, kaydet, dur.
          kuyruk.addFirst(g);
          if (!g.icerik) ziyaret.remove(g.url);
          neden = _dur
              ? 'Durduruldu. Her şey kaydedildi.'
              : 'Bağlantı koptu. Kaydedildi; internet gelince "Devam et"e bas.';
          break;
        }

        if (bayt - _kayitBayt >= a.kaydetMb * 1048576 ||
            sayfa - _kayitSayfa >= 50) {
          await _kaydet();
        }
        onGuncelle();
        if (sayfa % 20 == 0) {
          await arkaPlanYaz('$sayfa sayfa okundu, $bulunan başlık bulundu');
        }
        final bekle =
            _robotsGecikmeMs > a.beklemeMs ? _robotsGecikmeMs : a.beklemeMs;
        await Future.delayed(Duration(milliseconds: bekle));
      }
      neden ??= kuyruk.isEmpty
          ? 'Bitti: gezilecek başka sayfa kalmadı.'
          : 'Durdu.';
      if (robotsEngel > 0) {
        neden =
            '$neden Sitenin robots.txt dosyası $robotsEngel içerik sayfasına izin vermedi.';
      }
    } catch (e) {
      neden = 'Beklenmeyen hata: $e (kaydedildi)';
      _log(neden);
    } finally {
      await _kaydet();
      durum = neden ?? 'Durdu';
      calisiyor = false;
      onGuncelle();
    }
  }

  /// Sayfayı indirir. Sayfa HTML değilse (djvu, pdf, zip, resim...) gövdesini
  /// hiç indirmez, sadece başlığına bakıp bırakır.
  Future<http.Response> _getir(Uri u) async {
    final istek = http.Request('GET', u)..headers.addAll(_bas);
    final sr = await _istemci.send(istek).timeout(const Duration(seconds: 25));
    final ct = (sr.headers['content-type'] ?? '').toLowerCase();
    final basliklar = Map<String, String>.from(sr.headers);
    if (ct.isNotEmpty && !ct.contains('html')) {
      await sr.stream.listen((_) {}).cancel();
      _log('Dosya atlandı, indirilmedi (${ct.split(';').first}): $u');
      return http.Response('', sr.statusCode, headers: basliklar);
    }
    final baytlar = <int>[];
    var kesildi = false;
    await for (final parca in sr.stream.timeout(const Duration(seconds: 25))) {
      baytlar.addAll(parca);
      if (baytlar.length > 4 * 1048576) {
        kesildi = true;
        break;
      }
    }
    if (kesildi) basliklar['x-kesildi'] = '1';
    return http.Response.bytes(baytlar, sr.statusCode, headers: basliklar);
  }

  /// Bir sayfayı indirir ve tarar.
  /// true  -> devam edilebilir (sayfa okundu ya da atlanıp geçildi)
  /// false -> bağlantı sorunu, durmak gerekiyor
  Future<bool> _isle(Gorev g) async {
    http.Response? r;
    for (var deneme = 1; deneme <= 3; deneme++) {
      if (_dur) return false;
      try {
        r = await _getir(Uri.parse(g.url));
        if (r.statusCode == 429 || r.statusCode == 503) {
          var bekle = int.tryParse(r.headers['retry-after'] ?? '') ?? 30;
          if (bekle < 5) bekle = 5;
          if (bekle > 120) bekle = 120;
          _log('Site yavaşlamak istedi, $bekle sn bekleniyor');
          durum = 'Site yavaşlamak istedi, $bekle sn bekleniyor';
          onGuncelle();
          r = null;
          await Future.delayed(Duration(seconds: bekle));
          continue;
        }
        break;
      } catch (e) {
        r = null;
        _log('Hata ($deneme/3): ${g.url}');
        await Future.delayed(Duration(seconds: 2 * deneme));
      }
    }
    if (r == null) return false;

    sayfa++;
    bayt += r.bodyBytes.length;
    final ct = (r.headers['content-type'] ?? '').toLowerCase();
    if (r.statusCode != 200) {
      _log('HTTP ${r.statusCode}: ${g.url}');
      return true;
    }
    if (ct.isNotEmpty && !ct.contains('html')) return true;
    if (r.headers['x-kesildi'] == '1') {
      _log('Çok büyük sayfa atlandı: ${g.url}');
      return true;
    }
    final govde = ct.contains('charset')
        ? r.body
        : utf8.decode(r.bodyBytes, allowMalformed: true);
    try {
      _tara(g, govde);
    } catch (e) {
      _log('Okunamadı: ${g.url}');
    }
    return true;
  }

  // --- Sayfa içinden başlık ve bağlantı toplama -----------------------------

  Uri? _coz(Uri taban, String href) {
    try {
      return taban.resolve(href.trim());
    } catch (_) {
      return null;
    }
  }

  /// Sayfa numarası (page) dışındaki her şey aynıysa iki adres aynı konudur.
  String _sayfasiz(Uri u) {
    final q = Map<String, String>.from(u.queryParameters)..remove('page');
    final anahtarlar = q.keys.toList()..sort();
    return '${_kok(u.host)}${u.path}?${anahtarlar.map((k) => '$k=${q[k]}').join('&')}';
  }

  void _metinTopla(dom.Node n, StringBuffer sb, bool filtre) {
    if (n is dom.Text) {
      sb.write(n.data);
      return;
    }
    if (n is! dom.Element) return;
    final ad = n.localName ?? '';
    if (_atlaEtiket.contains(ad)) return;
    if (filtre) {
      if (_atlaEtiketTemiz.contains(ad)) return;
      final kimlik = (n.attributes['id'] ?? '').toLowerCase();
      if (kimlik.isNotEmpty && _atlaKimlik.contains(kimlik)) return;
      final sinif = (n.attributes['class'] ?? '').toLowerCase();
      if (sinif.isNotEmpty) {
        for (final c in sinif.split(RegExp(r'\s+'))) {
          if (_atlaSinif.contains(c)) return;
        }
      }
    }
    if (ad == 'br') {
      sb.write('\n');
      return;
    }
    final blok = _blokEtiket.contains(ad);
    if (blok) sb.write('\n');
    for (final c in n.nodes) {
      _metinTopla(c, sb, filtre);
    }
    if (blok) {
      sb.write('\n');
    } else if (ad == 'td' || ad == 'th') {
      sb.write('  ');
    }
  }

  /// Sayfanın ana yazı bölümünü bulur (wiki, makale, forum gövdesi).
  /// Bulamazsa tüm gövdeyi döndürür.
  dom.Element? _anaKap(dom.Document doc) {
    for (final sec in const [
      '#mw-content-text',
      'article',
      'main',
      '[role=main]',
      '#main-content',
      '#bodyContent',
      '#content'
    ]) {
      // Çok sayıda <article> varsa (her mesaj ayrı article) birini seçme.
      if (sec == 'article' && doc.querySelectorAll('article').length != 1) {
        continue;
      }
      final e = doc.querySelector(sec);
      if (e != null && e.text.trim().length >= 200) return e;
    }
    return doc.body;
  }

  String _metinSatirlari(dom.Element kok, bool filtre) {
    final sb = StringBuffer();
    _metinTopla(kok, sb, filtre);
    final satirlar = <String>[];
    for (final ham in sb.toString().split('\n')) {
      final t = ham.replaceAll(RegExp(r'[ \t\u00a0]+'), ' ').trim();
      if (t.isEmpty) continue;
      if (satirlar.isNotEmpty && satirlar.last == t) continue; // ardışık tekrar
      satirlar.add(t);
    }
    return satirlar.join('\n');
  }

  /// Sayfanın içindeki okunur yazıyı çıkarır. Menü, alt bilgi, yan panel gibi
  /// bölümleri atar. Temiz sonuç çok kısa kalırsa filtresiz yedek sürümü kullanır.
  String _sayfaMetni(dom.Document doc) {
    final b = doc.body;
    if (b == null) return '';
    var t = _metinSatirlari(_anaKap(doc) ?? b, true);
    if (t.length < 200) {
      final ham = _metinSatirlari(b, false);
      if (ham.length > t.length) t = ham;
    }
    if (t.length > a.icerikMaxKarakter) {
      t = '${t.substring(0, a.icerikMaxKarakter)}\n... (kısaltıldı)';
    }
    return t;
  }

  /// Eşleşen bir başlığın hedef sayfasını "içeriği alınacaklar" listesinin
  /// en başına koyar.
  void _icerikIste(Uri u, String baslik, String kelime, String kaynakUrl) {
    if (_kok(u.host) != _kokHost) return;
    if (_uzanti.hasMatch(u.path)) return;
    final adres = u.toString();
    if (adres == kaynakUrl || icerikAlinan.contains(adres)) return;
    final yol =
        (u.path.isEmpty ? '/' : u.path) + (u.hasQuery ? '?${u.query}' : '');
    if (_yasak.any((r) => r.hasMatch(yol))) {
      robotsEngel++;
      if (robotsEngel <= 3) {
        _log('İçerik alınmadı, sitenin robots.txt dosyası izin vermiyor: $adres');
      }
      return;
    }
    icerikAlinan.add(adres);
    kuyruk.addFirst(Gorev(adres, 0,
        icerik: true, konuSayfa: 1, baslik: baslik, kelime: kelime));
  }

  void _tara(Gorev g, String govde) {
    final doc = html_parser.parse(govde);
    final sayfaUrl = g.url;
    final taban = Uri.parse(sayfaUrl);

    final baslik = _temiz(doc.querySelector('title')?.text ?? '');
    if (!g.icerik && baslik.isNotEmpty) {
      _kontrol('SAYFA BAŞLIĞI', baslik, sayfaUrl, sayfaUrl);
    }

    for (final h in doc.querySelectorAll('h1, h2, h3, h4, h5, h6')) {
      final t = _temiz(h.text);
      if (t.isNotEmpty) {
        _kontrol((h.localName ?? 'h').toUpperCase(), t, sayfaUrl, sayfaUrl);
      }
    }

    final suan = int.tryParse(taban.queryParameters['page'] ?? '') ?? 1;
    final sayfasiz = _sayfasiz(taban);
    Uri? sonraki;

    for (final el in doc.querySelectorAll('a[href]')) {
      final href = el.attributes['href'];
      if (href == null || href.trim().isEmpty) continue;
      final hedef = _coz(taban, href);
      if (hedef == null) continue;
      if (hedef.scheme != 'http' && hedef.scheme != 'https') continue;
      final temiz = hedef.removeFragment();

      if (g.icerik) {
        // İçerik sayfasında sadece konunun bir sonraki sayfasını ara.
        if (sonraki == null &&
            g.konuSayfa < a.icerikKonuSayfa &&
            temiz.queryParameters['page'] == '${suan + 1}' &&
            _sayfasiz(temiz) == sayfasiz) {
          sonraki = temiz;
        }
        continue;
      }

      final adres = temiz.toString();
      var t = _temiz(el.text);
      if (t.isEmpty) t = _temiz(el.attributes['title'] ?? '');
      if (t.isNotEmpty) {
        final esl = _kontrol('BAĞLANTI', t, adres, sayfaUrl);
        if (esl != null && a.icerikAl) _icerikIste(temiz, t, esl, sayfaUrl);
      }

      if (g.derinlik < a.maxDerinlik && _gezilsin(temiz)) {
        gorulen.add(adres);
        kuyruk.add(Gorev(adres, g.derinlik + 1));
      }
    }

    if (g.icerik) {
      final metin = _sayfaMetni(doc);
      if (metin.isNotEmpty) {
        final ad = g.baslik.isNotEmpty ? g.baslik : baslik;
        final etiket = g.konuSayfa > 1 ? '$ad (sayfa ${g.konuSayfa})' : ad;
        bekleyen.add(
            Bulgu('İÇERİK', etiket, sayfaUrl, sayfaUrl, g.kelime, govde: metin));
        icerikSayisi++;
        sonBulgular.insert(0, '[İÇERİK] $etiket');
        if (sonBulgular.length > 40) sonBulgular.removeLast();
      }
      if (sonraki != null) {
        final s = sonraki.toString();
        if (icerikAlinan.add(s)) {
          kuyruk.addFirst(Gorev(s, 0,
              icerik: true,
              konuSayfa: g.konuSayfa + 1,
              baslik: g.baslik,
              kelime: g.kelime));
        }
      }
    }
  }

  bool _gezilsin(Uri u) {
    if (_kok(u.host) != _kokHost) return false; // başka siteye çıkma
    final adres = u.toString();
    if (gorulen.contains(adres)) return false;
    if (_uzanti.hasMatch(u.path)) return false;
    final k = adres.toLowerCase();
    for (final s in _atla) {
      if (k.contains(s)) return false;
    }
    if (_sadece.isNotEmpty && !_sadece.any((s) => k.contains(s))) return false;
    final yol = (u.path.isEmpty ? '/' : u.path) +
        (u.hasQuery ? '?${u.query}' : '');
    if (_yasak.any((r) => r.hasMatch(yol))) return false;
    return true;
  }

  /// Metinde aranan kelime varsa eşleşen kelimeleri döndürür (yoksa null).
  /// Yeni bir sonuçsa listeye de ekler.
  String? _kontrol(String tur, String metin, String adres, String kaynak) {
    final kat = katla(metin);
    final bulunanlar = <String>[];
    for (var i = 0; i < _kelimeler.length; i++) {
      if (esles(kat, _kelimeler[i], a.kelimeBasinda)) {
        bulunanlar.add(_orijinal[i]);
      }
    }
    if (bulunanlar.isEmpty) return null;
    final kelime = bulunanlar.join(', ');
    if (!bulunanAnahtar.add('$kat|$adres')) return kelime; // daha önce bulundu
    bekleyen.add(Bulgu(tur, metin, adres, kaynak, kelime));
    bulunan++;
    sonBulgular.insert(0, '[$tur] $metin');
    if (sonBulgular.length > 40) sonBulgular.removeLast();
    return kelime;
  }
}

// ---------------------------------------------------------------------------
// 4) ARAYÜZ
// ---------------------------------------------------------------------------

class UygulamaKok extends StatelessWidget {
  const UygulamaKok({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Başlık Tarayıcı',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B4D4A)),
        scaffoldBackgroundColor: const Color(0xFFF2F5F4),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      home: const AnaSayfa(),
    );
  }
}

class AnaSayfa extends StatefulWidget {
  const AnaSayfa({super.key});

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  static const Map<String, String> _varsayilan = {
    'url': '',
    'kelimeler': '',
    'maxSayfa': '300',
    'maxMb': '50',
    'maxDakika': '30',
    'beklemeMs': '1000',
    'maxDerinlik': '20',
    'kaydetMb': '10',
    'icerikMax': '20000',
    'konuSayfa': '3',
    'sadeceGez': '',
    'atla':
        'login,register,logout,member.php,search.php,today.php,u2u,printable,rss',
  };

  final Map<String, TextEditingController> _c = {};
  bool _basinda = false;
  bool _robots = true;
  bool _icerikAl = true;
  Tarayici? _t;
  String? _sonKlasor;
  bool _devamVar = false;

  @override
  void initState() {
    super.initState();
    _varsayilan.forEach((k, v) => _c[k] = TextEditingController(text: v));
    _yukle();
    arkaPlanHazirla();
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _yukle() async {
    final p = await SharedPreferences.getInstance();
    for (final k in _varsayilan.keys) {
      final v = p.getString(k);
      if (v != null) _c[k]!.text = v;
    }
    _basinda = p.getBool('kelimeBasinda') ?? false;
    _robots = p.getBool('robots') ?? true;
    _icerikAl = p.getBool('icerikAl') ?? true;
    _sonKlasor = p.getString('sonKlasor');
    await _devamKontrol();
    if (mounted) setState(() {});
  }

  Future<void> _ayarKaydet() async {
    final p = await SharedPreferences.getInstance();
    for (final e in _c.entries) {
      await p.setString(e.key, e.value.text);
    }
    await p.setBool('kelimeBasinda', _basinda);
    await p.setBool('robots', _robots);
    await p.setBool('icerikAl', _icerikAl);
  }

  Future<void> _devamKontrol() async {
    final yol = _sonKlasor;
    _devamVar = yol != null && await File('$yol/durum.json').exists();
    if (mounted) setState(() {});
  }

  void _yenile() {
    if (mounted) setState(() {});
  }

  void _mesaj(String s) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s)));
  }

  Ayarlar _ayarOku() {
    int n(String k, int d, int min) {
      final v = int.tryParse(_c[k]!.text.trim()) ?? d;
      return v < min ? min : v;
    }

    return Ayarlar()
      ..url = _c['url']!.text.trim()
      ..kelimeler = _c['kelimeler']!.text.trim()
      ..kelimeBasinda = _basinda
      ..maxSayfa = n('maxSayfa', 300, 1)
      ..maxMb = n('maxMb', 50, 1)
      ..maxDakika = n('maxDakika', 30, 1)
      ..beklemeMs = n('beklemeMs', 1000, 300)
      ..maxDerinlik = n('maxDerinlik', 20, 0)
      ..kaydetMb = n('kaydetMb', 10, 1)
      ..sadeceGez = _c['sadeceGez']!.text
      ..atla = _c['atla']!.text
      ..robots = _robots
      ..icerikAl = _icerikAl
      ..icerikMaxKarakter = n('icerikMax', 20000, 500)
      ..icerikKonuSayfa = n('konuSayfa', 3, 1);
  }

  /// Kayıt klasörü: izin verilirse Download/ForumTarayici, verilmezse
  /// uygulamanın kendi klasörü.
  Future<Directory> _kokKlasor() async {
    if (Platform.isAndroid) {
      var st = await Permission.manageExternalStorage.status;
      if (!st.isGranted) st = await Permission.manageExternalStorage.request();
      if (st.isGranted) {
        final d = Directory('/storage/emulated/0/Download/ForumTarayici');
        try {
          await d.create(recursive: true);
          return d;
        } catch (_) {}
      }
      final ext = await getExternalStorageDirectory();
      if (ext != null) return ext;
    }
    return getApplicationDocumentsDirectory();
  }

  String _damga() {
    final n = DateTime.now();
    String i(int x) => x.toString().padLeft(2, '0');
    return '${n.year}${i(n.month)}${i(n.day)}_${i(n.hour)}${i(n.minute)}${i(n.second)}';
  }

  Future<void> _baslat() async {
    var url = _c['url']!.text.trim();
    if (url.isEmpty) {
      _mesaj('Site adresini yaz.');
      return;
    }
    if (!url.startsWith('http')) url = 'https://$url';
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      _mesaj('Site adresi geçersiz görünüyor.');
      return;
    }
    if (_c['kelimeler']!.text.trim().isEmpty) {
      _mesaj('En az bir kelime yaz.');
      return;
    }
    _c['url']!.text = url;
    await _ayarKaydet();

    final kok = await _kokKlasor();
    final klasor = Directory('${kok.path}/${uri.host}_${_damga()}');
    await klasor.create(recursive: true);

    final t = Tarayici(_ayarOku(), klasor, _yenile);
    t.baslat(url);
    final p = await SharedPreferences.getInstance();
    await p.setString('sonKlasor', klasor.path);
    _sonKlasor = klasor.path;
    setState(() => _t = t);
    _calistir(t);
  }

  Future<void> _devam() async {
    final yol = _sonKlasor;
    if (yol == null) return;
    await _ayarKaydet();
    final t = Tarayici(_ayarOku(), Directory(yol), _yenile);
    final ok = await t.yukle();
    if (!ok) {
      _mesaj('Kayıtlı durum bulunamadı.');
      return;
    }
    setState(() => _t = t);
    _calistir(t);
  }

  Future<void> _calistir(Tarayici t) async {
    await arkaPlanBaslat();
    await t.calis();
    await arkaPlanDurdur();
    await _devamKontrol();
  }

  void _sciencemadnessDoldur() {
    setState(() {
      _c['url']!.text = 'https://www.sciencemadness.org/whisper/';
      _c['kelimeler']!.text = 'gas';
      _c['sadeceGez']!.text = 'forumdisplay.php,index.php';
      _c['atla']!.text =
          'orderby,ascdesc,member.php,misc.php,post.php,search.php,today.php,u2u,faq.php,stats.php,login,register,printable,goto=,action=';
      _c['maxDerinlik']!.text = '300';
      _c['maxSayfa']!.text = '300';
    });
  }

  // --- küçük arayüz parçaları ---

  Widget _baslik(String s) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(s,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
      );

  Widget _alan(String k, String etiket, {String? ipucu, int satir = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: _c[k],
          minLines: satir,
          maxLines: satir == 1 ? 1 : 6,
          decoration: InputDecoration(
              labelText: etiket, helperText: ipucu, helperMaxLines: 4),
        ),
      );

  Widget _sayi(String k, String etiket, String ipucu) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: _c[k],
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
              labelText: etiket, helperText: ipucu, helperMaxLines: 3),
        ),
      );

  Widget _sayac(String ad, String deger) => Padding(
        padding: const EdgeInsets.only(right: 20, bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(deger,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            Text(ad, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final calisiyor = t?.calisiyor ?? false;

    final iskele = Scaffold(
      appBar: AppBar(title: const Text('Başlık Tarayıcı')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const HfSayfa())),
                      icon: const Icon(Icons.cloud_download_outlined),
                      label: const Text('HuggingFace'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const FormatSayfa())),
                      icon: const Icon(Icons.science_outlined),
                      label: const Text('Format okuyucu'),
                    ),
                  ),
                ],
              ),
            ),
            _baslik('Ne aranacak?'),
            _alan('url', 'Site adresi',
                ipucu: 'Örnek: https://www.sciencemadness.org/whisper/'),
            _alan('kelimeler', 'Aranacak kelimeler',
                ipucu:
                    'Virgülle ayır. Kelime kökü yeter: "gas" yazarsan gases, gasoline de çıkar. Siteyle aynı dilde yaz.',
                satir: 2),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('İçinde geçsin')),
                ButtonSegment(value: true, label: Text('Kelime başında')),
              ],
              selected: {_basinda},
              onSelectionChanged: (s) => setState(() => _basinda = s.first),
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              title: const Text('Limitler ve hız'),
              initiallyExpanded: true,
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 8),
              children: [
                _sayi('maxSayfa', 'En fazla sayfa sayısı',
                    'İstek sayısı sınırı. Bu çalıştırmada bu kadar sayfa okununca durur.'),
                _sayi('maxMb', 'En fazla indirme (MB)',
                    'Toplam indirme bu değere gelince durur. Sonsuza kadar indirmez.'),
                _sayi('maxDakika', 'En fazla süre (dakika)', 'Süre dolunca durur.'),
                _sayi('beklemeMs', 'İstekler arası bekleme (ms)',
                    '1000 = 1 saniye. En az 300. Küçültürsen siteyi yorar, engellenebilirsin.'),
                _sayi('kaydetMb', 'Her kaç MB indirmede bir kaydet',
                    'Örnek 10: her 10 MB indirmede yeni bir sonuç dosyası yazılır ve durum kaydedilir.'),
                _sayi('maxDerinlik', 'En fazla derinlik',
                    'Başlangıç sayfasından kaç bağlantı uzağa gidilsin. Forum sayfa numaraları zincir gibi ilerler, büyük forumda yüksek tut.'),
              ],
            ),
            ExpansionTile(
              title: const Text('İçerik kaydetme'),
              initiallyExpanded: true,
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 8),
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Eşleşen başlığın içini de kaydet'),
                  subtitle: const Text(
                      'Bir başlıkta aranan kelime bulunursa o sayfa açılır ve içindeki yazı sonuç dosyasına eklenir.'),
                  value: _icerikAl,
                  onChanged: (v) => setState(() => _icerikAl = v),
                ),
                _sayi('icerikMax', 'Bir sayfadan en fazla karakter',
                    'Çok uzun konuların dosyayı şişirmemesi için. 20000 yaklaşık 10 yazılı sayfadır.'),
                _sayi('konuSayfa', 'Bir konunun en fazla kaç sayfası',
                    'Konu birden çok sayfaysa ilk bu kadarı alınır. (Sadece page=2 biçimindeki sayfalama bulunur.)'),
              ],
            ),
            ExpansionTile(
              title: const Text('Hangi adresler gezilsin?'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 8),
              children: [
                _alan('sadeceGez', 'Sadece şunları içeren adresleri gez',
                    ipucu:
                        'Virgülle ayır. Boş bırakırsan site içindeki her adres gezilir. Konu başlıkları liste sayfalarından zaten toplanır, konu içlerine girmek şart değil.',
                    satir: 2),
                _alan('atla', 'Şunları içeren adresleri atla',
                    ipucu: 'Virgülle ayır. Giriş, üye, arama gibi gereksiz sayfaları atlar.',
                    satir: 2),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Sitenin robots.txt kurallarına uy'),
                  subtitle: const Text(
                      'Site "buraya girme" dediği yerlere girilmez. Açık kalması önerilir.'),
                  value: _robots,
                  onChanged: (v) => setState(() => _robots = v),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: calisiyor ? null : _sciencemadnessDoldur,
                    icon: const Icon(Icons.science_outlined),
                    label: const Text('Sciencemadness örneğini doldur'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: calisiyor ? null : _baslat,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Yeni tarama'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (!calisiyor && _devamVar) ? _devam : null,
                    icon: const Icon(Icons.restore),
                    label: const Text('Devam et'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: calisiyor ? () => t?.durdur() : null,
              icon: const Icon(Icons.stop),
              label: const Text('Durdur ve kaydet'),
            ),
            if (t != null) ...[
              _baslik('Durum'),
              if (calisiyor) const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text(t.durum, maxLines: 3, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              Wrap(
                children: [
                  _sayac('Okunan sayfa', '${t.sayfa}'),
                  _sayac('Bulunan', '${t.bulunan}'),
                  _sayac('İndirilen (yaklaşık)',
                      '${(t.bayt / 1048576).toStringAsFixed(1)} MB'),
                  _sayac('Sırada', '${t.kuyruk.length}'),
                  _sayac('Alınan içerik', '${t.icerikSayisi}'),
                  if (t.robotsEngel > 0) _sayac('Robots engeli', '${t.robotsEngel}'),
                  _sayac('Yazılan dosya', '${t.parca}'),
                ],
              ),
              const SizedBox(height: 4),
              const Text('Kayıt klasörü (dosya yöneticisinde bul):',
                  style: TextStyle(fontSize: 12)),
              SelectableText(t.klasor.path,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              ExpansionTile(
                title: Text('Son bulunanlar (${t.sonBulgular.length})'),
                tilePadding: EdgeInsets.zero,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SelectableText(t.sonBulgular.join('\n\n')),
                  ),
                ],
              ),
              ExpansionTile(
                title: const Text('Kayıt defteri (hatalar, bilgiler)'),
                tilePadding: EdgeInsets.zero,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SelectableText(t.log.join('\n'),
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
    // Tarama sürerken geri tuşu uygulamayı kapatmaz, küçültür.
    return PopScope(
      canPop: !calisiyor,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) FlutterForegroundTask.minimizeApp();
      },
      child: iskele,
    );
  }
}
