#!/usr/bin/env bash
# giga-hooks installer — wires the hook bundle into a target repo.
#
# Usage:
#   ~/repositories/giga-hooks/install.sh              # symlink into $(pwd)
#   ~/repositories/giga-hooks/install.sh --copy       # copy instead of symlink
#   ~/repositories/giga-hooks/install.sh /path/to/repo
#   ~/repositories/giga-hooks/install.sh --copy /path/to/repo

set -euo pipefail

mode="symlink"
target=""
for arg in "$@"; do
    case "$arg" in
        --copy) mode="copy" ;;
        --symlink) mode="symlink" ;;
        -h|--help)
            grep '^#' "$0" | sed 's/^# \?//'
            exit 0
            ;;
        *) target="$arg" ;;
    esac
done

target="${target:-$(pwd)}"
target="$(cd "$target" && pwd)"   # absolutize

if [ ! -d "$target" ]; then
    echo "error: target directory does not exist: $target" >&2
    exit 1
fi

GIGA_HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
GIGA_HOOKS_DIR_HOOKS="${GIGA_HOOKS_DIR}/hooks"
TARGET_CLAUDE_DIR="${target}/.claude"
TARGET_LINK="${TARGET_CLAUDE_DIR}/giga-hooks"

mkdir -p "$TARGET_CLAUDE_DIR"

if [ -e "$TARGET_LINK" ] || [ -L "$TARGET_LINK" ]; then
    echo "warning: ${TARGET_LINK} already exists" >&2
    echo "Remove it first if you want to reinstall:" >&2
    echo "  rm -rf '${TARGET_LINK}'" >&2
    exit 1
fi

case "$mode" in
    symlink)
        ln -s "$GIGA_HOOKS_DIR_HOOKS" "$TARGET_LINK"
        echo "✓ Symlinked ${TARGET_LINK} → ${GIGA_HOOKS_DIR_HOOKS}"
        echo "  (Pulls in updates when you 'git pull' inside ${GIGA_HOOKS_DIR}.)"
        ;;
    copy)
        cp -r "$GIGA_HOOKS_DIR_HOOKS" "$TARGET_LINK"
        echo "✓ Copied ${GIGA_HOOKS_DIR_HOOKS} → ${TARGET_LINK}"
        echo "  (Independent file state; will NOT pick up giga-hooks updates.)"
        ;;
esac

cat <<'EOF'

Next: wire the hooks into your repo's .claude/settings.json. If you don't
have one yet, this template gets you all 5 hooks:

------ settings.json template ------
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PROJECT_DIR}/.claude/giga-hooks/run-hook.cmd\" project-context",
            "async": false
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PROJECT_DIR}/.claude/giga-hooks/run-hook.cmd\" block-destructive-bash",
            "async": false
          },
          {
            "type": "command",
            "command": "\"${CLAUDE_PROJECT_DIR}/.claude/giga-hooks/run-hook.cmd\" stage-godot-uid-sidecars",
            "async": false
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PROJECT_DIR}/.claude/giga-hooks/run-hook.cmd\" gdformat-on-edit",
            "async": false
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PROJECT_DIR}/.claude/giga-hooks/run-hook.cmd\" notify-done",
            "async": true
          }
        ]
      }
    ]
  }
}
------------------------------------

For a non-Godot project, drop the `stage-godot-uid-sidecars` and
`gdformat-on-edit` entries.

Prerequisites (each hook silent-no-ops if its tool is missing):
  - jq                (apt install jq)
  - notify-send       (apt install libnotify-bin)
  - xdotool           (apt install xdotool)         [X11 focus detection]
  - gdformat          (uv tool install gdtoolkit)   [Godot projects only]

EOF
