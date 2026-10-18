# Make my pitch deck

**Use it for:** Writing a clear 12-slide seed pitch deck with you, then building it in a style you pick.

**Runs in:** Any Claude chat. No website clicking needed, so no Claude in Chrome. With the skill installed, Claude follows `deck/HOW-TO-MAKE-A-DECK.md`.

**Fill in before you hand it over** (delete any line you don't know; leave no `{` or `}` behind):
- `{deck_link}`: a link to your old deck, if you have one. Optional.
- The "About me and my startup" lines: from the facts block in `SKILL.md`. If the company name is missing, write "my startup".

```text
Goal: help me make a clear 12-slide pitch deck for {company}, using only my real facts.
My old deck: {deck_link}

1. Ask me to upload my pitch deck (PDF) here or paste its link. Read all of it. If I don't have one, say so and we start fresh.
2. If I have no deck, or it is missing parts, ask me these plain questions, one or two at a time: What problem do you solve? Who has it? What is your fix? Why now? What traction do you have? How do you make money? Who is on the team? How much are you raising, and what for?
3. Write the 12 slides as plain text first: title, problem, who has it, solution, why now, product, traction, business model, market, competition, team, the raise and what it pays for, plus a closing line. Use only facts from my deck, my answers and the lines below. Never invent numbers, customers, logos or quotes. Mark anything unsure as [CHECK].
4. Show me the draft. Change it if I ask. Only when I type design do you build it.
5. Show me the styles and let me pick one. If the fundraise skill is installed, follow deck/HOW-TO-MAKE-A-DECK.md and use deck/deck-template.html. If not, build it as one self-contained HTML file with clean, simple slides.
6. Give me the deck as ONE HTML file (an artifact in claude.ai), and offer a PowerPoint copy too.
7. Report back: the file, the style, every slide title, and every [CHECK] item I still need to fix.

About me and my startup (use only these facts and my deck):
- Company: {company}
- What we do, in one line: {one_liner}
- Website: {website}
- My first name: {first_name}
- Stage: {stage}
- Sector: {sectors}
- Country: {country}
- We are raising: {raise}
- Traction: {traction}
- Accelerator we did before: {prior_accelerator}

Rules for the whole task:
- Never click Send, Submit, Connect, Pay or Accept without my clear yes.
- Never upload or share my deck anywhere without my clear yes.
- If you see a CAPTCHA, a security check or a warning from the site, stop and ask me to handle it.
- If the person or company doesn't match (wrong photo, title or company), stop and ask.
- Never invent numbers. Mark anything unsure as [CHECK].
- Use only my facts. Don't add customer logos, quotes or partners I didn't give you.
- Short slides: one idea per slide, a headline that says the point, a few words underneath.
```
