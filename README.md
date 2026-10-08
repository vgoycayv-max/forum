# Başlık Tarayıcı (sürüm 8)

Forum sitelerini gezip **başlıklarda, alt başlıklarda ve bağlantı yazılarında** aradığın kelimeyi
(ya da kelime kökünü) bulan, sonuçları `.txt` dosyalarına yazan bir Android uygulaması.

**Sürüm 8'de (Organic Syntheses tarifleri ve büyük bir hata düzeltmesi):**
- **Hata düzeltildi:** `çeviri_cıktı.txt` karmakarışıktı (`metanV5P0949`, `ADD SLamonyak` gibi). Sebebi: dosya "düz yazı" sanılınca uygulama, kural dosyasındaki madde yazılışlarını (`C` = metan, `O` = su, `N` = amonyak...) yazının her yerinde değiştiriyordu. Artık düz yazıda sadece `metin_kurallari` bölümündeki kodların uygulanır; madde yazılışlarına dokunulmaz.
- **Yeni biçim: Prosedür (rxID / source / target).** `{"rxID": "CV5P0949", "source": "...>>...", "target": "ADD $2$ ; STIR ; ..."}` satırlarını tanır ve Organic Syntheses tarzı bir **tarife** çevirir: Malzemeler, Beklenen ürün, Gereken araç-gereç, Adımlar, Sonuç. `$2$` yerine 2. malzemenin adı yazılır.
- **Önemli sınır:** Bu veri setinde **gerçek sayılar silinmiştir**: miktarlar (gram, mL), süreler (dakika) ve sıcaklıklar (°C) `@2@`, `#6#` gibi yer tutuculara çevrilmiş. Uygulama bunları uyduramaz. Tarifte "süre-2", "sıcaklık-6" olarak görünür (aynı numara aynı değerdir) ve notta açıklanır. Gerçek sayılar için orgsyn.org'da kayıt kodunu (örnek `CV5P0949`) aratmak gerekir.
- **ORD "Çevir" modu** artık aynı tarif düzenini verir (Malzemeler, Kap/düzenek, Adımlar, Sonuç). ORD kayıtlarında miktarlar vardır, o yüzden bu tariflerde sayılar görünür. Kayıtta olmayan bilgi (kap, süre, ekleme sırası) için "kayıtta yok" yazar, uydurmaz.
- **`~` işareti:** `[OH-]~[Na+]` gibi iyon çiftlerini artık okuyor.

**Sürüm 7'de düzeltmeler (senin ORD çıktılarına bakarak):**
- ORD'de ürünün yüzdesi "seçicilik" diye yazılıyordu, doğrusu **verim**. Düzeltildi.
- "Çevir" modu ORD için "Oku" ile aynı uzun çıktıyı veriyordu. Artık ORD kayıtları 3-4 satıra iniyor: `girenler → ürün` ve altında sıcaklık, verim, çözücü, kaynak.
- "Adı bilinmeyenleri formülle göster" anahtarı ORD'de çalışmıyordu. Artık çalışıyor.
- ORD kayıtlarının **kaynak** bilgisi (kurum, deney tarihi, DOI/patent, adres) çıktıya eklendi.
- PubChem'den ad alırken PubChem'in döndürdüğü formül, uygulamanın SMILES'tan hesapladığı formülle karşılaştırılıyor. Uyuşmazsa ad otomatik yazılmıyor, `kural.json` içinde `"pubchem": "formul-uyusmuyor"` diye işaretleniyor.
- **Hazır maddeleri kural dosyasına ekle** düğmesi eklendi: yeni hazır maddeleri (Pd2(dba)3, BINAP, Xantphos, anizol, DME, DMAc, DBU...) mevcut kural dosyana ekler, senin yazdığın adlara dokunmaz.

**Sürüm 6'da yeni: Format okuyucu.** Ana ekrandaki **Format okuyucu** düğmesiyle açılır. Telefondaki kimya dosyalarını (SMILES tepkime satırları, SMILES tablosu, ORD kayıtları, sayı tabloları) internetsiz okur, her maddenin formülünü ve molar kütlesini hesaplar, `kural.json` dosyasıyla kodları kelimeye çevirir. Ayrıntısı aşağıda "Format okuyucu" bölümünde.

**Sürüm 5'te eklenen: HuggingFace ekranı.** Ana ekranın sağ üstündeki **HuggingFace** düğmesiyle açılır. Forum yerine Hugging Face'teki hazır veri setlerinden (kimya, fizik, soru-cevap gibi) kelime arayıp sonuçları yine kelime başına `.txt` dosyalarına yazar. Ayrıntısı aşağıda "HuggingFace ekranı" bölümünde.

**Sürüm 4'te eklenen:**
- **Arka planda çalışma:** Tarama başlayınca bildirim çubuğunda küçük bir bildirim açılır. Ekranı kapatabilir, başka uygulamaya geçebilirsin, tarama sürer. Ekran kapalı olduğu için şarj çok daha az harcanır.
- **Dosyaları indirmez:** Sayfa HTML değilse (djvu, pdf, zip, epub, resim...) uygulama dosyayı hiç indirmez, sadece "bu bir dosya" diye bakıp geçer. Eskiden indirip siliyordu. Dosyanın bağlantısı başlığı eşleşirse `[BAĞLANTI]` olarak yine sonuç dosyana yazılır, sonra istersen kendin indirirsin. (Uygulama djvu/pdf içini **okumaz**.)
- **Daha temiz içerik:** Menü, yan panel, alt bilgi, kategori listesi gibi kısımlar atılır; sadece sayfanın ana yazısı kaydedilir.

**Sürüm 3'te eklenen:** Her aranan kelime **kendi dosyasına** yazılır: `klor_1.txt`, `klor_2.txt`, `titan_1.txt`, `gaz_1.txt`...
Kelimeler karışmaz. Bir başlıkta iki kelime birden geçerse o sonuç iki dosyaya da yazılır.

**Sürüm 2'de eklenen:** Eşleşen başlığın **içindeki yazıyı da** (konunun mesajlarını) sonuç dosyasına kaydeder.
Sürüm 1 sadece başlığı ve bağlantısını yazıyordu.

> Bu sürüm **test edilmedi**. Kodu yazdım ama bu ortamda Flutter olmadığı için derleyip çalıştıramadım.
> İlk derlemede hata çıkabilir. Çıkarsa hata mesajını bana yapıştır, düzeltirim.

---

## 1. Ne işe yarar?

Örnek: Sciencemadness forumunda "gas" kelimesini aratıyorsun. Uygulama:

1. Ana sayfadan forum bölümlerini bulur (Chemistry in General, Organic Chemistry...).
2. Her bölümün konu listesini sayfa sayfa gezer.
3. Konu başlıklarında "gas" geçenleri (gases, gasoline, gasification...) not eder.
4. Bulunan her başlığın **sayfasını açıp içindeki yazıyı alır** (konu birden çok sayfaysa ilk birkaç sayfasını).
5. Bulduklarını `sonuc_001.txt`, `sonuc_002.txt`... diye dosyalara yazar.

**Önemli:** Birden çok kelimeyi **virgülle** ayır. `making H2SO4` yazarsan bu iki kelime yan yana, tam böyle geçen başlıkları arar.
`making, H2SO4` yazarsan ikisinden birini içeren başlıkları arar.

**Önemli:** Site İngilizceyse kelimeyi İngilizce yazmalısın. "gaz" yazarsan "gas" geçen başlıkları bulamaz.

---

## 2. Dosyalar (zip'in içinde)

| Dosya | Ne işe yarar |
|---|---|
| `lib/main.dart` | Forum tarayıcı (gezme motoru + ekran) ve ortak parçalar |
| `lib/hf.dart` | HuggingFace veri seti okuyucu (motor + ekran) |
| `lib/format.dart` | Format okuyucu ekranı, kural dosyası, toplu tanımlama |
| `lib/kimya.dart` | Element tablosu, SMILES okuyucu (formül, molar kütle), ORD çözücü, hazır madde sözlüğü |
| `pubspec.yaml` | Uygulamanın kullandığı hazır parçaların listesi |
| `.github/workflows/build.yml` | GitHub'a "APK'yı derle" diyen tarif |
| `YEDEK_build.yml` | Yukarıdakinin kopyası (aşağıda "Sık sorunlar"a bak) |
| `.gitignore` | GitHub'a yüklenmeyecek dosyaların listesi |

---

## 3. APK nasıl elde edilir (adım adım)

APK, Android'e kurulan uygulama dosyasıdır. Telefonda derlemek yerine GitHub'ın bedava sunucusunda derletiyoruz.

1. github.com'da hesabın yoksa aç. **New repository** ile boş bir depo oluştur (adı: `forum-tarayici`).
2. Zip'i bilgisayarda ya da telefonda **klasöre çıkar**.
3. Depo sayfasında **Add file → Upload files** de. Çıkardığın klasörün **içindekileri** (lib, pubspec.yaml, .github...) sürükle. Sonra **Commit changes**.
4. Üstteki **Actions** sekmesine gir. "APK derle" görünür; derleme otomatik başlar. Başlamadıysa soldan "APK derle"yi seç, **Run workflow**'a bas.
5. Yaklaşık 5–10 dakika sonra yeşil tik çıkar. O çalıştırmanın içine gir, en altta **Artifacts** bölümünde `forum-tarayici-apk` var. İndir, zip'ten `app-release.apk` çıkar.
6. APK'ya dokun ve kur. Telefon "bilinmeyen kaynaklardan kurulum" izni isterse ver.

Kırmızı çarpı çıkarsa o adıma gir, hata satırını kopyalayıp bana gönder.

---

## 4. İlk kullanım

1. Uygulamayı aç. **Site adresi** ve **Aranacak kelimeler** alanlarını doldur.
   Deneme için "Sciencemadness örneğini doldur" düğmesine basabilirsin (Hangi adresler gezilsin? bölümünde).
2. **Yeni tarama**ya bas.
3. İlk seferde Android **"Tüm dosyalara erişim"** ayarını açar. Uygulamayı bulup izni aç, geri dön.
   - İzin verirsen sonuçlar `Download/ForumTarayici/` klasörüne yazılır (dosya yöneticisinden kolay bulunur).
   - Vermezsen uygulamanın kendi klasörüne yazılır. Ekranda yolu görürsün ama Android 11 ve üstünde oraya ulaşmak zordur.
4. İlk taramada Android iki şey sorar: **bildirim izni** (taramanın arka planda sürmesi için gerekli, ver) ve **pil optimizasyonu** (taramayı kısıtlamasın diye "İzin ver"/"Kısıtlama yok" de).
5. Tarama sürerken **ekranı kapatabilirsin**. Uygulamadan çıkmak için **ana ekran tuşunu** kullan. Geri tuşuna basarsan uygulama kapanmaz, küçülür (tarama sürer). Tamamen kapatmak için önce **Durdur ve kaydet**'e bas.
6. Android 15 ve üstünde sistem bu tür servisleri yaklaşık 6 saatte bir durdurabilir. Durursa kaydedilir, **Devam et** ile sürdür.

---

## 4b. HuggingFace ekranı

Hugging Face, açık veri setleri sitesidir. Sitenin kendi resmi "veri görüntüleyici" arayüzünü kullanıyoruz; yani bu yasal ve herkese açık bir yoldur. Veri seti dosyasının tamamını indirmeye gerek yok, dilim dilim okunur.

**Adım adım:**

1. Ana ekranda sağ üstteki **HuggingFace** düğmesine bas.
2. **Veri seti adı** kutusuna adı yaz ya da örneklerden birine dokun. Ad, `huggingface.co/datasets/` adresinin devamıdır (örnek: `zd21/SciInstruct`).
3. **Bilgi al** düğmesine bas. Veri setinin **lisansını** ve **bölümlerini** (config / split ve satır sayıları) gösterir. "Bu veri seti için görüntüleyici yok" yazarsa uygulama onu okuyamaz, başka veri seti seç. Lisansı mutlaka kontrol et; kullanım şartları sana ait.
4. İstersen **Config** ve **Split** kutularını doldur (Bilgi al listesinden). Boş bırakırsan bulunan hepsi sırayla gezilir.
5. **Aranacak kelimeleri** virgülle yaz. Kelimeleri veri setinin diliyle yaz: İngilizce veri setinde `chlorine`, Türkçe olanda `klor`.
6. **Yöntemi** seç:
   - **Sunucuda ara:** Hızlı. Hugging Face sunucusu aramayı yapar, sadece eşleşen satırlar iner. Kelimeyi bütün olarak arar; `gaz` yazınca `gazlar`ı bulamayabilir.
   - **Satır satır tara:** Yavaş ama esnek. Satırlar 100'erli iner, telefon süzer. Kelime kökü çalışır (`gaz` → gazlar, gazsoy). Büyük veri setinde çok istek gerekir, limitleri yükselt.
7. **Yeni tarama**ya bas. Sonuçlar forumdaki gibi kelime başına dosyalara yazılır: `klor_1.txt`, `titan_1.txt`... Her satırın tüm kolonları (soru, cevap, açıklama gibi) yazılır.
8. Kesilirse **Devam et** ile sürdür. Ekran kapalıyken de çalışır (forumdaki arka plan düzeni aynı).

**Limitler:** En fazla istek (her istek en çok 100 satır), en fazla MB, en fazla dakika, istekler arası bekleme ve her kaç MB'da bir kayıt. Hugging Face çok istek görünce "yavaşla" (HTTP 429) der; uygulama bunu görünce kendisi bekler.

**Örnek veri setleri** (arama sonuçlarında kimya/fizik etiketiyle gördüm, hepsinin çalışıp çalışmadığını **Bilgi al** ile sen doğrula):

| Ad | Dil | Not |
|---|---|---|
| `zd21/SciInstruct` | İngilizce | Fizik-kimya soru/cevap, lisans cc-by-4.0 görünüyordu |
| `checkai/oaCamel` | İngilizce | Kimya, fizik, biyoloji, matematik diyalogları, cc-by-4.0 |
| `daman1209arora/jeebench` | İngilizce | Küçük (1000'den az) kimya/fizik/matematik soruları, MIT |
| `LDJnr/Capybara` | İngilizce | Karışık konular (fizik, kimya dahil), apache-2.0 |
| `AYueksel/TurkishMMLU` | Türkçe | Türkçe sınav soruları; Physics, Chemistry gibi config'leri var |
| `BASF-AI/PubChemWikiTRPC` | İngilizce + Türkçe | Küçük kimya veri seti |
| `ysdede/khanacademy-turkish` | Türkçe | Khan Academy Türkçe metinler (kimya, biyoloji), cc-by-sa-3.0 |

**Bilmen gerekenler:**
- Hugging Face görüntüleyicisi her veri setinde yoktur ve çok uzun hücreleri (çok uzun metinleri) sunucu kısaltmış verebilir.
- İki tarama (forum ve HuggingFace) aynı anda çalışabilir ama telefon ve ağ yorulur; birini bitirip diğerini başlatmak daha iyi.

---

## 4c. Format okuyucu

Ana ekranda **Format okuyucu** düğmesine bas. Bu bölüm tamamen internetsiz çalışır (sadece "Çevrimiçi ad sor" anahtarını açarsan internet kullanır).

**Klasörler:** İlk açılışta şu klasörler oluşturulur (`Download/ForumTarayici/` içinde):
- `girdi` : Okunacak dosyalarını dosya yöneticisiyle buraya kopyala.
- `kurallar/kural.json` : Kural dosyası. Metin düzenleyiciyle düzenlenir.
- `cikti` : Sonuçlar buraya yazılır (`dosyaadi_okunur.txt`, `dosyaadi_ceviri.txt`).

**Adımlar:**
1. Dosyanı `girdi` klasörüne koy, uygulamada **Listeyi yenile**'ye bas ve dosyaya dokun.
2. **Biçim** olarak "Otomatik"i bırak. Uygulama dosyanın ne olduğunu kendisi anlar (aşağıdaki liste). Yanlış anlarsa biçimi elle seç.
3. **Ne yapılsın?** seç ve **Başlat**'a bas. Sonuç ekranda önizlenir ve `cikti` klasörüne yazılır.

**Tanıdığı biçimler:**

| Biçim | Nasıl görünür | Ne yapar |
|---|---|---|
| Tepkime satırları | `C C O . C C ( = O ) O ,C C O C ( C ) = O` (soldaki girenler, virgülden sonra ürün; harfler boşluklu olabilir) | Girenlerin ve ürünün formülünü, kütlesini yazar. Atom farkını da söyler (örneğin "kaybolan: H2O"). |
| SMILES tablosu | `SMILES,Y` başlıklı CSV | Her satıra formül ve molar kütle ekler, diğer sütunları korur. |
| Prosedür (rxID/source/target) | Her satır `{"rxID": "CV5P0949", "source": "A.B>>C", "target": "ADD $1$ ; STIR ; ..."}` | Organic Syntheses tarzı adım adım tarif (malzemeler, araçlar, adımlar, sonuç). Sayılar veri setinde silinmiş. |
| ORD kaydı | `reaction_id` ve `[10, 21, 8, ...]` sayı listesi (TSV) | Sayı listesini açar: girdiler (rol, miktar, madde), sıcaklık, işlem sonrası adımlar, ürün ve verim. |
| Sayı tablosu | Noktalı virgüllü sayılar (spektrum gibi) | En küçük, en büyük, ortalama ve en büyük değerin yerini yazar. |
| SMILES listesi | Her satırda bir SMILES | Formül ve kütle yazar. |
| Düz yazı | Başka her şey | Sadece "Çevir" modunda: kural dosyasındaki kodları kelimeye çevirir. |

**Üç mod:**
- **Oku:** Açıklayarak yazar. Madde adı sözlükte varsa onu, yoksa SMILES'ı gösterir; yanında formül ve molar kütle (g/mol) olur. "Atom ayrıntısı" anahtarı atomları ad ve atom numarasıyla da yazar.
- **Çevir:** Dosyayı kısa ve okunur hale getirir: `etanol + asetik asit → etil asetat` gibi. Adı bilinmeyen madde formülle gösterilir (anahtarla kapatılabilir). Kural dosyasındaki `metin_kurallari` da uygulanır. ORD kayıtlarında her tepkime 3-4 satıra iner:
```
Tepkime ord-56b1... — 1.3.1 [N-arylation with Ar-X] Bromo Buchwald-Hartwig amination
  sezyum karbonat + 1-Isopropylpiperazine + ... → Ethyl 4-(2,4-difluoroanilino)-...
  110 ± 10 °C | verim %65.39 | kaynak: AstraZeneca; deney tarihi 07/01/2008; https://...
```
- **Toplu tanımla:** Dosyadaki yeni maddeleri tek tek elle yazmak yerine `kural.json` içine toplu ekler (formül ve molar kütle hazır gelir, `isim` alanı boş). İstersen **Çevrimiçi ad sor (PubChem)** açılır; uygulama maddelerin İngilizce adlarını sorar ve `isim` alanına yazar. Saniyede 3 sorgu yapar, bulunamayanı işaretler ve tekrar sormaz. İnternetin azken az sayıyla ("En fazla sorgu sayısı") dene, tekrar çalıştırınca kaldığı yerden sürer.

**kural.json dosyası:** İlk açılışta hazır bir tane oluşur. İçinde 4 bölüm var:

```
"metin_kurallari": { "c0c01": "patlıcan", "ccc00r": "pişdi" }
```
Dosyada `c0c01` geçerse `patlıcan`, `ccc00r` geçerse `pişdi` yazılır. Kendi kodlarını alt alta ekleyebilirsin (virgüllere dikkat: son satırın sonunda virgül olmaz).

```
"maddeler": {
  "CCO": { "isim": "etanol", "isim_en": "ethanol", "formul": "C2H6O",
           "molar_kutle": 46.07, "esdeger": ["OCC"], "not": "çözücü" }
}
```
Her madde için istediğin alanı ekleyebilirsin (`not`, `kullanim`, `tehlike` gibi). Uygulama `isim` alanını kullanır. `esdeger`, aynı maddenin başka yazılışlarıdır.

```
"elementler": { "C": { "isim": "Karbon", "atom_no": 6, "atom_kutlesi": 12.011 } }
```
Element adlarını buradan değiştirirsin. Hazır dosyada 88 element ve yaygın 80 kadar madde (su, etanol, aseton, çözücüler, asitler, bazlar...) tanımlıdır.

**Dosyada hata olursa:** Bir virgül ya da tırnak eksik kalırsa uygulama dosyayı okuyamaz. Bunu ekranda açık yazar ve dosyana dokunmaz (üstüne yazmaz). "Kural dosyasını kontrol et" düğmesi durumu gösterir.

**Bilmen gerekenler (sınırlar):**
- **Aynı madde farklı yazılabilir.** SMILES'ta etanol `CCO` ya da `OCC` olarak yazılabilir. Uygulama yazılışları kendisi birleştirmez; sözlükte tam o yazılış (ya da `esdeger` listesindeki yazılış) varsa adı bulunur. Bulunamayanlar formülle gösterilir. PubChem sorgusu yazılış farkını kendisi çözer.
- **Formül hesabı** kimyasal yapıyı doğrulamaz, atom sayısını sayar. Çok nadir yazılışlarda (örneğin köşeli parantezsiz `se`, `as`) hata verebilir; o satır "SMILES okunamadı" diye işaretlenir.
- **ORD, senin örneğinle doğrulananlar:** Kimlikler, girdiler (rol, mol miktarı, çözücü hacmi litre olarak), sıcaklık, ürün, verim yüzdesi ve kaynak bilgisi. Formüller doğru çıkıyor (örneğin aril halojenür + amin − HBr = ürün).
- **ORD, emin olunamayanlar:** Verimin tür kodunu (3) senin verilerinden çıkardım: değerler 19-65 arasında yüzdeler ve AstraZeneca verisi, yani verim. ORD'nin güncel şema dosyasına erişip doğrulayamadım. **Süre** ve **basınç** birimlerinin kodu şema sürümüne göre değiştiği için bu iki değer tahmini birimle ve soru işaretiyle, birim kodu da yazılarak gösterilir (örnek: `2 saat? (birim kodu 2)`). Örnek dosyalarında bu iki alan yoktu.
- **ORD, madde adları:** Adlar PubChem'den geliyorsa PubChem'in başlığıdır. Bazılarında garip karakterler çıkabilir (örneğin BINAP için `(A+-)`) çünkü PubChem'in kendi başlığı öyledir. Ayrıca bir ad yanlış maddeye ait olabilir: örneğin 3 dba ve 2 Pd içeren `Pd2(dba)3` kaydına `Bis(dibenzylideneacetone)palladium` adı verilmişse bu yanlıştır (o, 1 Pd ve 2 dba içeren başka bir maddedir). Yeni sürüm bunu formül kontrolüyle yakalıyor. Eski adı düzeltmek için `kural.json` dosyasında o adı bulup metin düzenleyicide değiştirmen yeterli.
- **Formül yazımı:** Formüller Hill sırasıyla yazılır (önce C, sonra H, sonra alfabetik). Sezyum karbonat bu yüzden `CCs2O3` görünür (Cs2CO3 ile aynı madde).
- "ORD ham dökümünü ekle" anahtarı bilinmeyen alanları da gösterir; bir şey yanlışsa o çıktıyı gönder.
- **Sayı tablosu:** Örnek dosyada üst satırda 44, ikinci satırda 58 değer vardı (dosya kesik görünüyordu). Böyle durumlarda uygulama uyarı yazar ve baştan eşleştirir.

---

## 5. Ayarların anlamı

**Limitler** (hepsi "bu çalıştırma" için geçerlidir; **Devam et** deyince yeniden sıfırdan sayılır):

- **En fazla sayfa sayısı:** Bu kadar sayfa okununca durur. (İstek sayısı sınırı.) Varsayılan 300.
- **En fazla indirme (MB):** Bu kadar veri inince durur. Sonsuza kadar indirmeyi engelleyen asıl fren budur. Varsayılan 50. MB değeri yaklaşıktır.
- **En fazla süre (dakika):** Süre dolunca durur. Varsayılan 30.
- **İstekler arası bekleme (ms):** İki sayfa arasındaki bekleme. 1000 = 1 saniye. Düşük tutarsan siteyi yorarsın ve seni engelleyebilir. En az 300.
- **Her kaç MB'da bir kaydet:** Varsayılan 10. Her 10 MB indirmede o ana kadar bulunanlar, kelime başına yeni bir numaralı dosyaya yazılır (`klor_1.txt`, sonra `klor_2.txt`...) ve tarama durumu kaydedilir. Ayrıca her 50 sayfada bir de kaydedilir.
- **En fazla derinlik:** Başlangıç sayfasından kaç bağlantı uzağa gidileceği. Forumlarda "sayfa 2, sayfa 3..." bağlantıları zincir gibi ilerler. Büyük forumda bunu yüksek tut (Sciencemadness örneği 300 yapar).

**İçerik kaydetme (sürüm 2):**

- **Eşleşen başlığın içini de kaydet:** Açıkken, aranan kelime bir başlıkta bulunduğunda o sayfa açılır ve içindeki yazı sonuç dosyasına `[İÇERİK]` olarak eklenir. Kapatırsan sadece başlık ve bağlantı yazılır (sürüm 1 gibi).
- **Bir sayfadan en fazla karakter:** Çok uzun konular dosyayı şişirmesin diye. Varsayılan 20000 (yaklaşık 10 yazılı sayfa).
- **Bir konunun en fazla kaç sayfası:** Konu birden çok sayfaysa ilk bu kadarı alınır. Varsayılan 3. Sadece adreste `page=2` gibi yazan sayfalama bulunur.
- Alınan içerikler de "en fazla sayfa" ve "en fazla indirme" sınırlarına sayılır. Çok içerik istiyorsan o limitleri yükselt.

**Hangi adresler gezilsin?**

- **Sadece şunları içeren adresleri gez:** Boşsa her şey gezilir. Doluysa sadece bu yazıları içeren adresler. Örnek: `forumdisplay.php` yazarsan sadece forum liste sayfaları gezilir.
  **Forumlarda bunu mutlaka doldur.** Boş bırakırsan uygulama konu sayfalarına, üye sayfalarına, SSS'ye de girer ve sayfa limitini boşuna harcar. Liste sayfalarını doldur, konuların içi zaten bulunan başlıklar için ayrıca alınır.
- **Şunları içeren adresleri atla:** Giriş, üyelik, arama gibi işe yaramaz sayfaları dışarıda bırakır.
- **robots.txt:** Siteler "şuralara robot girmesin" diye bir kural dosyası tutar. Bu anahtar açıkken uygulama o kurala uyar. Açık bırak.

**Eşleştirme:**

- **İçinde geçsin:** "gas" kelimesi başlığın herhangi bir yerinde geçerse bulunur (doğalgas, gasoline, Vegas dahil).
- **Kelime başında:** Sadece "gas" ile başlayan sözcükler bulunur (gases, gasoline; doğalgas ve Vegas bulunmaz).
- Büyük/küçük harf ve Türkçe harf farkı önemsenmez (I, İ, ı, ş, ğ gibi).

---

## 6. Kaydetme ve kaldığı yerden devam

- Her ara kayıtta iki şey yazılır:
  - `klor_1.txt`, `klor_2.txt`, `titan_1.txt`... : bulunanlar. Dosya adı aranan kelimedir, sondaki sayı her ara kayıtta artar. O kayıtta bir kelimeden sonuç çıkmadıysa o kelimenin yeni dosyası yazılmaz.
  - `durum.json` : hangi sayfalar gezildi, sırada ne var. Silme, devam etmek için bu lazım.
- İnternet kesilirse uygulama 3 kez dener, olmazsa kaydedip durur ve "Bağlantı koptu" yazar.
- İnternet gelince **Devam et**'e bas. Kaldığı sayfadan sürer, aynı sonuçları tekrar yazmaz.
- Uygulamayı kapatsan bile **Devam et** son taramanı hatırlar. (En son kayıttan sonraki kısım tekrar gezilir, kayıp olmaz.)
- **Yeni tarama** her seferinde yeni bir klasör açar: `Download/ForumTarayici/siteadi_tarih_saat/`

Sonuç dosyası şöyle görünür:

```
[BAĞLANTI] Chlorine gas storage
  adres: https://.../viewthread.php?tid=123
  bulunduğu sayfa: https://.../forumdisplay.php?fid=2&page=4

[İÇERİK] Chlorine gas storage
  adres: https://.../viewthread.php?tid=123
  ---- içerik ----
  (konudaki mesajların yazısı burada)
  ---- içerik sonu ----
```

İçerik yazısı sayfanın ana bölümünden alınır. Menü ve alt bilgi atılır, ama her sitenin yapısı farklıdır; bazı sitelerde yine de birkaç menü satırı kalabilir.

Etiketler: `SAYFA BAŞLIĞI` (sayfanın başlığı), `H1`...`H6` (sayfa içi başlık ve alt başlıklar), `BAĞLANTI` (sayfadaki bir bağlantının yazısı; forumlarda konu başlıkları genelde bunlardır).

---

## 7. Sık sorunlar

- **Sadece `[BAĞLANTI]` çıkıyor, `[İÇERİK]` yok:** Ekranda **Alınan içerik** sayısına bak, sonra **Kayıt defteri**'ni aç. Nedenler:
  1. **Robots engeli:** Ekranda "Robots engeli" sayacı çıkıyorsa, sitenin robots.txt dosyası konu sayfalarını robotlara kapatmıştır. Uygulama varsayılan olarak buna uyar. "Sitenin robots.txt kurallarına uy" anahtarını kapatırsan site kuralını yok sayarsın; bu kararı sen verirsin ve sorumluluğu sana aittir. Kapatmadan önce sitenin kullanım şartlarına bak.
  2. **HTTP 403:** Kayıt defterinde "HTTP 403" yazıyorsa site konu sayfalarını bu uygulamaya vermiyor.
  3. **"Eşleşen başlığın içini de kaydet" kapalı:** "İçerik kaydetme" bölümünden aç.
  4. **Sayfa sınırı doldu:** "En fazla sayfa" değeri liste sayfalarında bitmiş olabilir. Yükselt.
- **Hiç sonuç çıkmıyor:** Kelimeyi sitenin diliyle yazdın mı? "Sadece şunları gez" alanı çok dar olabilir, boşalt ve dene.
- **Çok yavaş:** Normal. Her sayfa arasında 1 sn bekliyor ve siteyi yormamak için böyle olması gerek.
- **"Site yavaşlamak istedi" yazıyor:** Site fazla istek geldiğini söylüyor. Uygulama kendiliğinden bekler. Bekleme süresini artır.
- **Derleme "izin" ya da "sdk" hatası veriyor:** Hata satırını bana gönder.
- **`.github` klasörü yüklenmedi** (telefondan yüklerken gizli klasörler atlanabilir): GitHub'da **Add file → Create new file** de, dosya adına `.github/workflows/build.yml` yaz ve `YEDEK_build.yml`in içeriğini yapıştır.
- **Arka plan:** Bildirim izni verilmezse ya da telefonun pil tasarrufu uygulamayı sert kısıtlıyorsa (bazı markalarda) tarama ekran kapanınca durabilir. Pil ayarlarından uygulamayı "kısıtlama yok" yap.

---

## 8. Sınırlar (dürüst notlar)

- **Quora** gibi giriş isteyen ve botları engelleyen sitelerde çalışmaz. Herkese açık forumlar için.
- Sayfaları JavaScript ile sonradan yükleyen sitelerde (kaydırdıkça içerik gelenler) başlıklar görünmeyebilir. Klasik forum yazılımlarında (XMB, phpBB, vBulletin) sorun yok.
- Kelime **sadece başlıklarda, alt başlıklarda ve bağlantı yazılarında** aranır. Mesaj içlerinde kelime aranmaz; ama başlığı eşleşen konunun mesajları kaydedilir.
- Kaydedilen içerikte mesaj sahibi ve tarih gibi satırlar iç içe gelebilir.
- Sitelerin kullanım şartlarına ve robots.txt kurallarına uymak senin sorumluluğundadır. Siteyi yormamak için bekleme süresini düşürme.

---

## 9. Terimler sözlüğü

- **APK:** Android'e kurulan uygulama dosyası.
- **GitHub Actions:** GitHub'ın bedava sunucusunda uygulamayı senin yerine derleyen düzen.
- **Derlemek:** Yazılmış kodu çalışan uygulamaya çevirmek.
- **İstek:** Uygulamanın siteden bir sayfa istemesi.
- **Derinlik:** Başlangıç sayfasından kaç bağlantı tıklayarak gelindiği.
- **robots.txt:** Sitenin robotlara koyduğu "buraya girmeyin" kuralları.
- **Ara kayıt:** Her seferinde değil, belli aralıklarla diske yazmak. İnternet kesilirse o ana kadarki işin kaybolmaması için.
