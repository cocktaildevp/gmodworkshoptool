# Garry's Mod Workshop Downloader - Garry's Mod Atölye Öğesi İndirme Aracı

   ######                    English

**What it does?**
- Downloads Garry's Mod (app 4000) workshop add-ons with SteamCMD and unpacks the `.gma` files using `gmad.exe` into plain folders.

**Requirements**
- SteamCMD (the script auto-downloads it or you can pass your own path).
- `gmad.exe` from `Steam\\steamapps\\common\\GarrysMod\\bin`.

**Quick steps**
1. Run `download_gmod_workshop.ps1` (or double-click `run_downloader.bat`).
2. Paste workshop IDs/URLs separated by spaces or commas, or pass them with `-WorkshopIds` plus optional `-SteamCmdPath`, `-GmadPath`, `-ExtractRoot`.
3. Extracted files land under `extracted/<id>/`.

**Tips**
- SteamCMD self-updates each run and relocates itself out of cloud folders automatically.
- `_legacy.bin` files are copied to `.gma` so extraction keeps working.
- Delete the `steamcmd` folder if downloads misbehave; it will be rebuilt.

   ######                     Türkçe

**Nedir?**
- SteamCMD ile Garry's Mod atölye eklentilerini indirir ve `gmad.exe` ile `.gma` arşivlerini klasörlere açar.

**Gereksinimler**
- SteamCMD (script yoksa indirir veya kendi dosya yolunuzu girebilirsiniz).
- Garry's Mod dosya dizininde `gmad.exe` bulunması (`Steam\\steamapps\\common\\GarrysMod\\bin`).

**Hızlı kullanım**
1. PowerShell için `download_gmod_workshop.ps1` dosyasını çalıştırın (veya batchfile için `run_downloader.bat`a çift tıklayın).
2. Atölye ID/URL'lerini boşluk ya da virgülle girin veya `-WorkshopIds` ve isteğe bağlı `-SteamCmdPath`, `-GmadPath`, `-ExtractRoot` parametrelerini kullanın.
3. Açılan dosyalar `extracted/<id>/` klasörüne düşer.

**İpuçları**
- Script, SteamCMD'yi her çalışmada günceller ve bulut klasöründeyse otomatik olarak taşır.
- `_legacy.bin` dosyaları gerektiğinde `.gma` olarak kopyalanır.
- Sorun olursa `steamcmd` klasörünü silip scripti yeniden çalıştırın; tekrar indirir.

--- by cocktail ---
