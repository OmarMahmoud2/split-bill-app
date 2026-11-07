# Evens 2.0 premium polish: "Midnight & Mint"

Approved by the owner on 2026-11-07. Mockups: https://claude.ai/artifact/2ANh7wc8nZ6Q6sT2LCazQb
(System board, Home light/dark, Add-bill sheet, Roulette, You page, Guest portal).

Goal: deep polish, not a rebuild. Same flows and features, but every screen, sheet, dialog,
field and small widget must look and feel premium. Nothing generic, no tan.

## Colour tokens (replace the v3 "Quiet ledger" values; keep role names in AppPalette)

| Role | Light | Dark |
|---|---|---|
| canvas (page) | #F5F7FB | #0A0F1C |
| surface (cards, sheets, inputs) | #FFFFFF | #121A2B |
| raised / muted fill (chips, tiles, segmented track) | #EEF1F6 | #1A2438 |
| hairline border | #E3E7EF | #22304A |
| strong outline (ghost buttons) | #D4DAE6 | #2E3D5C |
| ink (text) | #0E1526 | #E8EDF7 |
| muted text / icons | #5B6478 | #9AA4B8 |
| hint (≥4.5:1 on every fill) | #5F687D | #8A94A8 |
| mint accent = owed to you, selection, links, focus | #0B7268 | #34D7C0 |
| mint soft fill / text on it | #E3F7F3 / #0A5F57 | rgba(52,215,192,.14) / #34D7C0 |
| on-mint | #FFFFFF | #06231F |
| coral = you owe (amount text uses the darker one) | #E8664A (text #C2452D) | #FF8A70 |
| coral soft fill / text | #FFECE6 / #A8381F | rgba(255,138,112,.14) / #FF8A70 |
| sky = waiting / pending confirmation | #3463D1 | #7AA2FF |
| error (errors and destructive only) | #C62828 | #FF6B6B |
| premium gold | #FFD36B on ink | same |
| hero card (balance) | #0E1526 with shadow 0 16 32 rgba(14,21,38,.22) | #1A2438 + 1px #2A3854 inner line |
| primary filled button | ink #0E1526 / white text | mint #34D7C0 / #06231F |

Rules: money always has a sign or a word next to the colour ("+E£620 owed to you", "−E£400 you owe",
"All square"). Red never means debt. Sentence case everywhere, never ALL CAPS section labels.

## Type
- Display and numbers: **Plus Jakarta Sans** 600/700/800 (bundle TTFs, OFL). Balances 40/800, letter-spacing −1.
- UI/body: **Inter** (already bundled) 400/500/600. Body 15/22, captions 12–13 muted.
- All money uses tabular figures (`FontFeature.tabularFigures()`).
- Arabic/Urdu and CJK fall back to the system font; keep existing fallbacks.

## Shape and spacing
- Radii: hero 28, cards 20, tiles/inputs 14, buttons 16–18, chips 999, sheets 32 top.
- Cards: surface + 1px hairline, no heavy shadows (only hero, primary buttons and the floating nav have shadows).
- Touch targets ≥ 44. Inputs 52 high, focus = 2px mint border + 4px mint ring at 12%.
- Page padding 20; vertical rhythm 16–18.

## Components
- **Primary button**: 52–56 high, radius 16–18, ink fill (light) / mint fill (dark), soft shadow, label + optional trailing arrow; shows count when relevant ("Continue · 4 people").
- **Secondary**: 1.5px outline, surface fill. **Tertiary**: text in mint.
- **Segmented control**: muted track, white selected pill with tiny shadow.
- **Chips**: 999 radius; selected = mint soft fill + mint text.
- **List rows (settings)**: 34px rounded-square icon tile with a soft tint per category, label, value, chevron; rows grouped in one rounded card with 1px inner dividers.
- **Bottom nav**: floating pill (16 from sides, 24 from bottom, radius 24, height 68, translucent surface + blur, hairline, soft shadow). Tabs Home, Activity, [center + button: 56px mint rounded-square raised −26px], Groups, You. Selected tab = ink icon with mint soft fill + label weight 600.
- **Header**: avatar + greeting on Home; other pages: large title (Plus Jakarta 22–28/800) with 40px rounded-square icon buttons (surface + hairline).
- **Sheets**: never full screen. Height = content, max 85% of screen; 32 top radius, 40×5 drag handle, title + subtitle + close button (40px muted square). Spring in.
- **Dialogs**: radius 24, icon tile at top, title, one sentence, two buttons full width.
- **Empty states**: pal avatar group or line illustration + one sentence + one action.
- **Skeletons** for loading lists; Lottie loader stays (owner likes it).
- **Success**: full-screen, check mark that draws itself, confetti in mint/coral/sky/sun, success haptic, amount and next action.
- **Errors**: inline field error shakes once + warning haptic; full error state = icon tile, plain sentence on how to fix, retry button.

## Pal avatars
Every person gets an avatar; initials are gone (except payment-method logos may keep their initials fallback).
- If the user has a photo (photoUrl data URL or network URL, incl. Google/Apple sign-in photo) show it.
- Otherwise draw a **pal**: deterministic from a stable seed (user id, else lowercased name):
  - colour pairs (bg, fg): mint (#C9F2EA,#0E7C72), coral (#FFD8CC,#E8664A), sky (#D8E3FF,#3B6FE0), sun (#FFE7A8,#C98A1E), lilac (#E7DBFF,#7C5CE0), rose (#FFD6E4,#D84C7E). pair = seed % 6; hair variant = (seed ~/ 2) % 3.
  - 48×48 geometry: bg circle; shoulders path `M8 48c1.5-9 8-13.5 16-13.5S38.5 39 40 48z` in fg; white head circle c(24,22) r10.5; hair in fg (variant 0 cap `M13.6 20.5c0-6.6 4.7-10.6 10.4-10.6s10.4 4 10.4 10.6c-3.2-2.6-6.6-3.6-10.4-3.6s-7.2 1-10.4 3.6z`; variant 1 bun circle c(33.5,12.5) r4.6 + fringe `M13.6 21c.6-6.4 5-10.1 10.4-10.1 5.2 0 9.4 3.4 10.3 9.2-4.6-.4-9.4-2.4-12.4-5.6-1.8 3.2-4.6 5.4-8.3 6.5z`; variant 2 tuft `M15 17l3-6 2.6 4 3.4-6 3.2 6 2.8-4 3 6c-3-1.4-6-2-9-2s-6 .6-9 2z`); eyes ink dots r1.35 at (20.2,22.6),(27.8,22.6); smile `M20.6 26.6c1.9 1.9 4.9 1.9 6.8 0` stroke 1.5 ink round.
  - Same algorithm in the guest web (it is the same Flutter code).
- Optional ring (2.5px) in mint for "you"/selected, or in surface colour for overlapping stacks (overlap −6).
- Use avatars wherever a person appears: lists, bill tiles (stack of 3), pickers, roulette slices, notifications, activity, guest portal, settle/IOU, groups. Names alone only in buttons and page titles.

## Icons
Replace generic Material icons with **Phosphor** (`phosphor_flutter`), through one semantic map `AppIcons` in lib/theme/app_icons.dart. Regular weight for UI, Fill for selected nav tab, Duotone for feature tiles.

## Motion and haptics (AppMotion / AppHaptics)
- Press: scale to 0.97 (120 ms), light haptic on primary buttons, toggles, chips.
- Sheets: spring up; stop at content height.
- Numbers: balances count up / roll on change (600 ms, easeOutCubic).
- Lists: first load only, rows fade + rise 8px, 30 ms stagger, max 8 rows animated.
- Page transitions: shared-axis / fade-through, 280 ms.
- Success: success haptic; Error: warning haptic + one shake (6px, 3 cycles, 300 ms).
- Roulette: selection tick haptic per slice passing the pointer, heavy impact on landing.
- Respect reduce-motion (MediaQuery.disableAnimations): skip count-ups, staggers, confetti.

## Copy
- Clear money words: "Owed to you", "You owe", "You sent · waiting for Omar", "Settled", "All square".
- IOU explainer: "A note that someone owes you, without a bill. Lent Ali E£200 for a taxi? Add an IOU and Evens keeps track until he pays you back." (translate to all 22 locales).
- Every new string goes through easy_localization in all 22 locales (assets/translations/*.json).
