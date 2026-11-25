#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PSTACK_REPO="https://github.com/michael-denyer/pstack-claude.git"
MATTPOCOCK_REPO="https://github.com/mattpocock/skills.git"

git clone --depth 1 "$PSTACK_REPO" "$TMP_DIR/pstack-claude"
git clone --depth 1 "$MATTPOCOCK_REPO" "$TMP_DIR/mattpocock-skills"

PSTACK_SHA="$(git -C "$TMP_DIR/pstack-claude" rev-parse --short HEAD)"
MATTPOCOCK_SHA="$(git -C "$TMP_DIR/mattpocock-skills" rev-parse --short HEAD)"

rm -rf "$REPO_ROOT/.agents/skills" "$REPO_ROOT/.agents/agents"
mkdir -p "$REPO_ROOT/.agents/skills" "$REPO_ROOT/.agents/agents"

# Copy Matt Pocock skills (flattened one level deep for Antigravity and Codex discovery)
mp_count=0
while IFS= read -r -d '' skill_md; do
  skill_dir="$(dirname "$skill_md")"
  name="$(basename "$skill_dir")"
  cp -R "$skill_dir" "$REPO_ROOT/.agents/skills/$name"
  mp_count=$((mp_count + 1))
done < <(find "$TMP_DIR/mattpocock-skills/skills" -name "SKILL.md" -print0 | sort -z)

# Copy pstack skills; prefix colliding names (tdd, teach) with pstack-
ps_count=0
for skill_dir in "$TMP_DIR/pstack-claude/plugins/pstack/skills"/*/; do
  [ -f "$skill_dir/SKILL.md" ] || continue
  name="$(basename "$skill_dir")"
  target_name="$name"
  if [ -d "$REPO_ROOT/.agents/skills/$name" ]; then
    target_name="pstack-$name"
  fi
  cp -R "${skill_dir%/}" "$REPO_ROOT/.agents/skills/$target_name"
  if [ "$target_name" != "$name" ]; then
    sed -i.bak -E "0,/^name:[[:space:]]*.*$/s//name: $target_name/" "$REPO_ROOT/.agents/skills/$target_name/SKILL.md"
    rm -f "$REPO_ROOT/.agents/skills/$target_name/SKILL.md.bak"
  fi
  ps_count=$((ps_count + 1))
done

# Copy pstack custom subagent definitions (discovered by Antigravity from .agents/agents/)
agent_count=0
for agent_md in "$TMP_DIR/pstack-claude/plugins/pstack/agents"/*.md; do
  [ -f "$agent_md" ] || continue
  cp "$agent_md" "$REPO_ROOT/.agents/agents/"
  agent_count=$((agent_count + 1))
done

cat > "$REPO_ROOT/SOURCES.json" <<EOF
{
  "updatedAt": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "pstack": {
    "repo": "$PSTACK_REPO",
    "commit": "$PSTACK_SHA",
    "skills": $ps_count,
    "agents": $agent_count
  },
  "mattpocock": {
    "repo": "$MATTPOCOCK_REPO",
    "commit": "$MATTPOCOCK_SHA",
    "skills": $mp_count
  },
  "totalSkills": $((mp_count + ps_count))
}
EOF

echo "Synced $((mp_count + ps_count)) skills ($ps_count pstack @ $PSTACK_SHA, $mp_count mattpocock @ $MATTPOCOCK_SHA) and $agent_count agents."
