# Unconditional

A private iOS journal for working through self-doubt one day at a time. Write or draw, reframe the thought, and log small wins. Built with SwiftUI, SwiftData, PencilKit, and the Speech framework.

## Screens
- **Today**: choose Write, Speak, or Draw, get the thought out, tag which loop it belongs to. Speak transcribes your voice on-device. Saving offers an optional reframe.
- **Reframe** (a step, not a tab): a CBT thought record with what happened, the belief underneath, evidence for and against, a kinder read, and one small step. Afterwards it shows one of your past wins.
- **Wins**: quick-add small successes and see the running list.
- **History**: past entries, how often each loop shows up, and editing the loops themselves.
- **Thought Reset** ("I'm spiraling"): one tap from Today. Pick the thought closest to yours, read a perspective you can rewrite, then let it be, save it as a reminder, park it for a weekly review, or choose one tiny step. Tiny steps get a gentle "did you try it?" follow-up, never "did it work?".
- **Career check-in**: after studying, applying, an interview, or a setback. Note what you learned and what was interesting, rate enjoyment, discouragement, and any urge to quit, and place that urge on a slider from "I don't like the work" to "I feel discouraged". History shows plain-language averages, and the weekly review shows what you learned and enjoyed this week alongside parked doubts.
- **Anchors**: Wins (each placed on an effort-to-outcome spectrum), Values (what matters regardless of outcomes), and Reminders (your own encouragement library).
- **Values first**: after a reframe, the app leads with something you care about rather than a past success. Worth isn't earned by wins, so the win is optional.
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
| `ResetThought` | thought, perspective, sort order | belongs to one `Loop` |
| `SavedReminder` | text | none |
| `ParkedThought` | thought, reviewed date, urgency at review, note | none |
| `CareerReflection` | moment, topic, learned, interesting, enjoyment, discouragement, urge to quit, quit source | none |
| `TinyStep` | text, outcome (tried / let go), snoozed until | none |

The five starting loops are seeded on first launch and can be edited in the app. All data stays on the device.

## Requirements
Xcode 16 or later, iOS 17 or later.
