# Dosya Yoneticisi

Delphi 10.2 VCL ile gelistirilmis, yerelde calisan sade bir dosya yoneticisidir.

## Islevler

- Secilen klasoru ve alt klasorlerini arka planda tarar.
- Dosyalari ad, uzanti, boyut ve degisiklik tarihine gore listeler.
- Dosya adinda arama yapar.
- Ada, tarihe, boyuta veya uzantiya gore siralama sunar.
- Liste ve kucuk simge gorunumleri vardir.
- Dosyaya tiklandiginda Windows varsayilan uygulamasiyla acilir.
- Buyuk klasorlerde kartlari parcalar halinde yukleyerek arayuzun yanit vermesini korur.

## Kapsam

Bu surum PDF, Word veya diger belge turlerinden metin cikartmaz. OCR, konu
siniflandirma, kalici konu katalogu ve belge ozeti yoktur. Dosyalar yalnizca
temel dosya sistemi bilgileriyle yonetilir.

## Derleme

Delphi 10.2 ile `VisualFileManager.dpr` dosyasini acip Win32 hedefinde
derleyin. Uygulama ag servisi, veritabani, OCR motoru veya harici araca
ihtiyac duymaz.
