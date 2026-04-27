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
  Приложение для macOS, которое добавляет светящийся хвост кометы к курсору.<br>
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

## Что умеет

- Анимированный хвост кометы в реальном времени
- Три пресета: `Presenter Glow`, `Neon Focus`, `Minimal Trace`
- Настройка длины, толщины, прозрачности и скорости затухания на лету - без перезапуска
- Отдельные цветопикеры для тела хвоста и его головы
- Глобальное включение через переключатель в заголовке меню или `⌥⌘C`
- Список исключений - можно отключить эффект в конкретных приложениях
- Запуск при входе в систему
- Работает на нескольких мониторах - отдельный overlay на каждый экран, всегда поверх окон
- Интерфейс на английском и русском

<p align="center">
  <img src="assets/settings.png" width="360" alt="Comet Cursor settings panel">
</p>

## Для кого

Если вы регулярно показываете экран, это приложение для вас:

- Разработчики на демо и парном программировании
- Дизайнеры и PM на презентациях в Figma или слайдах
- Преподаватели и менторы, объясняющие что-то на экране
- Стримеры и авторы скринкастов

---

## Скачать

Скачай `.dmg`, открой, перетащи **Comet Cursor** в Applications.

<p align="center">
  <a href="../../releases/latest"><strong>Скачать последний релиз →</strong></a>
</p>

## Решение проблем

**macOS блокирует приложение при первом запуске**
Нажми правой кнопкой → **Открыть** → **Открыть**.

**Ошибка "приложение повреждено"**
```
xattr -cr "/Applications/Comet Cursor.app"
```

**Хвост не появляется**
Приложению нужен доступ к Accessibility для отслеживания курсора через `CGEventTap`.
Открой `System Settings → Privacy & Security → Accessibility` и добавь Comet Cursor.

**Хвост лагает**
Без доступа к Accessibility приложение переключается на polling-режим, который чуть менее точен. Выдача доступа решает проблему.

---

## Поддержать

Если приложение полезно, поддержи разработку. Это помогает проекту жить и мотивирует делать новые фичи.

**[Поддержать на Boosty →](https://boosty.to/zaitsev_av)**

---

## Сборка из исходников

```bash
cd CometCursorApp
./scripts/build.sh
open "Comet Cursor.app"
```

Требуется Xcode Command Line Tools: `xcode-select --install`

Детали архитектуры и информация для контрибьюторов — в [CONTRIBUTING.md](./CONTRIBUTING.md).

---

## Go-прототип

Оригинальный прототип на Go + CGo + OpenGL находится в [`prototype-go/`](./prototype-go/). Архивный, не поддерживается.

---

## Лицензия

MIT
