#!/usr/bin/env bash
# Safety and structure checks for the repo. Run before every push and before making the repo public.
#   scripts/check.sh
# Fails (exit 1) on:
#   - secret-looking strings (sk-..., ghp_..., gho_..., AKIA..., api_key, API_KEY=), .env / key files
#   - email addresses (any address, @gmail included) and absolute local paths (/Users/<name>)
#   - the old engine's brand name (case-insensitive)
#   - invalid JSON, wrong plugin/marketplace names
#   - a missing or broken SKILL.md frontmatter, or files SKILL.md points to that don't exist
#   - prompts that break the 8-beat prompt contract
#   - missing deck files (template, styles, gallery picture) or duplicate style names
#   - a deck style that fails the 4.5:1 contrast check
#   - a built zip with the wrong layout, or one older than the skill files (only if dist/ has one)
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
SKILL_DIR="plugins/fundraise/skills/fundraise"
SELF="scripts/check.sh"

FAILS=0
WARNS=0
fail() { echo "FAIL  $*"; FAILS=$((FAILS + 1)); }
warn() { echo "WARN  $*"; WARNS=$((WARNS + 1)); }
ok()   { echo "ok    $*"; }

# Text files we scan: everything tracked-to-be, minus git internals, build output and this script
# (this script has to spell the patterns out).
GREP_EXCLUDES=(--exclude-dir=.git --exclude-dir=dist --exclude-dir=node_modules --exclude=check.sh)

scan() { # scan <label> <extended-regex> [grep flags...]
  local label="$1" re="$2"; shift 2
  local hits
  hits="$(grep -rInE "$@" "${GREP_EXCLUDES[@]}" -e "$re" . 2>/dev/null || true)"
  if [ -n "$hits" ]; then
    fail "$label:"; echo "$hits" | head -20 | sed 's/^/        /'
  else
    ok "no $label"
  fi
}

echo "== Secrets"
scan "OpenAI/Anthropic-style keys (sk-...)" '(^|[^A-Za-z0-9_-])sk-[A-Za-z0-9_-]{16,}'
scan "GitHub tokens (ghp_/gho_/ghs_/ghu_/github_pat_)" '(ghp|gho|ghs|ghu)_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}'
scan "AWS access keys (AKIA...)" 'AKIA[0-9A-Z]{16}'
scan "api_key mentions" 'api_key' -i
scan "API_KEY= assignments" 'API_KEY[[:space:]]*='
scan "private key blocks" '-----BEGIN [A-Z ]*PRIVATE KEY-----'
SECRET_FILES="$(find . \( -path ./.git -o -path ./node_modules \) -prune -o -type f \
  \( -name '.env' -o -name '.env.*' -o -name '*.pem' -o -name '*.key' -o -name 'id_rsa*' -o -name '*.p12' \) -print)"
if [ -n "$SECRET_FILES" ]; then fail "secret-looking files:"; echo "$SECRET_FILES" | sed 's/^/        /'; else ok "no .env or key files"; fi

echo "== Personal data"
EMAILS="$(grep -rIonE "${GREP_EXCLUDES[@]}" -e '[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}' . 2>/dev/null \
  | grep -viE '@[0-9]+x\.(png|jpe?g|webp|gif|svg)$' || true)"
if [ -n "$EMAILS" ]; then fail "email addresses:"; echo "$EMAILS" | head -20 | sed 's/^/        /'; else ok "no email addresses"; fi
scan "@gmail mentions" '@gmail' -i
scan "absolute local paths (/Users/..., /home/...)" '/Users/[A-Za-z0-9._-]+|/home/[a-z][a-z0-9._-]+/'

echo "== Brand"
OLD_BRAND="rel""ve"
scan "old engine brand name" "$OLD_BRAND" -i
# Pictures can carry text in their metadata too.
IMG_HITS="$(find . \( -path ./.git -o -path ./dist -o -path ./node_modules \) -prune -o -type f \
  \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' -o -name '*.pdf' \) -print0 \
  | xargs -0 -r grep -l -a -i -E "$OLD_BRAND|@gmail" 2>/dev/null || true)"
if [ -n "$IMG_HITS" ]; then fail "brand name or email inside image/PDF metadata:"; echo "$IMG_HITS" | sed 's/^/        /'; else ok "images clean"; fi

echo "== JSON, skill and prompts"
PYTMP="$(mktemp)"
python3 -I - "$ROOT" "$SKILL_DIR" > "$PYTMP" 2>&1 <<'PY'
import json, pathlib, re, sys
root = pathlib.Path(sys.argv[1]); skill = root / sys.argv[2]
fails = warns = 0
def fail(m):
    global fails; fails += 1; print("FAIL  " + m)
def warn(m):
    global warns; warns += 1; print("WARN  " + m)
def ok(m): print("ok    " + m)

# Every JSON file parses.
skip = {".git", "dist", "node_modules"}
jsons = [p for p in root.rglob("*.json") if not (set(p.relative_to(root).parts) & skip)]
bad = []
data = {}
for p in jsons:
    try: data[p] = json.loads(p.read_text(encoding="utf-8"))
    except Exception as e: bad.append(f"{p.relative_to(root)}: {e}")
if bad: fail("invalid JSON:\n        " + "\n        ".join(bad))
else: ok(f"{len(jsons)} JSON files parse")

# Marketplace and plugin names.
mp = data.get(root / ".claude-plugin/marketplace.json")
pj = data.get(root / "plugins/fundraise/.claude-plugin/plugin.json")
if not mp: fail("missing .claude-plugin/marketplace.json")
if not pj: fail("missing plugins/fundraise/.claude-plugin/plugin.json")
if mp and pj:
    names = [e.get("name") for e in mp.get("plugins", [])]
    if mp.get("name") != "fundraise-with-claude": fail("marketplace name must be fundraise-with-claude")
    elif "fundraise" not in names: fail("marketplace must list the plugin 'fundraise'")
    elif pj.get("name") != "fundraise": fail("plugin.json name must be fundraise")
    else: ok("marketplace fundraise-with-claude lists plugin fundraise")

# SKILL.md frontmatter.
sk = skill / "SKILL.md"
if not sk.exists():
    fail(f"missing {sk.relative_to(root)}")
    text = ""
else:
    text = sk.read_text(encoding="utf-8")
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        fail("SKILL.md has no frontmatter (--- ... --- at the top)")
    else:
        fm = dict(re.findall(r"^([a-z_-]+):\s*(.*)$", m.group(1), re.M))
        name, desc = fm.get("name", "").strip(), fm.get("description", "").strip()
        if name != skill.name: fail(f"SKILL.md name '{name}' must match its folder '{skill.name}'")
        elif not re.fullmatch(r"[a-z0-9-]{1,64}", name): fail("SKILL.md name must be lowercase letters, digits, hyphens, up to 64")
        elif not desc: fail("SKILL.md has no description")
        elif len(desc) > 1024: fail(f"SKILL.md description is {len(desc)} chars (max 1024)")
        elif "<" in desc or ">" in desc: fail("SKILL.md description must not contain < or >")
        else: ok(f"SKILL.md frontmatter (name: {name}, description {len(desc)} chars)")
    lines = text.count("\n") + 1
    if lines > 500: fail(f"SKILL.md is {lines} lines (keep under 500)")
    elif lines > 400: warn(f"SKILL.md is {lines} lines (aim for under 400)")
    else: ok(f"SKILL.md is {lines} lines")

# Files SKILL.md points to must exist.
alltext = text + "".join(p.read_text(encoding="utf-8") for p in [skill / "deck/HOW-TO-MAKE-A-DECK.md", *sorted((skill / "prompts").glob("*.md"))] if p.exists())
refs = sorted({r for r in re.findall(r"`((?:prompts|deck)/[A-Za-z0-9_./-]+)`", alltext) if "<" not in r})
missing = [r for r in refs if not (skill / r).exists()]
if missing: fail("the skill text points to files that don't exist yet: " + ", ".join(missing))
else: ok(f"all {len(refs)} files the skill text points to exist")

# Prompt contract (plan section 1).
P = skill / "prompts"
COMMON_RULES = ["Never click Send, Submit, Connect, Pay or Accept without my clear yes.",
                "CAPTCHA", "doesn't match", "Never invent numbers", "[CHECK]"]
WEB = ["Goal:", "which name and which", "Please log in, then type done.",
       "Never type a password and never create an account for me.",
       "Ask me to upload my pitch deck (PDF) here or paste its link.",
       "Show me the draft", "Report back"] + COMMON_RULES
need = {
    "linkedin-connect": WEB + ["under 300 characters", "Activity", "most recent post", "do not ask for money"],
    "linkedin-batch":   WEB + ["under 300 characters", "Activity", "most recent post", "do not ask for money", "one at a time"],
    "accelerator-apply": WEB + ["list every question on every page", "Ready to submit?"],
    "vc-pitch":         WEB + ["list every question on every page"],
    "follow-up":        WEB + ["most recent post"],
    "reply":            WEB + ["most recent post"],
    "book-call":        WEB,
    "investor-update":  WEB + ["BCC"],
    "deck":             ["Goal:", "Ask me to upload my pitch deck (PDF) here or paste its link.",
                         "Never invent numbers", "[CHECK]", "Show me the draft", "Report back", "HOW-TO-MAKE-A-DECK.md"],
    "find-investors":   ["Goal:", "Please log in, then type done.", "Never type a password and never create an account for me.",
                         "Ask me to upload my pitch deck (PDF) here or paste its link.", "Report back", "fundingcalendar.com"] + COMMON_RULES,
}
for kind, phrases in need.items():
    f = P / f"{kind}.md"
    if not f.exists(): fail(f"missing prompt prompts/{kind}.md"); continue
    t = f.read_text(encoding="utf-8")
    block = re.findall(r"```text\n(.*?)```", t, re.S)
    if not block: fail(f"prompts/{kind}.md has no ```text prompt block"); continue
    body = block[-1]
    miss = [p for p in phrases if p not in (body if kind != "find-investors" else t)]
    bad_tokens = [x for x in ("undefined", "{{", "[[", "}}") if x in body]
    if miss: fail(f"prompts/{kind}.md is missing: " + " | ".join(miss))
    elif bad_tokens: fail(f"prompts/{kind}.md contains " + ", ".join(bad_tokens))
    else: ok(f"prompts/{kind}.md follows the prompt contract ({len(body)} chars)")
    # The beats must be in order: who -> log in -> deck -> draft -> show -> report.
    order = [body.find(s) for s in ("which name and which", "Please log in", "pitch deck (PDF)", "Show me the draft", "Report back") if s in body]
    if order != sorted(order): fail(f"prompts/{kind}.md has the beats out of order")

# Deck folder (written in parallel; it must be complete before publishing).
deck = skill / "deck"
for rel in ["HOW-TO-MAKE-A-DECK.md", "deck-template.html", "previews/gallery.png"]:
    if (deck / rel).exists(): ok(f"deck/{rel} exists")
    else: fail(f"deck/{rel} is missing")
styles = sorted(p for p in (deck / "styles").glob("*.json") if p.name != "index.json") if (deck / "styles").is_dir() else []
index = data.get(deck / "styles" / "index.json")
if isinstance(index, dict):
    entries = index.get("styles", [])
    gone = [e.get("file") for e in entries if e.get("file") and not (deck / e["file"]).exists()]
    if gone: fail("styles/index.json points to missing files: " + ", ".join(gone))
    else: ok(f"styles/index.json lists {len(entries)} styles, all files present")
    nopic = [e.get("preview") for e in entries if e.get("preview") and not (deck / e["preview"]).exists()]
    if nopic: fail(f"{len(nopic)} preview pictures listed in styles/index.json are missing (first: {nopic[0]})")
if not styles: fail("deck/styles/ has no style files")
else:
    (ok if len(styles) == 20 else warn)(f"deck/styles has {len(styles)} styles (plan: 20)")
    for key in ("id", "name"):
        vals = [data.get(s, {}).get(key) for s in styles if isinstance(data.get(s), dict) and data.get(s, {}).get(key)]
        dups = sorted({v for v in vals if vals.count(v) > 1})
        if dups: fail(f"duplicate style {key}s: " + ", ".join(map(str, dups)))
        elif vals: ok(f"style {key}s are unique ({len(vals)})")
howto = deck / "HOW-TO-MAKE-A-DECK.md"
if howto.exists() and isinstance(index, dict):
    ht = howto.read_text(encoding="utf-8")
    unlisted = [e.get("name") for e in index.get("styles", []) if e.get("name") and f"**{e['name']}**" not in ht]
    if unlisted: fail("HOW-TO-MAKE-A-DECK.md does not list these styles: " + ", ".join(unlisted))
    else: ok("HOW-TO-MAKE-A-DECK.md lists every style")
# No leftover writing placeholders anywhere in the skill.
left = [str(p.relative_to(root)) for p in skill.rglob("*.md") if re.search(r"TEMPLATE_SECTION|\bTODO\b|\bTBD\b|lorem ipsum", p.read_text(encoding="utf-8"), re.I)]
if left: fail("unfinished text (TODO/TBD/placeholder) in: " + ", ".join(left))
else: ok("no TODO/TBD left in the skill text")
html = deck / "deck-template.html"
if html.exists():
    h = html.read_text(encoding="utf-8", errors="replace")
    ext = re.findall(r"<script[^>]+src=[\"']([^\"']+)", h)
    links = [u for u in re.findall(r"<link[^>]+href=[\"'](https?://[^\"']+)", h) if not re.match(r"https://fonts\.(googleapis|gstatic)\.com(/|$)", u)]
    if ext: fail("deck-template.html loads scripts from other sites: " + ", ".join(ext))
    elif links: fail("deck-template.html loads files from sites other than Google Fonts: " + ", ".join(links))
    else: ok("deck-template.html uses no outside scripts (Google Fonts only)")

print(f"__COUNTS__ {fails} {warns}")
PY
PYOUT="$(cat "$PYTMP")"; rm -f "$PYTMP"
echo "$PYOUT" | grep -v '^__COUNTS__ '
COUNTS="$(echo "$PYOUT" | grep '^__COUNTS__ ' | tail -1)"
if [ -z "$COUNTS" ]; then fail "the Python checks did not finish"; else
  set -- $COUNTS; FAILS=$((FAILS + $2)); WARNS=$((WARNS + $3)); fi

echo "== Claude Code validator"
if command -v claude >/dev/null 2>&1; then
  for target in . ./plugins/fundraise; do
    OUT="$(claude plugin validate "$target" 2>&1)"
    if echo "$OUT" | grep -q "Validation passed"; then ok "claude plugin validate $target"
    else fail "claude plugin validate $target:"; echo "$OUT" | tail -8 | sed 's/^/        /'; fi
  done
else
  warn "claude CLI not found; skipped 'claude plugin validate'"
fi

echo "== Deck colours"
if command -v node >/dev/null 2>&1; then
  if CONTRAST="$(node scripts/check-contrast.mjs 2>&1)"; then ok "every style passes the 4.5:1 contrast check"
  else fail "contrast check:"; echo "$CONTRAST" | tail -8 | sed 's/^/        /'; fi
else
  warn "node not found; skipped scripts/check-contrast.mjs"
fi

echo "== Zip"
ZIP="dist/fundraise-with-claude.zip"
if [ -f "$ZIP" ]; then
  LIST="$(unzip -Z1 "$ZIP" 2>/dev/null)"
  if ! echo "$LIST" | grep -qx 'fundraise/SKILL.md'; then fail "$ZIP has no fundraise/SKILL.md at the top"
  elif echo "$LIST" | grep -v '^fundraise/' | grep -q .; then fail "$ZIP has files outside fundraise/"
  else ok "$ZIP layout (fundraise/SKILL.md)"; fi
  NEWER="$(find "$SKILL_DIR" -type f -newer "$ZIP" ! -name '.DS_Store' | head -3)"
  if [ -n "$NEWER" ]; then fail "$ZIP is older than the skill files (run scripts/build-zip.sh again). Newer: $(echo "$NEWER" | tr '\n' ' ')"
  else ok "$ZIP is up to date with the skill files"; fi
else
  warn "no $ZIP yet (run scripts/build-zip.sh)"
fi

echo
if [ "$FAILS" -gt 0 ]; then echo "check: $FAILS failed, $WARNS warnings"; exit 1; fi
echo "check: all passed ($WARNS warnings)"
