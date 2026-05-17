---

<p align="center">
  <a href="README.md">English</a> &nbsp;|&nbsp; <a href="readme.ru.md">Русский</a>
</p>

---

<p align="center">
  <img src="assets/demo.gif" width="680" alt="Comet Cursor в действии">
</p>

<h1 align="center">☄️ Comet Cursor</h1>

<p align="center">
  <b>Бесплатное open-source приложение для macOS — светящийся хвост кометы за курсором.</b><br>
  <i>Ваша аудитория больше никогда не потеряет курсор на презентации.</i>
</p>

<p align="center">
  <a href="https://github.com/zaitsev-av/comet-cursor/releases/latest"><img src="https://img.shields.io/github/v/release/zaitsev-av/comet-cursor?label=Скачать&color=orange" alt="Скачать"></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-blue" alt="macOS 13+">
  <img src="https://img.shields.io/badge/Swift-5.9-orange" alt="Swift 5.9">
  <img src="https://img.shields.io/badge/Metal-GPU%20ускорение-black" alt="Metal GPU">
  <img src="https://img.shields.io/badge/лицензия-MIT-green" alt="MIT">
  <a href="https://github.com/zaitsev-av/comet-cursor/stargazers"><img src="https://img.shields.io/github/stars/zaitsev-av/comet-cursor?style=social" alt="GitHub Stars"></a>
</p>

---

## Зачем Comet Cursor?

Вы показываете экран. Аудитория щурится, пытаясь разглядеть крошечную стрелку курсора в море кода, слайдов или макетов. Вы начинаете нервно дёргать мышью.

Comet Cursor решает эту проблему. Он рисует красивый анимированный хвост кометы за курсором — **поверх всех окон, на всех мониторах, с GPU-ускорением, без задержек**. Ваша аудитория всегда видит, куда вы показываете.

### Сравнение с аналогами

| | Comet Cursor | Mouseposé | KeyCastr | Встроенные macOS |
|---|---|---|---|---|
| **Хвост за курсором** | ✅ Светящаяся комета | ✅ Базовая подсветка | ❌ Только клавиши | ❌ Нет |
| **Цена** | Бесплатно | $11 | Бесплатно | Бесплатно |
| **Открытый код** | ✅ MIT | ❌ | ❌ | ❌ |
| **GPU-ускорение** | ✅ Metal | ❌ | ❌ | — |
| **Несколько мониторов** | ✅ | ❌ | N/A | — |
| **Настройка** | 3 пресета + ручной режим | Ограниченная | N/A | Только размер курсора |
| **Исключения приложений** | ✅ На каждое | ❌ | — | — |

---

## Что умеет

- ☄️ Анимированный хвост кометы в реальном времени (60 FPS, Metal)
- 🎨 **3 встроенных пресета:** `Presenter Glow`, `Neon Focus`, `Minimal Trace`
- 🎛️ Настройка длины, толщины, прозрачности и скорости затухания на лету — без перезапуска
- 🎨 Отдельные выборы цвета для тела хвоста и головы
- ⌨️ Глобальное включение: переключатель в меню-баре или `⌥⌘C`
- 🚫 Список исключений — автоотключение в выбранных приложениях
- 🖥️ Несколько мониторов: отдельный оверлей на каждый экран
- 🌍 Интерфейс на русском и английском
- 🔋 Минимальное потребление: ~20 МБ RAM, почти нулевой CPU в простое

<p align="center">
  <img src="assets/settings.png" width="360" alt="Панель настроек Comet Cursor">
</p>

## Для кого

Если вы регулярно показываете экран — это приложение для вас:

- **Разработчики** — демо, парное программирование, код-ревью
- **Дизайнеры и PM** — презентации в Figma и слайды
- **Преподаватели и менторы** — объяснение материала на экране
- **Стримеры и контент-мейкеры** — запись туториалов и скринкастов

## Скачать

Скачай `.dmg`, открой, перетащи **Comet Cursor** в Applications.

<p align="center">
  <a href="https://github.com/zaitsev-av/comet-cursor/releases/latest"><strong>⬇ Скачать последний релиз</strong></a>
</p>

> **Первый запуск:** macOS может заблокировать приложение, т.к. оно не из App Store.
> Нажми правой кнопкой → **Открыть** → **Открыть**.

> **Нужен доступ к Accessibility** для отслеживания курсора. Приложение само предложит открыть настройки.

## Сборка из исходников

```bash
# Требуется Xcode Command Line Tools: xcode-select --install
git clone https://github.com/zaitsev-av/comet-cursor.git
cd comet-cursor/CometCursorApp
./scripts/build.sh
open "Comet Cursor.app"
```

Xcode не нужен — только `swift build`.

## Технологии

| Слой | Технология |
|---|---|
| Язык | Swift 5.9 |
| UI | SwiftUI + AppKit |
| Рендеринг | Metal (GPU) — triangle strip, без артефактов линий |
| Трекинг | CGEventTap + поллинг 120 Гц |
| Сборка | `swift build` (без `.xcodeproj`) |
| CI/CD | GitHub Actions → DMG → Release |
| Мин. версия | macOS 13+ |

Детали архитектуры — в [CONTRIBUTING.md](./CONTRIBUTING.md).

## Решение проблем

**macOS блокирует приложение при первом запуске**
Нажми правой кнопкой → **Открыть** → **Открыть**.

**Ошибка «приложение повреждено»**
```bash
xattr -cr "/Applications/Comet Cursor.app"
```

**Хвост не появляется**
Добавь Comet Cursor в `Системные настройки → Конфиденциальность → Универсальный доступ`.

**Хвост лагает**
Выдай доступ к Accessibility — без него приложение работает в polling-режиме.

## Поддержать

Если приложение полезно, поддержи разработку:

**[Поддержать на Boosty →](https://boosty.to/zaitsev_av)**

⭐ **Поставь звезду** — это помогает проекту находить новых пользователей!

---

## Go-прототип

Оригинальный прототип на Go + CGo + OpenGL лежит в [`prototype-go/`](./prototype-go/). Архивный, не поддерживается.

## English version

[🇬🇧 English version](./README.md)

## Лицензия

MIT — делай что хочешь, просто сохрани уведомление о лицензии.
