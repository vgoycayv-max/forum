// Kimya çekirdeği (sürüm 8)
//  1) Element tablosu (sembol, Türkçe/İngilizce ad, atom numarası, atom kütlesi)
//  2) SMILES okuyucu: formül ve molar kütle hesaplar (internetsiz)
//  3) ORD (Open Reaction Database) kayıtlarını çözen protobuf okuyucu
//  4) Sık kullanılan maddelerin hazır sözlüğü

import 'dart:convert';
import 'dart:typed_data';

/// SMILES yazısını madde adına çeviren işlev (bulamazsa null).
typedef IsimBulucu = String? Function(String smiles);

// ---------------------------------------------------------------------------
// 1) ELEMENT TABLOSU
// ---------------------------------------------------------------------------

class ElementBilgi {
  const ElementBilgi(this.no, this.sembol, this.ad, this.adEn, this.kutle);
  final int no;
  final String sembol;
  final String ad;
  final String adEn;
  final double kutle;
}

// atom_no,sembol,Türkçe ad,İngilizce ad,atom kütlesi (g/mol)
const String _elementTablosu = '''
1,H,Hidrojen,Hydrogen,1.008
2,He,Helyum,Helium,4.0026
3,Li,Lityum,Lithium,6.94
4,Be,Berilyum,Beryllium,9.0122
5,B,Bor,Boron,10.81
6,C,Karbon,Carbon,12.011
7,N,Azot,Nitrogen,14.007
8,O,Oksijen,Oxygen,15.999
9,F,Flor,Fluorine,18.998
10,Ne,Neon,Neon,20.18
11,Na,Sodyum,Sodium,22.99
12,Mg,Magnezyum,Magnesium,24.305
13,Al,Alüminyum,Aluminium,26.982
14,Si,Silisyum,Silicon,28.085
15,P,Fosfor,Phosphorus,30.974
16,S,Kükürt,Sulfur,32.06
17,Cl,Klor,Chlorine,35.45
18,Ar,Argon,Argon,39.948
19,K,Potasyum,Potassium,39.098
20,Ca,Kalsiyum,Calcium,40.078
21,Sc,Skandiyum,Scandium,44.956
22,Ti,Titanyum,Titanium,47.867
23,V,Vanadyum,Vanadium,50.942
24,Cr,Krom,Chromium,51.996
25,Mn,Manganez,Manganese,54.938
26,Fe,Demir,Iron,55.845
27,Co,Kobalt,Cobalt,58.933
28,Ni,Nikel,Nickel,58.693
29,Cu,Bakır,Copper,63.546
30,Zn,Çinko,Zinc,65.38
31,Ga,Galyum,Gallium,69.723
32,Ge,Germanyum,Germanium,72.63
33,As,Arsenik,Arsenic,74.922
34,Se,Selenyum,Selenium,78.971
35,Br,Brom,Bromine,79.904
36,Kr,Kripton,Krypton,83.798
37,Rb,Rubidyum,Rubidium,85.468
38,Sr,Stronsiyum,Strontium,87.62
39,Y,İtriyum,Yttrium,88.906
40,Zr,Zirkonyum,Zirconium,91.224
41,Nb,Niyobyum,Niobium,92.906
42,Mo,Molibden,Molybdenum,95.95
43,Tc,Teknesyum,Technetium,98
44,Ru,Rutenyum,Ruthenium,101.07
45,Rh,Rodyum,Rhodium,102.906
46,Pd,Paladyum,Palladium,106.42
47,Ag,Gümüş,Silver,107.868
48,Cd,Kadmiyum,Cadmium,112.414
49,In,İndiyum,Indium,114.818
50,Sn,Kalay,Tin,118.71
51,Sb,Antimon,Antimony,121.76
52,Te,Tellür,Tellurium,127.6
53,I,İyot,Iodine,126.904
54,Xe,Ksenon,Xenon,131.293
55,Cs,Sezyum,Caesium,132.905
56,Ba,Baryum,Barium,137.327
57,La,Lantan,Lanthanum,138.905
58,Ce,Seryum,Cerium,140.116
59,Pr,Praseodim,Praseodymium,140.908
60,Nd,Neodim,Neodymium,144.242
61,Pm,Prometyum,Promethium,145
62,Sm,Samaryum,Samarium,150.36
63,Eu,Evropiyum,Europium,151.964
64,Gd,Gadolinyum,Gadolinium,157.25
65,Tb,Terbiyum,Terbium,158.925
66,Dy,Disprozyum,Dysprosium,162.5
67,Ho,Holmiyum,Holmium,164.93
68,Er,Erbiyum,Erbium,167.259
69,Tm,Tülyum,Thulium,168.934
70,Yb,İterbiyum,Ytterbium,173.045
71,Lu,Lütesyum,Lutetium,174.967
72,Hf,Hafniyum,Hafnium,178.49
73,Ta,Tantal,Tantalum,180.948
74,W,Tungsten,Tungsten,183.84
75,Re,Renyum,Rhenium,186.207
76,Os,Osmiyum,Osmium,190.23
77,Ir,İridyum,Iridium,192.217
78,Pt,Platin,Platinum,195.084
79,Au,Altın,Gold,196.967
80,Hg,Cıva,Mercury,200.592
81,Tl,Talyum,Thallium,204.38
82,Pb,Kurşun,Lead,207.2
83,Bi,Bizmut,Bismuth,208.98
84,Po,Polonyum,Polonium,209
85,At,Astatin,Astatine,210
86,Rn,Radon,Radon,222
90,Th,Toryum,Thorium,232.038
92,U,Uranyum,Uranium,238.029
''';

Map<String, ElementBilgi> _elementleriOku() {
  final m = <String, ElementBilgi>{};
  for (final satir in _elementTablosu.split('\n')) {
    final p = satir.trim().split(',');
    if (p.length < 5) continue;
    m[p[1]] = ElementBilgi(
        int.parse(p[0]), p[1], p[2], p[3], double.parse(p[4]));
  }
  return m;
}

final Map<String, ElementBilgi> elementler = _elementleriOku();

// ---------------------------------------------------------------------------
// 2) SMILES OKUYUCU (formül + molar kütle)
// ---------------------------------------------------------------------------

class _Atom {
  _Atom(this.sym, this.arom, this.parantez, this.h);
  final String sym;
  final bool arom;
  final bool parantez; // köşeli parantez içinde mi? ([N+], [nH] gibi)
  final int h; // köşeli parantezde yazılan hidrojen sayısı
  int bag = 0; // bağ sayısı toplamı (aromatik bağ = 1)
}

class SmilesSonucu {
  SmilesSonucu(this.atomlar, this.yuk, this.hata);
  final Map<String, int> atomlar; // element -> adet (hidrojen dahil)
  final int yuk; // toplam yük
  final String? hata;

  bool get gecerli => hata == null && atomlar.isNotEmpty;
  String get formul => hillFormul(atomlar);
  double get kutle => kutleHesapla(atomlar);
}

const Map<String, List<int>> _degerlik = {
  'B': [3],
  'C': [4],
  'N': [3, 5],
  'O': [2],
  'P': [3, 5],
  'S': [2, 4, 6],
  'F': [1],
  'Cl': [1],
  'Br': [1],
  'I': [1],
};

final RegExp _parantezAtom = RegExp(
    r'^(\d*)(Cl|Br|[A-Z][a-z]?|[a-z][a-z]?|\*)(@{0,2})(?:H(\d*))?([+-]+\d*)?(?::\d+)?$');

/// Boşlukları siler. ("C C O" -> "CCO")
String bosluksuz(String s) => s.replaceAll(RegExp(r'\s+'), '');

/// SMILES yazısını çözer; formülü, molar kütleyi ve yükü hesaplar.
SmilesSonucu smilesCoz(String ham) {
  final smi = bosluksuz(ham);
  try {
    if (smi.isEmpty) throw const FormatException('boş');
    final atomlar = <_Atom>[];
    final yigin = <int>[];
    final halka = <int, List<int?>>{}; // rakam -> [atom, bağ derecesi]
    int? onceki;
    int? bekleyen;
    var yuk = 0;
    var i = 0;
    final n = smi.length;

    void bagla(int a, int b, int o) {
      atomlar[a].bag += o;
      atomlar[b].bag += o;
    }

    void ekle(String sym, bool arom, bool parantez, int h) {
      atomlar.add(_Atom(sym, arom, parantez, h));
      final idx = atomlar.length - 1;
      if (onceki != null) bagla(onceki!, idx, bekleyen ?? 1);
      onceki = idx;
      bekleyen = null;
    }

    while (i < n) {
      final c = smi[i];
      if (c == '[') {
        final j = smi.indexOf(']', i);
        if (j < 0) throw const FormatException('] eksik');
        final govde = smi.substring(i + 1, j);
        i = j + 1;
        final m = _parantezAtom.firstMatch(govde);
        if (m == null) throw FormatException('köşeli atom: $govde');
        final sym = m.group(2)!;
        var h = 0;
        final hg = m.group(4);
        if (hg != null) h = hg.isEmpty ? 1 : int.parse(hg);
        var ch = 0;
        final t = m.group(5);
        if (t != null && t.isNotEmpty) {
          final isaret = t[0] == '+' ? 1 : -1;
          final geri = t.replaceFirst(RegExp(r'^[+-]+'), '');
          ch = geri.isNotEmpty ? isaret * int.parse(geri) : isaret * t.length;
        }
        final arom = sym.codeUnitAt(0) >= 97 && sym.codeUnitAt(0) <= 122;
        final simge = arom ? sym[0].toUpperCase() + sym.substring(1) : sym;
        ekle(simge, arom, true, h);
        yuk += ch;
        continue;
      }
      if (c == '(') {
        if (onceki == null) throw const FormatException('( başta');
        yigin.add(onceki!);
        i++;
        continue;
      }
      if (c == ')') {
        onceki = yigin.removeLast();
        i++;
        continue;
      }
      if (c == '.') {
        onceki = null;
        bekleyen = null;
        i++;
        continue;
      }
      if ('-=#:\$/\\~'.contains(c)) {
        bekleyen = c == '=' ? 2 : (c == '#' ? 3 : (c == '\$' ? 4 : (c == '~' ? 0 : 1)));
        i++;
        continue;
      }
      final kod = c.codeUnitAt(0);
      if ((kod >= 48 && kod <= 57) || c == '%') {
        int d;
        if (c == '%') {
          d = int.parse(smi.substring(i + 1, i + 3));
          i += 3;
        } else {
          d = kod - 48;
          i++;
        }
        if (onceki == null) throw const FormatException('halka rakamı başta');
        if (halka.containsKey(d)) {
          final a = halka.remove(d)!;
          final o = bekleyen ?? a[1] ?? 1;
          bagla(a[0]!, onceki!, o);
          bekleyen = null;
        } else {
          halka[d] = [onceki, bekleyen];
          bekleyen = null;
        }
        continue;
      }
      if (i + 1 < n && (smi.startsWith('Cl', i) || smi.startsWith('Br', i))) {
        ekle(smi.substring(i, i + 2), false, false, 0);
        i += 2;
        continue;
      }
      if ('BCNOPSFI'.contains(c)) {
        ekle(c, false, false, 0);
        i++;
        continue;
      }
      if ('bcnops'.contains(c)) {
        ekle(c.toUpperCase(), true, false, 0);
        i++;
        continue;
      }
      if (c == '*') {
        ekle('*', false, false, 0);
        i++;
        continue;
      }
      throw FormatException('tanınmayan karakter: $c');
    }
    if (yigin.isNotEmpty) throw const FormatException('parantez kapanmadı');
    if (halka.isNotEmpty) throw const FormatException('halka kapanmadı');

    final say = <String, int>{};
    for (final a in atomlar) {
      say[a.sym] = (say[a.sym] ?? 0) + 1;
      var h = a.h;
      final vs = _degerlik[a.sym];
      if (!a.parantez && vs != null) {
        var baz = a.bag;
        if (a.arom && (a.sym == 'C' || a.sym == 'N' || a.sym == 'P' || a.sym == 'B')) {
          if (!(a.sym == 'N' && baz >= 3)) baz += 1;
        }
        h = 0;
        for (final v in vs) {
          if (v >= baz) {
            h = v - baz;
            break;
          }
        }
      }
      if (h > 0) say['H'] = (say['H'] ?? 0) + h;
    }
    return SmilesSonucu(say, yuk, null);
  } catch (e) {
    return SmilesSonucu(<String, int>{}, 0, e.toString());
  }
}

/// Hill sırası: önce C, sonra H, sonra alfabetik. (Karbon yoksa hepsi alfabetik.)
String hillFormul(Map<String, int> a) {
  final anahtarlar = a.keys.toList()..sort();
  final sira = <String>[];
  if (a.containsKey('C')) {
    sira.add('C');
    if (a.containsKey('H')) sira.add('H');
    sira.addAll(anahtarlar.where((k) => k != 'C' && k != 'H'));
  } else {
    sira.addAll(anahtarlar);
  }
  return sira.map((k) => (a[k] ?? 0) > 1 ? '$k${a[k]}' : k).join();
}

double kutleHesapla(Map<String, int> a) {
  var t = 0.0;
  a.forEach((k, v) {
    t += (elementler[k]?.kutle ?? 0) * v;
  });
  return t;
}

/// Girenler ile ürünler arasındaki atom farkını anlatır.
String atomFarki(Map<String, int> giren, Map<String, int> urun) {
  final kaybolan = <String, int>{};
  final eklenen = <String, int>{};
  final hepsi = <String>{...giren.keys, ...urun.keys};
  for (final k in hepsi) {
    final d = (giren[k] ?? 0) - (urun[k] ?? 0);
    if (d > 0) kaybolan[k] = d;
    if (d < 0) eklenen[k] = -d;
  }
  if (kaybolan.isEmpty && eklenen.isEmpty) return 'atomlar dengede';
  final p = <String>[];
  if (kaybolan.isNotEmpty) p.add('kaybolan: ${hillFormul(kaybolan)}');
  if (eklenen.isNotEmpty) {
    p.add('girenlerde olmayıp üründe olan: ${hillFormul(eklenen)} (listede olmayan bir ayıraç/çözücü gerekmiş olabilir)');
  }
  return p.join('; ');
}

/// Bu yazı bir SMILES gibi okunuyor mu? (düz yazı satırlarını ayırt etmek için)
bool smilesGibi(String ham) {
  final s = bosluksuz(ham);
  if (s.isEmpty || s.length > 2000) return false;
  if (!RegExp(r'^[A-Za-z0-9@+\-\[\]\(\)\\/=#$:.%*~]+$').hasMatch(s)) return false;
  if (!RegExp(r'[A-Za-z]').hasMatch(s)) return false;
  return smilesCoz(s).gecerli;
}

// ---------------------------------------------------------------------------
// 3) ORD (Open Reaction Database) - protobuf okuyucu
// ---------------------------------------------------------------------------
// ORD kayıtları "protobuf" denen ikili biçimde saklanır. Dosyada bunlar
// [10, 21, 8, 1, ...] gibi bir sayı listesi olarak görünür. Aşağıdaki kod bu
// sayıları alan alan açar. Alan numaraları ORD'nin resmi şemasına göre.

class PbAlan {
  PbAlan(this.no, this.tel, this.sayi, this.bayt);
  final int no; // alan numarası
  final int tel; // 0 tam sayı, 1 sabit64, 2 uzunluklu (yazı/iç içe kayıt), 5 sabit32 (ondalık)
  final int? sayi;
  final List<int>? bayt;
}

class PbSonuc {
  PbSonuc(this.alanlar, this.kesik);
  final List<PbAlan> alanlar;
  final bool kesik; // veri yarım kalmış mı
}

PbSonuc pbCoz(List<int> b) {
  final out = <PbAlan>[];
  var i = 0;
  var kesik = false;

  int? varint() {
    var r = 0;
    var sh = 0;
    while (true) {
      if (i >= b.length) return null;
      final c = b[i++];
      if (sh < 64) r |= (c & 0x7f) << sh;
      if ((c & 0x80) == 0) break;
      sh += 7;
    }
    return r;
  }

  while (i < b.length) {
    final k = varint();
    if (k == null) {
      kesik = true;
      break;
    }
    final no = k >> 3;
    final tel = k & 7;
    if (tel == 0) {
      final v = varint();
      if (v == null) {
        kesik = true;
        break;
      }
      out.add(PbAlan(no, 0, v, null));
    } else if (tel == 2) {
      final n = varint();
      if (n == null) {
        kesik = true;
        break;
      }
      if (i + n > b.length) {
        out.add(PbAlan(no, 2, null, b.sublist(i)));
        kesik = true;
        break;
      }
      out.add(PbAlan(no, 2, null, b.sublist(i, i + n)));
      i += n;
    } else if (tel == 5) {
      if (i + 4 > b.length) {
        kesik = true;
        break;
      }
      out.add(PbAlan(no, 5, null, b.sublist(i, i + 4)));
      i += 4;
    } else if (tel == 1) {
      if (i + 8 > b.length) {
        kesik = true;
        break;
      }
      out.add(PbAlan(no, 1, null, b.sublist(i, i + 8)));
      i += 8;
    } else {
      kesik = true; // bu bir protobuf değil ya da bozuk
      break;
    }
  }
  return PbSonuc(out, kesik);
}

double _pbFloat(List<int> b) =>
    Uint8List.fromList(b).buffer.asByteData().getFloat32(0, Endian.little);

String _pbYazi(List<int> b) => utf8.decode(b, allowMalformed: true);

List<List<int>> _hepsi(List<PbAlan> a, int no) =>
    [for (final x in a) if (x.no == no && x.tel == 2 && x.bayt != null) x.bayt!];

List<int>? _ilk(List<PbAlan> a, int no) {
  for (final x in a) {
    if (x.no == no && x.tel == 2 && x.bayt != null) return x.bayt;
  }
  return null;
}

/// Ondalık (float) ya da tam sayı olarak okur.
double? _say(List<PbAlan> a, int no) {
  for (final x in a) {
    if (x.no != no) continue;
    if (x.tel == 5 && x.bayt != null) return _pbFloat(x.bayt!);
    if (x.tel == 0 && x.sayi != null) return x.sayi!.toDouble();
  }
  return null;
}

String _fmt(double? x) {
  if (x == null) return '';
  if (x == x.roundToDouble() && x.abs() < 1e9) return x.toInt().toString();
  return double.parse(x.toStringAsPrecision(4)).toString();
}

/// Metinden bayt listesi çıkarır: [10, 21, ...] ya da onaltılık (hex) ya da base64.
List<int> ordBaytlar(String metin) {
  final t = metin.trim();
  if (t.startsWith('[') || RegExp(r'^\d+\s*,').hasMatch(t)) {
    return [
      for (final m in RegExp(r'\d+').allMatches(t)) int.parse(m.group(0)!) & 255
    ];
  }
  if (t.length.isEven && RegExp(r'^[0-9a-fA-F]+$').hasMatch(t)) {
    return [
      for (var i = 0; i < t.length; i += 2) int.parse(t.substring(i, i + 2), radix: 16)
    ];
  }
  try {
    return base64Decode(t);
  } catch (_) {
    return <int>[];
  }
}

const Map<int, String> _rol = {
  0: '?',
  1: 'reaktif',
  2: 'ayıraç',
  3: 'çözücü',
  4: 'katalizör',
  5: 'işlem sonrası',
  6: 'iç standart',
  7: 'gerçek standart',
  8: 'ürün',
};
const Map<int, String> _molBirim = {1: 'mol', 2: 'mmol', 3: 'µmol', 4: 'nmol'};
const Map<int, double> _molCarpan = {1: 1, 2: 1e-3, 3: 1e-6, 4: 1e-9};
const Map<int, String> _kutleBirim = {1: 'g', 2: 'mg', 3: 'µg', 4: 'kg'};
const Map<int, String> _hacimBirim = {1: 'L', 2: 'mL', 3: 'µL', 4: 'nL'};
const Map<int, String> _sicaklikBirim = {1: '°C', 2: '°F', 3: 'K'};
const Map<int, String> _basincBirim = {
  1: 'bar',
  2: 'atm',
  3: 'psi',
  4: 'kPa',
  5: 'mmHg',
  6: 'torr'
};
const Map<int, String> _zamanBirim = {1: 'gün', 2: 'saat', 3: 'dakika', 4: 'saniye'};
// Ürün ölçümü türleri. Örnek verilerde verim yüzdeleri 3 koduyla geliyor; bu
// yüzden sıra "1 özel, 2 kimlik, 3 verim, 4 seçicilik ..." olarak alındı.
const Map<int, String> _olcumTuru = {
  1: 'özel ölçüm',
  2: 'kimlik',
  3: 'verim',
  4: 'seçicilik',
  5: 'saflık',
  6: 'alan',
  7: 'sayım',
  8: 'şiddet',
  9: 'miktar',
};

class OrdOzet {
  OrdOzet(this.satirlar, this.smilesler, this.kesik);
  final List<String> satirlar;
  final List<String> smilesler; // kayıttaki bütün maddelerin SMILES'ları
  final bool kesik;
}

class _OrdMadde {
  String? smiles;
  final List<String> adlar = [];
}

_OrdMadde _maddeKimlik(List<List<int>> kimlikler) {
  final m = _OrdMadde();
  for (final k in kimlikler) {
    final a = pbCoz(k).alanlar;
    final tur = _say(a, 1)?.toInt() ?? 0;
    final v = _ilk(a, 3);
    if (v == null) continue;
    final t = _pbYazi(v);
    if (tur == 2 || tur == 10) {
      m.smiles ??= t;
    } else if (tur == 5 || tur == 6 || tur == 7 || tur == 1) {
      m.adlar.add(t);
    }
  }
  return m;
}

String _miktar(List<int>? b) {
  if (b == null) return '';
  final a = pbCoz(b).alanlar;
  for (final x in a) {
    if (x.tel == 2 && x.bayt != null && (x.no == 1 || x.no == 2 || x.no == 3)) {
      final u = pbCoz(x.bayt!).alanlar;
      final deger = _say(u, 1);
      final birim = _say(u, 3)?.toInt();
      final tablo = x.no == 1 ? _kutleBirim : (x.no == 2 ? _molBirim : _hacimBirim);
      return '${_fmt(deger)} ${tablo[birim] ?? 'birim$birim'}';
    }
    if (x.no == 4) return 'ölçülmemiş';
  }
  return '';
}

/// Miktar mol cinsindense gram karşılığını hesaplar.
double? _molDeger(List<int>? b) {
  if (b == null) return null;
  for (final x in pbCoz(b).alanlar) {
    if (x.no == 2 && x.tel == 2 && x.bayt != null) {
      final u = pbCoz(x.bayt!).alanlar;
      final deger = _say(u, 1);
      final birim = _say(u, 3)?.toInt();
      final c = _molCarpan[birim];
      if (deger != null && c != null) return deger * c;
    }
  }
  return null;
}

String _olcuTek(List<int>? b, Map<int, String> birimler) {
  if (b == null) return '';
  final a = pbCoz(b).alanlar;
  final d = _say(a, 1);
  final p = _say(a, 2);
  final u = _say(a, 3)?.toInt();
  if (d == null) return '';
  return '${_fmt(d)}${p != null && p > 0 ? ' ± ${_fmt(p)}' : ''} ${birimler[u] ?? ''}'.trim();
}

/// Birim kodunun anlamından emin olunamayan ölçüler için (süre, basınç):
/// tahmini birimi soru işaretiyle ve kodunu da yazarak gösterir.
String _olcuBelirsiz(List<int>? b, Map<int, String> tahmin) {
  if (b == null) return '';
  final a = pbCoz(b).alanlar;
  final d = _say(a, 1);
  if (d == null) return '';
  final p = _say(a, 2);
  final u = _say(a, 3)?.toInt();
  final ad = tahmin[u];
  final birim = ad == null ? 'birim kodu $u' : '$ad? (birim kodu $u)';
  return '${_fmt(d)}${p != null && p > 0 ? ' ± ${_fmt(p)}' : ''} $birim';
}

String _adGoster(_OrdMadde m, IsimBulucu? isim, [bool formulGoster = false]) {
  final s = m.smiles;
  final ad = (s != null ? isim?.call(s) : null) ?? (m.adlar.isNotEmpty ? m.adlar.first : null);
  if (ad != null) return ad;
  if (s == null) return '(adı yok)';
  if (formulGoster) {
    final r = smilesCoz(s);
    if (r.gecerli) return r.formul;
  }
  return s.length > 70 ? '${s.substring(0, 67)}...' : s;
}

String _maddeSatiri(_OrdMadde m, IsimBulucu? isim,
    {double? mol, bool formulGoster = false}) {
  final ad = _adGoster(m, isim, formulGoster);
  final s = m.smiles;
  if (s == null) return ad;
  final r = smilesCoz(s);
  if (!r.gecerli) return ad;
  var t = ad == r.formul
      ? '$ad (${r.kutle.toStringAsFixed(2)} g/mol'
      : '$ad (${r.formul}, ${r.kutle.toStringAsFixed(2)} g/mol';
  if (mol != null) {
    final g = mol * r.kutle;
    t += ', yaklaşık ${double.parse(g.toStringAsPrecision(3))} g';
  }
  return '$t)';
}

/// Ham protobuf ağacını girintili metin olarak döker (bilinmeyen alanları görmek için).
void pbDok(List<int> b, int girinti, List<String> out, [int derinlik = 0]) {
  final sonuc = pbCoz(b);
  final bosluk = ' ' * girinti;
  for (final x in sonuc.alanlar) {
    if (x.tel == 0) {
      out.add('$bosluk${x.no}: ${x.sayi}');
    } else if (x.tel == 5) {
      out.add('$bosluk${x.no}: ${_fmt(_pbFloat(x.bayt!))} (ondalık)');
    } else if (x.tel == 1) {
      out.add('$bosluk${x.no}: (8 bayt)');
    } else {
      final v = x.bayt ?? const <int>[];
      final yazilabilir = v.isNotEmpty && v.every((c) => c >= 32 && c < 127);
      if (yazilabilir) {
        final t = _pbYazi(v);
        out.add('$bosluk${x.no}: "${t.length > 200 ? '${t.substring(0, 200)}...' : t}"');
      } else if (v.isEmpty) {
        out.add('$bosluk${x.no}: {}');
      } else if (derinlik < 10) {
        out.add('$bosluk${x.no}: {');
        pbDok(v, girinti + 2, out, derinlik + 1);
        out.add('$bosluk}');
      }
    }
  }
  if (sonuc.kesik && derinlik == 0) out.add('$bosluk(veri burada yarım kalmış)');
}

class _Girdi {
  _Girdi(this.anahtar, this.rol, this.sinirlayici, this.miktar, this.mol, this.madde);
  final String anahtar;
  final String rol;
  final bool sinirlayici;
  final String miktar;
  final double? mol;
  final _OrdMadde madde;
}

class _Urun {
  _Urun(this.madde, this.istenen);
  final _OrdMadde madde;
  final bool istenen;
  final List<String> olcumler = [];
}

/// Bir ORD kaydını okunur bir özete çevirir.
///  kisa: true ise tepkimeyi 3-4 satırda anlatır ("Çevir" modu için).
///  formulGoster: adı bilinmeyen maddeleri SMILES yerine formülle gösterir.
OrdOzet ordOzetle(List<int> bayt,
    {String kimlik = '',
    IsimBulucu? isim,
    bool ham = false,
    bool kisa = false,
    bool formulGoster = false}) {
  final smilesler = <String>[];
  final top = pbCoz(bayt);
  final a = top.alanlar;

  // Kimlikler (1)
  final kimlikler = <String>[];
  var tur = '';
  for (final k in _hepsi(a, 1)) {
    final ka = pbCoz(k).alanlar;
    final det = _ilk(ka, 2);
    final val = _ilk(ka, 3);
    if (val == null) continue;
    final d = det != null ? _pbYazi(det) : 'kimlik';
    kimlikler.add('$d: ${_pbYazi(val)}');
    if (d == 'reaction type') tur = _pbYazi(val);
  }

  // Girdiler (2): anahtar -> ReactionInput
  final girdiler = <_Girdi>[];
  for (final e in _hepsi(a, 2)) {
    final ea = pbCoz(e).alanlar;
    final anahtar = _ilk(ea, 1);
    final deger = _ilk(ea, 2);
    final ad = anahtar != null ? _pbYazi(anahtar) : '?';
    if (deger == null) continue;
    for (final c in _hepsi(pbCoz(deger).alanlar, 1)) {
      final ca = pbCoz(c).alanlar;
      final madde = _maddeKimlik(_hepsi(ca, 1));
      if (madde.smiles != null) smilesler.add(madde.smiles!);
      final amount = _ilk(ca, 2);
      girdiler.add(_Girdi(
          ad,
          _rol[_say(ca, 3)?.toInt() ?? 0] ?? '?',
          _say(ca, 4) == 1,
          _miktar(amount),
          _molDeger(amount),
          madde));
    }
  }

  // Koşullar (4)
  final kosullar = <String>[];
  final kosul = _ilk(a, 4);
  if (kosul != null) {
    final ka = pbCoz(kosul).alanlar;
    final sic = _ilk(ka, 1);
    if (sic != null) {
      final t = _olcuTek(_ilk(pbCoz(sic).alanlar, 2), _sicaklikBirim);
      if (t.isNotEmpty) kosullar.add(t);
    }
    final bas = _ilk(ka, 2);
    if (bas != null) {
      final t = _olcuBelirsiz(_ilk(pbCoz(bas).alanlar, 2),
          const {1: 'bar', 2: 'atm', 3: 'psi', 4: 'kpsi', 5: 'Pa', 6: 'kPa'});
      if (t.isNotEmpty) kosullar.add('basınç $t');
    }
    final kar = _ilk(ka, 3);
    if (kar != null) {
      final k2 = pbCoz(kar).alanlar;
      final kd = _ilk(k2, 2);
      final hiz = _ilk(k2, 3);
      final rpm = (hiz != null ? _say(pbCoz(hiz).alanlar, 3) : null) ?? _say(k2, 4);
      final p = <String>[
        if (kd != null) _pbYazi(kd),
        if (rpm != null && rpm > 0) '${_fmt(rpm)} devir/dk',
      ];
      if (p.isNotEmpty) kosullar.add('karıştırma: ${p.join(', ')}');
    }
    if (_say(ka, 7) == 1) kosullar.add('geri soğutucu (reflü)');
    final ph = _say(ka, 8);
    if (ph != null) kosullar.add('pH ${_fmt(ph)}');
    final det = _ilk(ka, 10);
    if (det != null) kosullar.add(_pbYazi(det));
  }

  // İşlem sonrası adımlar (7)
  final islemler = <String>[];
  for (final w in _hepsi(a, 7)) {
    final wa = pbCoz(w).alanlar;
    final det = _ilk(wa, 2);
    final sure = _olcuBelirsiz(
        _ilk(wa, 3), const {1: 'gün', 2: 'saat', 3: 'dakika', 4: 'saniye'});
    final kod = _say(wa, 1)?.toInt();
    final p = <String>[
      if (det != null) _pbYazi(det),
      if (sure.isNotEmpty) 'süre $sure',
    ];
    if (p.isNotEmpty) {
      islemler.add('${p.join(', ')} (işlem türü kodu ${kod ?? '?'})');
    }
  }

  // Sonuçlar (8)
  final sureler = <String>[];
  final urunler = <_Urun>[];
  for (final o in _hepsi(a, 8)) {
    final oa = pbCoz(o).alanlar;
    final zaman = _olcuBelirsiz(
        _ilk(oa, 1), const {1: 'gün', 2: 'saat', 3: 'dakika', 4: 'saniye'});
    if (zaman.isNotEmpty) sureler.add(zaman);
    for (final u in _hepsi(oa, 3)) {
      final ua = pbCoz(u).alanlar;
      final madde = _maddeKimlik(_hepsi(ua, 1));
      if (madde.smiles != null) smilesler.add(madde.smiles!);
      final urun = _Urun(madde, _say(ua, 2) == 1);
      for (final m in _hepsi(ua, 3)) {
        final ma = pbCoz(m).alanlar;
        final turAd = _olcumTuru[_say(ma, 2)?.toInt() ?? 0] ?? 'ölçüm';
        final yuzde = _ilk(ma, 8);
        if (yuzde != null) {
          urun.olcumler.add('$turAd %${_fmt(_say(pbCoz(yuzde).alanlar, 1))}');
        } else {
          final f = _say(ma, 9);
          final sx = _ilk(ma, 10);
          if (f != null) urun.olcumler.add('$turAd ${_fmt(f)}');
          if (sx != null) urun.olcumler.add('$turAd ${_pbYazi(sx)}');
        }
      }
      urunler.add(urun);
    }
  }

  // Kaynak bilgisi (9): deneyi yapan, tarih, DOI, patent, adres
  final kaynak = <String>[];
  final prov = _ilk(a, 9);
  if (prov != null) {
    final pa = pbCoz(prov).alanlar;
    final kisi = _ilk(pa, 1);
    if (kisi != null) {
      final ka = pbCoz(kisi).alanlar;
      final ad = _ilk(ka, 2);
      final kurum = _ilk(ka, 4);
      final t = [
        if (ad != null) _pbYazi(ad),
        if (kurum != null) _pbYazi(kurum),
      ].join(', ');
      if (t.isNotEmpty) kaynak.add(t);
    }
    final tarih = _ilk(pa, 3);
    if (tarih != null) {
      final v = _ilk(pbCoz(tarih).alanlar, 1);
      if (v != null) kaynak.add('deney tarihi ${_pbYazi(v)}');
    }
    final doi = _ilk(pa, 4);
    if (doi != null) kaynak.add('DOI ${_pbYazi(doi)}');
    final patent = _ilk(pa, 5);
    if (patent != null) kaynak.add('patent ${_pbYazi(patent)}');
    final url = _ilk(pa, 6);
    if (url != null) kaynak.add(_pbYazi(url));
  }

  // Kap / düzenek (3)
  var kap = '';
  final kurulum = _ilk(a, 3);
  if (kurulum != null) {
    final ka = pbCoz(kurulum).alanlar;
    final kp = _ilk(ka, 1);
    final p = <String>[];
    if (kp != null) {
      final va = pbCoz(kp).alanlar;
      final det = _ilk(va, 2);
      if (det != null) p.add(_pbYazi(det));
      const tipler = <int, String>{
        2: 'yuvarlak dipli balon',
        3: 'vial (küçük şişe)',
        4: 'kuyucuklu plaka',
        5: 'mikrodalga vial',
        6: 'tüp',
        7: 'sürekli karıştırmalı tank',
        8: 'dolgulu yatak',
      };
      final tipAd = tipler[_say(va, 1)?.toInt()];
      if (tipAd != null && det == null) p.add('$tipAd?');
      final hacim = _olcuTek(_ilk(va, 7), _hacimBirim);
      if (hacim.isNotEmpty) p.add('hacim $hacim');
    }
    if (_say(ka, 2) == 1) p.add('otomatik düzenek');
    final plt = _ilk(ka, 3);
    if (plt != null) p.add(_pbYazi(plt));
    kap = p.join(', ');
  }

  final satirlar = <String>[];
  final baslik = 'Tepkime ${kimlik.isEmpty ? '' : kimlik}'.trim();
  if (kisa) {
    satirlar.add('TARİF — $baslik');
    if (tur.isNotEmpty) satirlar.add('  Tür: $tur');
    satirlar.add('  MALZEMELER');
    for (var i = 0; i < girdiler.length; i++) {
      final g = girdiler[i];
      satirlar.add(
          '    ${i + 1}. ${_maddeSatiri(g.madde, isim, mol: g.mol, formulGoster: formulGoster)} — ${g.miktar.isEmpty ? 'miktar kayıtta yok' : g.miktar} [${g.rol}${g.sinirlayici ? ', sınırlayıcı' : ''}]');
    }
    satirlar.add('  KAP / DÜZENEK: ${kap.isEmpty ? 'kayıtta yok' : kap}');
    satirlar.add('  ADIMLAR');
    var n = 1;
    if (girdiler.isNotEmpty) {
      satirlar.add(
          '    ${n++}. Malzemeleri (1-${girdiler.length}) kaba koy. Ekleme sırası kayıtta yok.');
    }
    if (kosullar.isNotEmpty) {
      satirlar.add('    ${n++}. Koşullar: ${kosullar.join('; ')}.');
    }
    satirlar.add(
        '    ${n++}. Süre: ${sureler.isEmpty ? 'kayıtta yok' : sureler.join('; ')}.');
    for (final w in islemler) {
      satirlar.add('    ${n++}. İşlem sonrası: $w.');
    }
    satirlar.add('  SONUÇ');
    if (urunler.isEmpty) satirlar.add('    Ürün bilgisi kayıtta yok.');
    for (final u in urunler) {
      satirlar.add(
          '    Ürün${u.istenen ? ' (istenen)' : ''}: ${_maddeSatiri(u.madde, isim, formulGoster: formulGoster)}');
      for (final o in u.olcumler) {
        satirlar.add('      $o');
      }
    }
    if (kaynak.isNotEmpty) satirlar.add('  KAYNAK: ${kaynak.join('; ')}');
  } else {
    satirlar.add(baslik);
    for (final k in kimlikler) {
      satirlar.add('  $k');
    }
    if (girdiler.isNotEmpty) satirlar.add('  Girdiler:');
    for (final g in girdiler) {
      final sinir = g.sinirlayici ? ', sınırlayıcı' : '';
      satirlar.add(
          '    • ${g.anahtar} [${g.rol}$sinir] ${g.miktar.isEmpty ? '' : '${g.miktar} — '}${_maddeSatiri(g.madde, isim, mol: g.mol)}');
    }
    if (kosullar.isNotEmpty) satirlar.add('  Koşullar: ${kosullar.join('; ')}');
    for (final w in islemler) {
      satirlar.add('  İşlem sonrası: $w');
    }
    for (final z in sureler) {
      satirlar.add('  Tepkime süresi: $z');
    }
    for (final u in urunler) {
      satirlar.add(
          '  Ürün${u.istenen ? ' (istenen ürün)' : ''}: ${_maddeSatiri(u.madde, isim)}');
      for (final o in u.olcumler) {
        satirlar.add('    $o');
      }
    }
    if (kaynak.isNotEmpty) satirlar.add('  Kaynak: ${kaynak.join('; ')}');
  }

  if (ham) {
    satirlar.add('  --- ham döküm ---');
    pbDok(bayt, 4, satirlar);
  }
  if (top.kesik) {
    satirlar.add('  (Kayıt yarım kalmış: dosya kesilmiş olabilir, görünenler yukarıda)');
  }
  return OrdOzet(satirlar, smilesler, top.kesik);
}

// ---------------------------------------------------------------------------
// 4) HAZIR MADDE SÖZLÜĞÜ
// ---------------------------------------------------------------------------
// Her satır: [Türkçe ad, İngilizce ad, SMILES yazılışı 1, 2, ...]
// Aynı madde birden çok biçimde yazılabildiği için birkaç yazılış verilmiştir.

const List<List<String>> varsayilanMaddeler = [
  ['su', 'water', 'O'],
  ['hidrojen', 'hydrogen', '[H][H]'],
  ['oksijen', 'oxygen', 'O=O'],
  ['azot', 'nitrogen', 'N#N'],
  ['karbondioksit', 'carbon dioxide', 'O=C=O'],
  ['karbonmonoksit', 'carbon monoxide', '[C-]#[O+]'],
  ['amonyak', 'ammonia', 'N'],
  ['hidrojen peroksit', 'hydrogen peroxide', 'OO'],
  ['hidroklorik asit', 'hydrochloric acid', 'Cl'],
  ['sülfürik asit', 'sulfuric acid', 'OS(O)(=O)=O', 'OS(=O)(=O)O'],
  ['nitrik asit', 'nitric acid', 'O[N+](=O)[O-]', 'O=[N+]([O-])O'],
  ['fosforik asit', 'phosphoric acid', 'OP(O)(O)=O', 'OP(=O)(O)O'],
  ['sodyum hidroksit', 'sodium hydroxide', '[OH-].[Na+]', '[Na+].[OH-]', '[Na]O'],
  ['potasyum hidroksit', 'potassium hydroxide', '[OH-].[K+]', '[K+].[OH-]'],
  ['sodyum klorür (sofra tuzu)', 'sodium chloride', '[Na+].[Cl-]', '[Cl-].[Na+]', '[Na]Cl'],
  ['potasyum karbonat', 'potassium carbonate', 'O=C([O-])[O-].[K+].[K+]', '[K+].[K+].[O-]C([O-])=O'],
  ['sodyum karbonat', 'sodium carbonate', 'O=C([O-])[O-].[Na+].[Na+]', '[Na+].[Na+].[O-]C([O-])=O'],
  ['sezyum karbonat', 'cesium carbonate', 'O=C([O-])[O-].[Cs+].[Cs+]', 'C(=O)([O-])[O-].[Cs+].[Cs+]'],
  ['sodyum bikarbonat', 'sodium bicarbonate', 'O=C(O)[O-].[Na+]', '[Na+].OC([O-])=O', 'OC([O-])=O.[Na+]'],
  ['kalsiyum karbonat', 'calcium carbonate', 'O=C([O-])[O-].[Ca+2]', '[Ca+2].[O-]C([O-])=O'],
  ['potasyum permanganat', 'potassium permanganate', 'O=[Mn](=O)(=O)[O-].[K+]', '[K+].[O-][Mn](=O)(=O)=O'],
  ['sodyum hipoklorit', 'sodium hypochlorite', '[Na+].[O-]Cl', '[O-]Cl.[Na+]', 'Cl[O-].[Na+]'],
  ['sodyum borhidrür', 'sodium borohydride', '[BH4-].[Na+]', '[Na+].[BH4-]'],
  ['lityum alüminyum hidrür', 'lithium aluminium hydride', '[Li+].[AlH4-]', '[AlH4-].[Li+]'],
  ['metan', 'methane', 'C'],
  ['etan', 'ethane', 'CC'],
  ['propan', 'propane', 'CCC'],
  ['bütan', 'butane', 'CCCC'],
  ['hekzan', 'hexane', 'CCCCCC'],
  ['siklohekzan', 'cyclohexane', 'C1CCCCC1'],
  ['eten (etilen)', 'ethylene', 'C=C'],
  ['etin (asetilen)', 'acetylene', 'C#C'],
  ['benzen', 'benzene', 'c1ccccc1', 'C1=CC=CC=C1'],
  ['toluen', 'toluene', 'Cc1ccccc1', 'CC1=CC=CC=C1'],
  ['naftalin', 'naphthalene', 'c1ccc2ccccc2c1'],
  ['metanol', 'methanol', 'CO', 'OC'],
  ['etanol', 'ethanol', 'CCO', 'OCC'],
  ['1-propanol', 'propan-1-ol', 'CCCO', 'OCCC'],
  ['2-propanol (izopropanol)', 'propan-2-ol', 'CC(C)O', 'OC(C)C'],
  ['1-bütanol', 'butan-1-ol', 'CCCCO', 'OCCCC'],
  ['etilen glikol', 'ethylene glycol', 'OCCO'],
  ['gliserol', 'glycerol', 'OCC(O)CO'],
  ['aseton', 'acetone', 'CC(C)=O', 'CC(=O)C'],
  ['asetaldehit', 'acetaldehyde', 'CC=O'],
  ['formaldehit', 'formaldehyde', 'C=O'],
  ['formik asit', 'formic acid', 'OC=O', 'O=CO'],
  ['asetik asit', 'acetic acid', 'CC(=O)O', 'OC(C)=O'],
  ['asetik anhidrit', 'acetic anhydride', 'CC(=O)OC(C)=O'],
  ['etil asetat', 'ethyl acetate', 'CCOC(C)=O', 'CC(=O)OCC'],
  ['metil asetat', 'methyl acetate', 'COC(C)=O', 'CC(=O)OC'],
  ['dietil eter', 'diethyl ether', 'CCOCC'],
  ['tetrahidrofuran (THF)', 'tetrahydrofuran', 'C1CCOC1'],
  ['1,4-dioksan', '1,4-dioxane', 'C1COCCO1'],
  ['diklorometan', 'dichloromethane', 'ClCCl'],
  ['kloroform', 'chloroform', 'ClC(Cl)Cl', 'C(Cl)(Cl)Cl'],
  ['karbon tetraklorür', 'carbon tetrachloride', 'ClC(Cl)(Cl)Cl'],
  ['dimetilformamid (DMF)', 'N,N-dimethylformamide', 'CN(C)C=O', 'O=CN(C)C'],
  ['dimetil sülfoksit (DMSO)', 'dimethyl sulfoxide', 'CS(C)=O'],
  ['asetonitril', 'acetonitrile', 'CC#N', 'N#CC'],
  ['piridin', 'pyridine', 'c1ccncc1', 'C1=CC=NC=C1'],
  ['trietilamin', 'triethylamine', 'CCN(CC)CC'],
  ['diizopropiletilamin (DIPEA)', 'N,N-diisopropylethylamine', 'CCN(C(C)C)C(C)C'],
  ['N-metilpirolidon (NMP)', 'N-methyl-2-pyrrolidone', 'CN1CCCC1=O'],
  ['4-dimetilaminopiridin (DMAP)', '4-dimethylaminopyridine', 'CN(C)c1ccncc1'],
  ['anilin', 'aniline', 'Nc1ccccc1', 'c1ccc(N)cc1'],
  ['fenol', 'phenol', 'Oc1ccccc1', 'c1ccc(O)cc1'],
  ['benzoik asit', 'benzoic acid', 'OC(=O)c1ccccc1', 'O=C(O)c1ccccc1'],
  ['benzaldehit', 'benzaldehyde', 'O=Cc1ccccc1'],
  ['üre', 'urea', 'NC(N)=O', 'O=C(N)N'],
  ['glisin', 'glycine', 'NCC(=O)O', 'C(C(=O)O)N'],
  ['metilamin', 'methylamine', 'CN'],
  ['etilamin', 'ethylamine', 'CCN'],
  ['dimetilamin', 'dimethylamine', 'CNC'],
  ['hidrazin', 'hydrazine', 'NN'],
  ['trifloroasetik asit (TFA)', 'trifluoroacetic acid', 'OC(=O)C(F)(F)F', 'O=C(O)C(F)(F)F'],
  ['tiyonil klorür', 'thionyl chloride', 'O=S(Cl)Cl', 'ClS(Cl)=O'],
  ['metil iyodür', 'methyl iodide', 'CI', 'IC'],
  ['benzil bromür', 'benzyl bromide', 'BrCc1ccccc1', 'C(Br)c1ccccc1'],
  ['di-tert-bütil dikarbonat (Boc anhidrit)', 'di-tert-butyl dicarbonate', 'CC(C)(C)OC(=O)OC(=O)OC(C)(C)C'],
  ['glikoz', 'glucose', 'OCC1OC(O)C(O)C(O)C1O'],
  ['kafein', 'caffeine', 'Cn1cnc2c1c(=O)n(C)c(=O)n2C', 'CN1C=NC2=C1C(=O)N(C(=O)N2C)C'],
  ['aspirin (asetilsalisilik asit)', 'aspirin', 'CC(=O)Oc1ccccc1C(=O)O', 'CC(=O)OC1=CC=CC=C1C(=O)O'],
  ['parasetamol', 'paracetamol', 'CC(=O)Nc1ccc(O)cc1'],
  ['anizol', 'anisole', 'COC1=CC=CC=C1', 'COc1ccccc1'],
  ['1,2-dimetoksietan (DME)', '1,2-dimethoxyethane', 'COCCOC'],
  ['dimetilasetamid (DMAc)', 'N,N-dimethylacetamide', 'CC(=O)N(C)C', 'CN(C)C(C)=O'],
  ['sodyum tert-bütoksit', 'sodium tert-butoxide', 'CC(C)(C)[O-].[Na+]', '[Na+].CC(C)(C)[O-]', 'CC(C)(C)O[Na]'],
  ['1,8-diazabisiklo[5.4.0]undek-7-en (DBU)', '1,8-diazabicyclo[5.4.0]undec-7-ene', 'C1CCC2=NCCCN2CC1'],
  ['tris(dibenzilidenaseton)dipaladyum(0) [Pd2(dba)3]', 'tris(dibenzylideneacetone)dipalladium(0)', 'C1=CC=C(C=C1)/C=C/C(=O)/C=C/C2=CC=CC=C2.C1=CC=C(C=C1)/C=C/C(=O)/C=C/C2=CC=CC=C2.C1=CC=C(C=C1)/C=C/C(=O)/C=C/C2=CC=CC=C2.[Pd].[Pd]'],
  ['BINAP (2,2\'-bis(difenilfosfino)-1,1\'-binaftil)', 'BINAP', 'C1=CC=C(C=C1)P(C2=CC=CC=C2)C3=C(C4=CC=CC=C4C=C3)C5=C(C=CC6=CC=CC=C65)P(C7=CC=CC=C7)C8=CC=CC=C8'],
  ['Xantphos (4,5-bis(difenilfosfino)-9,9-dimetilksanten)', 'Xantphos', 'CC1(C2=C(C(=CC=C2)P(C3=CC=CC=C3)C4=CC=CC=C4)OC5=C1C=CC=C5P(C6=CC=CC=C6)C7=CC=CC=C7)C'],
  ['paladyum(II) asetat (asetik asit + Pd olarak yazılmış)', 'palladium(II) acetate (as acetic acid + Pd)', 'CC(=O)O.CC(=O)O.[Pd]'],
];
