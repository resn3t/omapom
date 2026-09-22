# omapom — Pomodoro timer for Omarchy

Pomodoro timer as an [Omarchy](https://github.com/basecamp/omarchy) bar widget.

[![GitHub](https://img.shields.io/badge/GitHub-omapom-blue)](https://github.com/resn3t/omapom)

![Pomodoro widget with settings popup](docs/widget_screenshot.png)

## Features

- Start/pause with left-click, skip with middle-click, settings with right-click
- Configurable work, break, and long-break durations
- Tracks completed sessions before auto-promoting to a long break
- Theme-adaptive bar icon that shows the current phase and remaining time
- Break alerts: plays a notification sound with a short reminder. Cycles
  through 20 hardcoded one-liners (a new one each break) — no setup required.
- Back-to-work alerts: same idea when a break ends, cycling through a
  separate set of 20 one-liners.
- **Alert-driven phase transitions** — when a session ends, the next phase
  pauses instead of auto-starting. The alert button "Start break" / "Let's go"
  acknowledges and pauses the next phase. "Skip" jumps ahead. No more
  confusing duplicate button behaviour.
- **Points system** — earn points for completing sessions (+10 work, +2 break)
  and for quick alert responses (+5 bonus under 30 s, +1 under 120 s).
  Points display in the bar tooltip.
- **Response time tracking** — how fast you reacted to break/work alerts is
  recorded (last 50 entries) and contributes to your session score.
- Optional local-AI messages (off by default): enable the "Generate alert
  messages with a local AI (pi CLI + Ollama)" setting in the right-click
  settings popup to replace the hardcoded line with one freshly generated
  by a local `pi` CLI + Ollama model, if you have one configured on your
  machine. Nothing is called out to unless you turn this on.

## Install

```bash
omarchy plugin add https://github.com/resn3t/omapom.git --enable
```

Or manually:

```bash
git clone https://github.com/resn3t/omapom.git
cp -r omapom ~/.config/omarchy/plugins/resn3t.pomodoro
omarchy restart shell
```

Add the widget to your bar configuration via `omarchy edit shell` or by
editing `~/.config/omarchy/shell.json`.

Right-click the bar icon to open the settings popup.

## Remove

```bash
omarchy plugin remove resn3t.pomodoro --yes
```

Or manually delete `~/.config/omarchy/plugins/resn3t.pomodoro` and restart
the shell.

## Build / Development

No build step — the plugin is pure QML + a small Bash helper.

## License

MIT
