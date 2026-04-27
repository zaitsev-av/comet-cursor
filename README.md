---

<p align="center">
  <a href="README.md">English</a> &nbsp;|&nbsp; <a href="readme.ru.md">Русский</a>
</p>

---

<p align="center">
  <img src="assets/demo.gif" width="680" alt="Comet Cursor in action">
</p>

<h1 align="center">Comet Cursor</h1>

<p align="center">
  A menu bar app for macOS that adds a glowing comet trail to your cursor.<br>
</p>

<p align="center">
  <a href="https://github.com/zaitsev-av/comet-cursor/releases/latest"><img src="https://img.shields.io/github/v/release/zaitsev-av/comet-cursor?label=Download&color=orange" alt="Download"></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-blue" alt="macOS 13+">
  <img src="https://img.shields.io/badge/Swift-5.9-orange" alt="Swift 5.9">
  <img src="https://img.shields.io/badge/Metal-rendering-black" alt="Metal rendering">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT">
  <a href="https://github.com/zaitsev-av/comet-cursor/stargazers"><img src="https://img.shields.io/github/stars/zaitsev-av/comet-cursor?style=social" alt="GitHub Stars"></a>
  <img src="https://img.shields.io/github/last-commit/zaitsev-av/comet-cursor" alt="Last Commit">
  <a href="https://boosty.to/zaitsev_av"><img src="https://img.shields.io/badge/Support-Boosty-f15f2c" alt="Support on Boosty"></a>
</p>

## What it does

- Animated comet trail that follows your cursor in real time
- Three built-in presets: `Presenter Glow`, `Neon Focus`, `Minimal Trace`
- Adjust trail length, thickness, opacity, and fade speed on the fly - no restart needed
- Separate color pickers for the trail body and the head
- Global toggle via the menu bar header switch or `⌥⌘C` shortcut
- Per-app exclusion list so the effect doesn't get in the way in specific apps
- Launch at Login support
- Works across multiple monitors - one overlay per screen, always on top
- UI localized in English and Russian

<p align="center">
  <img src="assets/settings.png" width="360" alt="Comet Cursor settings panel">
</p>

## Who it's for

If you regularly share your screen, this is probably for you:

- Developers doing live demos or pair programming sessions
- Designers and PMs walking through Figma or slides
- Teachers and mentors pointing things out on screen
- Streamers and video creators recording screencasts

---

## Download

Download the `.dmg`, open it, drag **Comet Cursor** to Applications.

<p align="center">
  <a href="../../releases/latest"><strong>Download latest release →</strong></a>
</p>

## Troubleshooting

**macOS blocks the app on first launch**
Right-click the app → **Open** → **Open** to allow it once.

**"App is damaged" error**
```
xattr -cr "/Applications/Comet Cursor.app"
```

**Trail doesn't appear**
The app needs Accessibility access to track the cursor via `CGEventTap`.
Go to `System Settings → Privacy & Security → Accessibility` and add Comet Cursor.

**Trail feels laggy**
Without Accessibility access the app falls back to polling mode, which is slightly less precise. Granting access fixes this.

---

## Support

If Comet Cursor is useful to you, you can support its development. It helps keep the project alive and motivates new features.

**[Support on Boosty →](https://boosty.to/zaitsev_av)**

---

## Build from source

```bash
cd CometCursorApp
./scripts/build.sh
open "Comet Cursor.app"
```

Requires Xcode Command Line Tools: `xcode-select --install`

For architecture details and how to contribute, see [CONTRIBUTING.md](./CONTRIBUTING.md).

---

## Go Prototype

The original Go + CGo + OpenGL proof of concept lives in [`prototype-go/`](./prototype-go/). Archived, not maintained.

---

## License

MIT
