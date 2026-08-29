# School Bus System — Master Design System

Source of truth for the visual language shared by `school_parent`, `school_driver`, `school_admin`, and `school_super_admin`. Page-specific notes live in `design-system/pages/`; this file wins whenever they disagree.

Implementation lives in `packages/school_shared/lib/src/design/` and is consumed by all four apps — see "Theme architecture" at the bottom.

> **Note on the requested stack:** the brief referenced Riverpod. The codebase actually uses `flutter_bloc` end-to-end (Cubits for auth, Blocs for trip/list orchestration), and `go_router` is a declared but unused dependency — every app navigates with plain `Navigator.push`. This document and the implementation preserve the **actual** existing stack (bloc + Navigator) rather than introducing Riverpod/GoRouter, per the standing instruction to not rewrite architecture. Swapping state-management or routing libraries is out of scope for a UI/UX phase.

> **UI/UX Pro Max integration:** the `ui-ux-pro-max` local skill (`.claude/skills/ui-ux-pro-max/`) was verified executable (`py -3.13 .../scripts/search.py ...`, confirmed producing real, structured output) and used as a design-system input. Its own generated recommendation for this product — style **"Minimalism & Swiss Style"** ("clean, simple, spacious, functional... enterprise apps, dashboards, professional tools") with typography **Lexend (heading) + Source Sans 3 (body)** ("corporate, trustworthy, accessible, readable... enterprise, government, healthcare, finance, accessibility-focused") — was adopted: §3 below now uses that pairing in place of the single-family Plus Jakarta Sans used previously. Full persisted output: `design-system/jammam-school-bus/MASTER.md`.
>
> **One recommendation was deliberately rejected and is documented here rather than silently dropped:** querying the same tool for the *parent* app specifically (keywords included "family") matched its **"Claymorphism"** entry — a pink, bubbly, toy-like children's-app style. Applying that to a school-safety trust product would directly contradict this entire project's standing "not childish, not decorative" direction and its own emergency-communication requirements. The tool is a keyword-matched catalog of general product/marketing-site patterns, not a bespoke judgment for this domain — its output was used where it fit (typography, Flutter widget-level guidance) and set aside where it didn't (that one style match), per the standing instruction to make the most reasonable professional decision when a tool's output doesn't fit.

---

## 1. Brand

**Personality:** a calm, competent operator — not a toy, not a spreadsheet. The product that a school administrator, a driver mid-route, and a worried parent all trust to tell them the truth quickly.

**Visual direction:** quiet confidence over decoration. Flat, border-forward surfaces (no gradients, no glassmorphism, no drop-shadow-everywhere); color used sparingly and *semantically* (status, not decoration); generous whitespace; strong, unambiguous type hierarchy. If a screen needs a second look to find what matters, it has failed this brief.

**Trust & safety cues:** every state that matters (a bus's live status, a trip's stage, an emergency) gets one consistent visual language — a colored dot + label pattern used identically in all four apps — so a parent who has only ever opened the app during a crisis still recognizes what they're looking at.

**Per-app identity, one system:** each app gets a distinct accent color (its "seed"), not a distinct design system. Same type scale, same spacing, same radii, same components — cosmetically a different accent, structurally one product.

| App | Accent seed | Rationale |
|---|---|---|
| Parent | Teal `#0F6E71` | Calm, reassuring — the color of "everything is fine" without being clinical |
| Driver | Cobalt `#1E5FA8` | Higher contrast, more saturated — legible at a glance, in motion, in daylight |
| Admin | Indigo-slate `#3B4A6B` | Reads as a professional operations console, not a consumer app |
| Super Admin | Graphite + Gold `#C9A227` | Already-established "control tower" identity — kept, not replaced |

---

## 2. Colors

All values are tokens in `AppColorTokens` (`packages/school_shared/lib/src/design/tokens.dart`). Light/dark pairs are provided for every semantic role; nothing is a naive inversion.

| Token | Light | Dark | Usage |
|---|---|---|---|
| `background` | `#F7F8FB` | `#0E1116` | Scaffold background |
| `surface` | `#FFFFFF` | `#161A21` | Cards, sheets, dialogs |
| `surfaceElevated` | `#FFFFFF` (+shadow) | `#1D222B` | Dialogs, popups, floating menus |
| `border` | `#E3E6EC` | `#2A2F3A` | Card/input borders, dividers |
| `textPrimary` | `#12161C` | `#EDEFF3` | Headings, primary content |
| `textSecondary` | `#4A5160` | `#B7BCC6` | Supporting text |
| `textMuted` | `#8A90A0` | `#7C8293` | Timestamps, placeholders |
| `disabled` | `#C7CBD4` | `#3A404C` | Disabled controls |
| `success` | `#1E7A4C` | `#5FBF8A` | Trip completed, approved, on-time |
| `warning` | `#A5680A` | `#DBA847` | Paused, pending, delayed |
| `error` | `#B23B34` | `#E2726B` | Cancelled, rejected, failed |
| `info` | `#2C5DA6` | `#7FA6E0` | Informational banners, "starting" |
| `emergency` | `#C22A2A` | `#F0554F` | Reserved exclusively for emergency state — never reused for generic errors |

**Rule:** semantic colors (success/warning/error/info/emergency) are never used decoratively. If a color appears, it means something specific and the same something every time it appears, in every app.

---

## 3. Typography

**Latin:** **Lexend** for headings/titles, **Source Sans 3** for body/label text — the pairing UI/UX Pro Max's design-system query returned for this exact product ("corporate, trustworthy, accessible, readable... enterprise, government, healthcare, finance, accessibility-focused"). Replaces the previous single-family Plus Jakarta Sans. Lexend is specifically designed to reduce visual stress in reading, which is a genuine fit for a status/emergency-heavy interface, not just a stylistic swap.

**Arabic:** Plus Jakarta Sans has no Arabic glyphs, so Arabic text was previously falling back to whatever system font each Android version ships — inconsistent weight, inconsistent spacing, occasionally ugly. This phase adds **Cairo** (Google Fonts) as the dedicated Arabic face — geometric, highly legible at small sizes, wide weight range, and it visually pairs with Plus Jakarta Sans's own geometric structure instead of clashing with it. `AppTypography.textTheme(locale)` picks the correct family per active locale automatically; no screen chooses a font manually.

| Style | Size / Line height | Weight | Usage |
|---|---|---|---|
| Display | 30 / 38 | 800 | Rare — a single hero number (e.g. an empty-state illustration headline) |
| Headline | 24 / 32 | 700 | Page titles |
| Title | 18 / 26 | 700 | Card/section titles |
| Subtitle | 16 / 24 | 600 | Secondary emphasis, list item titles |
| Body | 14 / 22 | 400–500 | Default reading text |
| Caption | 12 / 16 | 500 | Timestamps, helper text |
| Label | 11 / 16 | 700, +0.4 tracking, uppercase | Section eyebrows, status-chip text |
| Button | 15 / 20 | 700 | All interactive labels |

No screen sets a raw `fontSize`/`fontWeight` outside these named styles — see Theme architecture.

---

## 4. Spacing

4pt base scale: `xs 4 · sm 8 · md 12 · lg 16 · xl 20 · 2xl 24 · 3xl 32 · 4xl 40 · 5xl 48 · 6xl 64`.

- Page padding: `20` (mobile), `24` (tablet+)
- Section-to-section spacing: `32`
- Component-to-component spacing within a section: `12`–`16`
- Card internal padding: `16`–`20`

---

## 5. Shape

| Token | Radius | Usage |
|---|---|---|
| `sm` | 10 | Chips, small badges |
| `md` | 14 | Buttons, inputs (unchanged from the existing theme — already correct) |
| `lg` | 20 | Cards (unchanged — already correct) |
| `xl` | 24 | Dialogs, bottom sheets (unchanged — already correct) |
| `pill` | 999 | Status badges, avatar-adjacent chips |

The existing radius system was already well-chosen; this phase keeps it and makes it a named, shared token instead of a magic number repeated in four files.

---

## 6. Elevation

The existing flat, border-forward card style is intentional and stays — it is exactly the "no glassmorphism, no shadow-soup" restraint this brief asks for. A real elevation scale is added *only* for surfaces that genuinely float above content, where a border alone reads as flat rather than "on top": dialogs, bottom sheets, popup/dropdown menus, and snackbars.

| Level | Shadow | Usage |
|---|---|---|
| 0 | none | Cards, list rows (border only) |
| 1 | `0 2px 8px rgba(ink, 0.06)` | Floating action button |
| 2 | `0 8px 24px rgba(ink, 0.10)` | Dropdown/popup menus, snackbars |
| 3 | `0 16px 40px rgba(ink, 0.14)` | Dialogs, bottom sheets |

Shadows use the theme's own ink color at low opacity (never pure black), so they read correctly in dark mode instead of muddying it.

---

## 7. Iconography

Material Symbols (via Flutter's built-in `Icons` set) — already the only icon family in use across all four apps, confirmed by inspection (no emoji-as-icon usage found anywhere). Kept as-is; audited for consistency rather than replaced.

| Size | Usage |
|---|---|
| 16 | Inline with caption/label text |
| 20 | Default control icons, list leading icons |
| 24 | App bar actions, bottom navigation |
| 32 | Empty-state / feature illustrations |

**Directional icons** (`arrow_back`, `chevron_right`, `arrow_forward_ios`, etc.) must be the semantic Material variants, which Flutter auto-mirrors under RTL `Directionality` — never a hand-picked left/right icon by literal direction.

---

## 8. Components

Built once in `packages/school_shared/lib/src/design/components/`, consumed by all four apps. Only what the apps actually need — no speculative component library.

- **AppButton** — `primary` / `secondary` / `destructive` variants over the existing Filled/Outlined/Text button themes; consistent loading-spinner-in-button state.
- **AppCard** — the existing 20px-radius bordered surface, formalized as a widget instead of copy-pasted `Card` decoration.
- **StatusBadge** — the one dot+label pattern used everywhere a trip/bus/membership/emergency status appears. Semantic color only, per §2.
- **SectionHeader** — title + optional trailing action, consistent spacing.
- **AppTextField** — wraps the existing `InputDecorationTheme`; adds a consistent error-text pattern.
- **EmptyStateView** — icon + headline + body + optional action button, replacing ad-hoc empty-state `Column`s scattered per screen.
- **ErrorStateView** — supersedes the four apps' existing (near-identical) `AsyncErrorView` widgets with one shared implementation; keeps the same call signature apps already use so replacing it doesn't touch call sites' logic.
- **AppSkeleton** — shimmering placeholder blocks for list/card loading states, replacing bare `CircularProgressIndicator` in list contexts (the spinner is kept for short one-shot loads; the skeleton is for list/dashboard content).
- **MetricStatCard** — the stat-card shape already used in `AnalyticsTab`, formalized and reused everywhere a number-with-label appears.
- **AppConfirmDialog** — one confirmation-dialog shape for every destructive/important action.
- **AppSnackbar** — a static helper (`AppSnackbar.success/error/info(context, message)`) over the existing `SnackBarTheme`, replacing ad-hoc `ScaffoldMessenger` calls with inconsistent icon/color choices.

---

## 9. States

| State | Treatment |
|---|---|
| Loading (short) | Centered `CircularProgressIndicator`, themed to the app's accent |
| Loading (list/dashboard) | `AppSkeleton` blocks matching the eventual content's shape |
| Empty | `EmptyStateView` — icon, one-sentence explanation, action button only if a real action exists |
| Error | `ErrorStateView` — the actual error's friendly message where a typed exception exists (`SchoolLocationException`, `TripOperationException`, etc.); a clear generic message only where the underlying error truly is opaque (raw Firebase codes) |
| Success | `AppSnackbar.success` — brief, dismissible, non-blocking |
| Disabled | Reduced-opacity `disabled` token, never a color change alone (also drops elevation/interaction) |
| Selected | Accent-tinted background at low opacity, per existing `NavigationBarTheme` pattern — extended to any other selectable list/chip |
| Pressed/Focused | Material's built-in `WidgetState` ink/overlay, plus an explicit visible focus ring for web/keyboard navigation (previously relying on Flutter's faint default) |

---

## 10. Motion

Restrained, purposeful, never decorative:

- **Page transitions:** subtle fade + 8px slide, 220ms, standard easing — replacing Flutter's default platform transition only where it currently feels abrupt (list → detail).
- **List/card entrance:** a single staggered fade-in the first time a list paints (≤ 220ms per item, capped stagger) — not re-triggered on every rebuild.
- **State transitions:** `AnimatedSwitcher` (180ms crossfade) between loading → content → error/empty, so a screen doesn't hard-cut.
- **Success feedback:** a small scale+check pop (300ms) on the two moments that most deserve it — boarding a student, resolving an emergency.
- **Live map marker movement:** the existing `_LatLngTween`/`TweenAnimationBuilder` animated bus marker in the parent app is correct and is the pattern extended to the admin's live-ops map, which currently snaps.
- **Reduced motion:** every animation above is skipped (replaced with an instant cut) when `MediaQuery.of(context).disableAnimations` is true.

No screen gets more than one of the above at once. Nothing spins, bounces, or pulses without a specific reason.

---

## 11. Responsive

| Breakpoint | Range | Layout |
|---|---|---|
| Mobile | < 600 | Single column, bottom navigation, bottom sheets for secondary actions |
| Tablet | 600–1024 | Wider content, admin/super-admin switch to a navigation rail |
| Desktop | 1024–1440 | Admin/super-admin switch to a full sidebar + top bar; tables replace stacked cards where appropriate |
| Large desktop | > 1440 | Content max-width constrained (1400px) and centered — never full-bleed stretched |

Parent/driver stay single-column on web (they are used in short sessions, mobile-first by nature); only admin/super-admin get the responsive shell treatment described in §17 of the brief.

---

## 12. Accessibility

- Every text/background pairing above meets **WCAG AA (4.5:1)** for body text; verified for the token pairs in §2.
- Touch targets stay at Material's 48×48 minimum (already satisfied by the existing button/input padding — preserved, not shrunk for density).
- Layouts avoid fixed heights that clip at 130% system text scale; `Wrap`/`Flexible` preferred over fixed-width `Row` children in redesigned screens.
- An explicit focus ring is added for web/keyboard navigation (Flutter's default is nearly invisible against light surfaces).
- `MediaQuery.of(context).disableAnimations` is respected everywhere motion is added (§10).

---

## 13. RTL / LTR

- Directional icons are the semantic Material set (§7), which Flutter mirrors automatically under `Directionality.rtl` — never hand-picked by literal left/right.
- Numbers, timestamps, and coordinates are wrapped in `Directionality(textDirection: TextDirection.ltr, ...)` even inside an Arabic screen — standard practice, prevents a phone number or a "12:45 PM" from visually reversing.
- Padding/margin in new and touched components uses `EdgeInsetsDirectional` (start/end) instead of literal left/right, so it mirrors correctly with zero special-casing.
- Tables/lists (admin) mirror column order under RTL via `Directionality` rather than a manually reversed `List`.
- This is an audit-and-fix pass on touched screens, not a claim that every pre-existing screen in the app was re-verified pixel-by-pixel under Arabic — see the Final Report for exactly which screens were checked.

---

## Theme architecture

Previously: each of the four apps carried its own near-identical `lib/app/theme.dart` (confirmed byte-identical or near-identical across three of the four apps in the prior audit). That duplication is replaced with a single implementation:

- `packages/school_shared/lib/src/design/tokens.dart` — `AppColorTokens`, `AppSpacing`, `AppRadius`, `AppShadows`, `AppDurations` (plain constant classes, no Flutter dependency beyond `Color`).
- `packages/school_shared/lib/src/design/typography.dart` — `AppTypography.textTheme(Locale locale, ColorScheme colors)`, locale-aware Latin/Arabic font selection.
- `packages/school_shared/lib/src/design/app_theme.dart` — `AppBrand` enum (`parent`, `driver`, `admin`, `superAdmin`) + `buildAppTheme({required AppBrand brand, required Brightness brightness, required Locale locale})`, producing the exact `ThemeData` shape the four apps already relied on (same field names/behavior), just built from shared tokens instead of four hand-copied files.
- `packages/school_shared/lib/src/design/components/` — the widgets in §8.

Each app's own `lib/app/theme.dart` becomes a two-line wrapper calling into `school_shared`, so app-level code that already imports `buildAppTheme(...)` keeps working unchanged. `school_super_admin` gains a dependency on `school_shared` for this reason (it previously had none) — a pure, additive, non-business-logic dependency; nothing about its independent auth stack changes.
