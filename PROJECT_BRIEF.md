# PROJECT BRIEF — Bible Alarm App (iOS)

> Read this whole file before writing any code. It is the single source of truth for this project.
> Keep it in the repo root and update it when decisions change.

---

## 0. Who you're working with (important)

- The owner is **Ryder**, a designer (Figma, UI/UX). **He does not write code.** You write all of it.
- **There is no Mac.** Ryder has a Windows PC and an iPhone. He will often work from the Claude app on his phone.
- Builds happen in the cloud: **GitHub → Codemagic (macOS) → TestFlight → his iPhone.**
- There is **no simulator**. Every test happens on a real iPhone via TestFlight, and each build takes ~15 min. So:
  - Make small, safe changes and keep the build green.
  - Before each push, double-check the code compiles in your head (imports, types, missing files).
  - When something needs Ryder to act (Apple website, Codemagic settings, GitHub), give **short numbered steps** he can follow on a phone or PC, in plain English. No jargon without a one-line explanation.
- Ask Ryder before any decision that costs money or is hard to undo.

---

## 1. The app in one paragraph

An alarm clock that helps people start every day by reading God's word. When the alarm rings, the user sees a random Bible verse with a **fill-in-the-blank** challenge. The alarm is only fully cleared after they complete the verse. If they tap Stop on the system alarm without reading, **backup alarms keep ringing every few minutes** until they finish the verse in the app. **No ads, ever. No tracking.**

Working name: **TBD** (ask Ryder). Placeholder bundle ID: `com.ryder.biblealarm` (confirm with Ryder before creating it on Apple's site).

---

## 2. Tech stack (decided)

| Area | Choice |
|---|---|
| Language / UI | Swift 6, **SwiftUI** |
| Minimum iOS | **iOS 26** (required for AlarmKit) |
| Alarms | **AlarmKit** (system-level alarms that ring through Silent mode and Focus) |
| Local data | **SwiftData** |
| Purchases | **StoreKit 2** (subscriptions, lifetime, tips) |
| Audio import/convert | AVFoundation |
| Chinese word splitting | NaturalLanguage framework (`NLTokenizer`, `.word` unit) |
| Read-aloud (Premium) | Speech framework (on-device recognition where possible) |
| Widgets (later) | WidgetKit |
| Project file | **XcodeGen** (`project.yml`) — no `.xcodeproj` committed; it's generated on Codemagic |
| CI / build | **Codemagic** (`codemagic.yaml`) with automatic code signing via App Store Connect API key |
| Distribution | TestFlight → App Store |

**Rules**
- No third-party SDKs unless truly necessary (no analytics, no ad SDKs, no crash SDK unless Ryder agrees).
- AlarmKit is new (iOS 26). **Check the current Apple documentation** for exact API names before writing alarm code. Don't rely on memory.
- Needed Info.plist keys include `NSAlarmKitUsageDescription` (verify), microphone + speech recognition usage strings (for Premium read-aloud/recording).

---

## 3. Features

### FREE
1. **Alarms**
   - Create, edit, delete alarms; time, label, repeat days, on/off toggle.
   - Rings through Silent/Focus via AlarmKit.
   - System alarm UI: Stop button + a secondary button that **opens the app to the verse screen** (App Intent).
2. **Backup alarms (anti-skip)**
   - When an alarm fires, schedule follow-up alarms every **3 minutes** (setting: 2/3/5 min, max ~10 backups).
   - Backups are cancelled **only** when the user completes today's verse challenge.
   - If the user opens the app and finishes the verse, cancel all pending backups for that alarm.
3. **Morning verse screen**
   - Random verse each morning (avoid repeating any verse from the last 60 days).
   - Calm, **dark** screen, **large text**, minimal UI — the user is half asleep.
4. **Fill-in-the-blank (core mechanic)**
   - Hide **1–2 meaningful words** (Easy = 1, Normal = 2).
   - User taps the right word from **3–4 choices**.
   - Wrong answer → gentle shake, try again (no punishment).
   - After success → show full verse, "Amen" / Done button, then optional reflection prompt.
   - See §5 for the word-picking algorithm.
5. **Bible versions (built in, public domain)**
   - **KJV**, **WEB** (English), **和合本 CUV** (Traditional Chinese).
   - Bundle as compact JSON. **Verify each source's license is public domain** before including it, and note the source in `CREDITS.md`.
6. **Custom alarm sound — import your own song (FREE)**
   - "Add your own sound" → pick audio file from Files app (MP3, M4A, WAV, AAC) via document picker.
   - Basic trim: choose a start point; app takes a fixed-length clip.
   - Convert to an alarm-compatible format (e.g., `.caf`) and save to the app container's `Library/Sounds` (verify where AlarmKit expects custom sounds and any length limit).
   - Show it in the sound picker next to built-in sounds.
   - DRM songs (Apple Music/Spotify) can't be imported — show a friendly message if a file fails.
   - **Never upload or share user sound files.** They stay on device.
7. **Habit**
   - Streak counter, history of verses completed, favorites, share verse as an image (nice typography card).
8. **Built-in sounds**
   - A few gentle tones. Only use sounds that are original, generated, or **CC0 / royalty-free** — record the source in `CREDITS.md`.

### PREMIUM
- **Advanced sound editing:** waveform trim (start + end), fade-in, **voice recording** (record your own alarm sound).
- **Strict mode:** type the missing word, or **read the verse aloud** (speech recognition must match ~80% of words).
- **Memorize mode:** quizzes on previously read verses.
- **Themed verse sets** (Peace, Strength, Hope, Psalms, Proverbs…) and **reading plans** (e.g., Proverbs in 31 days).
- **Audio Bible** playback of the morning verse (later phase).
- **Widgets** (Lock Screen / Home Screen verse of the day).
- **Themes** and **group streaks** (later phase; needs a backend — discuss with Ryder first).
- **Downloadable Bible versions** via API.Bible (later phase — see §6).

### Pricing (StoreKit 2)
| Product | Type | Price |
|---|---|---|
| Premium Monthly | Auto-renew subscription | US$2.99 |
| Premium Yearly | Auto-renew subscription (7-day free trial) | US$19.99 |
| Premium Lifetime | Non-consumable | US$39.99 |
| Tip — small / medium / large | Consumable | US$1.99 / 4.99 / 9.99 |

- Product IDs pattern: `<bundleid>.premium.monthly`, `.premium.yearly`, `.premium.lifetime`, `.tip.small`, `.tip.medium`, `.tip.large`.
- Add a **StoreKit configuration file** for local logic, plus "Restore Purchases".
- Tip jar copy: "Support this ministry."
- **No ads, ever** — say so on the paywall and App Store page.

---

## 4. Screens (Ryder will design these in Figma; build clean placeholders until designs arrive)

1. Onboarding (3 pages: purpose → alarm permission → pick Bible version & language)
2. Alarm list (home)
3. Alarm editor (time, repeat, label, sound, difficulty, backup interval)
4. Sound picker (built-in + "Add your own sound")
5. Sound trimmer (basic = free, waveform/fade = premium)
6. **Wake-up verse screen** (fill-in-the-blank)
7. Success screen (full verse, Amen, reflection prompt, share, favorite)
8. Streak & history
9. Favorites
10. Settings (Bible version, UI language, difficulty, backup interval, restore purchases, credits)
11. Paywall (Premium benefits, prices, trial, "No ads, ever")
12. Tip jar

**Design rules:** dark, calm, high contrast, large type, generous spacing, one main action per screen. UI localized in **English** and **Traditional Chinese (zh-Hant)** from day one (use String Catalogs).

---

## 5. Fill-in-the-blank algorithm

1. Tokenize the verse:
   - English: split on words, keep punctuation separate.
   - Chinese: use `NLTokenizer(unit: .word)` with language set to Traditional Chinese, so blanks are whole words (e.g., 平安, 喜樂), never half a word.
2. Remove stopwords (English: the, and, of, to, a, in, that, for, is, unto, thou… ; Chinese: 的、了、是、在、和、與、他、你、我、這、那、就…). Keep a small editable list per language.
3. Prefer **keywords**: a priority list (God, Lord, Jesus, love, peace, faith, hope, strength, grace, joy… / 神、主、耶穌、愛、平安、信心、盼望、力量、恩典、喜樂…). If the verse contains one, blank it first; otherwise pick the longest remaining content word.
4. Distractors: 2–3 words of similar length/type taken from other verses in the same version and language. No duplicates, never the correct word.
5. Shuffle choices.

---

## 6. Bible versions — licensing rules

- Built-in: only **verified public-domain** texts (KJV, WEB, CUV 和合本).
- Downloadable versions (later phase) via **API.Bible** — free tier is for **non-commercial** use and some versions need approval. Because the app has paid Premium, **Ryder must confirm terms with API.Bible / publishers before this ships.** Plan: keep Bible versions free; charge only for app features.
- Never hard-code a secret API key in a shipped app without discussing it with Ryder first (it can be extracted).
- Show each version's copyright notice in Settings → Credits.

---

## 7. Data model (SwiftData, starting point)

- `Alarm` — id, time, label, repeatDays, isEnabled, soundID, difficulty, backupIntervalMinutes, alarmKitIDs
- `CustomSound` — id, displayName, fileName, durationSeconds, createdAt
- `VerseRecord` — id, versionID, book, chapter, verse, completedAt, isFavorite
- `Streak` — currentCount, bestCount, lastCompletedDate
- `Settings` — bibleVersionID, uiLanguage, difficulty, isPremium (cached; StoreKit is the source of truth)

Bible text itself lives in bundled JSON files, not SwiftData.

---

## 8. Repo layout

```
/project.yml              # XcodeGen spec
/codemagic.yaml           # CI: generate project, sign, build, upload to TestFlight
/PROJECT_BRIEF.md         # this file
/CREDITS.md               # Bible text + sound sources and licenses
/BibleAlarm/
  App/                    # app entry, root navigation
  Features/Alarms/
  Features/Verse/
  Features/Sounds/
  Features/Streaks/
  Features/Paywall/
  Features/Settings/
  Services/               # AlarmService (AlarmKit), VerseService, BlankGenerator, SoundImporter, StoreService
  Models/
  Resources/Bibles/       # kjv.json, web.json, cuv.json
  Resources/Sounds/
  Resources/Localizable.xcstrings
/BibleAlarmTests/         # unit tests (BlankGenerator, verse picker, backup scheduling logic)
```

---

## 9. Codemagic setup (no Mac)

`codemagic.yaml` workflow should:
1. Use a macOS instance with the latest Xcode that supports iOS 26.
2. `brew install xcodegen` → `xcodegen generate`.
3. Use **automatic code signing** via an App Store Connect API key integration (Codemagic fetches/creates certificates & profiles — no Mac needed).
4. Increment build number automatically.
5. Run unit tests, build the `.ipa`, **publish to TestFlight**.
6. Trigger on push to `main`.

**Walk Ryder through the one-time setup step by step:**
1. Apple Developer Program (US$99/yr) — he may need to enroll first.
2. Create the bundle ID + app record in App Store Connect.
3. Create an App Store Connect **API key** (Users and Access → Integrations) and add it to Codemagic.
4. Connect the GitHub repo to Codemagic.
5. Add himself as an internal TestFlight tester and install TestFlight on his iPhone.

---

## 10. Build phases (do them in order; each phase must end with a working TestFlight build)

1. **Phase 0 — Pipeline:** minimal SwiftUI "Hello" app + `project.yml` + `codemagic.yaml`. Goal: it installs on Ryder's iPhone via TestFlight. Guide him through §9.
2. **Phase 1 — Alarm:** AlarmKit permission, create/edit/delete alarms, alarm rings with built-in sound, secondary button opens the app.
3. **Phase 2 — Verse:** bundle KJV + CUV (then WEB), random verse picker, wake-up screen.
4. **Phase 3 — Fill-in-the-blank:** BlankGenerator (§5) with unit tests, success screen.
5. **Phase 4 — Backup alarms:** schedule follow-ups on fire, cancel on completion. Test carefully on device.
6. **Phase 5 — Custom sounds (free):** import, basic trim, convert, use as alarm sound.
7. **Phase 6 — Habit:** streaks, history, favorites, share image.
8. **Phase 7 — Localization & onboarding:** English + 繁體中文, onboarding flow.
9. **Phase 8 — Premium:** StoreKit 2, paywall, tip jar, strict mode, memorize mode, advanced sound editing, voice recording.
10. **Phase 9 — Later:** widgets, themed sets, reading plans, audio Bible, API.Bible downloads, group streaks.

After each phase: give Ryder a short checklist of **what to test on his iPhone**.

---

## 11. App Store notes (for later)

- Privacy: no data collected; user sounds stay on device.
- App Store listing should say: "No ads, ever."
- Include Restore Purchases, Terms, and Privacy Policy links (help Ryder write simple ones).
