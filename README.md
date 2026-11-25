# Unconditional

A private iOS journal for working through self-doubt one day at a time. Write or draw, reframe the thought, and log small wins. Built with SwiftUI, SwiftData, and PencilKit.

## Screens
- **Today**: choose Write or Draw, get the thought out, tag which loop it belongs to. Saving offers an optional reframe.
- **Reframe** (a step, not a tab): a CBT thought record with what happened, the belief underneath, a kinder read, and one small step.
- **Wins**: quick-add small successes and see the running list.
- **History**: past entries, how often each loop shows up, and editing the loops themselves.

## Data model (SwiftData)
| Model | Holds | Relationships |
|---|---|---|
| `Loop` | name, pattern, core belief, sort order | has many `Entry` |
| `Entry` | date, kind (write/draw), text, drawing data | belongs to one `Loop`, has one optional `Reframe` |
| `Reframe` | trigger, core belief, kinder read, small step | belongs to one `Entry` |
| `Win` | date, text, meaning | none |

The five starting loops are seeded on first launch and can be edited in the app. All data stays on the device.

## Requirements
Xcode 16 or later, iOS 17 or later.
