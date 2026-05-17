# giga-hooks

Plug-and-play [Claude Code](https://claude.com/claude-code) hook bundle. Drop into any repo, wire up the canonical safety + quality-of-life hooks in one symlink, customize per stack.

## What's in the box

| Hook script | Event | Cadence | What it does |
|---|---|---|---|
| `project-context` | SessionStart | startup + compact | Injects `AGENTS.md` + the project's `MEMORY.md` index + current branch. Prevents post-compaction rule amnesia. |
| `block-destructive-bash` | PreToolUse:Bash | every Bash | Hard-blocks `rm -rf /`, `git push --force`, `git reset --hard origin/`, interactive rebase, commit amend, `--no-verify`, `--no-gpg-sign`. Exit code 2 → harness denies, cannot be bypassed. |
| `notify-done` | Stop | every turn end | Desktop notification iff the active window is NOT a terminal. xdotool-based; silent on Wayland-only setups (falls through to always-notify). |
| `stage-godot-uid-sidecars` | PreToolUse:Bash | every Bash | Godot-specific. On `git commit`, auto-stages matching `*.gd.uid` sidecars for newly-added `.gd` files. |
| `gdformat-on-edit` | PostToolUse:Write\|Edit | every edit | Godot-specific. Runs [`gdformat`](https://github.com/Scony/godot-gdscript-toolkit) on the edited file if it ends in `.gd`. Silent no-op if gdformat missing or file isn't `.gd`. |

The first three are stack-agnostic. The last two are Godot-specific and opt-in via your repo's `settings.json`.

## Install into a repo

```bash
# From the target repo's root:
~/repositories/giga-hooks/install.sh
```

The installer:
1. Creates `<repo>/.claude/giga-hooks` as a **symlink** to `~/repositories/giga-hooks/hooks` (so this repo gets rolling updates when you `git pull` giga-hooks).
2. Prints the `settings.json` template to wire the hooks; you copy-paste into your repo's `.claude/settings.json` (the installer does NOT modify an existing settings.json — too risky).
3. Reminds you about prerequisites per active hook (`jq`, `notify-send`, `xdotool`, `gdformat`).

For `--copy` mode (independent file state per repo, no rolling updates):

```bash
~/repositories/giga-hooks/install.sh --copy
```

## Per-repo customization

The installed `.claude/settings.json` is the customization surface. Add or remove hook entries to match your stack:

- **Bash-heavy project:** keep `block-destructive-bash`.
- **No GitHub remote yet:** the destructive-bash blocker still applies (it blocks force-push, hard-reset, etc.).
- **Not Godot:** drop the `stage-godot-uid-sidecars` and `gdformat-on-edit` entries from `PreToolUse:Bash` and `PostToolUse:Write|Edit` respectively.
- **Wayland-only:** `notify-done` will always notify; if too noisy, drop the entry.
- **CI / headless:** drop `notify-done` and `Stop` entry entirely.

For stack-specific hooks of your own, drop them in `<repo>/.claude/hooks/` (the per-repo hooks dir, parallel to the symlinked `giga-hooks/`) and reference them in settings.json. Per-repo agents can also extend the giga-hooks scripts in place, but those changes affect every other repo using the symlink — prefer per-repo additions over giga-hooks edits unless the change is genuinely generic.

## Prerequisites

| Tool | Required by | Install |
|---|---|---|
| `bash` 4+ | all hooks | (already on Linux/macOS) |
| `jq` | `block-destructive-bash`, `stage-godot-uid-sidecars`, `gdformat-on-edit` | `apt install jq` / `brew install jq` |
| `xdotool` | `notify-done` (X11 only) | `apt install xdotool` |
| `notify-send` | `notify-done` | `apt install libnotify-bin` |
| `gdformat` | `gdformat-on-edit` | `uv tool install gdtoolkit` |

Each hook checks for its dependencies and silent-no-ops if missing — installing the prerequisites is opt-in, never required for the hook to be wired.

## Adding a new hook

1. Drop the bash script in `hooks/` (extensionless, executable, `#!/usr/bin/env bash`).
2. Follow the `run-hook.cmd` invocation convention so it works under Windows too:
   ```json
   "command": "\"${CLAUDE_PROJECT_DIR}/.claude/giga-hooks/run-hook.cmd\" <hook-name>"
   ```
3. Add a row to the README table above.
4. Commit + push. Other repos using the symlink pick up the change immediately.

## Known limitations

- `block-destructive-bash` matches on the literal command string — commit messages or `echo` statements containing the dangerous pattern as text will trigger false positives. Paraphrase.
- `notify-done` X11-only for focus detection; on Wayland it always notifies.
- `gdformat-on-edit` runs synchronously (~50-100ms per .gd edit). Acceptable for typical flows; if your project edits hundreds of .gd files per turn, async or skip.
- `stage-godot-uid-sidecars` only handles newly-added `.gd` files (the `--diff-filter=A` case). Modified `.gd` files don't change their `.uid`, so no auto-stage needed.

## License

MIT.
