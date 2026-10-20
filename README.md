# selves

[![CI](https://github.com/letkode/selves-cc/actions/workflows/ci.yml/badge.svg)](https://github.com/letkode/selves-cc/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/letkode/selves-cc?sort=semver)](https://github.com/letkode/selves-cc/releases/latest)
[![License: MIT](https://img.shields.io/github/license/letkode/selves-cc)](LICENSE)

**Manage your selves in Claude Code.**
Folder-aware profiles: the right account in every project, side by side.

```bash
cd ~/work/api   && claude     # opens with your work account
cd ~/side/blog  && claude     # opens with your personal account
```

- **Folder-aware.** A `.selves` file in a project decides which account `claude` uses there, like `.nvmrc` or `.python-version`.
- **Side by side.** selves only sets `CLAUDE_CONFIG_DIR` for the process it launches. It never moves or replaces `~/.claude`, so several accounts can run at the same time.
- **Shared layer.** `CLAUDE.md`, skills, rules, agents and commands can be shared from `~/.claude`, as a whole or skill by skill. Each profile keeps its own login, history, settings, plugins and MCP servers.
- **Self-healing.** `selves doctor` finds known conflicts; `selves repair` fixes a corrupted `.claude.json` and cross-profile plugin paths.
- **Reproducible.** `selves dotfiles` saves your setup to a git repository and rebuilds it on a new machine.

> This is **selves-lite**, the single-file bash edition for Linux and macOS. A full edition (Go, also Windows) is in development and will share the same test suite.
> selves is independent and not affiliated with Anthropic. It never reads or sends credentials. Each account remains subject to its own terms.

## Install

```bash
mkdir -p ~/.local/bin
curl -fsSL -o ~/.local/bin/selves          https://github.com/letkode/selves-cc/releases/latest/download/selves
curl -fsSL -o ~/.local/bin/selves-dotfiles https://github.com/letkode/selves-cc/releases/latest/download/selves-dotfiles
chmod +x ~/.local/bin/selves ~/.local/bin/selves-dotfiles
selves version
```

To pin a version, replace `latest/download` with `download/<version>` (for example `download/1.3.0`) and check the files against that release's `SHA256SUMS`. `selves-dotfiles` is optional; you only need it for backups.

Requires bash ≥ 3.2 and Claude Code. `python3` is optional (used to validate `.claude.json` and export MCP servers).

## Five-minute setup

```bash
selves create work            # new profile at ~/.claude-work
selves run work               # log in once, then /exit
selves default personal       # optional: profile for folders without a binding
cd ~/work && selves bind work # this folder and everything below uses "work"
```

Add this line to `~/.bashrc` (or `~/.zshrc`, with `zsh`):

```bash
[ -x "$HOME/.local/bin/selves" ] && eval "$("$HOME/.local/bin/selves" init bash)"
```

It defines `claude` (picks the profile for the current folder) and `claude-<name>` for each profile. selves never edits your startup files.

> Use the absolute path as shown. On Ubuntu and Debian, `~/.profile` loads `~/.bashrc` before adding `~/.local/bin` to `PATH`, so over SSH a bare `selves init` is not found. `selves doctor` warns about it (`RC_INIT_PATH`).

Check everything with:

```bash
selves          # which profile applies here, and why
selves doctor   # known conflicts, with the fix for each
```

## The base profile

`base` is `~/.claude`, Claude Code's default directory. Use it in one of two ways:

- **As one of your accounts.** Keep your current account there and create a profile only for the other. IDE extensions always use `~/.claude`.
- **Without a login.** Every account gets its own profile, and `~/.claude` only holds what is shared.

Either way, `~/.claude` is the source of the shared layer. Do not delete it.

## What is shared and what is not

| Shared from `~/.claude` (by default) | Always per profile |
|---|---|
| `CLAUDE.md`, `skills`, `rules`, `agents`, `commands` | Login, history and conversations |
| | `settings.json`, plugins, MCP servers, `.claude.json` |
| | `skills/synced` (skills Claude Code syncs from each account) |

Change the shared items with `SELVES_SHARED="CLAUDE.md rules"`. To give a profile its own copy of something it shares today, run `selves unshare <profile> <item>`.

### Sharing per entry

By default each shared item (for example `skills/`) is one link to `~/.claude/skills`. To give a profile skills of its own while still sharing the common ones, switch it to per-entry mode:

```bash
selves entries work skills          # own folder, one link per shared skill
selves claim work 'skills/acme-*'   # move matching skills from base to "work" only
```

The result:

```
~/.claude/skills/          shared: every profile sees these
├── git-commit
└── php-pro

~/.claude-work/skills/     work only
├── git-commit  → ~/.claude/skills/git-commit
├── php-pro     → ~/.claude/skills/php-pro
├── acme-deploy            (work's own)
└── synced/                (work account's synced skills)
```

Shared skills stay in sync automatically: new ones in `~/.claude/skills` show up the next time you open Claude Code with that profile, and removed ones disappear. Anything you put directly in `~/.claude-work/skills/` stays private to that profile. Use `SELVES_ENTRIES="skills"` to create new profiles this way.

`skills/synced` is never shared: Claude Code syncs each account's skills there, so selves keeps one per profile. `selves doctor` warns if it is still shared (`SHARED_SYNCED`).

## Commands

| Command | Description |
|---|---|
| `selves` | Which profile applies here, and all profiles |
| `selves <name> [args]` · `run <name> [-- args]` | Launch Claude Code with a profile |
| `auto [-- args]` | Launch the profile for this folder (or the default) |
| `create <name> [--bare]` · `adopt <name>` | New profile · turn an existing `~/.claude-<name>` into one |
| `list` · `delete <name> [--yes]` · `default [name]` | Manage profiles |
| `bind <name>` · `unbind` · `which` | Folder bindings |
| `relink` · `unshare <profile> <item>` | Shared layer |
| `entries <profile> <item>` · `claim <profile> <item>/<pattern>` | Per-entry sharing |
| `doctor` · `repair <profile>` | Health checks and repairs |
| `init <bash\|zsh>` | Shell integration |
| `migrate [--yes]` | Convert a `claude-switch` setup |
| `dotfiles export\|install\|backup-history\|restore-history` | Backup and new machines |
| `shim install\|remove\|status` | Optional: route every `claude` call through selves |

## Backup and new machines

`selves dotfiles` (companion script `selves-dotfiles`, installed next to `selves`) saves your setup to a git repository and rebuilds it elsewhere:

```bash
selves dotfiles export                  # → ~/selves-dotfiles
cd ~/selves-dotfiles && git init && git add -A && git commit -m "selves setup"
```

It exports both scripts, the shared layer, and for each profile its settings, own skills, MCP servers and plugin marketplaces, plus the default profile and folder bindings.

**Never exported:** credentials, `.claude.json`, history, and `skills/synced` (Claude Code syncs it again).

Use a **private** repository. The export warns about literal secrets and about profile-owned files that may belong to your organization.

If your projects live outside your home folder, tell the export where to look for folder bindings:

```bash
export SELVES_DOTFILES_ROOTS="$HOME /data/projects"   # in ~/.bashrc
```

On the new machine, install Claude Code and clone your projects, then:

```bash
git clone <your-private-repo> ~/selves-dotfiles
bash ~/selves-dotfiles/bin/selves-dotfiles install     # --no-init to leave ~/.bashrc alone
```

It finishes by listing what is left to do by hand: logging in to each profile and reinstalling plugins with `/plugin`.

Skills that a skill installer placed in `~/.claude/skills` as links (for example to `~/.agents/skills`) are backed up by content. After a restore they become regular folders; reinstall them with that tool first if you want it to keep managing them.

History is backed up separately, never in git:

```bash
selves dotfiles backup-history           # ~/selves-history-YYYY-MM-DD.tgz, mode 0600
selves dotfiles restore-history <file>
```

## Using selves outside your shell (optional)

The `claude` wrapper from `selves init` only exists in interactive shells. Scripts and tools that run `claude` use the real binary, and therefore `base`. If you need them to follow your folder bindings too, install the shim:

```bash
selves shim install     # creates ~/.local/share/selves/shim/claude
selves shim status      # is it installed, and first in PATH?
selves shim remove      # undo
```

Open a new shell afterwards: `selves init` puts the shim first in `PATH`, so programs started from it use selves too.

| | Without shim | With shim |
|---|---|---|
| `claude` in your terminal | Folder profile | Folder profile |
| Script or tool running `claude` | `base` | Folder profile |
| `selves run <name>` | That profile | That profile |
| cron | `base` | Folder profile if called by full path: `~/.local/share/selves/shim/claude` |
| IDE extension with its own binary | `base` | `base` |

If you never install it, nothing changes: no files, no `PATH` changes, no `doctor` findings.

## Coming from claude-switch

```bash
selves doctor           # lists what will change
selves migrate          # markers, folder bindings, default profile, ~/.bashrc block
```

Then add the `selves init` line from the setup section to `~/.bashrc`. Profiles, history and logins are untouched.

## Limitations

- **IDE extensions** that bundle their own Claude Code binary always use `base`.
- **Same profile in parallel.** Two sessions of the **same** profile share its `.claude.json`. selves warns about it and repairs corruption, but separate profiles are the safer way to work in parallel.
- **macOS logins** live in the Keychain, so `list` shows "keychain" instead of verifying them.

## Development

```bash
shellcheck -S warning bin/selves bin/selves-dotfiles
SELVES_BIN="$PWD/bin/selves" bats --filter-tags core tests/
```

The acceptance suite is black-box: it only runs the binary in `SELVES_BIN`, so the same tests validate every edition.

## Contributing and security

See [CONTRIBUTING.md](CONTRIBUTING.md) for the development setup and rules, and [CHANGELOG.md](CHANGELOG.md) for what changed in each release. Report vulnerabilities privately as described in [SECURITY.md](SECURITY.md).

## License

MIT — see [LICENSE](LICENSE).
