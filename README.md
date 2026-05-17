---

<p align="center">
  <a href="README.md">English</a> &nbsp;|&nbsp; <a href="readme.ru.md">Русский</a>
</p>

---

<p align="center">
  <img src="assets/demo.gif" width="680" alt="Comet Cursor in action">
</p>

<h1 align="center">☄️ Comet Cursor</h1>

<p align="center">
  <b>Free & open-source macOS app that adds a glowing comet trail to your cursor.</b><br>
  <i>Never lose your audience during presentations again.</i>
</p>

<p align="center">
  <a href="https://github.com/zaitsev-av/comet-cursor/releases/latest"><img src="https://img.shields.io/github/v/release/zaitsev-av/comet-cursor?label=Download&color=orange" alt="Download"></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-blue" alt="macOS 13+">
  <img src="https://img.shields.io/badge/Swift-5.9-orange" alt="Swift 5.9">
  <img src="https://img.shields.io/badge/Metal-GPU%20accelerated-black" alt="Metal GPU">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT">
  <a href="https://github.com/zaitsev-av/comet-cursor/stargazers"><img src="https://img.shields.io/github/stars/zaitsev-av/comet-cursor?style=social" alt="GitHub Stars"></a>
</p>

---

## Why Comet Cursor?

You're sharing your screen. Your audience squints at a tiny cursor arrow, lost in a sea of code, slides, or design mockups. You wiggle the mouse hoping they'll notice.

Comet Cursor fixes this. It draws a beautiful, animated comet trail behind your cursor — **always on top, across all monitors, GPU-accelerated, zero lag**. Your audience sees exactly where you're pointing, every time.

### vs alternatives

| | Comet Cursor | Mouseposé | KeyCastr | Built-in macOS |
|---|---|---|---|---|
| **Cursor trail** | ✅ Glowing comet | ✅ Basic highlight | ❌ Keystrokes only | ❌ None |
| **Price** | Free | $11 | Free | Free |
| **Open source** | ✅ MIT | ❌ | ❌ | ❌ |
| **GPU-accelerated** | ✅ Metal | ❌ | ❌ | — |
| **Multi-monitor** | ✅ | ❌ | N/A | — |
| **Customizable** | 3 presets + full control | Limited | N/A | Cursor size only |
| **App exclusions** | ✅ Per-app | ❌ | — | — |

---

## What it does

- ☄️ Animated comet trail that follows your cursor in real time (60 FPS, Metal)
- 🎨 **3 built-in presets:** `Presenter Glow`, `Neon Focus`, `Minimal Trace`
- 🎛️ Adjust trail length, thickness, opacity, and fade speed on the fly — no restart needed
- 🎨 Separate color pickers for trail body and head
- ⌨️ Global toggle: menu bar switch or `⌥⌘C`
- 🚫 Per-app exclusion list — auto-disable in apps where you don't need it
- 🖥️ Multi-monitor: separate overlay per screen, always on top
- 🌍 UI in English and Russian
- 🔋 Minimal resource usage: ~20 MB RAM, near-zero CPU when idle

<p align="center">
  <img src="assets/settings.png" width="360" alt="Comet Cursor settings panel">
</p>

## Who it's for

If you regularly share your screen, this is for you:

- **Developers** — live demos, pair programming, code reviews
- **Designers & PMs** — Figma walkthroughs, slide presentations
- **Teachers & mentors** — explaining concepts on screen
- **Streamers & content creators** — recording tutorials and screencasts

## Download

Download `.dmg`, open it, drag **Comet Cursor** to Applications.

<p align="center">
  <a href="https://github.com/zaitsev-av/comet-cursor/releases/latest"><strong>⬇ Download latest release</strong></a>
</p>

> **First launch:** macOS may block the app since it's not from the App Store.
> Right-click the app → **Open** → **Open** to allow it once.

> **Requires Accessibility permission** for cursor tracking. The app will prompt you on first launch.

## Build from source

```bash
# Requires Xcode Command Line Tools: xcode-select --install
git clone https://github.com/zaitsev-av/comet-cursor.git
cd comet-cursor/CometCursorApp
./scripts/build.sh
open "Comet Cursor.app"
```

No Xcode required — just `swift build`.

## Tech stack

| Layer | Technology |
|---|---|
| Language | Swift 5.9 |
| UI | SwiftUI + AppKit |
| Rendering | Metal (GPU) — triangle strip ribbon, no line strip artifacts |
| Tracking | CGEventTap + 120 Hz polling fallback |
| Build | `swift build` (no `.xcodeproj`) |
| CI/CD | GitHub Actions → DMG → Release |
| Min OS | macOS 13+ |

For architecture details, see [CONTRIBUTING.md](./CONTRIBUTING.md).

## Troubleshooting

**macOS blocks the app on first launch**
Right-click the app → **Open** → **Open** to allow it once.

**"App is damaged" error**
```bash
xattr -cr "/Applications/Comet Cursor.app"
```

**Trail doesn't appear**
Add Comet Cursor to `System Settings → Privacy & Security → Accessibility`.

**Trail feels laggy**
Grant Accessibility access — the app falls back to polling mode without it.

## Support

If Comet Cursor is useful to you, support its development:

**[Support on Boosty →](https://boosty.to/zaitsev_av)**

⭐ **Star the repo** — it helps more people discover the app!

---

## Go Prototype

The original Go + CGo + OpenGL proof of concept lives in [`prototype-go/`](./prototype-go/). Archived, not maintained.

## Read this in Russian

[🇷🇺 Русская версия](./readme.ru.md)

## License

MIT — do whatever you want, just keep the license notice.
