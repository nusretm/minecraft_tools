# Çalışma ve Mimari Kuralları

Bu belge, kullanıcı ile ChatGPT/Codex arasında yürütülen yazılım geliştirme çalışmalarında
**authoritative çalışma standardı** olarak kabul edilir.

Bu kurallar sohbet, proje, repository veya kullanılan araçtan bağımsızdır. Yeni bir işte
aksi açıkça söylenmedikçe bu belge esas alınır.

---

## 1. Çalışma biçimi

- Büyük işleri tek seferde tasarlayıp uygulamaya çalışma.
- İşler **adım adım, parça parça** ilerletilir.
- Kullanıcı açık onay vermeden implementation başlatılmaz.
- Bir adım bitmeden sonraki adıma geçilmez.
- Önce mevcut yapı ve sınırlar anlaşılır, sonra değişiklik önerilir.
- Codex veya başka bir araç kullanılıyorsa görevler dar, net ve mekanik tutulur.
- Tüm projeyi veya mimariyi bir araca otomatik olarak tasarlatmak varsayılan yaklaşım değildir.
- Gereksiz checkpoint, aşırı test otomasyonu veya büyük promptlarla zaman/token tüketilmez.
- Testler production mimarisini şekillendirmez; production mimarisi doğru kurulur, testler ona uyar.
- Zorunlu olmadıkça patch dosyası üretilmez; repository değişiklikleri GitHub üzerinden yapılır.
- Pure Dart kodlarında `dart format` kullanılmaz; formatter'ın satır uzunluğu veya otomatik bölme tercihleri kaynak düzenini belirlemez.
- Pure Dart kodunda satırlar gerektiğinde doğal ifade tamamlanana kadar uzun kalabilir; okunabilirlik, formatter uyumundan önce gelir.
- Pure Dart doğrulamasında varsayılan komutlar `dart analyze` ve `dart test`tir; `dart format` yalnız kullanıcı açıkça isterse çalıştırılır.

---

## 2. Temel mimari prensip

Önce **omurga/core** tasarlanır.

Yeni özellikler omurgaya eklenir; omurga yeni özellikler uğruna yamalanmaz.

Core:

- küçük,
- belirgin,
- okunabilir,
- genişletilebilir,
- provider/implementation detaylarından bağımsız

olmalıdır.

Provider, loader, storage, utility ve benzeri yapılar core üzerine inşa edilir.

---

## 3. Kalıtım ve sınıf ağacı

Class inheritance destekleyen bir dilde ortak davranışlar tekrar tekrar bağımsız class'lar
olarak yazılmaz.

Aynı ailedeki sınıflar okunabilir bir ağaç oluşturmalıdır.

Örnek:

```text
MtnMinecraftAccountProvider
├─ MtnMinecraftAccountProviderOffline
├─ MtnMinecraftAccountProviderMicrosoft
└─ MtnMinecraftAccountProviderElyBy
```

Benzer şekilde:

```text
MtnMinecraftLoader
├─ MtnMinecraftLoaderVanilla
├─ MtnMinecraftLoaderFabric
├─ MtnMinecraftLoaderForge
└─ MtnMinecraftLoaderNeoForge
```

Ortak davranış base class'a alınır.

Aynı validation, serialization, lookup, lifecycle veya benzeri davranış tekrar tekrar
yazılıyorsa önce eksik bir base abstraction olup olmadığı sorgulanır.

---

## 4. Naming standardı

Subclass adı, base class adını **aynen korur** ve specialization sona eklenir.

Doğru:

```text
AccountProvider
AccountProviderOffline
AccountProviderMicrosoft
AccountProviderElyBy
```

Yanlış:

```text
OfflineAccountProvider
MicrosoftAccountProvider
ElyByAccountProvider
```

Genel kural:

```text
<BaseConcept><Specialization>
```

Namespace/prefix varsa:

```text
<Namespace><BaseConcept><Specialization>
```

Örnek:

```text
MtnMinecraftAccountProviderOffline
MtnMinecraftLoaderFabric
MtnContentProviderModrinth
```

Bu kural class ailelerinin IDE/autocomplete, dosya listesi, dokümantasyon ve stack trace içinde
birlikte görünmesini sağlar.

---

## 5. Registry / List authority

Genişletilebilir her ana sistemin tek bir registry/list authority'si olmalıdır.

Örnek:

```text
MtnMinecraftAccountProviderList
MtnMinecraftLoaderList
```

Yeni provider/loader bu listeye register olur.

Built-in implementation'lar da özel-case değildir.

Örneğin:

- Offline account provider
- Vanilla loader

manuel `if`, `switch` veya hardcoded çağrılarla ayrıcalıklı şekilde kullanılmaz.

Onlar da diğer implementation'larla aynı registration mekanizmasından geçer.

---

## 6. Special-case programlama yapılmaz

Aşağıdaki tipte kodlar varsayılan olarak istenmez:

```text
if provider == offline
if loader == fabric
switch providerName
switch loaderName
```

Davranış ilgili class tarafından taşınmalı veya registry doğru implementation'ı bulmalıdır.

Yeni provider eklemek core switch'lerini değiştirmeyi gerektiriyorsa mimari yanlış kurulmuştur.

---

## 7. Domain değerleri raw string olarak tekrar edilmez

Enum, registry veya başka bir merkezi authority varsa domain değerleri production kodunda
raw string olarak tekrar edilmez.

Örneğin:

```text
"offline"
"microsoft"
"elyBy"
"fabric"
"vanilla"
```

gibi domain isimleri source code boyunca elle yazılmaz.

Serialize ederken merkezi authority kullanılır.

Parse ederken enum/registry/list üzerinden çözülür.

### İstisna

External wire format'ın kendi literal tokenları parser/serializer sınırında bulunabilir.

Örneğin MRPACK içindeki:

```text
modrinth.index.json
formatVersion
required
optional
unsupported
```

gibi değerler dış format sözleşmesidir.

Bunlar yalnız ilgili provider/parser katmanında kalmalıdır.

---

## 8. Provider-specific bilgi core'a sızmaz

Core hiçbir provider'ın:

- API detayını,
- dosya formatını,
- wire tokenlarını,
- endpoint bilgisini,
- özel metadata yapısını

bilmemelidir.

Örnek:

```text
content_provider/modrinth/
    modrinth_provider.dart
    mrpack.dart
    mrpack_expander.dart
```

MRPACK bilgisi `minecraft_package` core'una ait değildir.

Bağımlılık yönü:

```text
core
 ↑
 │ implements / extends / produces
 │
provider implementation
```

Core provider'ı bilmez.

Provider core'u bilir.

---

## 9. Core ve extension kodu fiziksel olarak ayrılır

Klasör yapısı mimariyi görünür hale getirmelidir.

Core/omurga kodu ile bu omurgaya bağlı provider/loader/utility kodları aynı seviyede
birbirine karıştırılmaz.

Örnek yaklaşım:

```text
core/
    account/
    minecraft/
    package/

providers/
    account/
    content/

loaders/
    vanilla/
    fabric/
    forge/
```

İsimler projeye göre değişebilir; önemli olan sınırın fiziksel olarak da açık olmasıdır.

---

## 10. Private fonksiyonlar minimumda tutulur

Çok sayıda private helper fonksiyon kalite göstergesi değildir.

Bir class içinde çok sayıda:

```text
_parseX
_validateY
_convertZ
_buildA
_resolveB
```

oluşuyorsa önce şu sorular sorulur:

- Class fazla sorumluluk mu taşıyor?
- Eksik bir model/class abstraction mı var?
- Ortak davranış base class'a mı taşınmalı?
- Bu iş başka bir nesnenin doğal sorumluluğu mu?

Private helper yalnız gerçekten local ve küçük implementation detayı olduğunda tercih edilir.

---

## 11. Kod tekrarı kabul edilmez

Benzer davranış tekrar tekrar yazılmaz.

Tekrar varsa önce:

- inheritance,
- ortak base class,
- ortak value object,
- ortak registry davranışı,
- ortak serializer/parser

değerlendirilir.

Ancak sırf "ileride lazım olabilir" diye gereksiz abstraction da üretilmez.

Ama gerçek bir class ailesi veya ortak davranış mevcutsa duplication yerine doğru hiyerarşi kurulur.

---

## 12. Klasör ve dosya yapısı okunabilir olmalıdır

Bir dosyanın nerede bulunduğuna bakarak:

- core mu,
- provider mı,
- loader mı,
- utility mi,
- storage mı,
- UI mı

anlaşılabilmelidir.

Omurga ile omurgaya bağlı implementation'lar iç içe geçirilmez.

Bu sınır, ileride core üzerinde yapılacak yanlış bir değişikliğin tüm sistemi etkilemesini
önlemek için özellikle önemlidir.

---

## 13. Çalışıyor olması kalite standardı değildir

Aşağıdakiler tek başına başarı kabul edilmez:

- compile olması,
- testlerin geçmesi,
- gerçek uygulamanın açılması,
- feature'ın çalışması.

Kalite için aynı zamanda:

- mimari sınırlar,
- dependency direction,
- naming tutarlılığı,
- inheritance yapısı,
- tekrarın azlığı,
- okunabilirlik,
- genişletilebilirlik,
- core/extension ayrımı

doğru olmalıdır.

Çalışan ama standardı olmayan kod kabul edilmez.

---

## 14. Sadelik

"Sadelikte güzellik vardır."

Yeni class, interface, callback, wrapper, adapter veya helper eklemeden önce gerçekten gerekli
olup olmadığı sorgulanır.

Ancak sadelik, duplication veya special-case kod yazmak anlamına gelmez.

Amaç:

- az sayıda,
- doğru sorumluluklu,
- açık ilişkili,
- tahmin edilebilir

class'lardan oluşan bir yapı kurmaktır.

---

## 15. Backward compatibility

Kullanıcı açıkça istemedikçe backward compatibility için:

- deprecated alias,
- compatibility wrapper,
- legacy format,
- migration shim

eklenmez.

Yeni proje/ilk release aşamasında eski tasarımları taşımak için yeni mimari bozulmaz.

---

## 16. Yeni bir class eklemeden önce kontrol

Yeni class eklemeden önce şu sıra izlenir:

1. Mevcut base class var mı?
2. Bu class mevcut bir aileye mi ait?
3. Mevcut registry/list authority var mı?
4. Yeni class oraya register olmalı mı?
5. Ortak davranış tekrar mı ediliyor?
6. Provider-specific bilgi core'a mı sızıyor?
7. Naming base class adını aynen koruyor mu?
8. Dosya doğru mimari klasörde mi?

Bu sorular cevaplanmadan yeni class tanımlamak varsayılan yaklaşım değildir.

---

## 17. Yeni feature eklemeden önce kontrol

Yeni feature:

- core switch'ine yeni case eklemeyi,
- raw provider string'i eklemeyi,
- yeni özel-case branch oluşturmayı,
- aynı davranışı ikinci kez yazmayı,
- provider bilgisini core'a taşımayı

gerektiriyorsa implementation başlamadan mimari tekrar değerlendirilir.

---

## 18. ChatGPT / Codex çalışma kuralı

ChatGPT veya Codex:

- kullanıcıdan gelen naming ve architecture kurallarını "tercih" değil standart kabul eder,
- aynı standardı her sınıf ailesine kendiliğinden uygular,
- kullanıcıya her defasında aynı naming/hierarchy kuralını tekrar sordurmaz,
- geniş kapsamlı mimari kararları kullanıcı adına otomatik üretmez,
- önce mevcut omurgaya nasıl oturacağını belirler,
- emin olmadığı mimari kararda implementation yapmak yerine sorar.

---

## 19. Parça parça ilerleme

Yeni MtnLauncher rebuild sürecinde:

- eski implementation `_trash` altında yalnız referanstır,
- eski mimari otomatik olarak geri taşınmaz,
- ihtiyaç oldukça yalnız gerekli parça yeniden tasarlanır,
- bir parça bitmeden bir sonraki büyük subsystem'e geçilmez,
- her yeni parça bu belgedeki kurallara göre değerlendirilir.

---

## 20. Ana kalite sorusu

Her implementation öncesi ve sonrası şu soru sorulur:

> Bu kod yalnız bugün çalışıyor mu, yoksa projenin omurgasına doğal bir dal olarak mı ekleniyor?

İkinci cevap açık değilse kod tamamlanmış kabul edilmez.
