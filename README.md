# Konusal Dosya Yöneticisi

Delphi 10.2 VCL ile hazırlanmış, yerelde çalışan görsel dosya sınıflandırıcıdır.

## İşlevler

- Seçilen klasörü ve alt klasörlerini tarar.
- Dosya adını ve desteklenen dosyalardaki metni birlikte analiz eder.
- Finans, Hukuk, Projeler, Medya, Kişisel ve Diğer konularına puanla ayırır.
- Renkli kartlar ile dosya konusunu, önizlemeyi, boyutu ve güven puanını gösterir.
- Dosya adı veya indekslenen içerikte arama yapar.

## Metin çıkarma kapsamı

TXT, CSV, günlük, JSON, XML, kaynak kodu ve benzeri düz metinler doğrudan;
DOCX, paket içindeki `word/document.xml` üzerinden; PDF ise sayfadaki okunabilir
metin dizileri üzerinden taranır. Şifreli, taranmış görüntü PDF'leri ve eski DOC
dosyaları için güvenilir yerel metin çıkarma bu sürümde yoktur; bu dosyalar ad ve
uzantıya göre yine listelenir.

## Derleme

Delphi 10.2 ile `VisualFileManager.dpr` dosyasını açıp Win32 hedefinde derleyin.
Uygulama herhangi bir ağ servisine veya veritabanına ihtiyaç duymaz.
