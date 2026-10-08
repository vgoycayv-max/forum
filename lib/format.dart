// Format okuyucu (sürüm 8)
//
// Telefondaki klasöre (Download/ForumTarayici/girdi) koyduğun dosyaları okur:
//   - SMILES tepkime satırları ("reaktif . reaktif ,ürün")
//   - SMILES tablosu (CSV)
//   - ORD (Open Reaction Database) kayıtları
//   - Sayı tabloları (spektrum gibi)
//   - Düz yazı
// Kural dosyası (kurallar/kural.json) ile kodları ve maddeleri kelimeye çevirir.
// Sonuçlar "cikti" klasörüne yazılır.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'kimya.dart';
import 'main.dart';

// ---------------------------------------------------------------------------
// KLASÖRLER
// ---------------------------------------------------------------------------

class FormatKlasorleri {
  FormatKlasorleri(this.kok);
  final Directory kok;
  Directory get girdi => Directory('${kok.path}/girdi');
  Directory get kurallar => Directory('${kok.path}/kurallar');
  Directory get cikti => Directory('${kok.path}/cikti');
  File get kuralDosyasi => File('${kurallar.path}/kural.json');

  Future<void> olustur() async {
    await girdi.create(recursive: true);
    await kurallar.create(recursive: true);
    await cikti.create(recursive: true);
  }
}

// ---------------------------------------------------------------------------
// KURAL DOSYASI (kural.json)
// ---------------------------------------------------------------------------

class Kurallar {
  Kurallar(this.ham) {
    indeksle();
  }

  final Map<String, dynamic> ham;
  final Map<String, String> _isim = {}; // SMILES -> ad
  final Set<String> _anahtarlar = {}; // sözlükte tanımlı bütün yazılışlar
  List<MapEntry<String, String>> _metin = [];
  List<MapEntry<String, String>> _maddeCeviri = [];
  String? uyari; // dosya okunamadıysa nedeni

  static Kurallar varsayilan() {
    final maddeler = <String, dynamic>{};
    for (final m in varsayilanMaddeler) {
      final smi = m[2];
      final r = smilesCoz(smi);
      maddeler[smi] = {
        'isim': m[0],
        'isim_en': m[1],
        'formul': r.formul,
        'molar_kutle': double.parse(r.kutle.toStringAsFixed(2)),
        'esdeger': m.sublist(3),
      };
    }
    final el = <String, dynamic>{};
    elementler.forEach((k, v) {
      el[k] = {
        'isim': v.ad,
        'isim_en': v.adEn,
        'atom_no': v.no,
        'atom_kutlesi': v.kutle,
      };
    });
    return Kurallar({
      'aciklama': [
        'Bu dosya Başlık Tarayıcı uygulamasının kural dosyasıdır. Bir metin düzenleyiciyle açıp değiştirebilirsin.',
        'Dikkat: tırnaklara, virgüllere ve süslü parantezlere dokunma. Bir virgül eksik olursa uygulama dosyayı okuyamaz.',
        '"metin_kurallari": Soldaki yazı dosyada geçerse sağdaki kelimeyle değişir. Örnek: "c0c01": "patlıcan". İstediğin kadar satır ekleyebilirsin.',
        '"maddeler": SMILES yazısı -> madde bilgisi. "isim" doldurulursa SMILES yerine bu ad yazılır. "esdeger": aynı maddenin başka yazılışları. İstediğin ek alanı (örneğin "not", "kullanim") ekleyebilirsin.',
        '"elementler": Element adları. "isim" alanını değiştirirsen atom ayrıntısında o ad görünür.',
        'Uygulama "Toplu tanımla" ile maddeler bölümüne dosyadaki yeni maddeleri ekler, "isim" alanını sen doldurursun.',
      ],
      'metin_kurallari': {'c0c01': 'patlıcan', 'ccc00r': 'pişdi'},
      'maddeler': maddeler,
      'elementler': el,
    });
  }

  static Future<Kurallar> yukle(File f) async {
    if (!await f.exists()) {
      final k = Kurallar.varsayilan();
      await k.kaydet(f);
      return k;
    }
    try {
      final j = jsonDecode(await f.readAsString());
      if (j is! Map<String, dynamic>) {
        throw const FormatException('en dışta { } olmalı');
      }
      return Kurallar(j);
    } catch (e) {
      final k = Kurallar.varsayilan();
      k.uyari =
          'kural.json okunamadı (yazım hatası olabilir): $e. Dosyan silinmedi, değiştirilmedi; geçici olarak hazır sözlük kullanılıyor.';
      return k;
    }
  }

  void indeksle() {
    _isim.clear();
    _anahtarlar.clear();
    final m = ham['maddeler'];
    if (m is Map) {
      m.forEach((k, v) {
        final anahtarlar = <String>[bosluksuz(k.toString())];
        var isim = '';
        if (v is Map) {
          isim = (v['isim'] ?? '').toString().trim();
          final es = v['esdeger'];
          if (es is List) {
            anahtarlar.addAll(es.map((e) => bosluksuz(e.toString())));
          }
        } else if (v is String) {
          isim = v.trim();
        }
        for (final a in anahtarlar) {
          _anahtarlar.add(a);
          if (isim.isNotEmpty) _isim[a] = isim;
        }
      });
    }
    final t = ham['metin_kurallari'];
    final l = <MapEntry<String, String>>[];
    if (t is Map) {
      t.forEach((k, v) {
        final ks = k.toString();
        if (ks.isNotEmpty) l.add(MapEntry(ks, v.toString()));
      });
    }
    l.sort((a, b) => b.key.length.compareTo(a.key.length));
    _metin = l;
    final c = _isim.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    _maddeCeviri = c;
  }

  int get maddeSayisi {
    final m = ham['maddeler'];
    return m is Map ? m.length : 0;
  }

  int get metinSayisi => _metin.length;

  int get elementSayisi {
    final m = ham['elementler'];
    return m is Map ? m.length : 0;
  }

  String? isimBul(String smiles) {
    final t = bosluksuz(smiles);
    return _isim[t] ?? (t.contains('~') ? _isim[t.replaceAll('~', '.')] : null);
  }

  bool maddeVar(String smiles) {
    final t = bosluksuz(smiles);
    return _anahtarlar.contains(t) ||
        (t.contains('~') && _anahtarlar.contains(t.replaceAll('~', '.')));
  }

  /// Metin kurallarını (ve istenirse madde adlarını) uygular. En uzun anahtar önce.
  String metinUygula(String s, {bool maddeler = false}) {
    var t = s;
    for (final e in _metin) {
      t = t.replaceAll(e.key, e.value);
    }
    if (maddeler && _maddeCeviri.length <= 3000) {
      for (final e in _maddeCeviri) {
        t = t.replaceAll(e.key, e.value);
      }
    }
    return t;
  }

  String elementAdi(String sym) {
    final m = ham['elementler'];
    if (m is Map) {
      final e = m[sym];
      if (e is Map) {
        final ad = (e['isim'] ?? '').toString().trim();
        if (ad.isNotEmpty) return ad;
      }
    }
    return elementler[sym]?.ad ?? sym;
  }

  void maddeEkle(String smiles, SmilesSonucu r) {
    final m = ham.putIfAbsent('maddeler', () => <String, dynamic>{});
    if (m is! Map) return;
    m[smiles] = {
      'isim': '',
      'isim_en': '',
      'formul': r.gecerli ? r.formul : '',
      'molar_kutle': r.gecerli ? double.parse(r.kutle.toStringAsFixed(2)) : 0.0,
      'esdeger': <String>[],
    };
    _anahtarlar.add(smiles);
  }

  /// Hazır sözlükteki maddelerden kural dosyasında olmayanları ekler.
  /// Var olanlara (kullanıcının yazdığı adlara) dokunmaz. Eklenen sayısını verir.
  int hazirlariBirlestir() {
    final m = ham.putIfAbsent('maddeler', () => <String, dynamic>{});
    if (m is! Map) return 0;
    var n = 0;
    for (final x in varsayilanMaddeler) {
      final tum = <String>[x[2], ...x.sublist(3)].map(bosluksuz);
      if (tum.any((e) => _anahtarlar.contains(e))) continue;
      final r = smilesCoz(x[2]);
      m[x[2]] = {
        'isim': x[0],
        'isim_en': x[1],
        'formul': r.formul,
        'molar_kutle': double.parse(r.kutle.toStringAsFixed(2)),
        'esdeger': x.sublist(3),
      };
      n++;
    }
    indeksle();
    return n;
  }

  Map? madde(String smiles) {
    final m = ham['maddeler'];
    if (m is Map) {
      final e = m[smiles];
      if (e is Map) return e;
    }
    return null;
  }

  /// İsmi boş ve daha önce çevrimiçi sorulmamış maddelerin listesi.
  List<String> adsizlar() {
    final out = <String>[];
    final m = ham['maddeler'];
    if (m is Map) {
      m.forEach((k, v) {
        if (v is Map &&
            (v['isim'] ?? '').toString().trim().isEmpty &&
            !v.containsKey('pubchem')) {
          out.add(k.toString());
        }
      });
    }
    return out;
  }

  Future<bool> kaydet(File f) async {
    if (uyari != null) return false; // bozuk dosyanın üstüne yazma
    await f.parent.create(recursive: true);
    final gecici = File('${f.path}.tmp');
    await gecici.writeAsString(
        const JsonEncoder.withIndent('  ').convert(ham),
        flush: true);
    await gecici.rename(f.path);
    return true;
  }
}

// ---------------------------------------------------------------------------
// BİÇİM TANIMA
// ---------------------------------------------------------------------------

enum Bicim { otomatik, tepkime, csv, ord, prosedur, spektrum, liste, metin }

String bicimAdi(Bicim b) {
  switch (b) {
    case Bicim.otomatik:
      return 'Otomatik';
    case Bicim.tepkime:
      return 'Tepkime satırları';
    case Bicim.csv:
      return 'SMILES tablosu (CSV)';
    case Bicim.ord:
      return 'ORD kaydı';
    case Bicim.prosedur:
      return 'Prosedür (rxID/source/target)';
    case Bicim.spektrum:
      return 'Sayı tablosu';
    case Bicim.liste:
      return 'SMILES listesi';
    case Bicim.metin:
      return 'Düz yazı';
  }
}

Future<List<String>> ilkSatirlar(File f, int n, {bool bosAtla = true}) async {
  final out = <String>[];
  final akis = f
      .openRead()
      .transform(const Utf8Decoder(allowMalformed: true))
      .transform(const LineSplitter());
  await for (final l in akis) {
    if (bosAtla && l.trim().isEmpty) continue;
    out.add(l);
    if (out.length >= n) break;
  }
  return out;
}

double? _sayi(String t) => double.tryParse(t.trim().replaceAll(',', '.'));

String _ayrac(String satir) {
  final noktali = ';'.allMatches(satir).length;
  final virgul = ','.allMatches(satir).length;
  final tab = '\t'.allMatches(satir).length;
  if (tab > noktali && tab > virgul) return '\t';
  return noktali > virgul ? ';' : ',';
}

Bicim bicimTani(List<String> s) {
  if (s.isEmpty) return Bicim.metin;
  final ilk = s.first;
  final ordKalibi = RegExp(r'\t\s*\[\s*\d+\s*,\s*\d+');
  if (ilk.toLowerCase().startsWith('reaction_id') ||
      ordKalibi.hasMatch(ilk) ||
      (s.length > 1 && ordKalibi.hasMatch(s[1]))) {
    return Bicim.ord;
  }
  if (ilk.trimLeft().startsWith('{') &&
      ilk.contains('"rxID"') &&
      ilk.contains('"source"') &&
      ilk.contains('"target"')) {
    return Bicim.prosedur;
  }
  if (ilk.toLowerCase().contains('smiles') &&
      (ilk.contains(',') || ilk.contains(';') || ilk.contains('\t'))) {
    return Bicim.csv;
  }
  // sayı tablosu
  final p = ilk.split(';');
  if (p.length >= 8) {
    final sayisal = p.where((t) => _sayi(t) != null).length;
    if (sayisal / p.length >= 0.8) return Bicim.spektrum;
  }
  final ornek = s.take(8).toList();
  // tepkime satırları: "sol,sağ"
  var tepkime = 0;
  for (final l in ornek) {
    if (','.allMatches(l).length == 1) {
      final i = l.indexOf(',');
      if (smilesGibi(l.substring(0, i)) && smilesGibi(l.substring(i + 1))) {
        tepkime++;
      }
    }
  }
  if (tepkime / ornek.length >= 0.8) return Bicim.tepkime;
  // başlıksız CSV: ilk hücre SMILES
  var csv = 0;
  for (final l in ornek) {
    final a = _ayrac(l);
    if (l.contains(a) && smilesGibi(l.split(a).first)) csv++;
  }
  if (csv / ornek.length >= 0.8) return Bicim.csv;
  var liste = 0;
  for (final l in ornek) {
    if (smilesGibi(l)) liste++;
  }
  if (liste / ornek.length >= 0.8) return Bicim.liste;
  return Bicim.metin;
}

// ---------------------------------------------------------------------------
// KÜÇÜK YARDIMCILAR
// ---------------------------------------------------------------------------

List<String> csvBol(String satir, String ayrac) {
  final out = <String>[];
  final sb = StringBuffer();
  var tirnak = false;
  for (var i = 0; i < satir.length; i++) {
    final c = satir[i];
    if (c == '"') {
      if (tirnak && i + 1 < satir.length && satir[i + 1] == '"') {
        sb.write('"');
        i++;
      } else {
        tirnak = !tirnak;
      }
    } else if (c == ayrac && !tirnak) {
      out.add(sb.toString());
      sb.clear();
    } else {
      sb.write(c);
    }
  }
  out.add(sb.toString());
  return out;
}

String csvHucre(String h, String ayrac) =>
    (h.contains(ayrac) || h.contains('"') || h.contains('\n'))
        ? '"${h.replaceAll('"', '""')}"'
        : h;

String _kisalt(String t, [int n = 70]) =>
    t.length > n ? '${t.substring(0, n - 3)}...' : t;

String dosyaKoku(File f) {
  final ad = f.uri.pathSegments.isNotEmpty ? f.uri.pathSegments.last : 'dosya';
  final i = ad.lastIndexOf('.');
  return i > 0 ? ad.substring(0, i) : ad;
}

/// "A.B.C" bileşenlerini birleştirip sözlükte bilinen tuzları tek madde sayar.
List<String> grupla(List<String> parcalar, Kurallar k) {
  final out = <String>[];
  var i = 0;
  while (i < parcalar.length) {
    var bulundu = false;
    final son = i + 4 < parcalar.length ? i + 4 : parcalar.length - 1;
    for (var j = son; j > i; j--) {
      final birlesik = parcalar.sublist(i, j + 1).join('.');
      if (k.isimBul(birlesik) != null) {
        out.add(birlesik);
        i = j + 1;
        bulundu = true;
        break;
      }
    }
    if (!bulundu) {
      out.add(parcalar[i]);
      i++;
    }
  }
  return out;
}

List<String> bolMolekuller(String s, Kurallar k) => grupla(
    bosluksuz(s).split('.').where((e) => e.isNotEmpty).toList(), k);

Map<String, int> _formulSay(String f) {
  final m = <String, int>{};
  for (final x in RegExp(r'([A-Z][a-z]?)(\d*)').allMatches(f)) {
    final n = x.group(2)!.isEmpty ? 1 : int.parse(x.group(2)!);
    m[x.group(1)!] = (m[x.group(1)!] ?? 0) + n;
  }
  return m;
}

/// İki formül aynı atomları aynı sayıda içeriyor mu? (yazım sırası önemsiz)
bool _formulEsit(String a, String b) {
  if (a.isEmpty || b.isEmpty) return true; // karşılaştıracak bir şey yok
  final x = _formulSay(a);
  final y = _formulSay(b);
  if (x.length != y.length) return false;
  for (final k in x.keys) {
    if (x[k] != y[k]) return false;
  }
  return true;
}

// ---------------------------------------------------------------------------
// İŞLEYİCİ
// ---------------------------------------------------------------------------

class FormatSecenek {
  Bicim bicim = Bicim.otomatik;
  int mod = 0; // 0 oku, 1 çevir, 2 toplu tanımla
  bool formulGoster = true;
  bool atomAyrinti = false;
  bool ham = false;
  int maxSatir = 5000;
  int maxYeni = 500;
  bool online = false;
  int maxOnline = 100;
}

class FormatSonuc {
  Bicim? bicim;
  String? cikti;
  int okunan = 0;
  int yazilan = 0;
  int hatali = 0;
  int yeniMadde = 0;
  int adBulunan = 0;
  String mesaj = '';
  List<String> onizleme = [];
}

class Isleyici {
  Isleyici(this.kural, this.sec, this.kl, this.bildir);
  final Kurallar kural;
  final FormatSecenek sec;
  final FormatKlasorleri kl;
  final void Function(String) bildir;
  bool dur = false;

  // --- madde yazımı ---

  String _atomlar(SmilesSonucu r) {
    final ks = r.atomlar.keys.toList()
      ..sort((a, b) =>
          (elementler[a]?.no ?? 999).compareTo(elementler[b]?.no ?? 999));
    return ks
        .map((e) =>
            '$e ${kural.elementAdi(e)} (${elementler[e]?.no ?? '?'}) ×${r.atomlar[e]}')
        .join(', ');
  }

  String _tanim(String smi) {
    final t = bosluksuz(smi);
    final r = smilesCoz(t);
    final isim = kural.isimBul(t);
    if (!r.gecerli) return '${isim ?? _kisalt(t)} (SMILES okunamadı)';
    final yuk = r.yuk == 0 ? '' : ' (yük ${r.yuk > 0 ? '+' : ''}${r.yuk})';
    var x =
        '${isim ?? _kisalt(t, 90)} — ${r.formul}$yuk — ${r.kutle.toStringAsFixed(2)} g/mol';
    if (sec.atomAyrinti) x += '\n         atomlar: ${_atomlar(r)}';
    return x;
  }

  String _goster(String smi) {
    final t = bosluksuz(smi);
    final isim = kural.isimBul(t);
    if (isim != null) return isim;
    if (sec.formulGoster) {
      final r = smilesCoz(t);
      if (r.gecerli) return r.formul;
    }
    return t;
  }

  String _adKisa(String smi) {
    final t = bosluksuz(smi);
    final isim = kural.isimBul(t);
    if (isim != null) return isim;
    final r = smilesCoz(t);
    if (r.gecerli) return r.formul;
    return _kisalt(t, 40);
  }

  // --- Organic Syntheses benzeri "rxID / source / target" kayıtları ---

  static final RegExp _rxKod = RegExp(r'^(CV|V)(\d+)P(\d+)(?:_(\d+))?$');

  String _kaynakKodu(String id) {
    final m = _rxKod.firstMatch(id);
    if (m == null) return id;
    final cilt = m.group(1) == 'CV' ? 'Toplu Cilt ${m.group(2)}' : 'Cilt ${m.group(2)}';
    final sayfa = int.parse(m.group(3)!);
    final ek = m.group(4) != null ? ', ${m.group(4)}. tepkime' : '';
    return 'Organic Syntheses, $cilt, sayfa $sayfa$ek';
  }

  static const Map<String, String> _fiilTR = {
    'ADD': 'Ekle',
    'SETTEMPERATURE': 'Sıcaklığı ayarla',
    'MAKESOLUTION': 'Çözelti hazırla',
    'WAIT': 'Bekle',
    'STIR': 'Karıştır',
    'CONCENTRATE': 'Çözücüyü uçurup derişik hale getir',
    'COLLECTLAYER': 'Fazı ayır ve al',
    'WASH': 'Yıka',
    'DRYSOLUTION': 'Çözeltiyi kurut',
    'DRYSOLID': 'Katıyı kurut',
    'FILTER': 'Süz',
    'QUENCH': 'Tepkimeyi sonlandır (söndür)',
    'EXTRACT': 'Özütle (ekstrakte et)',
    'PH': 'pH ayarla',
    'PURIFY': 'Saflaştır',
    'RECRYSTALLIZE': 'Yeniden kristallendir',
    'REFLUX': 'Geri soğutucu altında kaynat',
    'DEGAS': 'Gazını al',
    'MICROWAVE': 'Mikrodalga uygula',
    'SONICATE': 'Ultrason uygula',
    'PARTITION': 'İki faz arasında dağıt',
    'PHASESEPARATION': 'Fazları ayır',
    'FLASHCHROMATOGRAPHY': 'Flaş kromatografi yap',
    'THROWAWAY': 'At (kullanma)',
    'YIELD': 'Ürünü al (verim)',
    'NOACTION': 'İşlem yok',
    'FOLLOWOTHERPROCEDURE': 'Başka bir prosedürü izle',
  };

  // Uzun ifadeler önce. Anahtarlar küçük harfle yazılır, büyük/küçük fark etmez.
  static const Map<String, String> _sozTR = {
    'keep filtrate': 'süzüntüyü sakla',
    'keep precipitate': 'çökeleği sakla',
    'sodium bicarbonate': 'sodyum bikarbonat',
    'sodium hydroxide': 'sodyum hidroksit',
    'sodium chloride': 'sodyum klorür',
    'sodium carbonate': 'sodyum karbonat',
    'sodium sulfate': 'sodyum sülfat',
    'magnesium sulfate': 'magnezyum sülfat',
    'calcium sulfate': 'kalsiyum sülfat',
    'calcium chloride': 'kalsiyum klorür',
    'potassium carbonate': 'potasyum karbonat',
    'acetic acid': 'asetik asit',
    'hydrochloric acid': 'hidroklorik asit',
    'sulfuric acid': 'sülfürik asit',
    'ethyl acetate': 'etil asetat',
    'diethyl ether': 'dietil eter',
    'petroleum ether': 'petrol eteri',
    'dichloromethane': 'diklorometan',
    'sln': 'hazırlanan çözelti',
    'dropwise': 'damla damla',
    'nitrogen': 'azot',
    'organic': 'organik faz',
    'aqueous': 'sulu faz',
    'filtrate': 'süzüntü',
    'precipitate': 'çökelek',
    'hexane': 'hekzan',
    'ethanol': 'etanol',
    'methanol': 'metanol',
    'toluene': 'toluen',
    'benzene': 'benzen',
    'acetone': 'aseton',
    'brine': 'tuzlu su',
    'water': 'su',
    'ether': 'eter',
    'under': 'altında',
    'with': 'ile',
    'and': 've',
    'from': 'şuradan:',
    'keep': 'sakla:',
    'over': 'üzerinde',
    'at': 'şu koşulda:',
  };

  String _eylemTR(String e, List<String> girenAd, List<String> urunAd) {
    final p = e.trim().split(RegExp(r'\s+'));
    final fiil = p.first.toUpperCase();
    var rest = p.skip(1).join(' ');
    // "with X" -> "X ile" (çözelti hazırlarken "X kullanarak")
    rest = rest.replaceFirstMapped(
        RegExp(r'^with\s+(.+?)(?=\s+(?:dropwise|at\s|over\s|for\s)|$)', caseSensitive: false),
        (m) => '${m.group(1)} ${fiil == 'MAKESOLUTION' ? 'kullanarak' : 'ile'}');
    // "under nitrogen" -> "azot altında", "over X" (kurutucu) -> "X üzerinde"
    rest = rest.replaceAllMapped(
        RegExp(r'\bunder\s+(\w+)', caseSensitive: false), (m) => '${m.group(1)} altında');
    rest = rest.replaceFirstMapped(RegExp(r'\bover\s+(?!@)(.+)$', caseSensitive: false),
        (m) => '${m.group(1)} üzerinde');
    rest = rest.replaceAllMapped(RegExp(r'\bat\s+#(\d+)#'),
        (m) => 'sıcaklık-${m.group(1)} değerinde');
    rest = rest.replaceAllMapped(RegExp(r'\b(?:for|over)\s+@(\d+)@'),
        (m) => 'süre-${m.group(1)} boyunca');
    rest = rest.replaceAllMapped(
        RegExp(r'#(\d+)#'), (m) => 'sıcaklık-${m.group(1)}');
    rest = rest.replaceAllMapped(RegExp(r'@(\d+)@'), (m) => 'süre-${m.group(1)}');
    for (final x in _sozTR.entries) {
      rest = rest.replaceAll(
          RegExp('\\b${RegExp.escape(x.key)}\\b', caseSensitive: false), x.value);
    }
    rest = rest.replaceAllMapped(RegExp(r'\$(-?\d+)\$'), (m) {
      final n = int.parse(m.group(1)!);
      if (n > 0 && n <= girenAd.length) return '$n numaralı madde (${girenAd[n - 1]})';
      if (n < 0 && -n <= urunAd.length) return 'ürün (${urunAd[-n - 1]})';
      return '$n numaralı madde';
    });
    rest = rest.replaceAll('damla damla damla damla', 'damla damla').trim();
    final ad = _fiilTR[fiil] ?? fiil;
    return rest.isEmpty ? '$ad.' : '$ad: $rest.';
  }

  List<String> _gereclerTR(List<String> eylemler, String hedef) {
    final fiiller = eylemler.map((e) => e.trim().split(RegExp(r'\s+')).first.toUpperCase()).toSet();
    final g = <String>['reaksiyon kabı (boyutu kayıtta yok)'];
    if (fiiller.contains('STIR') || fiiller.contains('MAKESOLUTION')) g.add('karıştırıcı');
    if (fiiller.contains('SETTEMPERATURE') || RegExp(r'at #\d+#').hasMatch(hedef)) {
      g.add('ısıtma / soğutma banyosu ve termometre');
    }
    if (fiiller.contains('REFLUX')) g.add('geri soğutucu (kondenser)');
    if (fiiller.contains('FILTER')) g.add('süzme düzeneği (huni, filtre kağıdı)');
    if (fiiller.contains('CONCENTRATE')) g.add('döner buharlaştırıcı (evaporatör)');
    if (fiiller.contains('EXTRACT') ||
        fiiller.contains('COLLECTLAYER') ||
        fiiller.contains('WASH') ||
        fiiller.contains('PHASESEPARATION')) {
      g.add('ayırma hunisi');
    }
    if (fiiller.contains('DRYSOLUTION') || fiiller.contains('DRYSOLID')) {
      g.add('kurutma maddesi / kurutma düzeneği');
    }
    if (fiiller.contains('RECRYSTALLIZE')) g.add('kristallendirme kabı');
    if (RegExp(r'\bnitrogen\b', caseSensitive: false).hasMatch(hedef)) {
      g.add('azot gazı kaynağı');
    }
    return g;
  }

  void _tarifYaz(Map j, void Function(String) yaz) {
    final id = (j['rxID'] ?? '').toString();
    final kaynak = (j['source'] ?? '').toString();
    final hedef = (j['target'] ?? '').toString();
    final k = kaynak.indexOf('>>');
    final sol = k >= 0 ? kaynak.substring(0, k) : kaynak;
    final sag = k >= 0 ? kaynak.substring(k + 2) : '';
    List<String> bol(String x) =>
        bosluksuz(x).split('.').where((e) => e.isNotEmpty).toList();
    final giren = bol(sol);
    final urun = bol(sag);
    final girenAd = giren.map(_adKisa).toList();
    final urunAd = urun.map(_adKisa).toList();
    final eylemler =
        hedef.split(';').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final ayrinti = sec.mod == 0;

    yaz('TARİF $id');
    yaz('  Kaynak: ${_kaynakKodu(id)}. Gerçek miktarlar ve süreler için orgsyn.org sitesinde "$id" kodunu ara.');
    yaz('  MALZEMELER (numaralar adımlardaki numaralarla aynıdır)');
    for (var i = 0; i < giren.length; i++) {
      yaz('    ${i + 1}. ${ayrinti ? _tanim(giren[i]) : _goster(giren[i])}   [miktar: bu kayıtta yok]');
    }
    yaz('  BEKLENEN ÜRÜN');
    for (final u in urun) {
      yaz('    ${ayrinti ? _tanim(u) : _goster(u)}');
    }
    yaz('  GEREKEN ARAÇ-GEREÇ (adımlardan çıkarıldı, kayıtta açıkça yazmıyor)');
    for (final g in _gereclerTR(eylemler, hedef)) {
      yaz('    • $g');
    }
    yaz('  ADIMLAR');
    var n = 1;
    for (final e in eylemler) {
      yaz('    ${n++}. ${_eylemTR(e, girenAd, urunAd)}');
    }
    if (RegExp(r'[@#]\d+[@#]').hasMatch(hedef)) {
      yaz('  NOT: "süre-N" ve "sıcaklık-N" yerine gelen gerçek sayılar bu veri setinde silinmiş. Aynı numara aynı değeri gösterir (örneğin iki yerde "süre-2" varsa ikisi aynı süredir).');
    }
    yaz('  SONUÇ');
    yaz('    ${urun.isEmpty ? 'Ürün bilgisi yok' : 'Ürün: ${urunAd.join(' + ')}'}. Verim sayısı bu kayıtta yok.');
    yaz('');
  }

  Map<String, int> _topla(List<String> maddeler) {
    final say = <String, int>{};
    for (final m in maddeler) {
      final r = smilesCoz(m);
      if (!r.gecerli) continue;
      r.atomlar.forEach((k, v) => say[k] = (say[k] ?? 0) + v);
    }
    return say;
  }

  // --- ana işlem ---

  Future<FormatSonuc> calis(File dosya) async {
    final s = FormatSonuc();
    final ornek = await ilkSatirlar(dosya, 40);
    final bicim = sec.bicim == Bicim.otomatik ? bicimTani(ornek) : sec.bicim;
    s.bicim = bicim;
    if (kural.uyari != null && sec.mod == 2) {
      s.mesaj = 'Toplu tanımlama için kural.json düzgün okunabilmeli. ${kural.uyari}';
      return s;
    }
    if (sec.mod == 2) return _topluTanimla(dosya, bicim, s);
    if (bicim == Bicim.metin && sec.mod == 0) {
      s.mesaj =
          'Bu dosyanın biçimi tanınmadı (düz yazı gibi görünüyor). Biçimi elle seçmeyi dene ya da "Çevir" modunu kullan.';
      return s;
    }

    final cikti = File(
        '${kl.cikti.path}/${dosyaKoku(dosya)}_${sec.mod == 0 ? 'okunur' : 'ceviri'}.txt');
    final sink = cikti.openWrite(encoding: utf8);
    s.cikti = cikti.path;

    void yaz(String t) {
      sink.writeln(kural.metinUygula(t));
      s.yazilan++;
    }

    final akis = dosya
        .openRead()
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter());

    var no = 0;
    var ilk = true;
    List<String>? baslik;
    var smilesKol = 0;
    var ayrac = ',';
    List<double>? xs;
    try {
      await for (final satir in akis) {
        if (dur) {
          s.mesaj = 'Durduruldu.';
          break;
        }
        if (satir.trim().isEmpty && bicim != Bicim.metin) continue;
        s.okunan++;
        if (sec.maxSatir > 0 && s.okunan > sec.maxSatir) {
          s.mesaj = 'Satır sınırına ulaşıldı (${sec.maxSatir}).';
          break;
        }
        if (s.okunan % 200 == 0) {
          bildir('${s.okunan} satır işlendi...');
          await sink.flush();
          await Future.delayed(Duration.zero);
        }
        try {
          switch (bicim) {
            case Bicim.tepkime:
              no++;
              final i = satir.lastIndexOf(',');
              if (i < 0) {
                s.hatali++;
                yaz('[$no] virgül bulunamadı: ${_kisalt(satir)}');
                break;
              }
              final giren = bolMolekuller(satir.substring(0, i), kural);
              final urun = bolMolekuller(satir.substring(i + 1), kural);
              if (sec.mod == 1) {
                yaz('[$no] ${giren.map(_goster).join(' + ')} → ${urun.map(_goster).join(' + ')}');
              } else {
                yaz('[$no]');
                yaz('  Girenler:');
                for (var j = 0; j < giren.length; j++) {
                  yaz('    ${j + 1}. ${_tanim(giren[j])}');
                }
                yaz('  Ürün:');
                for (var j = 0; j < urun.length; j++) {
                  yaz('    ${j + 1}. ${_tanim(urun[j])}');
                }
                yaz('  Atom farkı: ${atomFarki(_topla(giren), _topla(urun))}');
                yaz('');
              }
              break;
            case Bicim.csv:
              if (ilk) {
                ilk = false;
                ayrac = _ayrac(satir);
                final h = csvBol(satir, ayrac);
                final idx =
                    h.indexWhere((e) => e.toLowerCase().contains('smiles'));
                if (idx >= 0) {
                  smilesKol = idx;
                  baslik = h;
                  yaz(sec.mod == 1 ? satir : 'Sütunlar: ${h.join(' | ')}');
                  break;
                }
                smilesKol = 0; // başlık yok, ilk sütun SMILES
              }
              no++;
              final h = csvBol(satir, ayrac);
              if (smilesKol >= h.length) {
                s.hatali++;
                break;
              }
              if (sec.mod == 1) {
                final yeni = List<String>.from(h);
                yeni[smilesKol] = _goster(h[smilesKol]);
                yaz(yeni.map((e) => csvHucre(e, ayrac)).join(ayrac));
              } else {
                final t = bosluksuz(h[smilesKol]);
                final r = smilesCoz(t);
                final isim = kural.isimBul(t);
                final diger = <String>[];
                for (var j = 0; j < h.length; j++) {
                  if (j == smilesKol) continue;
                  final ad = baslik != null && j < baslik.length ? baslik[j] : 'sütun${j + 1}';
                  diger.add('$ad=${h[j]}');
                }
                if (!r.gecerli) s.hatali++;
                final ana = r.gecerli
                    ? '${isim ?? _kisalt(t, 60)} | ${r.formul} | ${r.kutle.toStringAsFixed(2)} g/mol'
                    : '${isim ?? _kisalt(t, 60)} | SMILES okunamadı';
                yaz('[$no] $ana${diger.isEmpty ? '' : ' | ${diger.join(' | ')}'}');
                if (sec.atomAyrinti && r.gecerli) yaz('      atomlar: ${_atomlar(r)}');
              }
              break;
            case Bicim.liste:
              no++;
              if (sec.mod == 1) {
                yaz(_goster(satir));
              } else {
                yaz('[$no] ${_tanim(satir)}');
              }
              break;
            case Bicim.ord:
              if (satir.toLowerCase().startsWith('reaction_id')) break;
              no++;
              final p = satir.split('\t');
              final id = p.length > 1 ? p[0] : '';
              final veri = p.length > 1 ? p[1] : p[0];
              final b = ordBaytlar(veri);
              if (b.isEmpty) {
                s.hatali++;
                yaz('[$no] kayıt okunamadı');
                break;
              }
              final oz = ordOzetle(b,
                  kimlik: id,
                  isim: kural.isimBul,
                  ham: sec.ham,
                  kisa: sec.mod == 1,
                  formulGoster: sec.formulGoster);
              if (oz.kesik) s.hatali++;
              for (final l in oz.satirlar) {
                yaz(l);
              }
              yaz('');
              break;
            case Bicim.prosedur:
              no++;
              final j = jsonDecode(satir);
              if (j is! Map) {
                s.hatali++;
                yaz('[$no] JSON okunamadı');
                break;
              }
              _tarifYaz(j, yaz);
              break;
            case Bicim.spektrum:
              final p = satir.split(';');
              if (xs == null && ilk) {
                ilk = false;
                final sayisal = p.map(_sayi).whereType<double>().toList();
                if (sayisal.length >= p.length * 0.8) {
                  xs = sayisal;
                  yaz('Ölçüm noktaları (üst satır): ${xs.length} değer, ${_f(xs.first)} … ${_f(xs.last)}');
                  yaz('');
                  break;
                }
              }
              ilk = false;
              no++;
              var etiket = 'satır $no';
              var basla = 0;
              if (p.isNotEmpty && _sayi(p.first) == null) {
                etiket = p.first.trim();
                basla = 1;
              }
              final y = p.skip(basla).map(_sayi).toList();
              final gecerli = y.whereType<double>().toList();
              if (gecerli.isEmpty) {
                s.hatali++;
                yaz('[$no] sayı bulunamadı: ${_kisalt(satir)}');
                break;
              }
              var enB = gecerli.first;
              var enBIdx = 0;
              var enK = gecerli.first;
              var toplam = 0.0;
              for (var j = 0; j < y.length; j++) {
                final v = y[j];
                if (v == null) continue;
                toplam += v;
                if (v > enB) {
                  enB = v;
                  enBIdx = j;
                }
                if (v < enK) enK = v;
              }
              yaz('Satır "$etiket": ${y.length} değer');
              yaz('  en küçük: ${_f(enK)}   en büyük: ${_f(enB)}   ortalama: ${_f(toplam / gecerli.length)}');
              if (xs != null && enBIdx < xs.length) {
                yaz('  en büyük değerin yeri: ${_f(xs[enBIdx])}');
              }
              if (xs != null && xs.length != y.length) {
                yaz('  Uyarı: üst satırda ${xs.length}, bu satırda ${y.length} değer var; eşleştirme baştan yapıldı. Örnek dosya kesilmiş olabilir.');
              }
              yaz('  sıra;x;y');
              for (var j = 0; j < y.length; j++) {
                final v = y[j];
                if (v == null) continue;
                final x = xs != null && j < xs.length ? _f(xs[j]) : '';
                yaz('  ${j + 1};$x;${_f(v)}');
              }
              yaz('');
              break;
            case Bicim.metin:
              yaz(satir);
              break;
            case Bicim.otomatik:
              break;
          }
        } catch (e) {
          s.hatali++;
          yaz('(satır işlenemedi: $e)');
        }
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
    if (s.mesaj.isEmpty) s.mesaj = 'Bitti.';
    s.onizleme = await ilkSatirlar(cikti, 60, bosAtla: false);
    return s;
  }

  String _f(double v) {
    if (v == v.roundToDouble() && v.abs() < 1e12) return v.toInt().toString();
    return double.parse(v.toStringAsPrecision(6)).toString();
  }

  // --- toplu tanımlama ---

  Future<FormatSonuc> _topluTanimla(File dosya, Bicim bicim, FormatSonuc s) async {
    final yeni = <String>[];
    final gorulen = <String>{};
    final akis = dosya
        .openRead()
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter());
    var ilk = true;
    var ayrac = ',';
    var smilesKol = 0;

    void ekle(String m) {
      final t = bosluksuz(m);
      if (t.isEmpty || gorulen.contains(t) || kural.maddeVar(t)) return;
      gorulen.add(t);
      yeni.add(t);
    }

    await for (final satir in akis) {
      if (dur || yeni.length >= sec.maxYeni) break;
      if (satir.trim().isEmpty) continue;
      s.okunan++;
      if (sec.maxSatir > 0 && s.okunan > sec.maxSatir) break;
      if (s.okunan % 200 == 0) {
        bildir('${s.okunan} satır tarandı, ${yeni.length} yeni madde...');
        await Future.delayed(Duration.zero);
      }
      try {
        switch (bicim) {
          case Bicim.tepkime:
            final i = satir.lastIndexOf(',');
            if (i < 0) break;
            for (final m in bolMolekuller(satir.substring(0, i), kural)) {
              ekle(m);
            }
            for (final m in bolMolekuller(satir.substring(i + 1), kural)) {
              ekle(m);
            }
            break;
          case Bicim.csv:
            if (ilk) {
              ilk = false;
              ayrac = _ayrac(satir);
              final h = csvBol(satir, ayrac);
              final idx = h.indexWhere((e) => e.toLowerCase().contains('smiles'));
              if (idx >= 0) {
                smilesKol = idx;
                break;
              }
            }
            final h = csvBol(satir, ayrac);
            if (smilesKol < h.length) ekle(h[smilesKol]);
            break;
          case Bicim.liste:
            ekle(satir);
            break;
          case Bicim.prosedur:
            final j = jsonDecode(satir);
            if (j is Map) {
              final kay = (j['source'] ?? '').toString();
              for (final m in bosluksuz(kay.replaceAll('>>', '.')).split('.')) {
                ekle(m);
              }
            }
            break;
          case Bicim.ord:
            if (satir.toLowerCase().startsWith('reaction_id')) break;
            final p = satir.split('\t');
            final b = ordBaytlar(p.length > 1 ? p[1] : p[0]);
            if (b.isEmpty) break;
            for (final m in ordOzetle(b).smilesler) {
              ekle(m);
            }
            break;
          default:
            break;
        }
      } catch (_) {
        s.hatali++;
      }
    }

    if (bicim == Bicim.metin || bicim == Bicim.spektrum) {
      s.mesaj = 'Bu biçimde madde (SMILES) bulunamaz. Toplu tanımlama SMILES içeren dosyalar içindir.';
      return s;
    }

    for (final m in yeni) {
      kural.maddeEkle(m, smilesCoz(m));
    }
    s.yeniMadde = yeni.length;
    kural.indeksle();
    var ok = await kural.kaydet(kl.kuralDosyasi);
    if (!ok) {
      s.mesaj = 'kural.json kaydedilemedi.';
      return s;
    }
    bildir('${yeni.length} yeni madde kural dosyasına eklendi.');

    if (sec.online) {
      var denenen = 0;
      var bulunan = 0;
      var uyusmayan = 0;
      final adaylar = kural.adsizlar();
      var hataMesaji = '';
      for (final smi in adaylar) {
        if (dur || denenen >= sec.maxOnline) break;
        denenen++;
        bildir('PubChem sorgusu $denenen/${sec.maxOnline < adaylar.length ? sec.maxOnline : adaylar.length}  (bulunan: $bulunan)');
        try {
          final r = await http
              .post(
                  Uri.parse(
                      'https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/smiles/property/Title,IUPACName,MolecularFormula/JSON'),
                  headers: const {
                    'Accept': 'application/json',
                    'User-Agent': 'BaslikTarayici/1.0',
                  },
                  body: {'smiles': smi})
              .timeout(const Duration(seconds: 30));
          final madde = kural.madde(smi);
          if (madde == null) continue;
          if (r.statusCode == 200) {
            final j = jsonDecode(utf8.decode(r.bodyBytes));
            final liste = (j is Map && j['PropertyTable'] is Map)
                ? (j['PropertyTable']['Properties'] as List?)
                : null;
            if (liste != null && liste.isNotEmpty && liste.first is Map) {
              final p = liste.first as Map;
              final baslik = (p['Title'] ?? '').toString().trim();
              final iupac = (p['IUPACName'] ?? '').toString().trim();
              final ad = baslik.isNotEmpty ? baslik : iupac;
              final pf = (p['MolecularFormula'] ?? '').toString();
              final bizimF = (madde['formul'] ?? '').toString();
              madde['pubchem_cid'] = p['CID'];
              madde['isim_en'] = ad;
              if (_formulEsit(pf, bizimF)) {
                madde['pubchem'] = 'bulundu';
                if ((madde['isim'] ?? '').toString().trim().isEmpty) {
                  madde['isim'] = ad;
                }
                if (ad.isNotEmpty) bulunan++;
              } else {
                // PubChem'in verdiği madde bizim hesapladığımız formülle uyuşmuyor:
                // ad otomatik yazılmaz, sadece "isim_en" alanında önerilir.
                madde['pubchem'] = 'formul-uyusmuyor';
                madde['pubchem_formul'] = pf;
                uyusmayan++;
              }
            } else {
              madde['pubchem'] = 'bulunamadi';
            }
          } else if (r.statusCode == 404) {
            madde['pubchem'] = 'bulunamadi';
          } else if (r.statusCode == 429 || r.statusCode == 503) {
            hataMesaji = 'PubChem yavaşlamak istedi (HTTP ${r.statusCode}). Biraz sonra tekrar dene.';
            break;
          } else {
            madde['pubchem'] = 'hata-${r.statusCode}';
          }
        } catch (e) {
          hataMesaji = 'Bağlantı sorunu, çevrimiçi sorgu durdu. Şu ana kadar bulunanlar kaydedildi.';
          break;
        }
        if (denenen % 20 == 0) {
          kural.indeksle();
          await kural.kaydet(kl.kuralDosyasi);
        }
        await Future.delayed(const Duration(milliseconds: 300));
      }
      kural.indeksle();
      ok = await kural.kaydet(kl.kuralDosyasi);
      s.adBulunan = bulunan;
      s.mesaj = 'Bitti. ${yeni.length} yeni madde eklendi. PubChem: $denenen sorgu, $bulunan ad bulundu${uyusmayan > 0 ? ', $uyusmayan tanesinde formül uyuşmadığı için ad yazılmadı (kural.json içinde "formul-uyusmuyor" diye işaretli)' : ''}. $hataMesaji'.trim();
    } else {
      s.mesaj = 'Bitti. ${yeni.length} yeni madde kural.json dosyasına eklendi (formül ve molar kütle ile). "isim" alanlarını sen doldurabilirsin.';
    }
    return s;
  }
}

// ---------------------------------------------------------------------------
// EKRAN
// ---------------------------------------------------------------------------

class FormatSayfa extends StatefulWidget {
  const FormatSayfa({super.key});

  @override
  State<FormatSayfa> createState() => _FormatSayfaState();
}

class _FormatSayfaState extends State<FormatSayfa> {
  FormatKlasorleri? _kl;
  List<File> _dosyalar = [];
  File? _secili;
  Bicim _bicim = Bicim.otomatik;
  int _mod = 0;
  bool _formulGoster = true;
  bool _atomAyrinti = false;
  bool _ham = false;
  bool _online = false;
  final _maxSatir = TextEditingController(text: '5000');
  final _maxYeni = TextEditingController(text: '500');
  final _maxOnline = TextEditingController(text: '100');

  bool _calisiyor = false;
  String _durum = '';
  String _kuralBilgi = '';
  FormatSonuc? _sonuc;
  Isleyici? _isl;

  @override
  void initState() {
    super.initState();
    _hazirla();
  }

  @override
  void dispose() {
    _maxSatir.dispose();
    _maxYeni.dispose();
    _maxOnline.dispose();
    super.dispose();
  }

  void _yenile() {
    if (mounted) setState(() {});
  }

  void _mesaj(String s) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> _hazirla() async {
    try {
      final kok = await kayitKoku();
      final kl = FormatKlasorleri(kok);
      await kl.olustur();
      _kl = kl;
      await _dosyalariYenile();
      await _kuralKontrol();
    } catch (e) {
      _durum = 'Klasörler oluşturulamadı: $e';
    }
    _yenile();
  }

  Future<void> _dosyalariYenile() async {
    final kl = _kl;
    if (kl == null) return;
    final l = <File>[];
    try {
      await for (final e in kl.girdi.list()) {
        if (e is File) l.add(e);
      }
    } catch (_) {}
    l.sort((a, b) => a.path.compareTo(b.path));
    _dosyalar = l;
    if (_secili != null && !l.any((f) => f.path == _secili!.path)) {
      _secili = null;
    }
    _yenile();
  }

  Future<void> _kuralKontrol() async {
    final kl = _kl;
    if (kl == null) return;
    final k = await Kurallar.yukle(kl.kuralDosyasi);
    _kuralBilgi = k.uyari ??
        'Kural dosyası hazır: ${k.maddeSayisi} madde, ${k.metinSayisi} metin kuralı, ${k.elementSayisi} element.';
    _yenile();
  }

  Future<void> _hazirEkle() async {
    final kl = _kl;
    if (kl == null) return;
    final k = await Kurallar.yukle(kl.kuralDosyasi);
    if (k.uyari != null) {
      _mesaj('kural.json okunamadı, önce yazım hatasını düzelt.');
      return;
    }
    final n = k.hazirlariBirlestir();
    if (n > 0) await k.kaydet(kl.kuralDosyasi);
    await _kuralKontrol();
    _mesaj(n > 0
        ? '$n yeni hazır madde eklendi. Mevcut adlarına dokunulmadı.'
        : 'Eklenecek yeni hazır madde yok.');
  }

  Future<void> _basla() async {
    final kl = _kl;
    final dosya = _secili;
    if (kl == null || dosya == null) {
      _mesaj('Önce listeden bir dosya seç.');
      return;
    }
    setState(() {
      _calisiyor = true;
      _durum = 'Başlıyor...';
      _sonuc = null;
    });
    final sec = FormatSecenek()
      ..bicim = _bicim
      ..mod = _mod
      ..formulGoster = _formulGoster
      ..atomAyrinti = _atomAyrinti
      ..ham = _ham
      ..maxSatir = int.tryParse(_maxSatir.text.trim()) ?? 5000
      ..maxYeni = int.tryParse(_maxYeni.text.trim()) ?? 500
      ..online = _online
      ..maxOnline = int.tryParse(_maxOnline.text.trim()) ?? 100;
    final aktifArka = _mod == 2 && _online;
    try {
      final kural = await Kurallar.yukle(kl.kuralDosyasi);
      final isl = Isleyici(kural, sec, kl, (m) {
        _durum = m;
        _yenile();
      });
      _isl = isl;
      if (aktifArka) await arkaPlanBaslat();
      final sonuc = await isl.calis(dosya);
      _sonuc = sonuc;
      _durum = sonuc.mesaj;
    } catch (e) {
      _durum = 'Hata: $e';
    } finally {
      if (aktifArka) await arkaPlanDurdur();
      _calisiyor = false;
      await _kuralKontrol();
      _yenile();
    }
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

  Widget _sayi(TextEditingController c, String etiket, String ipucu) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
              labelText: etiket, helperText: ipucu, helperMaxLines: 3),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final kl = _kl;
    final sonuc = _sonuc;
    return Scaffold(
      appBar: AppBar(title: const Text('Format okuyucu')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            _baslik('Klasörler'),
            if (kl == null)
              Text(_durum.isEmpty ? 'Hazırlanıyor...' : _durum)
            else ...[
              const Text('Okunacak dosyaları buraya koy:',
                  style: TextStyle(fontSize: 12)),
              SelectableText(kl.girdi.path,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text('Kural dosyası (metin düzenleyiciyle düzenlenir):',
                  style: TextStyle(fontSize: 12)),
              SelectableText(kl.kuralDosyasi.path,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text('Sonuçlar buraya yazılır:',
                  style: TextStyle(fontSize: 12)),
              SelectableText(kl.cikti.path,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(_kuralBilgi, style: const TextStyle(fontSize: 12)),
            ],
            _baslik('Dosya seç'),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _dosyalariYenile,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Listeyi yenile'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _kuralKontrol,
                  child: const Text('Kural dosyasını kontrol et'),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: _hazirEkle,
              icon: const Icon(Icons.library_add_outlined),
              label: const Text('Hazır maddeleri kural dosyasına ekle'),
            ),
            if (_dosyalar.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                    'Girdi klasörü boş. Dosyalarını dosya yöneticisiyle oraya kopyala, sonra "Listeyi yenile"ye bas.',
                    style: TextStyle(fontSize: 12)),
              ),
            for (final f in _dosyalar)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                selected: _secili?.path == f.path,
                leading: Icon(_secili?.path == f.path
                    ? Icons.check_circle
                    : Icons.insert_drive_file_outlined),
                title: Text(f.uri.pathSegments.last),
                subtitle: Text(
                    '${(f.lengthSync() / 1024).toStringAsFixed(1)} KB'),
                onTap: () => setState(() => _secili = f),
              ),
            _baslik('Ne yapılsın?'),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 0, label: Text('Oku')),
                ButtonSegment(value: 1, label: Text('Çevir')),
                ButtonSegment(value: 2, label: Text('Toplu tanımla')),
              ],
              selected: {_mod},
              onSelectionChanged: (s) => setState(() => _mod = s.first),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 8),
              child: Text(
                _mod == 0
                    ? 'Oku: Her maddenin formülünü, molar kütlesini ve adını açıklayarak yazar.'
                    : (_mod == 1
                        ? 'Çevir: Kural dosyasındaki kodları ve madde adlarını uygulayıp dosyayı kısa, okunur yazıya çevirir. ORD kayıtları 3-4 satıra iner.'
                        : 'Toplu tanımla: Dosyadaki bilinmeyen maddeleri kural.json içine ekler (formül ve molar kütle ile). İstersen adlarını PubChem\'den internetle sorar.'),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const Text('Biçim', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                for (final b in Bicim.values)
                  ChoiceChip(
                    label: Text(bicimAdi(b), style: const TextStyle(fontSize: 12)),
                    selected: _bicim == b,
                    onSelected: (_) => setState(() => _bicim = b),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_mod == 1)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Adı bilinmeyenleri formülle göster'),
                subtitle: const Text('Kapalıysa bilinmeyen maddelerin SMILES yazısı olduğu gibi kalır.'),
                value: _formulGoster,
                onChanged: (v) => setState(() => _formulGoster = v),
              ),
            if (_mod == 0) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Atom ayrıntısı ekle'),
                subtitle: const Text('Her maddenin atomlarını ad ve atom numarasıyla yazar.'),
                value: _atomAyrinti,
                onChanged: (v) => setState(() => _atomAyrinti = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('ORD ham dökümünü ekle'),
                subtitle: const Text('ORD kayıtlarında bilinmeyen alanları da görmek için.'),
                value: _ham,
                onChanged: (v) => setState(() => _ham = v),
              ),
            ],
            if (_mod == 2) ...[
              _sayi(_maxYeni, 'En fazla yeni madde', 'Bu çalıştırmada kural dosyasına en çok bu kadar yeni madde eklenir.'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Çevrimiçi ad sor (PubChem)'),
                subtitle: const Text('İnternet gerekir. Saniyede 3 sorgu. Bulunamayanlar işaretlenir, tekrar sorulmaz.'),
                value: _online,
                onChanged: (v) => setState(() => _online = v),
              ),
              if (_online)
                _sayi(_maxOnline, 'En fazla sorgu sayısı', 'Bu çalıştırmada en çok bu kadar madde sorulur. Tekrar çalıştırınca kaldığı yerden sürer.'),
            ],
            _sayi(_maxSatir, 'En fazla satır (0 = hepsi)', 'Büyük dosyalarda önce küçük bir sayıyla dene.'),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (_calisiyor || kl == null) ? null : _basla,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Başlat'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _calisiyor ? () => _isl?.dur = true : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Durdur'),
                  ),
                ),
              ],
            ),
            if (_calisiyor) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_durum.isNotEmpty && kl != null) ...[
              const SizedBox(height: 12),
              Text(_durum),
            ],
            if (sonuc != null) ...[
              _baslik('Sonuç'),
              Text(
                  'Biçim: ${bicimAdi(sonuc.bicim ?? Bicim.metin)}   Okunan satır: ${sonuc.okunan}   Yazılan: ${sonuc.yazilan}   Sorunlu: ${sonuc.hatali}'
                  '${_mod == 2 ? '   Yeni madde: ${sonuc.yeniMadde}   Ad bulunan: ${sonuc.adBulunan}' : ''}',
                  style: const TextStyle(fontSize: 12)),
              if (sonuc.cikti != null) ...[
                const SizedBox(height: 6),
                const Text('Çıktı dosyası:', style: TextStyle(fontSize: 12)),
                SelectableText(sonuc.cikti!,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
              if (sonuc.onizleme.isNotEmpty)
                ExpansionTile(
                  title: const Text('Önizleme (ilk satırlar)'),
                  initiallyExpanded: true,
                  tilePadding: EdgeInsets.zero,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SelectableText(sonuc.onizleme.join('\n'),
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
