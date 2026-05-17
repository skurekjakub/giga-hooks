#!/usr/bin/env bash
# giga-hooks installer — copies the hook bundle into a target repo as a
# customizable template. Default is COPY (each repo owns its files; tweak
# freely per stack). For an advanced share-everything mode use --symlink.
#
# Usage:
#   ~/repositories/giga-hooks/install.sh              # copy into $(pwd)/.claude/giga-hooks/
#   ~/repositories/giga-hooks/install.sh /path/to/repo
#   ~/repositories/giga-hooks/install.sh --symlink    # share via symlink (rolling updates)
#   ~/repositories/giga-hooks/install.sh -h           # this help

set -euo pipefail

mode="copy"
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
    echo "  (cleanup command for whichever form it is)" >&2
    exit 1
fi

case "$mode" in
    copy)
        cp -r "$GIGA_HOOKS_DIR_HOOKS" "$TARGET_LINK"
        echo "✓ Copied ${GIGA_HOOKS_DIR_HOOKS} → ${TARGET_LINK}"
        echo "  Independent file state — tweak freely per stack."
        echo "  (Will NOT pick up upstream giga-hooks updates. Re-install or"
        echo "  cherry-pick manually if you want them.)"
        ;;
    symlink)
        ln -s "$GIGA_HOOKS_DIR_HOOKS" "$TARGET_LINK"
        echo "✓ Symlinked ${TARGET_LINK} → ${GIGA_HOOKS_DIR_HOOKS}"
        echo "  Rolling updates from upstream giga-hooks. Edits affect every"
        echo "  repo using the symlink — usually not what you want."
        ;;
esac

cat <<'EOF'

Next: customize for your stack.

1. Open ${TARGET_LINK}/ — delete or edit any hook script that doesn't apply.
   - Not a Godot project? rm stage-godot-uid-sidecars gdformat-on-edit
   - Wayland-only and don't want unconditional notifications? rm notify-done
   - Need a stack-specific hook (eslint-on-edit, pytest-on-edit, etc.)?
     Drop a new script in there following the existing pattern.

2. Wire your customized set into .claude/settings.json. If you don't have
   one yet, this template gets you the default 5 hooks (drop the entries
   for hooks you removed):

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
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PROJECT_DIR}/.claude/giga-hooks/run-hook.cmd\" remind-rules",
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

Prerequisites (each hook silent-no-ops if its tool is missing):
  - jq                (apt install jq)
  - notify-send       (apt install libnotify-bin)
  - xdotool           (apt install xdotool)         [X11 focus detection]
  - gdformat          (uv tool install gdtoolkit)   [Godot projects only]

EOF
