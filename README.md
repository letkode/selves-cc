# selves

**Manage your selves in Claude Code.**
Folder-aware profiles: the right account in every project, side by side.

```bash
cd ~/work/api   && claude     # opens with your work account
cd ~/side/blog  && claude     # opens with your personal account
```

- **Folder-aware.** A `.selves` file in a project decides which account `claude` uses there, like `.nvmrc` or `.python-version`.
- **Side by side.** selves only sets `CLAUDE_CONFIG_DIR` for the process it launches. It never moves or replaces `~/.claude`, so several accounts can run at the same time.
- **Shared layer.** `CLAUDE.md`, skills, rules, agents and commands can be shared from `~/.claude`; each profile keeps its own login, history, settings, plugins and MCP servers.
- **Self-healing.** `selves doctor` finds known conflicts; `selves repair` restores a corrupted `.claude.json` from Claude Code's own backups.

> This is **selves-lite**, the single-file bash edition (Linux, macOS). The full edition (Go, also Windows) is in development and will share the same test suite.
> selves is independent and not affiliated with Anthropic. It never reads or sends credentials. Each account remains subject to its own terms.

## Install

```bash
mkdir -p ~/.local/bin
curl -fsSL -o ~/.local/bin/selves          https://github.com/letkode/selves-cc/releases/download/<versión>/selves            # pin a version
curl -fsSL -o ~/.local/bin/selves-dotfiles https://github.com/letkode/selves-cc/releases/download/<versión>/selves-dotfiles   # optional: backups
chmod +x ~/.local/bin/selves ~/.local/bin/selves-dotfiles                  # check SHA-256 sums
```

Requires bash ≥ 3.2 and Claude Code. `python3` is optional (used to validate `.claude.json`).

## Five-minute setup

```bash
selves create work            # new profile at ~/.claude-work
selves run work               # log in once, then /exit
selves default personal       # optional: profile for folders without a binding
cd ~/work && selves bind work # this folder and everything below uses "work"
```

Add to `~/.bashrc` (or `~/.zshrc`, with `zsh`):

```bash
eval "$(selves init bash)"
```

This defines `claude` (picks the profile for the current folder) and `claude-<name>` for each profile. selves never edits your startup files.

## The base profile

`base` is `~/.claude`, Claude Code's default directory. Use it in one of two ways:

- **As one of your accounts.** Keep your current account there and create a profile only for the other. IDE extensions always use `~/.claude`.
- **Without a login.** Every account gets its own profile, and `~/.claude` only holds what is shared.

Either way, `~/.claude` is the source of the shared layer. Do not delete it.

## Commands

| Command | Description |
|---|---|
| `selves` | Which profile applies here, and all profiles |
| `selves <name> [args]` / `run <name> [-- args]` | Launch Claude Code with a profile |
| `auto [-- args]` | Launch the profile for this folder (or the default) |
| `create <name> [--bare]` · `adopt <name>` | New profile · turn an existing `~/.claude-<name>` into one |
| `list` · `delete <name> [--yes]` · `default [name]` | Manage profiles |
| `bind <name>` · `unbind` · `which` | Folder bindings |
| `relink` · `unshare <profile> <item>` | Shared layer |
| `doctor` · `repair <profile>` | Health checks and `.claude.json` recovery |
| `init <bash\|zsh>` | Shell integration |
| `migrate [--yes]` | Convert a `claude-switch` setup |
| `dotfiles export\|install\|backup-history\|restore-history` | Back up and rebuild (companion script) |

Override the shared items with `SELVES_SHARED="CLAUDE.md rules"`.

## Backup and new machines

`selves dotfiles` (companion script `selves-dotfiles`, installed next to `selves`) saves your setup to a git repository and rebuilds it elsewhere:

```bash
selves dotfiles export                  # → ~/selves-dotfiles
cd ~/selves-dotfiles && git init && git add -A && git commit -m "selves setup"
```

It exports both scripts, the shared layer, and for each profile its settings, own items, MCP servers and plugin marketplaces, plus the default profile and folder bindings. **Credentials, `.claude.json` and history are never exported.** Use a **private** repository: the export warns about literal secrets and about profile-owned content that may belong to your organization.

On the new machine, install Claude Code and clone your projects, then:

```bash
git clone <your-private-repo> ~/selves-dotfiles
bash ~/selves-dotfiles/bin/selves-dotfiles install     # --no-init to leave ~/.bashrc alone
```

It finishes by listing what is left to do by hand: logging in to each profile and reinstalling plugins with `/plugin`.

History is backed up separately, never in git:

```bash
selves dotfiles backup-history           # ~/selves-history-YYYY-MM-DD.tgz, mode 0600
selves dotfiles restore-history <file>
```

## Coming from claude-switch

```bash
selves doctor           # lists what will change
selves migrate          # markers, folder bindings, default profile, ~/.bashrc block
```

Then add `eval "$(selves init bash)"` to `~/.bashrc`. Profiles, history and logins are untouched.

## Limitations

- **Outside your shell.** The `claude` wrapper only exists in interactive shells. Scripts, cron jobs and some IDE extensions run the real `claude` binary, so they use `base`. See [Using selves outside your shell](#using-selves-outside-your-shell-scripts-cron-some-ides) below.
- **Same profile in parallel.** Two sessions of the **same** profile share its `.claude.json`. selves warns about it and repairs corruption, but separate profiles are the safer way to work in parallel.
- **macOS logins.** Logins live in the Keychain, so `list` shows "keychain" instead of verifying them.

### Using selves outside your shell (scripts, cron, some IDEs)

To make every `claude` call go through selves, put a small shim earlier in `PATH` than the real binary. Create it **before** adding `~/bin` to `PATH`, so `command -v claude` still finds the real binary:

```bash
mkdir -p ~/bin
cat > ~/bin/claude <<EOF
#!/usr/bin/env bash
export SELVES_CLAUDE_BIN="$(command -v claude)"   # the real claude
exec "$(command -v selves)" auto -- "\$@"
EOF
chmod +x ~/bin/claude
```

Then put `~/bin` first in `PATH` (for example, `export PATH="$HOME/bin:$PATH"` in `~/.bashrc`) and check with `command -v claude`, which should print `~/bin/claude`.

`SELVES_CLAUDE_BIN` points to the real binary, so the shim never calls itself. IDE extensions that bundle their own Claude Code binary are not affected.

## Development

```bash
shellcheck -S warning bin/selves bin/selves-dotfiles
SELVES_BIN="$PWD/bin/selves" bats --filter-tags core tests/
```

## License

MIT
