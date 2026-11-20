# Submitting TokenMeter to the official zcode-plugins marketplace

Step-by-step. Everything needed is in this `submission/` folder.

## 0. Prerequisites

- `gh` CLI logged in (done: account Hasan5858)
- A **screenshot of the widget** (you are preparing it) — save it as
  `submission/screenshot.png` before running step 4's push, or attach it in the PR UI afterwards.

## 1. Fork + clone the official repo

```bash
gh repo fork zai-org/zcode-plugins --clone
cd zcode-plugins
git checkout -b feat/zcode-token-meter-mac
```

## 2. Copy the plugin in

```bash
SUB="<path-to-this-submission-folder>"
mkdir -p external_plugins
cp -R "$SUB/external_plugins/zcode-token-meter-mac" external_plugins/
```

## 3. Register in the root marketplace.json

Open `marketplace.json` at the repo root, and paste the object from
`submission/marketplace-entry.json` into the `"plugins": [ ... ]` array
(keep JSON valid — add a comma after the previous entry).

## 4. Validate (their scripts)

```bash
python3 scripts/validate.py
python3 scripts/build_dist.py
git diff --check
```

Fix anything they flag; usually nothing for us since the layout matches
`external_plugins/anet` (their community reference plugin).

## 5. Commit + push + PR

```bash
git add external_plugins/zcode-token-meter-mac marketplace.json
git commit -m "feat(zcode-token-meter-mac): add macOS floating token/cache widget"
git push -u origin feat/zcode-token-meter-mac
gh pr create \
  --repo zai-org/zcode-plugins \
  --title "feat(zcode-token-meter-mac): add macOS floating token/cache widget" \
  --body-file "$SUB/PR_DESCRIPTION.md"
```

In the PR UI: select plugin type **Standard plugin**, attach the widget
screenshot, then request review.

## After submission

- Review is manual — no timeline promised. Watch the PR for their questions.
- **Keep versions in sync**: any future content change bumps the version in
  THREE places: your repo's `plugin.json` + `marketplace.json`, and the same
  version in the zcode-plugins `external_plugins` copy + root `marketplace.json`.
- Until approved, users keep installing from your repo
  (`Hasan5858/zcode-token-meter-mac`) — unaffected by the review.
