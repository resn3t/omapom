# omapom — Pomodoro timer for Omarchy

Pomodoro timer as an [Omarchy](https://github.com/basecamp/omarchy) bar widget.

[![GitHub](https://img.shields.io/badge/GitHub-omapom-blue)](https://github.com/resn3t/omapom)

![Pomodoro widget with settings popup](docs/widget_screenshot.png)

## Features

- Start/pause with left-click, skip with middle-click, settings with right-click
- Configurable work, break, and long-break durations
- Tracks completed sessions before auto-promoting to a long break
- Theme-adaptive bar icon that shows the current phase and remaining time
- Break alerts: plays a notification sound with a short, witty reminder.
  Cycles through 20 hardcoded pomodoro/productivity one-liners (a new one
  each break) — no setup required. If a local `pi` CLI with an Ollama model
  is configured on the machine, that line gets replaced with a freshly
  generated one instead.

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
