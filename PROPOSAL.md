# Proposal: Alert Behaviour, Response Time & Points

## Problem

When a Pomodoro session or break completes (timer hits zero), the flow is:

1. `advancePhase(true)` is called — the next phase **starts immediately** in the background.
2. An alert popup appears with three buttons:
   - **"▶ Got it" / "▶ Enjoy the break"** — dismissed the popup but does **nothing** to the timer (it's already running the next phase).
   - **"Skip"** — advances to the *following* phase (skips a whole round).
   - **"Dismiss"** — same as the start button, only closes the popup.

This is confusing because:
- The primary action button ("▶ Enjoy the break" / "▶ Got it") implies it will start the next phase, but the phase is already running.
- The user has no feedback on how quickly they responded to the alert.
- There's no motivation or gamification beyond the progress bar.

## Inspiration: Forest (iOS)

[Forest](https://www.foresthappy.com/) gamifies focus sessions:
- You plant a virtual tree when you start a focus session.
- If you leave the app (break focus), the tree dies.
- Successful sessions grow trees you can collect in a garden.
- Points / XP / streaks reward consistent use.
- Visual feedback is immediate and satisfying.

Key ideas borrowed for omapom:
- **Points** for completing sessions (XP system).
- **Bonus points** for quick alert responses (reduces "break creep").
- **Streaks** for consecutive days of completed sessions.
- **Visual session history** (simple list of recent sessions with scores).

## Proposed Behaviour Changes

### 1. Pause on session end, don't auto-start

When the timer expires, the widget should go into a **"paused"** state for the
next phase.  The countdown shows the full duration of the next phase but the
timer doesn't tick.  The alert popup now controls the flow:

- **"▶ Start break" / "▶ Let's go"** → sets the phase to paused (full time
  remaining), closes the popup.  The user starts it when ready with the bar
  icon or the start button in settings.
- **"Skip"** → skips ahead (existing behaviour).
- **"Dismiss"** → same as "Start break" (pauses the next phase).

The two primary buttons now **do the same thing**: they acknowledge the alert
and pause the next phase.  Only "Skip" actually jumps a round.

### 2. Response time tracking

When the user presses the start/dismiss button in the alert, the elapsed time
since the alert appeared is recorded.  This measures how fast the user reacted
to the break/work prompt.

- **Fast response** (< 30 s) → bonus points.
- **Normal response** (30–120 s) → no bonus.
- **Slow response** (> 120 s) → logged but no penalty (soft nudge only).

Response time is shown in the session log and contributes to the session score.

### 3. Points system

| Action | Points |
|--------|--------|
| Complete a work session | +10 |
| Complete a break (acknowledged) | +2 |
| Fast alert response (< 30 s) | +5 bonus |
| Normal alert response (30–120 s) | +1 bonus |
| Day streak (same day) | +1 per session |
| Completed a long break | +3 |

Points are persisted in `state.json` and displayed in the tooltip.

### 4. Session log (optional, stretch goal)

A simple log of recent sessions with:
- Phase name, duration, points earned, response time.
- Accessible from the settings popup.

## Implementation Scope

### Phase 1 (this PR)
- [x] Change `advancePhase(true)` → `advancePhase(false)` on timer expiry
- [x] Add `lastAlertTime` to track alert appearance
- [x] Calculate response time on alert button press
- [x] Add `points` and `responseTimes` to persisted state
- [x] Award points for session completion and response speed
- [x] Update alert popup button behaviour (start → pause, not skip)
- [x] Add points to bar tooltip
- [x] Update manifest version

### Phase 2 (future)
- [ ] Session log popup in settings
- [ ] Day streak tracking
- [ ] Configurable point thresholds / milestones
- [ ] Visual progress towards milestones in the tooltip

## Backwards Compatibility

New state fields (`points`, `lastAlertTime`) are optional — the state loader
already handles missing keys with defaults.  Existing state files will continue
to work and just start accruing points from this point forward.
