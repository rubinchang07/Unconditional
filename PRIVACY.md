# Privacy

_Last updated November 25, 2026_

Unconditional is a journal for hard thoughts, so it is built to keep them private. The short version: **everything you write, say, or draw stays on your iPhone, and nobody else can see it, including the developer.**

## What the app stores
Your entries, drawings, reframes, loops, wins, values, reminders, parked thoughts, tiny steps, career reflections, and the links on your map. They're kept in an on-device database (SwiftData) inside the app's private storage, protected by iOS while your phone is locked.

Small settings, such as your theme, orb colors, and reminder time, are kept on the phone too.

## What the app does not do
- No accounts and no sign-in.
- No servers. The app has no backend and doesn't send your journal anywhere.
- No analytics, tracking, ads, or third-party code. The app uses only Apple's own frameworks.
- No iCloud sync, for now. If it's ever added it will be off until you turn it on, and this page will be updated first.

## Permissions, and why
| Permission | Used for | When |
|---|---|---|
| Microphone | Speaking an entry instead of typing | Only while you're recording in Speak |
| Speech recognition | Turning what you say into text | Only while you're recording. On iPhones that support it (most recent ones), this happens entirely on the phone. If your phone can't do it on-device, iOS may send the audio to Apple to transcribe, under [Apple's privacy policy](https://www.apple.com/legal/privacy/). The recording itself is never saved. |
| Face ID | Locking the journal when you leave the app | Only if you turn on "Require Face ID". Apple handles Face ID; the app only learns whether it succeeded. |
| Notifications | One daily reminder | Only if you turn it on. The reminder is scheduled on the phone. |

Finding the words you use most (on Your map) uses Apple's NaturalLanguage framework on the phone.

## Exporting and restoring
**Settings → Your data → Export everything** saves your whole journal to one readable JSON file, wherever you choose (for example Files or AirDrop). It only happens when you tap it. Once the file leaves the app, it's yours to keep safe: anyone with the file can read it, so keep it somewhere private.

**Restore from a file** adds what's in an export and skips anything you already have. It never overwrites or deletes.

## Deleting your data
Swipe to delete anything in the app. To remove everything, delete the app: iOS removes its storage with it. Exported files are separate and need to be deleted wherever you saved them.

## If you're in crisis
The app isn't a substitute for care. **Settings → Support and crisis lines** lists 988 (call or text in the US), Crisis Text Line (text HOME to 741741), and findahelpline.com for other countries.

## Questions
Open an issue on this repository.
