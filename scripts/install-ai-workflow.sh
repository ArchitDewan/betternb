#!/usr/bin/env bash

set -euo pipefail

setup_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
codex_dir=${CODEX_HOME:-"${HOME}/.codex"}

command -v herdr >/dev/null
command -v npx >/dev/null

mkdir -p "${codex_dir}"
install -m 0644 "${setup_root}/config/codex/AGENTS.md" "${codex_dir}/AGENTS.md"

DISABLE_TELEMETRY=1 npx -y skills add "${setup_root}/skills/reviewable-delivery" \
  --skill reviewable-delivery \
  --global \
  --agent codex \
  --agent claude-code \
  --agent opencode \
  --copy \
  --yes

DISABLE_TELEMETRY=1 npx -y skills add herdrdev/herdr \
  --skill herdr \
  --global \
  --agent codex \
  --agent claude-code \
  --agent opencode \
  --copy \
  --yes

herdr integration install codex
herdr integration install claude
herdr integration install opencode

printf '%s\n' 'Installed the reviewable-delivery and Herdr skills for Codex, Claude Code, and OpenCode.'
printf '%s\n' 'Installed Herdr integrations for Codex, Claude Code, and OpenCode.'
printf '%s\n' 'Start a fresh agent session inside Herdr to load the new skills.'
