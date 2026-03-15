<p align="center">
  <img src="assets/demo.gif" width="680" alt="Comet Cursor in action">
</p>

<h1 align="center">Comet Cursor</h1>

<p align="center">
  A menu bar app for macOS that adds a glowing comet trail to your cursor.<br>
  Приложение для macOS, которое добавляет светящийся хвост кометы к курсору.
</p>

<p align="center">
  <a href="https://github.com/zaitsev-av/comet-cursor/releases/latest"><img src="https://img.shields.io/github/v/release/zaitsev-av/comet-cursor?label=Download&color=orange" alt="Download"></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-blue" alt="macOS 13+">
  <img src="https://img.shields.io/badge/Swift-5.9-orange" alt="Swift 5.9">
  <img src="https://img.shields.io/badge/Metal-rendering-black" alt="Metal rendering">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT">
  <a href="https://boosty.to/zaitsev_av"><img src="https://img.shields.io/badge/Support-Boosty-f15f2c" alt="Support on Boosty"></a>
</p>

---

<p align="center">
  <a href="#english">English</a> &nbsp;|&nbsp; <a href="#русский">Русский</a>
</p>

---

## Download

<table>
<tr>
<td>

**English:** Download the `.dmg`, open it, drag **Comet Cursor** to Applications.

> **First launch:** macOS may block the app since it's not signed with an Apple certificate.
> Right-click the app -> **Open** -> **Open** to allow it once.
>
> If you see "app is damaged" - run in Terminal:
> ```
> xattr -cr "/Applications/Comet Cursor.app"
> ```

</td>
<td>

**Русский:** Скачай `.dmg`, открой, перетащи **Comet Cursor** в Applications.

> **При первом запуске** macOS может заблокировать приложение.
> Нажми правой кнопкой -> **Открыть** -> **Открыть**.
>
> Если видишь "приложение повреждено" - выполни в Терминале:
> ```
> xattr -cr "/Applications/Comet Cursor.app"
> ```

</td>
</tr>
</table>

<p align="center">
  <a href="../../releases/latest"><strong>Download latest release →</strong></a>
</p>

---

## Support / Поддержать

<table>
<tr>
<td>

If Comet Cursor is useful to you, you can support its development. It helps keep the project alive and motivates new features.

**[Support on Boosty →](https://boosty.to/zaitsev_av)**

</td>
<td>

Если приложение полезно, поддержи разработку. Это помогает проекту жить и мотивирует делать новые фичи.

**[Поддержать на Boosty →](https://boosty.to/zaitsev_av)**

</td>
</tr>
</table>

---

## English

### What it does

- Animated comet trail that follows your cursor in real time
- Three built-in presets: `Presenter Glow`, `Neon Focus`, `Minimal Trace`
- Adjust trail length, thickness, opacity, and fade speed on the fly - no restart needed
- Separate color pickers for the trail body and the head
- Global toggle and pause via `⌥⌘C`
- Per-app exclusion list so the effect doesn't get in the way in specific apps
- Launch at Login support
- Works across multiple monitors - one overlay per screen, always on top
- UI localized in English and Russian

### Who it's for

If you regularly share your screen, this is probably for you:

- Developers doing live demos or pair programming sessions
- Designers and PMs walking through Figma or slides
- Teachers and mentors pointing things out on screen
- Streamers and video creators recording screencasts

### Build from source

```bash
cd CometCursorApp
./scripts/build.sh
open "Comet Cursor.app"
```

Requires Xcode Command Line Tools: `xcode-select --install`

### Permissions

The app tracks the cursor via `CGEventTap`, which requires **Accessibility** access.

1. Open `System Settings -> Privacy & Security -> Accessibility`
2. Add `Comet Cursor` to the list

Without it, the app falls back to polling - works, but slightly less precise.

### Architecture

<p align="center">
  <img src="assets/settings.png" width="360" alt="Comet Cursor settings panel">
</p>

Built with **SwiftUI + Metal + AppKit**, targeting macOS 13+.

| File | What it does |
|---|---|
| `AppDelegate.swift` | Menu bar item, settings window, overlay lifecycle |
| `CursorTracker.swift` | CGEventTap with polling fallback |
| `TrailManager.swift` | Trail point history, timestamp-based fade |
| `CometRenderer.swift` | Metal rendering, ribbon geometry, presets |
| `SettingsModel.swift` | ObservableObject wrapping UserDefaults |
| `SettingsView.swift` | SwiftUI settings panel, sliders, color pickers |

<details>
<summary>Data flow & rendering details</summary>

**Data flow:**
```
CGEventTap -> DispatchQueue.main -> TrailManager.update()
                                          |
MTKView render thread -> TrailManager.tick() + snapshot() -> CometRenderer.draw()
```

**Rendering:** The trail is a Metal triangle strip ribbon. Each trail point generates a left/right vertex pair; adjacent segments share vertices so there are no gaps at joints. Soft-edge falloff is done in the fragment shader. Shaders compile at runtime via `device.makeLibrary(source:)` - no `xcrun metal` needed at build time.

**Multi-monitor:** One `NSWindow + MTKView` per `NSScreen`, positioned via `setFrame(screen.frame)`.

**Coordinate conversion:** CGEvent uses top-left origin (Y down), AppKit uses bottom-left (Y up). Conversion happens before passing points to the renderer.

</details>

---

## Русский

### Что умеет

- Анимированный хвост кометы в реальном времени
- Три пресета: `Presenter Glow`, `Neon Focus`, `Minimal Trace`
- Настройка длины, толщины, прозрачности и скорости затухания на лету - без перезапуска
- Отдельные цветопикеры для тела хвоста и его головы
- Глобальное включение/пауза через `⌥⌘C`
- Список исключений - можно отключить эффект в конкретных приложениях
- Запуск при входе в систему
- Работает на нескольких мониторах - отдельный overlay на каждый экран, всегда поверх окон
- Интерфейс на английском и русском

### Для кого

Если вы регулярно показываете экран, это приложение для вас:

- Разработчики на демо и парном программировании
- Дизайнеры и PM на презентациях в Figma или слайдах
- Преподаватели и менторы, объясняющие что-то на экране
- Стримеры и авторы скринкастов

### Сборка из исходников

```bash
cd CometCursorApp
./scripts/build.sh
open "Comet Cursor.app"
```

Требуется Xcode Command Line Tools: `xcode-select --install`

### Разрешения

Приложение отслеживает курсор через `CGEventTap`, для которого нужен доступ к **Accessibility**.

1. `System Settings -> Privacy & Security -> Accessibility`
2. Добавьте `Comet Cursor` в список разрешённых приложений

Без него приложение переключится на polling - работает, но с чуть меньшей точностью.

### Архитектура

Написано на **SwiftUI + Metal + AppKit**, минимальная версия macOS 13.

| Файл | За что отвечает |
|---|---|
| `AppDelegate.swift` | Иконка в меню-баре, окно настроек, lifecycle overlay-окон |
| `CursorTracker.swift` | CGEventTap и fallback через polling |
| `TrailManager.swift` | История точек хвоста, fade по timestamp |
| `CometRenderer.swift` | Metal-рендеринг, геометрия ленты, пресеты |
| `SettingsModel.swift` | ObservableObject поверх UserDefaults |
| `SettingsView.swift` | SwiftUI-панель настроек, слайдеры, цветопикеры |

<details>
<summary>Поток данных и детали рендеринга</summary>

**Поток данных:**
```
CGEventTap -> DispatchQueue.main -> TrailManager.update()
                                          |
MTKView render thread -> TrailManager.tick() + snapshot() -> CometRenderer.draw()
```

**Рендеринг:** Хвост - это Metal triangle strip (лента). Каждая точка хвоста генерирует пару вершин (левая/правая), соседние сегменты разделяют вершины - никаких разрывов. Размытие края в фрагментном шейдере. Шейдеры компилируются в рантайме через `device.makeLibrary(source:)`.

**Мультимонитор:** По одному `NSWindow + MTKView` на каждый `NSScreen`, позиционирование через `setFrame(screen.frame)`.

**Конвертация координат:** CGEvent - Y сверху вниз, AppKit - Y снизу вверх. Конвертация до передачи точек в рендерер.

</details>

---

## Go Prototype

The original Go + CGo + OpenGL proof of concept lives in [`prototype-go/`](./prototype-go/). Archived, not maintained.

---

## License

MIT
