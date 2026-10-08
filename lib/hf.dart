// Hugging Face veri seti okuyucu (Başlık Tarayıcı - sürüm 5)
//
// Hugging Face'in resmi "dataset viewer" arayüzünü kullanır:
//   /search : veri setinin içinde sunucuda kelime arar (hızlı, sadece eşleşenleri verir)
//   /rows   : satırları 100'erli dilimler halinde verir (biz telefonda süzeriz)
// Sonuçları kelime başına numaralı .txt dosyalarına yazar (klor_1.txt gibi).
// Kesinti olursa kaldığı yerden devam eder.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';

// ---------------------------------------------------------------------------
// MOTOR
// ---------------------------------------------------------------------------

class HfAyarlar {
  String dataset = '';
  String config = '';
  String split = '';
  String kelimeler = '';
  bool ara = true; // true: sunucuda ara, false: satır satır tara
  bool kelimeBasinda = false; // sadece "tara" yönteminde işe yarar
  int maxIstek = 300; // bu çalıştırmada en fazla kaç istek
  int maxMb = 50; // bu çalıştırmada en fazla kaç MB indirme
  int maxDakika = 30;
  int beklemeMs = 600; // istekler arası bekleme
  int kaydetMb = 10; // her kaç MB'da bir kaydet
}

class HfBulgu {
  HfBulgu(this.kelime, this.dataset, this.config, this.split, this.satirNo,
      this.alanlar);
  final String kelime;
  final String dataset;
  final String config;
  final String split;
  final int satirNo;
  final Map<String, String> alanlar;
}

String _hfDosyaAdi(String k) {
  var s = k.trim().replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
  if (s.length > 40) s = s.substring(0, 40);
  return s.isEmpty ? 'kelime' : s;
}

String _k(String s) => Uri.encodeQueryComponent(s);

class HfTarayici {
  HfTarayici(this.a, this.klasor, this.onGuncelle);

  /// Ekrandan çıkıp geri girilince çalışan taramayı yeniden bulmak için.
  static HfTarayici? aktif;

  final HfAyarlar a;
  final Directory klasor;
  void Function() onGuncelle;

  static const String _sunucu = 'https://datasets-server.huggingface.co';
  static const Map<String, String> _bas = {
    'User-Agent': 'BaslikTarayici/1.0',
    'Accept': 'application/json',
  };

  // Durum (devam etmek için diske yazılır)
  final List<List<String>> ciftler = []; // [config, split]
  int pi = 0; // hangi config/split çifti
  int ki = 0; // hangi kelime (sadece "ara" yönteminde)
  int offset = 0; // hangi satırdan devam
  int istek = 0;
  int satir = 0;
  int bulunan = 0;
  int bayt = 0;
  int parca = 0;
  final Map<String, int> kelimeParca = <String, int>{};

  // Sadece ekran için
  final List<HfBulgu> bekleyen = <HfBulgu>[];
  final List<String> sonBulgular = <String>[];
  final List<String> log = <String>[];
  bool calisiyor = false;
  String durum = 'Hazır';

  bool _dur = false;
  int _kayitBayt = 0;
  int _kayitIstek = 0;
  List<String> _orijinal = [];
  List<String> _katli = [];
  final http.Client _istemci = http.Client();

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

  // --- Bilgi al: lisans + bölümler ---------------------------------------

  /// Veri setinin lisansını ve bölümlerini (config / split) öğrenir.
  static Future<String> bilgiAl(String dataset) async {
    final id = dataset.trim();
    final sb = StringBuffer();
    if (id.isEmpty) return 'Önce veri seti adını yaz.';
    try {
      final r = await http
          .get(Uri.parse('https://huggingface.co/api/datasets/$id'),
              headers: _bas)
          .timeout(const Duration(seconds: 30));
      if (r.statusCode == 200) {
        final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
        String? lis;
        final kart = j['cardData'];
        if (kart is Map && kart['license'] != null) {
          lis = kart['license'].toString();
        }
        if (lis == null && j['tags'] is List) {
          for (final t in (j['tags'] as List)) {
            final s = t.toString();
            if (s.startsWith('license:')) lis = s.substring(8);
          }
        }
        sb.writeln('Lisans: ${lis ?? 'belirtilmemiş'}');
        sb.writeln(
            'Lisansı kullanmadan önce sen de kontrol et (veri setinin sayfasında yazar).');
      } else {
        sb.writeln(
            'Veri seti bulunamadı (HTTP ${r.statusCode}). Adı "kullanici/ad" biçiminde doğru yazdın mı?');
        return sb.toString();
      }
    } catch (_) {
      sb.writeln('Lisans bilgisi alınamadı (bağlantı sorunu).');
    }
    try {
      final r = await http
          .get(Uri.parse('$_sunucu/size?dataset=${_k(id)}'), headers: _bas)
          .timeout(const Duration(seconds: 40));
      if (r.statusCode == 200) {
        final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
        final size = j['size'];
        final bolumler = (size is Map ? size['splits'] : null) as List?;
        if (bolumler == null || bolumler.isEmpty) {
          sb.writeln('Bölüm bilgisi yok.');
        } else {
          sb.writeln('Bölümler (config / split : satır sayısı):');
          for (final e in bolumler) {
            final m = e as Map;
            sb.writeln('  ${m['config']} / ${m['split']} : ${m['num_rows']}');
          }
        }
      } else {
        sb.writeln(
            'Bu veri seti için görüntüleyici yok ya da hazırlanmamış (HTTP ${r.statusCode}). Uygulama bunu okuyamaz.');
      }
    } catch (_) {
      sb.writeln('Bölüm bilgisi alınamadı (bağlantı sorunu).');
    }
    return sb.toString();
  }

  // --- Ağ ---------------------------------------------------------------

  /// JSON döndürür. HTTP hatasında {'_hata': kod}, bağlantı sorununda null.
  Future<Map<String, dynamic>?> _getir(String url) async {
    for (var deneme = 1; deneme <= 3; deneme++) {
      if (_dur) return null;
      try {
        final r = await _istemci
            .get(Uri.parse(url), headers: _bas)
            .timeout(const Duration(seconds: 45));
        istek++;
        bayt += r.bodyBytes.length;
        final kod = r.statusCode;
        if (kod == 429 || kod == 502 || kod == 503 || kod == 504) {
          var bekle = int.tryParse(r.headers['retry-after'] ?? '') ?? 20;
          if (bekle < 5) bekle = 5;
          if (bekle > 120) bekle = 120;
          _log('Sunucu yavaşlamak istedi (HTTP $kod), $bekle sn bekleniyor');
          durum = 'Sunucu yavaşlamak istedi, $bekle sn bekleniyor';
          onGuncelle();
          await Future.delayed(Duration(seconds: bekle));
          continue;
        }
        if (kod != 200) {
          return <String, dynamic>{'_hata': kod};
        }
        return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      } catch (e) {
        _log('Hata ($deneme/3)');
        await Future.delayed(Duration(seconds: 2 * deneme));
      }
    }
    return null;
  }

  Future<bool> _ciftleriHazirla() async {
    ciftler.clear();
    final cfg = a.config.trim();
    final spl = a.split.trim();
    if (cfg.isNotEmpty && spl.isNotEmpty) {
      ciftler.add([cfg, spl]);
      return true;
    }
    final j = await _getir('$_sunucu/splits?dataset=${_k(a.dataset.trim())}');
    if (j == null || j['_hata'] != null) return false;
    final liste = (j['splits'] as List?) ?? const [];
    for (final e in liste) {
      final m = e as Map;
      final c = m['config']?.toString() ?? '';
      final s = m['split']?.toString() ?? '';
      if (cfg.isNotEmpty && c != cfg) continue;
      if (spl.isNotEmpty && s != spl) continue;
      ciftler.add([c, s]);
    }
    return ciftler.isNotEmpty;
  }

  // --- Kaydetme / geri yükleme -------------------------------------------

  Future<void> _kaydet() async {
    try {
      if (bekleyen.isNotEmpty) {
        final gruplar = <String, List<HfBulgu>>{};
        final gorunen = <String, String>{};
        for (final b in bekleyen) {
          final ad = _hfDosyaAdi(b.kelime);
          gorunen.putIfAbsent(ad, () => b.kelime);
          gruplar.putIfAbsent(ad, () => <HfBulgu>[]).add(b);
        }
        final yeniSayac = Map<String, int>.from(kelimeParca);
        for (final e in gruplar.entries) {
          final no = (yeniSayac[e.key] ?? 0) + 1;
          final dosya = '${e.key}_$no.txt';
          final sb = StringBuffer();
          sb.writeln('# Kelime: ${gorunen[e.key]}');
          sb.writeln('# Veri seti: ${a.dataset}');
          sb.writeln('# Parça: $no   Tarih: ${DateTime.now()}');
          sb.writeln();
          for (final b in e.value) {
            sb.writeln('[SATIR ${b.satirNo}] ${b.config} / ${b.split}');
            b.alanlar.forEach((kolon, deger) {
              sb.writeln('  $kolon:');
              sb.writeln(deger);
            });
            sb.writeln();
          }
          await File('${klasor.path}/$dosya')
              .writeAsString(sb.toString(), flush: true);
          yeniSayac[e.key] = no;
          parca++;
          _log('Kaydedildi: $dosya (${e.value.length} satır)');
        }
        kelimeParca
          ..clear()
          ..addAll(yeniSayac);
        bekleyen.clear();
      }
      final gecici = File('${klasor.path}/durum_hf.json.tmp');
      await gecici.writeAsString(
          jsonEncode({
            'dataset': a.dataset,
            'ara': a.ara,
            'kelimeler': a.kelimeler,
            'config': a.config,
            'split': a.split,
            'ciftler': ciftler,
            'pi': pi,
            'ki': ki,
            'offset': offset,
            'istek': istek,
            'satir': satir,
            'bulunan': bulunan,
            'bayt': bayt,
            'parca': parca,
            'kelimeParca': kelimeParca,
          }),
          flush: true);
      await gecici.rename('${klasor.path}/durum_hf.json');
      _kayitBayt = bayt;
      _kayitIstek = istek;
    } catch (e) {
      _log('Kaydetme hatası: $e');
    }
  }

  Future<bool> yukle() async {
    try {
      final f = File('${klasor.path}/durum_hf.json');
      if (!await f.exists()) return false;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      a.dataset = (j['dataset'] as String?) ?? a.dataset;
      a.ara = (j['ara'] as bool?) ?? a.ara;
      a.kelimeler = (j['kelimeler'] as String?) ?? a.kelimeler;
      a.config = (j['config'] as String?) ?? a.config;
      a.split = (j['split'] as String?) ?? a.split;
      ciftler.clear();
      for (final e in ((j['ciftler'] as List?) ?? const [])) {
        final l = e as List;
        ciftler.add([l[0].toString(), l[1].toString()]);
      }
      pi = (j['pi'] as num?)?.toInt() ?? 0;
      ki = (j['ki'] as num?)?.toInt() ?? 0;
      offset = (j['offset'] as num?)?.toInt() ?? 0;
      istek = (j['istek'] as num?)?.toInt() ?? 0;
      satir = (j['satir'] as num?)?.toInt() ?? 0;
      bulunan = (j['bulunan'] as num?)?.toInt() ?? 0;
      bayt = (j['bayt'] as num?)?.toInt() ?? 0;
      parca = (j['parca'] as num?)?.toInt() ?? 0;
      kelimeParca.clear();
      ((j['kelimeParca'] as Map?) ?? const {}).forEach((k, v) {
        kelimeParca[k.toString()] = (v as num).toInt();
      });
      _kayitBayt = bayt;
      _kayitIstek = istek;
      _log('Önceki durum yüklendi: $istek istek, $bulunan satır');
      return true;
    } catch (e) {
      _log('Durum okunamadı: $e');
      return false;
    }
  }

  // --- Ana döngü ---------------------------------------------------------

  void _ekle(String kelime, String c, String s, int idx,
      Map<String, String> alanlar) {
    bekleyen.add(HfBulgu(kelime, a.dataset, c, s, idx, alanlar));
    bulunan++;
    final ilk = alanlar.values.isEmpty ? '' : alanlar.values.first;
    final ozet =
        (ilk.length > 90 ? '${ilk.substring(0, 90)}...' : ilk).replaceAll('\n', ' ');
    sonBulgular.insert(0, '[$kelime] #$idx $ozet');
    if (sonBulgular.length > 40) sonBulgular.removeLast();
  }

  void _satirIsle(Map m, String c, String s) {
    final idx = (m['row_idx'] as num?)?.toInt() ?? -1;
    final ham = m['row'];
    if (ham is! Map) return;
    final alanlar = <String, String>{};
    ham.forEach((k, v) {
      var t = v is String ? v : jsonEncode(v);
      if (t.length > 20000) t = '${t.substring(0, 20000)}... (kısaltıldı)';
      alanlar[k.toString()] = t;
    });
    if (a.ara) {
      // Sunucu zaten bu kelimeyi içeren satırları verdi.
      _ekle(_orijinal[ki], c, s, idx, alanlar);
    } else {
      final tum = StringBuffer();
      alanlar.forEach((k, v) {
        tum.write(v);
        tum.write('\n');
      });
      final kat = katla(tum.toString());
      for (var i = 0; i < _katli.length; i++) {
        if (esles(kat, _katli[i], a.kelimeBasinda)) {
          _ekle(_orijinal[i], c, s, idx, alanlar);
        }
      }
    }
  }

  Future<void> calis(bool devam) async {
    if (calisiyor) return;
    calisiyor = true;
    aktif = this;
    _dur = false;
    _orijinal = a.kelimeler
        .split(RegExp(r'[,\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    _katli = _orijinal.map(katla).toList();
    durum = 'Çalışıyor';
    onGuncelle();

    final i0 = istek;
    final b0 = bayt;
    final sw = Stopwatch()..start();
    String? neden;
    try {
      if (_orijinal.isEmpty) {
        neden = 'En az bir kelime yaz.';
        return;
      }
      if (!devam || ciftler.isEmpty) {
        final ok = await _ciftleriHazirla();
        if (!ok) {
          neden = _dur
              ? 'Durduruldu.'
              : 'Veri seti bölümleri alınamadı. Adı, config ve split doğru mu? "Bilgi al"a bas.';
          return;
        }
      }
      while (pi < ciftler.length) {
        if (_dur) {
          neden = 'Durduruldu. Her şey kaydedildi.';
          break;
        }
        if (istek - i0 >= a.maxIstek) {
          neden = 'İstek sınırına ulaşıldı (${a.maxIstek}).';
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

        final c = ciftler[pi][0];
        final s = ciftler[pi][1];
        final base = '$_sunucu/${a.ara ? 'search' : 'rows'}'
            '?dataset=${_k(a.dataset.trim())}&config=${_k(c)}&split=${_k(s)}';
        final url = a.ara
            ? '$base&query=${_k(_orijinal[ki])}&offset=$offset&length=100'
            : '$base&offset=$offset&length=100';
        durum = a.ara
            ? 'Aranıyor: "${_orijinal[ki]}" ($c / $s) satır $offset'
            : 'Taranıyor: $c / $s satır $offset';
        onGuncelle();

        final j = await _getir(url);
        if (j == null) {
          neden = _dur
              ? 'Durduruldu. Her şey kaydedildi.'
              : 'Bağlantı koptu ya da sunucu sınırladı. Kaydedildi; biraz sonra "Devam et"e bas.';
          break;
        }

        var bitti = false;
        if (j['_hata'] != null) {
          _log('$c / $s: HTTP ${j['_hata']}, bu bölüm atlandı');
          bitti = true;
        } else {
          final rows = (j['rows'] as List?) ?? const [];
          final toplam = (j['num_rows_total'] as num?)?.toInt() ?? 0;
          for (final e in rows) {
            if (e is Map) _satirIsle(e, c, s);
          }
          offset += rows.length;
          satir += rows.length;
          bitti = rows.isEmpty ||
              rows.length < 100 ||
              (toplam > 0 && offset >= toplam);
        }
        if (bitti) {
          offset = 0;
          if (a.ara && ki + 1 < _orijinal.length) {
            ki++;
          } else {
            ki = 0;
            pi++;
          }
        }

        if (bayt - _kayitBayt >= a.kaydetMb * 1048576 ||
            istek - _kayitIstek >= 20) {
          await _kaydet();
        }
        if (istek % 10 == 0) {
          await arkaPlanYaz('$istek istek, $bulunan satır bulundu');
        }
        onGuncelle();
        await Future.delayed(Duration(milliseconds: a.beklemeMs));
      }
      neden ??= pi >= ciftler.length ? 'Bitti: tüm bölümler tarandı.' : 'Durdu.';
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
}

// ---------------------------------------------------------------------------
// EKRAN
// ---------------------------------------------------------------------------

class HfSayfa extends StatefulWidget {
  const HfSayfa({super.key});

  @override
  State<HfSayfa> createState() => _HfSayfaState();
}

class _HfSayfaState extends State<HfSayfa> {
  static const Map<String, String> _varsayilan = {
    'dataset': '',
    'config': '',
    'split': '',
    'kelimeler': '',
    'maxIstek': '300',
    'maxMb': '50',
    'maxDakika': '30',
    'beklemeMs': '600',
    'kaydetMb': '10',
  };

  // Aramalarda bulunmuş, kimya/fizik ağırlıklı örnek veri setleri.
  // Lisans ve içerik için "Bilgi al"a bas, veri setinin sayfasını da kontrol et.
  static const List<String> _ornekler = [
    'zd21/SciInstruct',
    'checkai/oaCamel',
    'daman1209arora/jeebench',
    'LDJnr/Capybara',
    'AYueksel/TurkishMMLU',
    'BASF-AI/PubChemWikiTRPC',
    'ysdede/khanacademy-turkish',
  ];

  final Map<String, TextEditingController> _c = {};
  bool _ara = true;
  bool _basinda = false;
  HfTarayici? _t;
  String? _sonKlasor;
  bool _devamVar = false;
  String _bilgi = '';
  bool _bilgiYukleniyor = false;

  @override
  void initState() {
    super.initState();
    _varsayilan.forEach((k, v) => _c[k] = TextEditingController(text: v));
    final t = HfTarayici.aktif;
    if (t != null) {
      t.onGuncelle = _yenile;
      _t = t;
    }
    _yukle();
  }

  @override
  void dispose() {
    _t?.onGuncelle = () {};
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _yenile() {
    if (mounted) setState(() {});
  }

  void _mesaj(String s) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> _yukle() async {
    final p = await SharedPreferences.getInstance();
    for (final k in _varsayilan.keys) {
      final v = p.getString('hf_$k');
      if (v != null) _c[k]!.text = v;
    }
    _ara = p.getBool('hf_ara') ?? true;
    _basinda = p.getBool('hf_basinda') ?? false;
    _sonKlasor = p.getString('hf_sonKlasor');
    await _devamKontrol();
    _yenile();
  }

  Future<void> _kaydetAyar() async {
    final p = await SharedPreferences.getInstance();
    for (final e in _c.entries) {
      await p.setString('hf_${e.key}', e.value.text);
    }
    await p.setBool('hf_ara', _ara);
    await p.setBool('hf_basinda', _basinda);
  }

  Future<void> _devamKontrol() async {
    final yol = _sonKlasor;
    _devamVar = yol != null && await File('$yol/durum_hf.json').exists();
    _yenile();
  }

  HfAyarlar _ayarOku() {
    int n(String k, int d, int min) {
      final v = int.tryParse(_c[k]!.text.trim()) ?? d;
      return v < min ? min : v;
    }

    return HfAyarlar()
      ..dataset = _c['dataset']!.text.trim()
      ..config = _c['config']!.text.trim()
      ..split = _c['split']!.text.trim()
      ..kelimeler = _c['kelimeler']!.text.trim()
      ..ara = _ara
      ..kelimeBasinda = _basinda
      ..maxIstek = n('maxIstek', 300, 1)
      ..maxMb = n('maxMb', 50, 1)
      ..maxDakika = n('maxDakika', 30, 1)
      ..beklemeMs = n('beklemeMs', 600, 200)
      ..kaydetMb = n('kaydetMb', 10, 1);
  }

  String _damga() {
    final n = DateTime.now();
    String i(int x) => x.toString().padLeft(2, '0');
    return '${n.year}${i(n.month)}${i(n.day)}_${i(n.hour)}${i(n.minute)}${i(n.second)}';
  }

  Future<void> _bilgiAl() async {
    setState(() {
      _bilgiYukleniyor = true;
      _bilgi = '';
    });
    final s = await HfTarayici.bilgiAl(_c['dataset']!.text);
    if (!mounted) return;
    setState(() {
      _bilgi = s;
      _bilgiYukleniyor = false;
    });
  }

  Future<void> _baslat() async {
    if (_t?.calisiyor ?? false) return;
    final ad = _c['dataset']!.text.trim();
    if (ad.isEmpty || !ad.contains('/')) {
      _mesaj('Veri seti adını "kullanici/ad" biçiminde yaz.');
      return;
    }
    if (_c['kelimeler']!.text.trim().isEmpty) {
      _mesaj('En az bir kelime yaz.');
      return;
    }
    await _kaydetAyar();
    final kok = await kayitKoku();
    final klasor =
        Directory('${kok.path}/hf_${ad.replaceAll('/', '_')}_${_damga()}');
    await klasor.create(recursive: true);
    final t = HfTarayici(_ayarOku(), klasor, _yenile);
    final p = await SharedPreferences.getInstance();
    await p.setString('hf_sonKlasor', klasor.path);
    _sonKlasor = klasor.path;
    setState(() => _t = t);
    _calistir(t, false);
  }

  Future<void> _devam() async {
    final yol = _sonKlasor;
    if (yol == null || (_t?.calisiyor ?? false)) return;
    await _kaydetAyar();
    final t = HfTarayici(_ayarOku(), Directory(yol), _yenile);
    final ok = await t.yukle();
    if (!ok) {
      _mesaj('Kayıtlı durum bulunamadı.');
      return;
    }
    setState(() => _t = t);
    _calistir(t, true);
  }

  Future<void> _calistir(HfTarayici t, bool devam) async {
    await arkaPlanBaslat();
    await t.calis(devam);
    await arkaPlanDurdur();
    await _devamKontrol();
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

    return Scaffold(
      appBar: AppBar(title: const Text('HuggingFace veri setleri')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            _baslik('Hangi veri seti?'),
            _alan('dataset', 'Veri seti adı',
                ipucu:
                    'huggingface.co/datasets/ ile başlayan adresin devamı. Örnek: zd21/SciInstruct'),
            const Text('Örnekler (dokununca adı yazılır):',
                style: TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                for (final o in _ornekler)
                  ActionChip(
                    label: Text(o, style: const TextStyle(fontSize: 12)),
                    onPressed: () => setState(() => _c['dataset']!.text = o),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _bilgiYukleniyor ? null : _bilgiAl,
              icon: const Icon(Icons.info_outline),
              label: Text(_bilgiYukleniyor
                  ? 'Bakılıyor...'
                  : 'Bilgi al (lisans ve bölümler)'),
            ),
            if (_bilgi.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SelectableText(_bilgi),
              ),
            const SizedBox(height: 12),
            _alan('config', 'Config (isteğe bağlı)',
                ipucu:
                    'Veri setinin alt grubu. Boş bırakırsan bulunan hepsi sırayla gezilir. "Bilgi al" listesinden seç.'),
            _alan('split', 'Split (isteğe bağlı)',
                ipucu: 'Genelde train, test ya da validation. Boşsa hepsi.'),
            _baslik('Ne aranacak?'),
            _alan('kelimeler', 'Aranacak kelimeler',
                ipucu:
                    'Virgülle ayır. Veri setinin diliyle yaz (İngilizce veri setinde "chlorine", Türkçede "klor").',
                satir: 2),
            const Text('Yöntem', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: true, label: Text('Sunucuda ara')),
                ButtonSegment(value: false, label: Text('Satır satır tara')),
              ],
              selected: {_ara},
              onSelectionChanged: (s) => setState(() => _ara = s.first),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 8),
              child: Text(
                _ara
                    ? 'Hızlı: Hugging Face sunucusu aramayı yapar, sadece eşleşen satırlar inecek. Kelimeyi bütün olarak arar, "gaz" yazınca "gazlar"ı bulamayabilir.'
                    : 'Yavaş ama esnek: satırlar 100\'erli iner, telefon süzer. Kelime kökü çalışır ("gaz" → gazlar, gazsoy).',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            if (!_ara)
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, label: Text('İçinde geçsin')),
                  ButtonSegment(value: true, label: Text('Kelime başında')),
                ],
                selected: {_basinda},
                onSelectionChanged: (s) => setState(() => _basinda = s.first),
              ),
            ExpansionTile(
              title: const Text('Limitler ve hız'),
              initiallyExpanded: true,
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 8),
              children: [
                _sayi('maxIstek', 'En fazla istek sayısı',
                    'Her istek en çok 100 satır getirir. 300 istek = en çok 30000 satır.'),
                _sayi('maxMb', 'En fazla indirme (MB)',
                    'Bu kadar veri inince durur.'),
                _sayi('maxDakika', 'En fazla süre (dakika)', 'Süre dolunca durur.'),
                _sayi('beklemeMs', 'İstekler arası bekleme (ms)',
                    '600 = yarım saniyeden biraz fazla. En az 200. Çok düşürürsen sunucu seni yavaşlatır.'),
                _sayi('kaydetMb', 'Her kaç MB indirmede bir kaydet',
                    'Bulunanlar kelime başına numaralı dosyaya yazılır, durum kaydedilir.'),
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
                  _sayac('İstek', '${t.istek}'),
                  _sayac('Okunan satır', '${t.satir}'),
                  _sayac('Bulunan satır', '${t.bulunan}'),
                  _sayac('İndirilen (yaklaşık)',
                      '${(t.bayt / 1048576).toStringAsFixed(1)} MB'),
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
  }
}
