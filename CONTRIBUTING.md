# Contributing to selves

Thanks for helping. Bug reports with the output of `selves doctor` are the most useful contribution of all.

## Development setup

```bash
# Debian/Ubuntu
sudo apt install bats shellcheck
# macOS
brew install bats-core shellcheck
```

Run the same checks as CI:

```bash
shellcheck -S warning bin/selves bin/selves-dotfiles
SELVES_BIN="$PWD/bin/selves" bats --filter-tags core tests/
```

## Rules for changes

1. **Every behavior change comes with a test** in `tests/selves.bats`, tagged `# bats test_tags=core`. Fixes start with a test that fails without the fix.
2. **Tests are black-box.** They only call the binary in `SELVES_BIN` and a fake `claude` that logs how it was launched. They must never touch your real `~/.claude`.
3. **Stay portable.** selves-lite runs on Linux and macOS with bash 3.2. Avoid `mapfile`, associative arrays, `${var,,}`, `sed -i`, and GNU-only flags without a fallback (`stat -c`, `readlink -f`).
4. **Never handle credentials.** Checking that a file exists is fine; reading it is not.
5. **Keep `doctor` codes stable.** Scripts and tests rely on them. Add new codes; do not rename existing ones.
6. **Messages are in English**, short, and include the command that fixes the problem.

## Commits and releases

- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `docs:`, `test:`.
- Releases are tagged by the maintainer without a `v` prefix (`1.4.0`) and listed in `CHANGELOG.md`.
