# How to make a pitch deck with the founder

Follow these steps in order. Talk in plain words and ask one or two questions at a time. The founder may never have
made a deck before; that is fine.

The golden rule: **never invent numbers, customers, logos, quotes or team members.** If something is unsure or
missing, write `[CHECK]` in its place and tell the founder. List every `[CHECK]` at the end.

## Step 1. Get what they already have

Ask: **"Do you have an old pitch deck? Please upload it (PDF or PowerPoint) or paste its link."**

How to read an old deck:
- Read every slide, including small text, charts and footnotes. Note the numbers exactly as written, with their
  dates ("1,200 users in March 2026").
- Sort what you find into the 12 slides below. Note which slides are missing or weak.
- Look for common problems: too many words, a vague problem, no "why now", traction without dates, no clear ask,
  market size without a source, a team slide without why this team.
- Tell the founder in a short list: what is strong, what is missing, and the 3 changes that would help most.
- Keep their real facts. Improve the wording, not the numbers.

Also use the facts block from `SKILL.md` and their website, if they gave one.

## Step 2. Ask the 8 plain questions (only the ones still missing)

1. **The problem:** What problem do you solve? Tell me about one real person who has it.
2. **Who has it:** Who has this problem, and how many of them are there? (Rough is fine; say where the number is from.)
3. **Your fix:** What do you do about it? What does the customer do differently with you?
4. **Why now:** Why is now the right time? What changed (technology, law, habits, cost)?
5. **Traction:** What proof do you have? Users, waitlist, revenue per month, pilots, letters of intent, growth.
   With dates.
6. **Business model:** How do you make money? Who pays, how much, how often?
7. **Team:** Who is on the team, and why are you the right people to build this?
8. **The raise:** How much are you raising, and what will the money pay for? What will you reach with it
   (for example "18 months, 10,000 users, $50k monthly revenue")?

If they have no traction yet, that is normal for very early teams. Use what they do have: customer interviews,
a waitlist, a working prototype, letters of intent, or past things they built.

## Step 3. Write the 12-slide seed story as plain text

Write every slide as text first, in a short list, and let the founder fix it before any design. Each slide has a
**headline that says the point** (a full short sentence, not a label) and a few words or numbers underneath.

| # | Slide | What goes on it |
|---|---|---|
| 1 | **Title** | Company name, the one-line pitch, the round ("Pre-seed round, $500k"), website. |
| 2 | **Problem** | The pain in one sentence. One real example. What it costs people today. |
| 3 | **Who has it** | The people or companies with this problem, and roughly how many. Who you start with first. |
| 4 | **Solution** | What you do, in one sentence. The 2 or 3 things that make it work. |
| 5 | **Why now** | What changed that makes this possible or urgent now. |
| 6 | **Product** | What it looks like: a screenshot or a simple "how it works" in 3 steps. |
| 7 | **Traction** | Proof, with dates: users, revenue, growth, pilots, waitlist. The best number first. |
| 8 | **Business model** | Who pays, how much, how often. Early unit numbers if they have them. |
| 9 | **Market** | How big this can get, with where the number comes from. Start from the first group of customers. |
| 10 | **Competition** | Who else solves it (including "doing nothing" or spreadsheets) and why you win. |
| 11 | **Team** | The founders, one line each on why they fit. Key advisers if any. |
| 12 | **The raise and use of funds** | How much, what it pays for (3 or 4 parts with rough shares), and what you will reach. |
| + | **Closing** | One line to remember, plus name and website. No email unless they give it to you. |

Rules for the text:
- One idea per slide. Under about 30 words on most slides.
- Use their words when they are clear. Cut jargon.
- Numbers only from the founder, their deck or their website. Every number has a date or a source, or a `[CHECK]`.
- No made-up customer logos, quotes, partners, awards or press.
- Market size: if they don't have a source, write a simple bottom-up line ("2 million small cafes in the US x
  $600 a year") and mark it `[CHECK]`.

Show the slide text and wait. Change it until they say it is right.

## Step 4. Pick a style

Show the styles. In claude.ai, show the picture `deck/previews/gallery.png` (it has all styles side by side). Each
style also has its own pictures, listed in `deck/styles/index.json` (`preview` and `preview2`).
In Claude Code, the founder can also open `deck/gallery.html` in a browser to see every style larger.

If you can't show pictures, list the styles with one line each. The full list, with fonts, is in
`deck/styles/index.json`:

- **Ember**: pre-seed and seed decks that feel warm and human
- **Harbor**: Series A decks backed by real numbers
- **Current**: tech startups with a strong growth chart
- **Ledger**: investor updates and board-ready decks
- **Granite**: fintech, infrastructure and serious B2B
- **Stage**: demo days and big-room pitches
- **Grove**: climate, food and impact startups
- **Lantern**: fintech and data-heavy decks
- **Fern**: consumer, beauty and wellness brands
- **Dusk**: deep tech and research-led startups
- **Meadow**: agritech, climate and calm impact stories
- **Forge**: hardware, logistics and no-nonsense operators
- **Volt**: bold consumer apps and developer tools
- **Opal**: health, care and mental-health startups
- **Iris**: AI and product-led startups
- **Sorbet**: friendly consumer and family products
- **Signal**: sales-led startups that want a punchy pitch
- **Glacier**: climate tech and cold, clear data stories
- **Velvet**: hospitality, food and drink brands
- **Spark**: creator tools and launch-day energy

Suggest 2 or 3 that fit their company and say why in one line. If they can't choose, use the default in
`deck/styles/index.json` (Ember).

## Step 5. Build the deck as ONE HTML file

The template is `deck/deck-template.html`. It is a complete sample deck (style Ember, a made-up company) with
the full fill-in steps in a comment at the top. Read that comment first. In short:

1. **Copy the template.** Start from a copy of `deck/deck-template.html`. Name it after the company, for example
   `acme-pitch-deck.html`. Never edit the original.
2. **Load the style.** Open `deck/styles/<id>.json` for the style they picked (the `file` in
   `deck/styles/index.json`).
3. **Paste the tokens** into the `:root` block marked "STYLE TOKENS". Each name in the style's `tokens` maps to one
   CSS variable, camelCase to kebab-case: `bg` → `--bg`, `surface` → `--surface`, `ink` → `--ink`, `muted` →
   `--muted`, `line` → `--line`, `accent` → `--accent`, `accent2` → `--accent2`, `accentInk` → `--accent-ink`,
   `positive` → `--positive`, `negative` → `--negative`, `cover` → `--cover`, `coverInk` → `--cover-ink`,
   `headFont` → `--head-font`, `bodyFont` → `--body-font`, `radius` → `--radius`, `headWeight` → `--head-weight`,
   `headCase` → `--head-case`, `headTrack` → `--head-track`. Copy the values exactly.
4. **Set the decoration:** put the style's `tokens.decoration` value in `data-deco` on the `<html>` tag.
5. **Set the fonts:** set the `href` of `<link id="google-fonts">` to
   `https://fonts.googleapis.com/css2?` followed by the style's `googleFonts` value. Add no other outside files or
   scripts.
6. **Fill the slides.** Each slide is one `<section class="slide" data-section="...">`. Put the founder's approved
   text from step 3 into these sections:

   | Story slide | Template section (layout) |
   |---|---|
   | 1 Title | `cover` (title) |
   | 2 Problem | `problem` (statement: one big number, one sentence, 3 facts) |
   | 3 Who has it | copy the `problem` block, set `data-section="who-has-it"` and the eyebrow to "Who has it". For a shorter deck, fold it into the problem slide's 3 facts instead |
   | 4 Solution | `solution` (bullets: 3 numbered points) |
   | 5 Why now | `why-now` (statement) |
   | 6 Product | `product` (cards: 3, or 4 with class `four`) |
   | 7 Traction | `traction` (kpis: 3 or 4 numbers). Keep `growth` (bar chart) only if they gave monthly numbers; otherwise delete that block |
   | 8 Business model | `business-model` (cards) |
   | 9 Market | `market` (kpis: who could buy, who we can reach, first goal) |
   | 10 Competition | `competition` (table) |
   | 11 Team | `team` (initials, or photos they give you) |
   | 12 The raise and use of funds | `raise` (amount + use-of-funds bars whose widths add up to 100%) |
   | Closing | `contact` (closing) |

   Copy a block to add a slide, delete a block to drop one. Use the story order from step 3, or the style's
   `slideOrder` if the founder prefers it. Put the company name in every footer.
7. **Remove every trace of the sample:** the sample company name, its copy and numbers, the "Sample" tag on the
   cover and on the closing slide, and the `<title>` (set it to "<Company> · Pitch deck"). The style JSON's `sample`
   block is made-up text for previews only. **Never copy sample numbers into a real deck.**
8. **Bar chart and use-of-funds bars:** follow steps 7 and 8 in the template's comment (the maths for bar heights,
   and widths that add up to 100%).
9. **Check before you deliver:** every number came from the founder; every unsure item says `[CHECK]`; headlines
   are one line (two at most); no slide is crowded; the deck opens with the arrow keys working.

## Step 6. Deliver it

- Give the deck as **one HTML file**. In claude.ai, show it as an artifact so they can see it right away. Tell them
  they can download it and open it in any browser, and press the arrow keys to move between slides.
- Offer a **PowerPoint copy**: "Would you like a PowerPoint (.pptx) version too?" If yes, use Claude's built-in
  PowerPoint skill (pptx) to make one with the same slide text, and the style's colours and fonts as closely as
  PowerPoint allows.
- End with a short report:
  - the style they picked;
  - every slide headline, in order;
  - every `[CHECK]` still in the deck, and what is needed to fix it;
  - one or two tips: "Send the deck as a PDF or a view-only link, not an editable file", "Keep a 1-page
    summary ready for emails".

## Good deck habits to share

- 12 slides is plenty. Investors spend a few minutes on a first look.
- The headline of each slide should make sense on its own. Someone reading only the headlines should get the story.
- Put the strongest proof early. If traction is the best part, it can come right after the solution.
- Update the deck every month, when the numbers change.
