# Unconditional

A private iOS journal for working through self-doubt one day at a time. Write or draw, reframe the thought, and log small wins. Built with SwiftUI, SwiftData, PencilKit, and the Speech framework.

## Screens
- **Today**: choose Write, Speak, or Draw, get the thought out, tag which loop it belongs to. Speak transcribes your voice on-device. Saving offers an optional reframe.
- **Reframe** (a step, not a tab): a CBT thought record with what happened, the belief underneath, evidence for and against, a kinder read, and one small step. Afterwards it shows one of your past wins.
- **Wins**: quick-add small successes and see the running list.
- **History**: past entries, how often each loop shows up, and editing the loops themselves.
- **Anchors**: Wins (each placed on an effort-to-outcome spectrum) and Values (what matters regardless of outcomes).
- **Support tools**: a one-minute breathing exercise, a self-compassion break, before/after distress and belief sliders on every reframe, and a support page with crisis lines.
- **Settings**: pick a theme (Sage, Dusk, Sky) from live previews, set a daily reminder, and turn on Face ID lock.

## Data model (SwiftData)
| Model | Holds | Relationships |
|---|---|---|
| `Loop` | name, pattern, core belief, sort order | has many `Entry` |
| `Entry` | date, kind (write/draw), text, drawing data | belongs to one `Loop`, has one optional `Reframe` |
| `Reframe` | trigger, core belief, evidence for/against, kinder read, small step | belongs to one `Entry` |
| `Win` | date, text, meaning, effort-to-outcome (0 to 1) | none |
| `PersonalValue` | name, meaning, lived lately (0 to 10) | none |

The five starting loops are seeded on first launch and can be edited in the app. All data stays on the device.

## Requirements
Xcode 16 or later, iOS 17 or later.
