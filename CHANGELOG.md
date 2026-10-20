# Changelog

All notable changes to selves-lite are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [1.3.0] — 2026-10-20

### Added
- `selves shim install|remove|status`: optional shim that routes every `claude` call (scripts, tools, terminals that skip `~/.bashrc`) through selves. Nothing changes unless it is installed.
- `selves init` puts the shim folder first in `PATH` when the shim exists.
- `doctor` checks `SHIM_STALE` and `SHIM_NOT_FIRST`.

### Changed
- The Claude Code binary lookup skips selves shims, so `selves run <name>` always keeps the requested profile.

## [1.2.1] — 2026-10-20

### Fixed
- `dotfiles export` finds folder bindings outside `$HOME` with `SELVES_DOTFILES_ROOTS`.
- The "profile-owned material" warning only appears when a profile has real files of its own.
- Links to base entries count as shared even when the base entry is itself a link (for example, skills installed under `~/.agents/skills`).

## [1.2.0] — 2026-10-20

### Added
- Per-entry sharing: `selves entries <profile> <item>` and `SELVES_ENTRIES`. Shared entries stay in sync on every launch.
- `selves claim <profile> <item>/<pattern>` moves base entries into a single profile.
- `doctor` checks `SHARED_SYNCED`, `RC_CLAUDE_ALIAS` and `RC_INIT_PATH`, and also reads `~/.bash_aliases`.

### Changed
- `skills/synced` (per-account skills synced by Claude Code) is never shared: per-entry mode skips it, `claim` refuses it and `dotfiles export` excludes it.
- The recommended `init` line calls selves by absolute path, so login shells on Ubuntu and Debian find it.

## [1.0.1] — 2026-10-19

### Fixed
- `unshare` rewrites plugin paths recorded under another profile while the item was shared.

### Added
- `doctor` check `FOREIGN_PATHS`; `repair` rewrites plugin paths that point into other profiles.

## [1.0.0] — 2026-10-19

### Added
- First release of selves-lite: folder bindings (`.selves`), side-by-side profiles with `CLAUDE_CONFIG_DIR`, shared layer, `doctor`, `repair`, `migrate` from claude-switch, `init` for bash and zsh, and the `selves-dotfiles` companion for backups.

[1.3.0]: https://github.com/letkode/selves-cc/compare/1.2.1...1.3.0
[1.2.1]: https://github.com/letkode/selves-cc/compare/1.2.0...1.2.1
[1.2.0]: https://github.com/letkode/selves-cc/compare/1.0.1...1.2.0
[1.0.1]: https://github.com/letkode/selves-cc/compare/1.0.0...1.0.1
[1.0.0]: https://github.com/letkode/selves-cc/releases/tag/1.0.0
