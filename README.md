# giga-hooks

Customizable [Claude Code](https://claude.com/claude-code) hook **template**. Pull into any repo, then tweak the copied hooks for your specific stack. The bundle is a starting point — not a runtime dependency.

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
1. **Copies** `hooks/` into `<repo>/.claude/giga-hooks/` (the target owns its files now — tweak freely, no upstream concerns).
2. Prints the `settings.json` template; you copy-paste into your repo's `.claude/settings.json` (installer does NOT modify an existing one — too risky).
3. Reminds you about prerequisites per active hook (`jq`, `notify-send`, `xdotool`, `gdformat`).

For an advanced "share files via symlink" mode (rolling updates from upstream, but every consuming repo sees the same edits):

```bash
~/repositories/giga-hooks/install.sh --symlink
```

Default is copy. Symlink is rarely what you want — different projects have different stacks.

## Per-repo customization

You have TWO customization surfaces after install:

**1. The copied hook scripts** at `<repo>/.claude/giga-hooks/`. These are yours now — edit, delete, or extend them in place:

- **Not a Godot project?** `rm .claude/giga-hooks/{stage-godot-uid-sidecars,gdformat-on-edit}`.
- **Different formatter?** Replace `gdformat-on-edit` with `ruff-on-edit` / `prettier-on-edit` / `gofmt-on-edit`. Same pattern: extract file path from JSON input, check extension, run the formatter, never block on failure.
- **Different framework's sidecar pattern?** Adapt `stage-godot-uid-sidecars` — same shape, different glob.
- **Need a new hook?** Drop another script in `.claude/giga-hooks/` and wire it in `settings.json`. Or PR it upstream if it's generic.

**2. `.claude/settings.json`** decides which hooks fire when:

- **Bash-heavy project:** keep `block-destructive-bash` for sure.
- **No GitHub remote yet:** the destructive blocker still applies (covers force-push, hard-reset, rebase -i, amend, --no-verify).
- **Wayland-only desktop:** `notify-done` will always notify (no X11 focus check); drop the Stop entry if it's too noisy.
- **CI / headless:** drop `notify-done` and the `Stop` block entirely.

Per-stack stuff like `ruff-on-edit`, `pytest-on-save`, `tsc-on-edit` etc. belongs in your repo's copy, not upstream. Send a PR only if it's broadly useful across many projects.

## Prerequisites

| Tool | Required by | Install |
|---|---|---|
| `bash` 4+ | all hooks | (already on Linux/macOS) |
| `jq` | `block-destructive-bash`, `stage-godot-uid-sidecars`, `gdformat-on-edit` | `apt install jq` / `brew install jq` |
| `xdotool` | `notify-done` (X11 only — gets the active window ID) | `apt install xdotool` |
| `xprop` | `notify-done` (X11 only — reads `WM_CLASS` off the active window) | `apt install x11-utils` |
| `notify-send` | `notify-done` | `apt install libnotify-bin` |
| `gdformat` | `gdformat-on-edit` | `uv tool install gdtoolkit` |

Each hook checks for its dependencies and silent-no-ops if missing — installing the prerequisites is opt-in, never required for the hook to be wired.

## Adding a new hook

**To this template (upstream):**

1. Drop the bash script in `hooks/` (extensionless, executable, `#!/usr/bin/env bash`).
2. Follow the `run-hook.cmd` invocation convention so it works under Windows too:
   ```json
   "command": "\"${CLAUDE_PROJECT_DIR}/.claude/giga-hooks/run-hook.cmd\" <hook-name>"
   ```
3. Add a row to the README table above.
4. PR if it's generic; otherwise keep it in your own repo's copy.

**To one specific repo only:** drop the script directly in that repo's `.claude/giga-hooks/` (or a sibling per-repo hooks dir) and wire it in that repo's `settings.json`. No need to touch upstream.

## Known limitations

- `block-destructive-bash` matches on the literal command string — commit messages or `echo` statements containing the dangerous pattern as text will trigger false positives. Paraphrase.
- `notify-done` X11-only for focus detection; on Wayland it always notifies.
- `gdformat-on-edit` runs synchronously (~50-100ms per .gd edit). Acceptable for typical flows; if your project edits hundreds of .gd files per turn, async or skip.
- `stage-godot-uid-sidecars` only handles newly-added `.gd` files (the `--diff-filter=A` case). Modified `.gd` files don't change their `.uid`, so no auto-stage needed.

## License

MIT.
