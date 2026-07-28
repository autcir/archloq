# 🎨 Catppuccin Mocha Rice — Lenovo LOQ 17IRX10
### KDE Plasma 6.7 · Wayland · Arch Linux · 2026

> Rice completo Catppuccin Mocha Blue per KDE Plasma 6 su Wayland.
> Ogni componente è configurato: dal login screen (SDDM) alla shell, dal terminale all'editor.
> Idempotente — rieseguibile su un sistema pulito da zero.

---

> [!CAUTION]
> **`kwin-effects-better-blur-dx` NON è compatibile con Plasma 6.7 Wayland.**
> Causa blocco totale dell'input del mouse sul desktop.
> **NON installarlo.** Il blur usa esclusivamente il blur nativo KDE (`blurEnabled=true`).
> Stessa cosa per `kwin-effects-forceblur` e altri fork blur su questa versione.

> [!IMPORTANT]
> **Dopo ogni reboot/reset Plasma**, esegui:
> ```bash
> bash ~/Documenti/cbrain/dev/arch/loq/dotfiles/scripts/reapply.sh
> ```

---

## Preview

| Componente | Tema | Note |
|---|---|---|
| Plasma Color Scheme | `CatppuccinMochaBlue` | Ufficiale catppuccin/kde |
| Window Decoration | `CatppuccinMocha-Classic` | Aurorae rounded |
| Application Style | `catppuccin-mocha-blue` | Kvantum Qt |
| GTK 3/4 Theme | `catppuccin-mocha-blue-standard+default` | |
| Icon Theme | `Papirus-Dark` | Folder color: blue catppuccin |
| Cursor | `catppuccin-mocha-blue-cursors` | |
| SDDM Login | `catppuccin-mocha-blue` | |
| Splash Screen | `Catppuccin-Mocha-Blue` | |
| Blur | `kwin-effects-better-blur-dx` | Force blur Wayland |
| Trasparenza | 92% active / 82% inactive | Via KWin window rules |
| Wallpaper | Catppuccin Mocha Evening Sky | `~/.local/share/wallpapers/catppuccin-mocha/` |

---

## Struttura repo

```
loq/
├── install.sh                    # Entrypoint principale (interattivo o --yes)
├── dotfiles/
│   ├── config/
│   │   ├── fastfetch/            # config.jsonc — Catppuccin + Nerd Font icons
│   │   ├── ghostty/              # config — Catppuccin Mocha, blur 85%, JetBrains NF 13
│   │   ├── konsole/              # colorscheme + profile CatppuccinMocha
│   │   ├── starship/             # starship.toml — prompt powerline Catppuccin
│   │   ├── zsh/                  # .zshrc base (stow-friendly)
│   │   ├── bat/                  # config + themes/CatppuccinMocha.tmTheme
│   │   ├── btop/                 # btop.conf + themes/catppuccin_mocha.theme
│   │   ├── cava/                 # config — gradiente Mocha 60fps
│   │   ├── nvim/                 # init.lua — lazy.nvim + catppuccin.nvim
│   │   ├── kvantum/              # catppuccin-mocha-blue/ kvconfig
│   │   └── kwin/                 # kwinrc.relevant — snapshot Effect-better_blur_dx
│   ├── scripts/
│   │   ├── 00-prereqs.sh         # yay, stow, konsave, dipendenze base
│   │   ├── 01-terminal.sh        # ghostty + fastfetch install
│   │   ├── 02-shell.sh           # starship, zsh-syntax-highlighting, autosuggestions
│   │   ├── 03-fonts.sh           # JetBrainsMono Nerd Font, Inter, Font Awesome
│   │   ├── 04-theme-catppuccin.sh# Plasma colorscheme + Kvantum + GTK + Konsole + splash + cursor
│   │   ├── 05-plasma-widgets.sh  # Widget opzionali (documentazione)
│   │   ├── 06-konsave-backup.sh  # Backup profilo Plasma via konsave
│   │   ├── 07-eyecare-transparency.sh # KWin blur + font UI Inter + eye-care
│   │   ├── 08-themes-github.sh   # Catppuccin/KDE + Kvantum + look-and-feel da GitHub
│   │   ├── 09-icons-papirus.sh   # Papirus-Dark + papirus-folders blue
│   │   ├── 10-gtk-catppuccin.sh  # catppuccin-gtk-theme-mocha GTK3/GTK4
│   │   ├── 11-wallpaper-catppuccin.sh # Download + applica wallpaper Catppuccin
│   │   ├── 12-transparency-blur.sh    # [DEPRECATED] Better Blur DX — NON usare su Plasma 6.7
│   ├── reapply.sh            # ⭐ Riapplica tutto dopo reboot in modo SICURO
│   ├── 99-rollback.sh        # Rollback via konsave backup
│   │   └── verify-catppuccin.sh  # Verifica ✅/❌ tutti i componenti
│   └── wallpapers/               # arch-start.png (fallback locale)
├── config/
│   ├── applications/             # .desktop files custom
│   └── legion_linux/             # Config hardware LOQ specifiche
├── scripts/                      # Script utility sistema (loq-mode, loq-power, ecc.)
├── manage/                       # loq-backup.sh
└── optimize/                     # Script ottimizzazione
```

---

## Installazione da zero (formato)

### 1. Prerequisiti di sistema

```bash
# Installa yay (AUR helper)
sudo pacman -S --needed base-devel git
git clone https://aur.archlinux.org/yay.git /tmp/yay
cd /tmp/yay && makepkg -si --noconfirm

# Clona il repo
git clone <repo-url> ~/Documenti/cbrain/dev/arch/loq
cd ~/Documenti/cbrain/dev/arch/loq
```

### 2. Esecuzione automatica (consigliata)

```bash
bash install.sh --yes
```

### 3. Esecuzione manuale fase per fase

```bash
# SEMPRE prima: backup del profilo Plasma attuale
bash dotfiles/scripts/06-konsave-backup.sh

# Fase 0: prerequisiti (yay, stow, konsave)
bash dotfiles/scripts/00-prereqs.sh

# Fase 3: font (JetBrainsMono Nerd, Inter)
bash dotfiles/scripts/03-fonts.sh

# Fase 2: shell (starship, zsh plugins)
bash dotfiles/scripts/02-shell.sh

# Fase 1: terminale (ghostty, fastfetch)
bash dotfiles/scripts/01-terminal.sh

# Fase 8: temi Catppuccin da GitHub (CORE — esegui prima di 04)
bash dotfiles/scripts/08-themes-github.sh

# Fase 4: color scheme + Kvantum + GTK + Konsole + SDDM
bash dotfiles/scripts/04-theme-catppuccin.sh

# Fase 9: icone Papirus
bash dotfiles/scripts/09-icons-papirus.sh

# Fase 10: GTK theme
bash dotfiles/scripts/10-gtk-catppuccin.sh

# Fase 11: wallpaper Catppuccin
bash dotfiles/scripts/11-wallpaper-catppuccin.sh

# Fase 7: eye-care, blur KWin, font Inter
bash dotfiles/scripts/07-eyecare-transparency.sh

# Fase 12: trasparenza + Better Blur DX (la chicca)
bash dotfiles/scripts/12-transparency-blur.sh

# Verifica tutto
bash dotfiles/scripts/verify-catppuccin.sh
```

---

## Pacchetti installati

### Pacman (ufficiali)

| Pacchetto | Scopo |
|---|---|
| `ghostty` | Terminale GPU-accelerated Wayland |
| `fastfetch` | System info Catppuccin |
| `starship` | Prompt shell Catppuccin powerline |
| `bat` | `cat` colorato con tema Catppuccin |
| `btop` | Monitor sistema con braille graphs |
| `fzf` | Fuzzy finder con palette Catppuccin |
| `neovim` | Editor con lazy.nvim + catppuccin.nvim |
| `cava` | Audio visualizer gradiente Mocha |
| `papirus-icon-theme` | Icon theme base |
| `papirus-folders` | Folder color blue Catppuccin |
| `kvantum` | Application style Qt |
| `inter-font` | Font UI sistema |
| `wlsunset` | Blue light filter serale Wayland |
| `zsh-syntax-highlighting` | Highlighting Catppuccin palette |
| `zsh-autosuggestions` | Suggerimenti shell |
| `wget` `unzip` | Dipendenze script |

### AUR

| Pacchetto | Scopo |
|---|---|
| `catppuccin-gtk-theme-mocha` | GTK3/GTK4 Catppuccin (tutti gli accent) |
| `catppuccin-sddm-theme-mocha` | Login screen SDDM Catppuccin |
| `kwin-effects-better-blur-dx` | **Force blur su TUTTE le finestre Wayland** |

### Via GitHub/catppuccin org (script 08)

| Repo | Cosa installa |
|---|---|
| `catppuccin/kde` | Color scheme + Aurorae + splash + look-and-feel |
| `catppuccin/kvantum` | Application style Qt Mocha |
| `catppuccin/bat` | Tema sintassi per bat |
| `catppuccin/btop` | Tema btop |
| `catppuccin/wallpapers` | Wallpaper Mocha |

---

## Configurazione Neovim (lazy.nvim)

Al primo avvio di `nvim`, lazy.nvim scarica automaticamente:

| Plugin | Funzione |
|---|---|
| `catppuccin/nvim` | Colorscheme transparent mocha |
| `nvim-lualine/lualine.nvim` | Statusline Catppuccin |
| `nvim-treesitter` | Syntax highlighting |
| `nvim-telescope/telescope.nvim` | Fuzzy finder |
| `echasnovski/mini.files` | File explorer |
| `folke/which-key.nvim` | Keybind helper |
| `echasnovski/mini.starter` | Dashboard ASCII |
| `lewis6991/gitsigns.nvim` | Git decorations |
| `echasnovski/mini.indentscope` | Guide indentazione |

---

## Shell — alias nerd 2026

```zsh
ff          # fastfetch
btop        # monitor sistema
cava        # visualizzatore audio
nv / vim    # neovim
cat         # bat (Catppuccin syntax)
lt          # eza --tree --icons
glo         # git log grafico
gs          # git status -sb
reload      # exec zsh
zrc         # nvim ~/.zshrc
nrc         # nvim ~/.config/nvim/init.lua
kwin-restart # qdbus6 KWin reconfigure
```

---

## Trasparenza e Blur

Il rice usa **due livelli** di trasparenza:

### 1. Terminali (controllato dall'app stessa)
| App | Opacità | File |
|---|---|---|
| Ghostty | `0.85` | `dotfiles/config/ghostty/config` |
| Konsole | `8%` | `dotfiles/config/konsole/CatppuccinMocha.profile` |

### 2. App Qt (controllato da Kvantum)
| Impostazione | Valore |
|---|---|
| `reduce_window_opacity` | `15` (15% più trasparente) |
| `translucent_windows` | `true` |
| `blurring` | `true` |
| `blur_konsole` | `true` |

### 3. Blur engine (nativo KDE — SAFE)
- **Blur nativo KDE** (`blurEnabled=true`) — unico metodo sicuro su Wayland
- BlurStrength: `12`, NoiseStrength: `0`

> [!CAUTION]
> **NON installare `kwin-effects-better-blur-dx` o altri fork blur.**
> Su KDE Plasma 6.7 Wayland bloccano l'input del mouse sul desktop in modo permanente.
> Richiede reboot per ripristinare. Il blur nativo KDE è sufficiente.

---

## ⚠️ Azione manuale richiesta (una volta dopo install)

**Papirus folder color** — se papirus-folders non ha applicato il colore:
```bash
papirus-folders -C blue --theme Papirus-Dark
```

**Dopo ogni aggiornamento Plasma/KWin:**
```bash
bash ~/Documenti/cbrain/dev/arch/loq/dotfiles/scripts/reapply.sh
```

---

## Eye-care

| Tool | Config |
|---|---|
| KWin blur | NoiseStrength=0, BlurStrength=15 |
| Ghostty opacity | 0.85 (sfondo visibile ma leggibile) |
| wlsunset | `wlsunset -T 4500 -t 3000 -l 40.7 -L 14.6` (sera) |
| Font UI | Inter 11pt |
| Font terminale | JetBrainsMono Nerd Font 11pt |

---

## Rollback

```bash
# Ripristina profilo Plasma dal backup konsave
bash dotfiles/scripts/99-rollback.sh

# Oppure manualmente
konsave -a ~/loq-konsave-backups/<nome-backup>.konsave
```

---

## Verifica installazione

```bash
bash dotfiles/scripts/verify-catppuccin.sh
```

Output atteso: `✅ PASS: 15 | ❌ FAIL: 0 | ⚠️ WARN: 0`

---

## Hardware target

- **Macchina**: Lenovo LOQ 17IRX10
- **GPU**: NVIDIA + Intel iGPU (Wayland Optimus)
- **Display**: 1920×1080 + esterno
- **DE**: KDE Plasma 6.7.2 su Wayland

---

*Ultimo aggiornamento: Luglio 2026 — rice Catppuccin Mocha Blue completo*
