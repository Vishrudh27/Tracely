# Tracely — Google Stitch Prompt Kit

> **Relationship to other docs:** this is a *translation layer* that turns
> `docs/design_master_prompt.md` into prompts Google Stitch can consume.
> Where the two disagree, **`design_master_prompt.md` wins** — it is the
> authoritative UI spec. This file must never introduce a token, radius,
> duration or rule that contradicts it or the theme files in `lib/app/theme/`.
>
> **Two deliberate divergences from `design_master_prompt.md`, recorded so
> the two docs do not silently disagree:**
>
> 1. **Second theme.** That doc names the planned second palette
>    *Slate & Indigo*. This kit ships three **brown-family** variants
>    instead (§5), because the brown direction was chosen after that doc
>    was written. Slate & Indigo is not cancelled — it is simply no longer
>    the assumed second theme. Decide explicitly which two ship.
> 2. **Bottom navigation grows to four items.** That doc assumes the
>    current three (`Home / Habits / Stats`). Including Tasks makes it
>    four, which changes `TracelyShell`'s `_routes` list and destinations.
>    Screen 3.12 is drawn with four; every other screen in this kit is
>    drawn with three. **Regenerate the three-item screens once you commit
>    to four**, or the nav bar will be inconsistent across the app.
>
> All other values in this kit were mechanically verified against
> `lib/app/theme/` — 16 dimension tokens and every colour pair.

---

## 0. How to actually use this (read first — it changes everything)

Stitch is not a "paste one giant spec" tool. Three findings from its own
prompt guide and user reports drive the structure of this kit:

1. **Prompts over ~5,000 characters reliably drop components.** A single
   master prompt describing the whole app will silently lose half of it.
2. **One screen per prompt.** Quality collapses when you ask for several.
3. **One or two changes per refinement.** Multi-change edits make Stitch
   rebuild the entire layout instead of adjusting what you asked for.

So the kit is built as: **one short Style Block + one focused prompt per
screen.**

**The loop:**

1. Copy **Section 1 (Style Block)**.
2. Paste it, then paste **one** screen prompt from Section 3 underneath.
3. Generate. Treat output as a *starting point*, never a finished screen.
4. Refine with single-change requests: *"Make the streak number larger."*
   Then: *"Increase spacing above the section header."* One at a time.
5. Move to the next screen. Re-paste the Style Block every time — Stitch
   does not remember it between screens, and drift in colour and spacing
   is the #1 reason multi-screen AI designs look incoherent.

**Budget check:** Style Block ≈ 1,300 chars. Screen prompts are each
1,500–2,500 chars. Combined you stay in the 3,000–3,800 range — safely
under the limit. If you extend a screen prompt, delete something else;
do not let the combined prompt pass ~4,500 characters.

**Changing colour later:** Section 5 holds drop-in colour variants. To
re-skin the whole app, swap only the colour lines inside the Style Block
and re-run the same screen prompts unchanged. Layout, spacing and
component structure stay identical across variants — which is exactly
the workflow you asked for.

---

## 1. STYLE BLOCK — paste this above every screen prompt

```
Design a mobile app screen for Android (phone, 1080x2400). The app is
Tracely, a calm offline-first habit tracker.

Overall style: warm, quiet, grounded. Premium but understated - it should
feel like a well-made paper notebook, not a data dashboard. Generous
whitespace. Nothing shouts for attention.

Use exactly these colors:
- Page background: #FAF8F5 (warm bone)
- Cards and raised surfaces: #FFFFFF
- Recessed fills (inputs, unselected chips): #F2EDE6 (oat)
- Primary, for buttons and active states: #6F4E37 (coffee brown)
- Text on primary: #FFFFFF
- Accent fill, for gentle attention only: #C2703D (terracotta)
- Accent text: #9A4F24
- Headings and body text: #1F1A15
- Secondary text: #655A4E
- Disabled text: #9A8E83
- Hairline borders and dividers: #E6DFD5
- Input outlines: #9F8D7B
- Success: #5A7233 (olive)
- Errors and alerts: #9C4A32 (muted brick) - never bright red

Typography: Inter. Screen title 24px semibold, section header 16px
semibold, body 14-16px regular, caption 12px. Body line height 1.5.

Shape: cards 16px corner radius, buttons 12px, chips 8px, bottom sheets
20px top corners only. Exactly one soft shadow: 0 2px 8px rgba(0,0,0,0.05).
No glassmorphism, no gradients, no neumorphism, no glow effects.

Spacing: strict 4px grid. 20px screen side padding, 16px padding inside
cards, 24px between sections.

Icons: thin 2px rounded-stroke line icons, one consistent family.

Hard rules: nothing is bright red. Only ONE terracotta element per screen.
All tap targets at least 48x48dp.
```

---

## 2. Screen inventory

| # | Screen | Status in codebase |
|---|---|---|
| 3.1 | Splash | Not built |
| 3.2 | Onboarding 1 — the gap | Stub only |
| 3.3 | Onboarding 2 — how it works | Stub only |
| 3.4 | Onboarding 3 — first habit | Stub only |
| 3.5 | Daily Opening Ritual | Built |
| 3.6 | Dashboard | Built (tasks section is new) |
| 3.7 | Habits list | Built |
| 3.8 | Add Habit | Built |
| 3.9 | Habit Detail | Not built |
| 3.10 | Statistics | Built |
| 3.11 | Pause & Reflect sheet | Built |
| 3.12 | Tasks list | Not built |
| 3.13 | Add Task | Not built |
| 3.14 | Settings | Not built |
| 3.15 | Empty & error states | Partially built |

---

## 3. Screen prompts

### 3.1 Splash

```
This is the app launch screen. It appears for under 2 seconds on cold
start and must feel like the first frame of a calm animation, not a
loading screen.

Layout: completely centered, single column, nothing else on screen.
- The Tracely wordmark in Inter semibold 28px, color #1F1A15, letter
  spacing slightly loose.
- Directly above it, a simple line-art mark: a single unbroken circular
  stroke in #6F4E37, 2px, about 56px across, with a small gap at the top
  right - suggesting a loop that is still being closed.
- 12px below the wordmark, the tagline "Know why, not just what" in 13px
  regular, color #655A4E.

Background is a very soft radial warmth: #FAF8F5 at the edges lifting to
a barely-lighter warm tone behind the mark. The shift must be almost
imperceptible - if it reads as a visible gradient it is too strong.

No spinner, no progress bar, no percentage, no version number.
```

### 3.2 Onboarding 1 — the gap

```
First of three onboarding screens. Full screen, no app bar.

Layout top to bottom:
- 64px top spacing.
- An illustration area about 240px tall, centered: a simple line-art
  drawing in 2px #6F4E37 strokes on transparent background, showing a row
  of seven small circles where five are filled solid and two are hollow.
  Beneath the two hollow ones, a small question mark in #C2703D. Flat
  line art only - no 3D, no shading, no mascot, no stock illustration.
- 40px gap.
- Headline, 24px semibold #1F1A15, centered, max two lines:
  "Every tracker shows what you missed."
- 12px gap.
- Body, 16px regular #655A4E, centered, line height 1.5, max 60
  characters per line:
  "None of them show why. That blank space is the whole reason Tracely
  exists."
- Flexible space pushing the rest to the bottom.
- Three page-indicator dots, centered, 8px each with 8px gaps. First dot
  filled #6F4E37, other two #E6DFD5.
- 24px gap.
- Full-width primary button, 52px tall, 12px radius, fill #6F4E37, label
  "Next" in #FFFFFF 16px semibold.
- 12px gap.
- A plain text button "Skip" centered, 14px #9A8E83, no background.
- 32px bottom spacing.
```

### 3.3 Onboarding 2 — how it works

```
Second of three onboarding screens. Identical layout skeleton, spacing
and button placement to the previous screen - only the illustration and
copy change. Keep the structure pixel-identical so the transition between
steps feels still rather than jumpy.

- Illustration area 240px: line art of a small bottom sheet rising into
  frame, with three rounded chips inside it labelled with tiny generic
  marks, one chip outlined in #C2703D to show selection. 2px strokes in
  #6F4E37.
- Headline: "When you miss a day, we ask one gentle question."
- Body: "One tap. Always skippable. Never a guilt trip."
- Page indicator: second dot filled #6F4E37, first and third #E6DFD5.
- Primary button "Next". Text button "Skip" below it.
```

### 3.4 Onboarding 3 — first habit

```
Third and final onboarding screen. Same layout skeleton as the previous
two, with one change: this screen has no "Skip" button, and the primary
button is the only action.

- Illustration area 240px: line art of a single rounded card with a
  circular checkbox on its left edge, the checkbox drawn mid-check with
  the stroke partially complete. 2px strokes in #6F4E37.
- Headline: "Start with one habit."
- Body: "Not ten. One you could do tomorrow even on a bad day."
- Page indicator: third dot filled #6F4E37, first two #E6DFD5.
- Primary button, full width, label "Create my first habit".
- No skip button. Replace it with 52px of empty space so the button sits
  at exactly the same height as on the previous two screens.
```

### 3.5 Daily Opening Ritual

```
A full-screen calm moment shown once per day on first open. It is
deliberately slow and uncluttered - this screen's entire job is to feel
like a pause. No bottom navigation bar on this screen.

Layout top to bottom:
- Background: #FAF8F5 with an extremely soft warm radial glow behind the
  center. Barely visible.
- 15% down from the top: a time-aware greeting, "Good Morning", in 28px
  semibold #1F1A15, centered.
- 8px below: today's date, "Thursday, 18 September", 16px regular
  #655A4E, centered.
- Centered in the middle of the screen, a quote card:
  - White #FFFFFF card, 16px radius, 20px internal padding, full width
    minus 20px side margins.
  - A single quotation-mark glyph icon at the top center, 24px, in
    #6F4E37.
  - 16px gap.
  - The quote text, 18px semibold #1F1A15, centered, line height 1.6,
    three lines: "Small disciplines repeated with consistency lead to
    remarkable achievements."
  - 20px gap.
  - Attribution "- John C. Maxwell", 14px italic #655A4E, centered.
  - One soft shadow, plus a barely-there warm halo directly beneath the
    card. The halo must read as light, not as a glow effect.
- Anchored to the bottom with 20px margins: a full-width button, 52px
  tall, 12px radius, fill #6F4E37, label "Continue" in #FFFFFF 16px
  semibold, with a small right-pointing arrow icon after the label.

Nothing else. No stats, no streak count, no habit list, no skip link.
```

### 3.6 Dashboard

```
The app's home screen. Progressive disclosure is the rule here: only
today matters. No charts, no achievements, no streak counters.

Layout top to bottom, scrollable:
- 20px top spacing.
- Greeting "Good Morning" 24px semibold #1F1A15, left aligned.
- 4px below: subtitle "Fresh start ahead." 14px regular #655A4E.
- 24px gap.
- A daily progress card: white, 16px radius, 20px padding, full width.
  On the left, a circular progress ring 120px across with 8px stroke,
  track #F2EDE6 and fill #6F4E37, sweeping about 60%. Inside the ring,
  "3/5" in 24px semibold #1F1A15 with the word "today" in 12px #655A4E
  beneath it. To the right of the ring, stacked left-aligned text: "Nicely
  paced" 16px semibold, and "2 habits left" 14px #655A4E.
- 24px gap.
- Section header row: "Today's Habits" 16px semibold #1F1A15 on the left,
  and "3/5" 12px #655A4E right aligned.
- 8px gap.
- A vertical list of 5 habit rows. Each row: white card, 16px radius,
  16px horizontal and 12px vertical padding, 72px minimum height, 8px
  gap between rows.
  - Left: a circular checkbox 28px. Unchecked rows show a 2px #9F8D7B
    ring on #FFFFFF. Checked rows show a solid #6F4E37 fill with a white
    check mark.
  - Then an emoji 20px.
  - Then the habit name, 16px medium #1F1A15. Completed rows show the
    name in #9A8E83, not struck through.
  - Below the name, 12px #655A4E, the category name.
  - Far right: a small vertical 3px-wide category colour bar, full height
    of the card, 2px radius. Use olive #5A7233, slate blue #3F6480 and
    terracotta #AC5E2D across different rows.
- 24px gap.
- Section header "Today's Tasks" 16px semibold, with "1/3" right aligned.
- 8px gap.
- Three task rows, visually lighter than habit rows so the two sections
  are never confused: no card background, just a row on the page
  background with a 1px #E6DFD5 divider beneath each.
  - Left: a 22px rounded-square checkbox, 4px radius, 2px #9F8D7B outline.
  - Task title 15px regular #1F1A15.
  - Below it, 12px #655A4E: a due label such as "Today, 6:00 PM".
  - Right: a small 8px priority dot. High priority uses #C2703D, normal
    priority uses #9A8E83.
- 48px gap.
- A single quiet line of centered italic text, 12px #9A8E83:
  "Progress is the sum of small wins."
- 64px bottom spacing.

Bottom navigation bar, 72px tall, #FFFFFF, with a 1px #E6DFD5 top
border. Three items: Home, Habits, Stats. Selected item uses a filled
icon and #6F4E37 label with a soft #6F4E37 pill behind the icon at 12%
opacity. Unselected items use outline icons and #9A8E83 labels.
```

### 3.7 Habits list

```
The habit management screen, reached from the bottom navigation.

Layout top to bottom:
- App bar, 64px, background #FAF8F5, no shadow, no elevation. Title
  "Habits" 24px semibold #1F1A15 left aligned at 20px from the edge. On
  the right, a thin-stroke filter icon, 24px, #655A4E.
- 8px gap.
- A horizontal scrolling row of filter chips with 8px gaps, 20px side
  padding, 36px tall, 8px radius. The selected chip "All" has a #6F4E37
  fill with #FFFFFF 14px semibold text. Unselected chips ("Health",
  "Mind", "Fitness", "Archived") have #F2EDE6 fill, 1px #E6DFD5 border
  and #655A4E 14px text.
- 16px gap.
- A vertical list of habit management rows, 8px apart. Each: white card,
  16px radius, 16px padding, 72px min height.
  - Left: a 10px circular category dot.
  - 12px gap, then an emoji 20px.
  - Then a two-line stack: habit name 16px medium #1F1A15, and beneath
    it in 12px #655A4E the schedule, e.g. "Daily" or "Mon, Wed, Fri".
  - Far right: a thin chevron-right icon 20px in #9A8E83.
- Show 6 rows with varied names and schedules so the list reads as real.
- A floating action button anchored bottom right, 56px circular, fill
  #6F4E37, a white plus icon 24px, one soft shadow. It sits 16px above
  the bottom navigation bar and 20px from the right edge.

Bottom navigation identical to the dashboard, with Habits selected.
```

### 3.8 Add Habit

```
A full-screen form for creating a habit. It is presented as a page, not
a dialog.

Layout top to bottom:
- App bar 64px, #FAF8F5, no elevation. A thin close X icon 24px #655A4E
  on the left. Title "New Habit" 20px semibold centered. On the right, a
  text button "Save" 16px semibold in #6F4E37, shown at 38% opacity to
  indicate it is disabled until the form is valid.
- 24px gap.
- Field label "Name" 14px semibold #1F1A15, 8px gap, then a text input:
  56px tall, #F2EDE6 fill, 12px radius, 1px #9F8D7B border, 16px internal
  padding, placeholder "Morning walk" in #9A8E83 16px.
- 24px gap.
- Label "Icon". 8px gap. A row of 6 emoji tiles, each 48x48px, 12px
  radius, 8px apart. Unselected tiles have #F2EDE6 fill. The selected
  tile has #FFFFFF fill with a 2px #6F4E37 border.
- 24px gap.
- Label "Category". 8px gap. A wrapping set of category chips, 36px tall,
  8px radius, 8px gaps. Each chip has a 10px coloured dot then its label
  in 14px. Unselected: #F2EDE6 fill, #655A4E text. Selected: #FFFFFF
  fill, 2px border in that category's own colour, text in the same colour.
  Use Health olive #5A7233, Mind violet #6B5B8C, Fitness terracotta
  #AC5E2D, Learning slate #3F6480.
- 24px gap.
- Label "Frequency". 8px gap. Two chips side by side, "Daily" and
  "Specific days", styled like the category chips with "Specific days"
  selected in #6F4E37.
- 12px gap. A row of 7 circular day toggles, 36px each, evenly spaced
  across the full width, labelled M T W T F S S. Selected days (M, W, F)
  are filled #6F4E37 with #FFFFFF letters. Unselected are #FFFFFF with a
  1px #E6DFD5 border and #655A4E letters.
- 24px gap.
- Label "Reminder". 8px gap. A single row: the text "Remind me" 16px
  #1F1A15 on the left, and on the right a toggle switch in the off
  position, track #E6DFD5.
- 48px bottom spacing.

No bottom navigation bar on this screen.
```

### 3.9 Habit Detail

```
A single habit's own screen, opened by tapping a habit. Read-only
analytics for one habit.

Layout top to bottom, scrollable:
- App bar 64px, #FAF8F5, no elevation. A thin back-arrow icon on the
  left. On the right, a thin pencil edit icon 24px #655A4E.
- 8px gap.
- A header block, centered: an emoji at 40px, 12px gap, the habit name
  "Morning Walk" 24px semibold #1F1A15, and 4px below it "Health -
  Daily" in 14px #655A4E.
- 24px gap.
- A row of three stat cards with 8px gaps, each equal width, white, 16px
  radius, 16px padding, centered content. Each shows a number in 28px
  semibold #1F1A15 above a label in 12px #655A4E. The three: "14" /
  "Current streak", "31" / "Best streak", "86%" / "Last 30 days". In the
  first card only, place a small 16px flame-outline icon in #C2703D
  directly above the number.
- 24px gap.
- Section header "This year" 16px semibold.
- 8px gap.
- A GitHub-style contribution heatmap in a white card, 16px radius, 16px
  padding. Cells 16px square with 4px gaps, arranged in 7 rows. Use five
  intensity levels: #F1EDE7 empty, then #E3D3C0, #CDB094, #A97F58, and
  #6F4E37 for full. Month labels above in 11px #9A8E83. A small legend
  bottom right: "Less" then five 12px swatches then "More", all 11px
  #9A8E83.
- 24px gap.
- Section header "Why it slipped" 16px semibold.
- 8px gap.
- A white card, 16px radius, 16px padding, listing three reasons. Each
  row: a small 16px line icon, then the reason label 14px medium #1F1A15,
  then a thin horizontal bar 6px tall with 3px radius, then a percentage
  in 12px #655A4E right aligned. Bars use #6F4E37 at descending widths.
  Rows read "Low energy 40%", "Too busy 35%", "Traveling 25%".
- 48px bottom spacing.
```

### 3.10 Statistics

```
The analytics screen, reached from the bottom navigation. Emphasis is on
cumulative progress, never on an unbroken streak.

Layout top to bottom, scrollable:
- App bar 64px, #FAF8F5, no elevation, title "Statistics" 24px semibold
  left aligned.
- 8px gap.
- A hero streak card: white, 16px radius, 20px padding, full width. A
  large number "14" at 48px semibold #6F4E37, centered, with the word
  "day streak" beneath it in 14px #655A4E. Below that, a single thin
  divider line #E6DFD5, then a row of two stats side by side, each
  centered: "Best 31" and "Total 248", label 12px #655A4E above value
  16px semibold #1F1A15.
- 16px gap.
- A row of three period chips, 36px tall, 8px radius: "7 days", "30 days",
  "90 days", with "30 days" selected in #6F4E37 and white text.
- 16px gap.
- A completion trend card: white, 16px radius, 16px padding, 220px tall.
  Inside, a smooth line chart with a single #6F4E37 line, 2px, with a
  soft #6F4E37 fill beneath it at about 8% opacity. Horizontal grid lines
  1px #E6DFD5. Axis labels 11px #9A8E83. No chart legend, no data point
  markers except a single filled dot on the most recent point.
- 16px gap.
- Section header "Overall activity" 16px semibold.
- 8px gap.
- A heatmap card identical in style to the Habit Detail heatmap.
- 16px gap.
- A weekly insight card. This one is visually distinct: fill #FFFBF5
  instead of white, 16px radius, 16px padding, and a 3px #C2703D bar down
  its left edge. Inside: a small 16px sparkle line icon in #9A4F24, then
  a heading "This week" 14px semibold #9A4F24, then body text 14px
  #1F1A15 line height 1.5 reading "78% completion this week - steady and
  building. Wednesday seems to be your power day."
- 16px gap.
- A "What gets in the way" card, white, matching the Habit Detail reason
  card exactly.
- 48px bottom spacing.

This is the only screen where a terracotta element appears - the insight
card's left bar. Nothing else on this screen may be terracotta.

Bottom navigation identical to the dashboard, with Stats selected.
```

### 3.11 Pause & Reflect sheet

```
A modal bottom sheet that slides up over a dimmed dashboard. It appears
the morning after a habit was missed. Its tone is the most important
thing about it: gentle, never accusatory, always escapable.

The sheet covers about 82% of the screen height, #FFFFFF, with 20px
radius on the top two corners only. The dashboard behind it is dimmed
with a warm dark overlay at about 35%.

Layout inside the sheet, top to bottom:
- 12px top padding, then a centered drag handle 40x4px, 2px radius,
  #E6DFD5.
- A top row with a single right-aligned text button "Not now", 14px
  #655A4E, 20px from the right edge. There is no X and no back arrow -
  dismissing must feel easy, not like closing a dialog.
- 16px gap.
- A small leaf glyph 32px, centered.
- 16px gap.
- Centered text block: "Today didn't go exactly as planned." 18px
  semibold #1F1A15, then 4px gap, "That's okay." 14px #655A4E, then 4px
  gap, "What got in the way?" 18px semibold #1F1A15.
- 24px gap.
- Five labelled reason groups stacked vertically with 16px between them.
  Each group: a small row with a 16px emoji then the group name in 14px
  semibold #655A4E with slight letter spacing; then 8px gap; then a
  wrapping set of chips. Chips are 8px radius, 12px horizontal and 8px
  vertical padding, #F2EDE6 fill with a 1px #E6DFD5 border and 12px
  #1F1A15 text. Exactly one chip anywhere in the sheet is shown selected:
  #FFFFFF fill, 2px #6F4E37 border, #6F4E37 semibold text.
  Groups and chips: Energy (Low Energy, Poor Sleep, Felt Sick, Burned
  Out); Time (Too Busy, Unexpected Work, Meetings, Family); Mind (Lost
  Motivation, Procrastinated, Forgot, Overwhelmed); Environment
  (Traveling, Weather, No Equipment, Away From Home); Personal (Needed
  Rest, Mental Break, Personal Event, Emergency).
- 16px gap.
- A "My Reason" block: a small pencil glyph then the label "My Reason"
  14px semibold, 8px gap, then a single-line text input 56px tall,
  #F2EDE6 fill, 12px radius, 1px #E6DFD5 border, placeholder "Something
  else on your mind..." in #9A8E83.
- 24px gap.
- Pinned to the bottom of the sheet: a full-width button 52px tall, 12px
  radius, #6F4E37 fill, label "Continue" #FFFFFF 16px semibold. Below it
  12px gap, then centered italic 12px #9A8E83 text: "Tomorrow, we'll try
  again."
- 24px bottom padding.
```

### 3.12 Tasks list

```
The to-do screen. Tasks are lighter-weight than habits and the design
must make that obvious at a glance - flatter, less card-like, more
list-like.

Layout top to bottom:
- App bar 64px, #FAF8F5, no elevation. Title "Tasks" 24px semibold left
  aligned. On the right, a thin search icon 24px #655A4E.
- 8px gap.
- A horizontal row of filter chips, 36px tall, 8px radius, 8px gaps:
  "Today" selected in #6F4E37 with white text, then "Upcoming",
  "Overdue", "Done" in #F2EDE6 with #655A4E text. The "Overdue" chip
  carries a small 6px #C2703D dot before its label.
- 16px gap.
- Grouped task list. Each group starts with a small left-aligned header
  in 12px semibold #9A8E83 with letter spacing: "OVERDUE", then "TODAY",
  then "TOMORROW".
- Under each header, task rows on the page background with no card fill,
  separated by 1px #E6DFD5 dividers, 16px vertical padding, 20px side
  padding.
  Each row:
  - Left: a 22px rounded-square checkbox, 4px radius, 2px #9F8D7B
    outline. Completed rows show a filled #5A7233 box with a white check.
  - 12px gap, then a two-line stack: the task title 15px regular
    #1F1A15, and below it 12px #655A4E showing due time and category,
    e.g. "6:00 PM - Learning".
  - Completed rows show the title in #9A8E83 with a single 1px
    strikethrough, and the whole row at 60% opacity.
  - Far right: a priority dot 8px. High #C2703D, medium #97692A, low
    #9A8E83.
  - Overdue rows show their due label in #9C4A32 instead of #655A4E.
- Show 2 overdue, 4 today (one completed), and 2 tomorrow.
- A floating action button bottom right, 56px circular, #6F4E37, white
  plus icon, sitting 16px above the bottom navigation.

Bottom navigation for this screen has four items: Home, Habits, Tasks,
Stats - with Tasks selected.
```

### 3.13 Add Task

```
A full-screen form for creating a task. It must feel lighter and shorter
than the Add Habit form - fewer fields, more air.

Layout top to bottom:
- App bar 64px, #FAF8F5, no elevation. Close X icon left. Title "New
  Task" 20px semibold centered. Text button "Save" right, 16px semibold
  #6F4E37 at 38% opacity to show it is disabled.
- 24px gap.
- Label "What needs doing?" 14px semibold #1F1A15, 8px gap, a text input
  56px tall, #F2EDE6 fill, 12px radius, 1px #9F8D7B border, placeholder
  "Finish the assignment" #9A8E83 16px.
- 24px gap.
- Label "Due". 8px gap. Two side-by-side selector fields with a 12px gap,
  each equal width, 56px tall, #F2EDE6 fill, 12px radius, 1px #E6DFD5
  border. The left shows a small 20px calendar line icon then "Today" in
  16px #1F1A15. The right shows a small 20px clock line icon then "6:00
  PM".
- 24px gap.
- Label "Priority". 8px gap. Three chips in a row, 36px tall, 8px radius,
  8px gaps: "Low", "Normal", "High". Each has a leading 8px dot in its
  own colour - #9A8E83, #97692A, #C2703D. "Normal" is selected: #FFFFFF
  fill, 2px #6F4E37 border, #6F4E37 semibold label.
- 24px gap.
- Label "Category". 8px gap. A wrapping set of category chips identical
  in style to the Add Habit screen.
- 24px gap.
- Label "Notes (optional)". 8px gap. A multi-line text area, 96px tall,
  #F2EDE6 fill, 12px radius, 1px #E6DFD5 border, placeholder "Anything
  worth remembering..." #9A8E83 14px, text top-aligned.
- 48px bottom spacing.

No bottom navigation bar on this screen.
```

### 3.14 Settings

```
The settings screen. Grouped, calm, text-forward. No icons-in-coloured-
squares, no avatars, no account section - this app has no login.

Layout top to bottom, scrollable:
- App bar 64px, #FAF8F5, no elevation, title "Settings" 24px semibold
  left aligned.
- 16px gap.
- Group header "APPEARANCE" 12px semibold #9A8E83 with letter spacing,
  20px left padding.
- 8px gap.
- A white card, 16px radius, containing two rows separated by a 1px
  #E6DFD5 divider that is inset 16px from the left.
  Row 1: "Theme" 16px #1F1A15 on the left; on the right "Clay & Oat"
  14px #655A4E followed by a chevron-right 20px #9A8E83. 56px row height,
  16px horizontal padding.
  Row 2: "Reduce motion" 16px #1F1A15 on the left, a toggle switch on the
  right in the off position with track #E6DFD5.
- 24px gap.
- Group header "REMINDERS".
- A white card with two rows: "Daily reminder" with a toggle in the on
  position, track #6F4E37; and "Reminder time" with "8:30 AM" and a
  chevron.
- 24px gap.
- Group header "YOUR DATA".
- A white card with three rows, each with a chevron: "Export as CSV",
  "Export as JSON", and "Import from backup". Below the third row, inside
  the same card, a 12px #655A4E caption on two lines: "Everything stays
  on this device. Tracely has no account and no servers."
- 24px gap.
- Group header "ABOUT".
- A white card with two rows: "Version" with "0.1.0" right aligned in
  14px #655A4E and no chevron; and "Send feedback" with a chevron.
- 48px bottom spacing.

Bottom navigation is not shown on this screen.
```

### 3.15 Empty and error states

```
Generate four state variations of the Dashboard screen. All four keep the
same app structure and bottom navigation - only the main content area
changes. Each must feel composed and intentional, never like a broken or
half-loaded screen.

1. EMPTY - no habits yet.
   Centered in the content area: a line-art glyph 64px in #9F8D7B of a
   single empty circle with a soft dotted outline. 24px gap. Headline
   "Ready when you are" 20px semibold #1F1A15. 8px gap. Body "Add your
   first habit and start building." 14px #655A4E, centered, max two
   lines. 24px gap. A primary button that is NOT full width - about 200px
   wide, 52px tall, 12px radius, #6F4E37, label "Add First Habit".

2. LOADING - skeleton, not a spinner.
   Reproduce the real dashboard layout with every text and card replaced
   by a #F2EDE6 rounded block at the exact size and position of the
   content it stands in for: a 160x28 block for the greeting, a 120x16
   block for the subtitle, a full-width 130px block for the progress
   card, a 140x18 block for the section header, and three full-width 72px
   blocks for habit rows. No spinner anywhere on screen.

3. ERROR - something failed to load.
   Centered: a line-art glyph 64px in #9F8D7B of a cloud with a small
   break in its outline. 24px gap. Headline "Couldn't load today" 20px
   semibold #1F1A15. 8px gap. Body "Something went wrong reading your
   habits. Your data is safe." 14px #655A4E centered. 24px gap. A ~200px
   wide button, outlined rather than filled: #FFFFFF fill, 2px #6F4E37
   border, #6F4E37 label "Try Again". No red anywhere, no error code, no
   technical text.

4. ALL DONE - every habit completed.
   The progress ring is full and filled #5A7233, showing "5/5" inside.
   The habit rows are all in their completed state. Below the list, a
   centered line of 14px #5A7233 semibold text: "All five, done." No
   confetti, no trophy, no badge, no celebration animation.
```

---

## 4. Refinement prompts

After the first generation of any screen, use these one at a time. Never
combine two.

**Fixing the most common Stitch drift:**

```
Remove all shadows except a single soft shadow on cards: 0 2px 8px
rgba(0,0,0,0.05).
```
```
The background is too white. Change the page background to exactly
#FAF8F5 and keep cards #FFFFFF so cards sit slightly above the page.
```
```
Reduce the corner radius on all buttons to 12px. Cards stay at 16px.
```
```
There is more than one terracotta element on this screen. Keep only the
single most important one and change the rest to #6F4E37 or #655A4E.
```
```
Increase the vertical gap between sections to 24px throughout.
```
```
Make all icons thin 2px rounded-stroke line icons from one family.
Remove any filled or duotone icons except the selected bottom navigation
item.
```
```
Tighten the copy. No sentence may exceed 60 characters per line.
```

**Asking for variants:**

```
Generate a variant of this screen where the habit rows are flat list
items with dividers instead of individual cards. Keep all colors,
typography and spacing identical.
```

---

## 4.1 Round-1 corrections (audited 2026-09-19)

The first Stitch generation was audited against this kit — colour tokens
resolved from markup, plus headless-Chrome renders. Verdict: **structurally
correct, four real defects.** Do not regenerate whole screens; apply these as
single-change refinements.

### FALSE ALARM — do not act on this

The exported `screen.png` previews show **text overlapping** on nearly every
screen (greeting over date, headline over subheadline, card heading over body).
**This is a Stitch preview artifact, not a defect.** Every affected pair sits
in a normal `flex flex-col` with `mt-*` spacing, which cannot overlap. Headless
Chrome renders of `daily_opening_ritual`, `pause_reflect` and `dashboard` are
clean. The previews are screenshotted before Inter finishes loading.

The same applies to **aggressive truncation** in the previews (`Morning Sencha
T...`). At real phone width all names render in full. Judge layout from a
browser render of `code.html`, never from `screen.png`.

### Defect 1 — glassmorphism (banned, 9 files)

`backdrop-blur-xl` on the sticky header of dashboard, habits, tasks, settings,
habit_detail, statistics and all four dashboard state variants.

```
Remove the backdrop blur from the header. Give it a solid #FAF8F5 background
with a 1px #E6DFD5 bottom border and no shadow.
```

### Defect 2 — account avatar (8 files)

A `person` icon sits top-right on dashboard, habits, statistics, settings and
the four state variants. **Tracely has no login and no account** — this is a
product error, not a style preference.

```
Remove the circular avatar icon from the top right of the header. This app has
no user account and no login.
```

### Defect 3 — invented app header (8 files)

An app bar with a Tracely brand mark and a "Home"/"Stats" subtitle was added to
screens whose prompts start at the greeting. It also loads an external
`lh3.googleusercontent.com` image that will not exist in the real app.

```
Remove the entire top header bar including the logo image and the app name.
The screen content starts directly with the greeting at 20px from the top.
```

For Habits, Statistics, Settings and Tasks — which *do* have an app bar in
this kit — keep the bar but strip the logo:

```
Remove the logo image and the small subtitle from the header. Keep only the
screen title text, left aligned.
```

### Defect 4 — this kit contradicts itself on terracotta

Not Stitch's error. The Style Block says *"only ONE terracotta element per
screen,"* but the **Tasks** prompt asks for a terracotta Overdue-chip dot *and*
terracotta high-priority dots, and **Add Task** asks for a terracotta priority
dot. Three ways out — pick one and make the kit consistent:

1. Treat priority dots as a *semantic scale* exempt from the one-accent rule
   (recommended — they are data, not decoration).
2. Change high priority to `#9A4F24` (accentText) so only the Overdue chip is
   true terracotta.
3. Drop the dot from the Overdue chip and let the label colour carry it.

`onboarding_2` uses terracotta four times, but all four are inside one
illustration SVG — that is a single element and needs no fix.

### Clean — no action

- **Nothing is red anywhere.** Material's default error reds are declared in
  the auto-generated Tailwind token block but never applied.
- Only five off-spec colours reach the markup, all incidental neutrals.
- Inter, the 4px rhythm, `0 2px 8px rgba(0,0,0,0.05)` shadow, radii, the
  brown ramp, the 4-item nav and the Statistics insight card are all correct.

---

## 4.2 Round-2 verification (2026-09-19, after corrections)

All 18 screens re-extracted, token-audited, and rendered in headless Chrome.

**Fixed — confirmed gone:**

| Defect | Round 1 | Round 2 |
|---|---|---|
| Account avatar | 8 screens | **0** |
| Invented logo header | 8 screens | **1** (splash only — correct) |
| `backdrop-blur` | 9 screens | **2** |
| External Google images | 8 screens | **2** |
| Red anywhere | 0 | **0** |

**Still open — 4 items:**

1. **`backdrop-blur-xl` remains** on `dashboard_all_done_state` and
   `dashboard_empty_state`. These live in the *second* zip and were missed.
2. **Nav icons drift between zips.** The four main screens use
   `home / repeat / check_circle / insights`; the four state screens use
   `space_dashboard / spa / check_circle / monitoring`. Three of four differ.
   This is exactly the cross-screen drift that happens when the Style Block
   is not re-pasted for a separate session.
   ```
   Change the bottom navigation icons to exactly: home, repeat, check_circle,
   insights — in that order, thin outline style.
   ```
3. **Photographic banner on Habits.** A stock-style flatlay photo of a journal
   and matcha cup sits above the habit list, loaded from Google's CDN. It was
   never in the prompt, contradicts the flat-line-art rule, and will not exist
   in the real app.
   ```
   Remove the photographic banner card above the habit list. The filter chips
   are followed directly by the first habit row.
   ```
4. **Duplicate title on Statistics** — "Statistics" renders in both the fixed
   header and the page body.
   ```
   Remove the duplicate "Statistics" heading from the page body. Keep only the
   one in the fixed header.
   ```

**Verified sound — two false alarms retracted:**

- The preview-PNG text overlap is a Stitch screenshot artifact (confirmed
  again — renders clean in Chrome).
- **Retracted:** a 360px render appeared to drop the "Stats" nav item and clip
  cards. That was Chrome headless not applying mobile viewport emulation — it
  laid out at ~500px and cropped the image. All 8 nav-bearing screens contain
  4 items in markup, no page sets a `min-width`, and the only fixed width near
  the limit (`min-w-[340px]` on the Habit Detail heatmap) sits inside
  `overflow-x-auto` by design. **There is no responsive defect.**

---

## 4.3 Re-check of Dashboard empty/loading/error states (2026-09-19)

User re-pasted the HTML for `dashboard_empty_state`, the loading skeleton, and
`dashboard_error_state` after a targeted fix. Token-audited directly (no zip
this time — HTML pasted inline).

**Confirmed fixed:**

- Item 1 from §4.2 — `backdrop-blur-xl` is gone from `dashboard_empty_state`.
  Nav is now solid `bg-surface-card`. (`dashboard_all_done_state` was not
  re-sent, so it is still assumed broken until it's checked too.)
- Item 2 from §4.2 — nav icons on all three screens are now
  `home / repeat / check_circle / insights`, matching the main set. Icon
  drift is resolved for this screen family.

**New — contrast fail introduced, not previously caught:**

The empty-state quote — `"Progress is the sum of small wins."` — is styled
`text-text-disabled` (`#9A8E83`) on `page-bg` (`#FAF8F5`).

```
contrast(#9A8E83, #FAF8F5) = 3.01:1   -- fails 4.5:1 (small italic text)
contrast(#655A4E, #FAF8F5) = 6.34:1   -- text-secondary, the correct token
```

`text-disabled` is meant for inactive UI (greyed-out controls), not for text
someone is supposed to read. Swap the class to `text-text-secondary`.

```
Change the quote text colour on the Dashboard empty state from text-disabled
to text-secondary. Disabled grey is reserved for inactive controls, not
readable copy.
```

**Minor — nav background inconsistency (not blocking):**

`dashboard_empty_state` nav is solid `bg-surface-card`. The loading skeleton
and `dashboard_error_state` nav are `bg-page-bg/80` (80% opacity, no blur).
Not glassmorphism, but it means these three states of the same screen don't
share one nav treatment. Pick solid `bg-surface-card` (matches the fixed
empty state) for all three and move on — not worth its own regeneration
round.

**Clean on all three:** no avatar, no external images, no red, no duplicate
headers. Loading skeleton and error state were not previously seen in the
round-1/round-2 zips — both are well-built (skeleton dimensions match the
real card layout; error state avoids alarming red and uses a calm outlined
coffee-brown retry button instead).

---

## 4.4 Final zip re-check (2026-09-19) — all tracked defects closed

Both zips re-extracted (18 screens total, 14 + 4) and token-audited after the
user's latest correction pass. Checked every item still open as of §4.2/§4.3:

| Item | Status |
|---|---|
| `backdrop-blur-xl` on the two dashboard state screens | **Fixed** — 0/18 files contain it |
| Nav icon drift between the two zips | **Fixed** — all 8 nav-bearing screens now render identical `home / repeat / check_circle / insights` |
| Nav bg inconsistency (`bg-page-bg/80` vs `bg-surface-card`) | **Fixed** — unified to solid `bg-surface-card` everywhere |
| Photographic banner on Habits | **Fixed** — no external `<img>` on `habits` |
| Duplicate "Statistics" title | **Fixed** — the word appears exactly once, in the `<h1>` |
| Empty-state quote contrast (`text-disabled`, 3.01:1) | **Fixed** — now `text-secondary` |

One false positive during this pass: `habit_detail` matched an "avatar" scan
on the string `<!-- Day of Week initials (M, W, F...) -->` — a code comment
about schedule-day letters, not an account avatar. Confirmed by reading the
surrounding markup; not a defect.

`splash` is still the only screen with an external image
(`lh3.googleusercontent.com/aida/...` — Stitch's own generated artwork used
as the app logo). That's correct for what the screen is; the only action
needed is later, when building the real app: download that image and bundle
it as a local asset rather than hotlinking a Stitch CDN URL that isn't
guaranteed to stay live.

**Nothing left to regenerate.** Every mechanically-checkable defect from
round 1 through this pass is closed.

---

## 5. Colour variants — swap these lines only

To re-skin, replace **only** the colour lines inside the Style Block.
Leave every screen prompt untouched. Every variant below has been
verified to meet WCAG AA (4.5:1 for text, 3:1 for UI boundaries).

### 5.1 Clay & Oat — ACTIVE

```
- Page background: #FAF8F5   - Cards: #FFFFFF
- Recessed fills: #F2EDE6    - Primary: #6F4E37
- Accent fill: #C2703D       - Accent text: #9A4F24
- Text: #1F1A15              - Secondary text: #655A4E
- Disabled: #9A8E83          - Borders: #E6DFD5
- Input outlines: #9F8D7B    - Success: #5A7233
- Error: #9C4A32
```

### 5.2 Espresso & Linen — deeper, more formal

```
- Page background: #FBF9F6   - Cards: #FFFFFF
- Recessed fills: #F1ECE5    - Primary: #5A4033
- Accent fill: #B4622F       - Accent text: #8F4520
- Text: #1C1714              - Secondary text: #61564B
- Disabled: #978B80          - Borders: #E5DED4
- Input outlines: #9C8A78    - Success: #556B33
- Error: #94452F
```

### 5.3 Umber & Sand — lighter, friendlier

```
- Page background: #FAF7F2   - Cards: #FFFFFF
- Recessed fills: #F3EEE5    - Primary: #8B5E3C
- Accent fill: #BE6A33       - Accent text: #964E22
- Text: #211B15              - Secondary text: #6A5E51
- Disabled: #9C9085          - Borders: #E8E0D5
- Input outlines: #A08E7C    - Success: #5F7A3F
- Error: #A04B34
```

### 5.4 Supporting ramps (same across all three variants)

Heatmap, empty to full:
`#F1EDE7` → `#E3D3C0` → `#CDB094` → `#A97F58` → `#6F4E37`

Category colours — all verified at 4.5:1 or better as text:
| Category | Hex |
|---|---|
| Health | `#5A7233` |
| Mind | `#6B5B8C` |
| Fitness | `#AC5E2D` |
| Learning | `#3F6480` |
| Creativity | `#9C5A6B` |
| Social | `#3F7A76` |
| Self-Care | `#97692A` |
| Custom | `#7C7067` |

---

## 6. What the competitor research says to do differently

| App | What it does well | What Tracely should do instead |
|---|---|---|
| **Streaks** | Grid of circular icons, fills on completion, strong haptics. Caps you at 12 habits to force prioritisation. | Borrow the tactile completion moment; reject the cap. Unlimited habits is a stated product promise. |
| **Habitify** | Clean cross-platform charts, light/dark themes, polished stats. | Match the chart polish, but keep charts one tap away from home. Habitify puts analytics front and centre; the spec forbids that. |
| **Loop** | Genuinely free, offline, no account. | Same posture — but Loop looks dated. The opportunity is "Loop's ethics with 2026 visual craft." |
| **TickTick / Todoist** | Strong task management. | Their most-repeated complaint is reminders and calendar behind a paywall. Never paywall those. |
| **Notion / Obsidian** | Infinitely flexible. | Their failure is "the system becomes the work." Every screen in this kit must stay a single scroll with no configuration surface. |

**The visual trend to deliberately avoid:** several 2026 habit trackers
have converged on soft neumorphism with glowing accents. It photographs
well on Dribbble and reads as generic in the Play Store. The Style Block
bans it explicitly for that reason. Tracely's differentiator is warmth
and restraint, not effects.

**What actually makes a habit tracker look paid rather than templated:**
composed empty states, skeletons instead of spinners, one accent colour
used once per screen, and completion moments that feel physical. All four
are specified above — they are the part most AI-generated UI skips.

---

## 7. Revenue — what the spec permits

Your own spec is unusually strict here, and the design must not quietly
undermine it. Section 3 states *"No feature is free-tier-gated. Reminders,
calendar view, and habit/task count are never paywalled — that's the exact
complaint this app exists to not repeat."* Section 5 lists *"any paywalled
core feature or subscription requirement"* under **Explicitly NOT
Building**.

Industry data points the other way — hard paywalls convert at roughly
10.7% D35 versus 2.1% for freemium — but following it would delete the
product's reason to exist. So:

**Compatible with the spec:**
- **Theme packs as a one-time purchase.** The kit already ships three
  verified palettes and the Settings screen already has a Theme row. This
  is the single cheapest monetisation hook you have, it is purely
  cosmetic, and it gates nothing functional.
- **A one-time "supporter" unlock.** No feature attached. Some users pay
  to support an app that refuses to rent-seek — and saying so plainly is
  on-brand for this product.
- **Cloud sync as the paid tier at v1.0.** Already the roadmap. Sync is
  genuinely a recurring cost, so charging for it is defensible in a way
  that charging for reminders is not.

**Incompatible — do not design these:**
- Any habit or task count limit.
- Reminders, calendar, statistics, or export behind a paywall.
- A subscription for anything that works offline.
- A paywall screen during onboarding.

There is deliberately no paywall screen in this kit. Adding one is a
product decision that contradicts the spec, and it should be made
explicitly by you rather than absorbed silently through a design.

---

## 8. Before you ship to Play Store

Carried from `design_master_prompt.md` §7 — Stitch will not do these for
you:

- [ ] Adaptive app icon, foreground + background layers, 512×512 master
- [ ] Splash matches the first frame of the Ritual animation
- [ ] All text ≥ 4.5:1 in every theme you ship
- [ ] TalkBack navigates every screen in a sensible order
- [ ] Layout survives 130% system font scaling
- [ ] Every animated screen tested with "Remove animations" enabled
- [ ] Feature graphic 1024×500 built from real screenshots, not mockups
- [ ] Closed testing: ~12 testers for ~14 consecutive days — start
      recruiting now, this is the longest lead time on your launch
