# my_settings – Linux Setup & Dotfiles

Disztrófüggetlen Linux telepítő- és konfigurációs (dotfiles) gyűjtemény. A célja, hogy újratelepítéskor vagy egy új gép (laptop, asztali gép, Raspberry Pi szerver) beüzemelésekor egyetlen paranccsal felkerüljenek a szükséges programok, a Zsh környezet, a saját téma, az aliasok és a saját binárisok.

---

## Támogatott rendszerek

A telepítő automatikusan felismeri az alábbi csomagkezelőket:
* **Debian / Ubuntu / Raspberry Pi OS** (`apt`)
* **Fedora / RHEL-alapú rendszerek** (`dnf`)
* **Arch Linux / Manjaro / EndeavourOS** (`pacman`)
* **openSUSE** (`zypper`)

A grafikus alkalmazások telepítése **Flatpak** alapon történik, így nem kell disztrónként eltérő csomagnevekkel vagy külső tárolókkal foglalkozni.

---


### Automatikus profilfelismeréssel (megerősítéssel)
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Bence-3878/my_settings/master/bootstrap.sh)"
```

### Közvetlen profillal
**Asztali gép / laptop:**
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Bence-3878/my_settings/master/bootstrap.sh)" -- --desktop
```

**Szerver / Raspberry Pi:**
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Bence-3878/my_settings/master/bootstrap.sh)" -- --server
```

---

## Profilok működése

Ha nem adsz meg kapcsolót, az `install.sh` automatikusan javasol egy profilt (ha nincs grafikus felület vagy Raspberry Pi-t észlel, akkor `server`, különben `desktop`), majd rákérdez.

| Funkció / Csomagcsoport | `server` | `desktop` |
| :--- | :---: | :---: |
| Alap CLI eszközök (`mc`, `zsh`, `git`, `fzf`, `btop`, `tmux`, `micro`, `eza`, `fastfetch`, `tldr`, `bat`, stb.) | ✅ | ✅ |
| SSH szerver (`openssh-server`) | ✅ | ✅ |
| Tűzfal (`ufw` / `gufw`) | `ufw` | `gufw` |
| Automatikus `tmux` indítás SSH/terminál belépéskor | ✅ | ❌ |
| Asztali & fejlesztői csomagok (`gcc`, `clang`, `gdb`, `terminator`, `wine`, `git-cola`, `mplayer`, stb.) | ❌ | ✅ |
| X11-specifikus eszközök (`numlockx`, `guake`) | ❌ | Csak X11 alatt |
| Flatpak GUI appok (GIMP, Remmina) | ❌ | ✅ |
| Espanso (X11/Wayland detektálással) & UltraEdit (`uex`) | ❌ | ✅ |
| Oh My Zsh + pluginok + saját téma + konfig symlinkek | ✅ | ✅ |
| Saját C programok fordítása (`bin/*.c` → `~/bin`) | ✅ *(ha van fordító)* | ✅ |

---

## Használat meglévő rendszeren

Ha nem akarod a teljes csomagtelepítést lefuttatni, a részscriptek külön is használhatók a klónozott repó mappájából:

```bash
# Csak Oh My Zsh és pluginok telepítése / frissítése
bash ./setup_zsh.sh

# Csak a konfigok bekötése és profil beállítása (vagy váltása)
bash ./link_configs.sh desktop   # vagy: server

# Saját C binárisok újrafordítása a ~/bin mappába
bash ./build_bin.sh
```

A teljes `install.sh` is biztonságosan újrafuttatható meglévő rendszeren: a már telepített csomagokat és meglévő pluginokat átugorja, a korábbi `.zshrc` fájlról pedig `.zshrc.bak` mentést készít.

---

## Mappaszerkezet

```text
my_settings/
├── bootstrap.sh          # Egyparancsos indító (git telepítés, klónozás, install.sh)
├── install.sh            # Fő telepítő (profilok, csomagkezelő, X11, Flatpak, extra appok)
├── setup_zsh.sh          # Oh My Zsh (--unattended) és külső pluginok klónozása
├── link_configs.sh       # Symlinkek létrehozása és ~/.my_settings_env mentése
├── build_bin.sh          # bin/*.c forrásfájlok fordítása a ~/bin mappába
├── zshrc                 # Fő Zsh konfiguráció (symlinkelve: ~/.zshrc)
├── bin/                  # Saját scriptek és C források (pl. unzip.sh, error_teszt.c)
├── config/               # Programspecifikus konfigfájlok (pl. neofetch.conf)
├── valami/               # Egyéb erőforrások (pl. done.mp3 a beep aliashoz)
└── zsh/
    ├── aliases.zsh       # Saját aliasok és shell függvények
    ├── plugins/          # Külső Oh My Zsh pluginok (setup_zsh.sh tölti le)
    └── themes/
        └── my.zsh-theme  # Saját 2 soros Agnoster-stílusú Zsh téma
```

---

## Zsh környezet és saját téma (`my.zsh-theme`)

A `my.zsh-theme` egy letisztított, két soros, Agnoster-stílusú Powerline téma.

**Funkciók:**
* **Két soros elrendezés:** felül a színes szegmensek, alatta a parancssor (a `❯` nyíl zöld sikeres, piros hibás előző parancs után).
* **Kiemelt SSH jelzés:** távoli kapcsolatnál külön színű `SSH user@host` blokkot mutat.
* **Python környezet:** kijelzi az aktív `venv`/`.venv` vagy `conda` környezetet (ha a mappa neve simán `venv`/`.venv`, a szülő projekt nevét írja ki).
* **Rövidített mappanév:** 4 vagy több szint mélységnél tömöríti az útvonalat (`~/…/szülő/aktuális`).
* **Jobb oldali prompt (`RPROMPT`):** hiba esetén piros hibakód (`✘`), 2 másodpercnél hosszabb parancsoknál futási idő (`⏱ 2m 5s`), valamint aktuális idő.

### Használt Zsh pluginok
* **Beépített (OMZ):** `git`, `sudo`, `web-search`, `virtualenv`, `ssh-agent`, `copyfile`
* **Külső:**
  * `zsh-z` – gyors mappaugrás gyakoriság alapján
  * `you-should-use` – figyelmeztet, ha egy parancsra már van aliasod
  * `zsh-autopair` – automatikus idézőjel- és zárójelpár-kezelés
  * `fzf-tab` – interaktív `fzf` menü a `Tab` kiegészítéshez
  * `zsh-autosuggestions` – gépelés közbeni előzmény-javaslatok
  * `zsh-history-substring-search` – előzménykeresés a nyilakkal
  * `zsh-completions` – extra kiegészítések CLI eszközökhöz
  * `zsh-syntax-highlighting` – szintaxiskiemelés a parancssorban

---

## Hasznos aliasok és függvények (`zsh/aliases.zsh`)

* `m` / `nano` – alapértelmezett szerkesztő (`micro` helyben, `nano` SSH alatt); `nano2` az eredeti `/bin/nano`
* `bat` / `cat` – Ubuntu/Debian alatt a `batcat` automatikusan `bat`-ra van aliasolva
* `zshconfig` – a repó `zshrc` fájljának megnyitása szerkesztésre
* `aliases` – a `zsh/aliases.zsh` megnyitása szerkesztésre
* `beep` – értesítő hang lejátszása hosszabb parancsok végén (pl. `hosszu_parancs; beep`)
* `kra` – `*.jpg.kra` fájlok rendezése a `kra/` mappába és backup (`*~`) fájlok törlése

---

## Tippek és hibaelhárítás

* **Betűtípus:** A prompt elválasztó jeleihez Powerline vagy Nerd Font (pl. *MesloLGS NF*, *JetBrainsMono Nerd Font*) beállítása szükséges a terminálban.
* **Szerver `tmux` megkerülése:** Ha `server` profilnál egyszer mégis `tmux` nélkül szeretnél belépni SSH-val:
  ```bash
  ssh felhasznalo@szerver -t "TMUX=1 zsh"
  ```
* **Plugin-cache frissítése:** Ha új kiegészítéseket vettél fel (`zsh-completions`), futtasd:
  ```bash
  rm -f ~/.zcompdump* && exec zsh
  ```
* **Biztonság (publikus repó esetén):** Ne tölts fel a repóba privát SSH-kulcsokat, jelszavakat vagy termékkulcsokat (ellenőrizd a `.gitignore` fájlt commit előtt).