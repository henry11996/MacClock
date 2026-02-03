# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MacClock is a macOS menu bar floating clock and timer app built with SwiftUI. It features a Pomodoro timer, countdown timers, and supports macOS 13.0+. The UI uses a glass effect aesthetic and is designed to float above other windows.

## Build Commands

```bash
# Build the project
xcodebuild -project MacClock.xcodeproj -scheme MacClock -configuration Debug build

# Build for release
xcodebuild -project MacClock.xcodeproj -scheme MacClock -configuration Release build

# Run the app (after building)
open build/Debug/MacClock.app
```

## Architecture

### App Entry & Window Management
- `MacClockApp.swift` - App entry point with `AppDelegate` that manages:
  - Floating `NSPanel` for the main widget (always visible, movable)
  - Full-screen window for Pomodoro breaks
  - Settings window with tabbed interface (`UnifiedSettingsView`)
  - URL scheme handling via `application(_:open:)`

### Core Singletons
All timer systems use singletons with `@Observable` pattern:
- `PomodoroTimer.shared` - Manages Pomodoro work/break cycles
- `CountdownManager.shared` - Manages multiple countdown timers (max 15)
- `ScheduleManager.shared` - Manages scheduled tasks (max 20)

### Feature Modules

**Pomodoro** (`MacClock/Pomodoro/`)
- `PomodoroTimer` - Timer logic with phase management (work/shortBreak/longBreak)
- `PomodoroSettings` - Persisted settings including durations, sound, auto-start
- `PomodoroState` - Phase enum and session state for persistence
- Views: Widget, FullScreen, Settings

**Countdown** (`MacClock/Countdown/`)
- `CountdownManager` - Multi-timer management with tick loop
- `CountdownTimer` - Individual timer model with completion commands
- `CountdownSettings` - Position, sound, visibility settings
- Views: Widget, Compact item, Settings

**Schedule** (`MacClock/Schedule/`)
- `ScheduleManager` - Schedule management with minute-based check loop
- `Schedule` - Schedule model with action, time, and recurrence rule
- `ScheduleAction` - Action types: startPomodoro, startTimer, runCommand, notification
- `RecurrenceRule` - Recurrence types: none, daily, weekly, interval
- `ScheduleSettings` - Position, font scale, max visible settings
- Views: SettingsTab, EditSheet, WidgetView

### URL Scheme API

The app responds to `macclock://` URLs handled by `URLSchemeHandler`:

```bash
# Timer commands
macclock://timer?sec=300&label=Break           # Quick start timer
macclock://timer?action=add&sec=60&start=true  # Add and start
macclock://timer?action=cancel&all=true        # Cancel all timers

# Pomodoro commands
macclock://pomodoro?action=start
macclock://pomodoro?action=pause
macclock://pomodoro?action=reset

# Schedule commands
macclock://schedule?action=add&time=09:00&do=pomodoro&repeat=daily&name=開始工作
macclock://schedule?action=add&time=18:00&do=notify&title=提醒&msg=下班了&repeat=weekday
macclock://schedule?action=list
macclock://schedule?action=toggle&label=開始工作
macclock://schedule?action=remove&label=開始工作

# Status query
macclock://status
```

Timer supports `command` parameter for shell execution on completion and `repeat=true` for looping.

Schedule supports:
- `do`: `pomodoro`, `timer`, `command`, `notify`
- `repeat`: `daily`, `weekday`, `weekend`, or hours interval (e.g., `2` for every 2 hours)

### App Intents

`MacClock/Intents/` provides Siri/Shortcuts integration:
- `StartTimerIntent` - Set countdown timers via Siri
- `PomodoroIntent` - Control Pomodoro via Siri
- `MacClockShortcuts` - App shortcut phrases

### Design System

`ContentView.swift` defines shared design tokens:
- `ThemeColors` - Primary, phase colors (work/break)
- `Spacing` - xs/sm/md/lg/xl spacing constants
- `AnimationPresets` - Spring and micro-interaction animations
- `InteractiveButtonStyle` - Hover/press feedback styles

### Services

- `BackgroundRefreshService` - Manages Liquid Glass effect FPS updates
- `NotificationService` - System notifications and sound playback
- `URLSchemeHandler` - Parses and executes URL commands

### Persistence

All settings use `UserDefaults` with JSON encoding:
- `PomodoroSettings` / `PomodoroSessionState`
- `CountdownSettings` / `CountdownTimer` array
- `ScheduleSettings` / `Schedule` array (via ScheduleManager)

## Key Patterns

- UI is localized in Traditional Chinese (zh-TW)
- Window position persists across launches
- Timers survive app restart (running timers restore from `targetEndTime`)
- Countdown timers can execute shell commands on completion
- Liquid Glass effect is optional and configurable per-FPS
