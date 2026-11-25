# agent-skills

Shared skill repository bundling [pstack](https://github.com/michael-denyer/pstack-claude) and [mattpocock/skills](https://github.com/mattpocock/skills) for both Antigravity and Codex.

## Layout

- `.agents/skills/<name>/SKILL.md`: flat one-level skill directories scanned natively by both Antigravity and Codex.
- `.agents/agents/*.md`: custom subagent definitions from `pstack` (scanned by Antigravity, ignored by Codex).
- `SOURCES.json`: upstream commit hashes and skill counts from the last sync.

### Name overlaps

Both upstream packs define `tdd` and `teach`. To keep both available without overwriting each other in `.agents/skills/`:

- `tdd` and `teach` come from `mattpocock/skills`.
- `pstack-tdd` and `pstack-teach` come from `pstack`.

## Cloud use (Antigravity Remote Agents and Codex Cloud)

1. Create a private GitHub repository named `agent-skills` under your GitHub account.
2. Push this repo to GitHub:
   ```powershell
   git remote add origin https://github.com/<your-username>/agent-skills.git
   git push -u origin main
   ```
3. In Antigravity Remote Projects, attach `agent-skills` alongside your target code repository under **Project Settings > Resources > GitHub**.

## Keeping skills up to date

### Cloud repository (automatic)

`.github/workflows/sync.yml` runs every Monday at 09:00 UTC (and manually from the **Actions** tab via **Run workflow**). It pulls both upstream repositories, rebuilds `.agents/`, and commits any changes.

### Local Windows PC (Antigravity and Codex)

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\update-local.ps1
```

This upgrades both Codex Git marketplaces, refreshes Codex's plugins, and syncs the latest `pstack` (with Windows `hooks.json`) and `mattpocock-skills` into `~/.gemini/config/plugins/`.
