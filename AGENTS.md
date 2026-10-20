# AGENTS.md — working on selves

Guide for anyone (human or coding agent) changing this repository. Read it before editing, committing or releasing.

## What this project is

**selves** gives Claude Code folder-aware profiles: a `.selves` file in a folder decides which account `claude` uses there. It only sets `CLAUDE_CONFIG_DIR` for the process it launches and never moves or replaces `~/.claude`.

This repo holds **selves-lite**, the bash edition (Linux and macOS). A Go edition is planned; it must pass the same acceptance tests.

| Path | Purpose |
|---|---|
| `bin/selves` | The tool. Single bash file. Its `VERSION="X.Y.Z"` line is the release version |
| `bin/selves-dotfiles` | Companion for `selves dotfiles …` (backup and restore) |
| `tests/selves.bats` | Black-box acceptance suite (`bats`) |
| `tests/helpers.bash` | Test harness: temporary `HOME` and a fake `claude` that logs how it was launched |
| `.github/workflows/ci.yml` | Lint + tests on Ubuntu and macOS for every push and pull request |
| `.github/workflows/release.yml` | Publishes a GitHub release when a version tag is pushed |
| `.github/dependabot.yml` | Weekly updates for the GitHub Actions used by the workflows |
| `CHANGELOG.md` | One section per release; the release notes are taken from here |
| `compose.yaml`, `docker/dev/Dockerfile` | Development container: Go toolchain, bats, shellcheck, python3 |
| `scripts/dev` | Runs any command inside the dev container (`scripts/dev go test ./...`) |
| `scripts/check` | Runs every CI check inside the dev container |
| `SPEC.md` (local only) | Design specification. Kept out of git on purpose (`.git/info/exclude`). **Never commit it** |

## Rules that are never broken

1. **Every behavior change comes with a test** in `tests/selves.bats`, tagged `# bats test_tags=core`. A fix starts with a test that fails without the fix.
2. **Tests are black-box.** They only call the binary in `SELVES_BIN` and the fake `claude`. They must never touch a real `~/.claude`.
3. **Portable bash.** Must run on bash 3.2 (macOS) with BSD tools. Do not use `mapfile`, associative arrays, `${var,,}`, `sed -i`, or GNU-only flags without a fallback (`stat -c`, `readlink -f`). With `set -u`, guard empty arrays: `${arr[@]+"${arr[@]}"}`.
4. **Never handle credentials.** Checking that `.credentials.json` exists is fine; reading it is not. No network access, no telemetry.
5. **`doctor` codes are a public interface.** Add new codes; never rename or remove existing ones.
6. **Optional features stay invisible until enabled.** Example: without `selves shim install`, no files, no `PATH` changes, no `doctor` findings.
7. **Never write personal data** (local paths, user or company names) into tracked files, test fixtures or commit messages.
8. **User-facing messages are in English**, short, and include the command that fixes the problem.

## Development environment (Docker)

Nothing needs to be installed on the host except Docker: Go, bats, shellcheck and python3 live in the dev container. The repository is mounted at `/work`, commands run as your own user (files are never owned by root), and the Go build cache persists in the `selves-go-cache` volume.

```bash
scripts/dev                     # interactive shell in the container
scripts/dev go test ./...       # any single command
scripts/dev --rebuild           # rebuild the image after editing docker/dev/Dockerfile
GO_VERSION=1.26 scripts/dev --rebuild   # change the Go version
```

Run `git` on the host, not inside the container. Build output goes to `build/`, which is ignored by git.

## Checks before every commit

```bash
scripts/check                      # shellcheck, bats (lite), and go vet/test/build + bats (Go) once go.mod exists
git status --short                 # only the files you meant to change; SPEC.md must not appear
```

Without Docker, the same checks for selves-lite are:

```bash
shellcheck -S warning bin/selves bin/selves-dotfiles
SELVES_BIN="$PWD/bin/selves" bats --filter-tags core tests/
```

## Committing a change

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/):

| Prefix | Use for |
|---|---|
| `feat:` | New behavior (bumps MINOR at release) |
| `fix:` | Bug fix (bumps PATCH at release) |
| `docs:` | README, CHANGELOG, this file |
| `test:` | Tests only |
| `ci:` | Workflows, Dependabot |
| `chore:` | Anything else that does not change behavior |

```bash
git add <files>
git commit -m "fix: short description of the change"
git push
```

Branch protection on `main`:

- **No force pushes and no branch deletion, for anyone** (ruleset `main-protection`). Never rewrite published history; fix mistakes with a new commit.
- **CI must pass** (ruleset `main-ci`). Repository admins may push directly; GitHub then prints `Bypassed rule violations … required status checks are expected`. That message is expected. Check the run in the **Actions** tab afterwards.
- Contributors without bypass open a pull request; it can merge once `selves-lite (ubuntu-latest)` and `selves-lite (macos-latest)` are green.

## Releasing a version

Versions follow [Semantic Versioning](https://semver.org/) and tags have **no `v` prefix** (`1.4.0`, not `v1.4.0`). Only release when users get something new or fixed; CI or documentation changes alone do not need a release.

**Order matters. Prepare everything, then tag.**

1. Set the version in `bin/selves`:
   ```bash
   sed -i 's/^VERSION=".*"/VERSION="1.4.0"/' bin/selves   # on macOS: sed -i '' …
   ```
2. Add the section to `CHANGELOG.md`, above the previous one, and its comparison link at the bottom:
   ```markdown
   ## [1.4.0] — YYYY-MM-DD

   ### Added
   - …

   [1.4.0]: https://github.com/letkode/selves-cc/compare/1.3.0...1.4.0
   ```
3. Run the checks, then commit and push:
   ```bash
   git add bin/selves CHANGELOG.md
   git commit -m "release 1.4.0"
   git push
   ```
4. Wait for CI to be green on `main`. Then push the tag:
   ```bash
   git tag -a 1.4.0 -m "selves-lite 1.4.0"
   git push origin 1.4.0
   ```
5. The **release** workflow then lints and tests, checks that `VERSION` equals the tag, takes the notes from the matching `CHANGELOG.md` section, builds `SHA256SUMS` and publishes the release with `selves`, `selves-dotfiles` and `SHA256SUMS`. It marks the release as **Latest** only if it is the highest version.
6. Verify:
   ```bash
   gh release list --repo letkode/selves-cc
   ```

Do not create releases by hand with `gh release create` unless the workflow cannot run. If you must, always pass `--repo letkode/selves-cc`; `gh` otherwise uses whatever repository the current folder belongs to.

## Things never to do

- **Never push a test tag.** Ruleset `releases` makes tags permanent: they cannot be deleted, moved or force-pushed.
- **Never tag before `VERSION` and `CHANGELOG.md` are committed.** A tag cannot be moved to fix it afterwards.
- **Never force-push** `main` or rewrite published commits.
- **Never commit `SPEC.md`**, credentials, `.selves` files from your own projects, or patch files.
- **Never transfer patches or scripts by pasting them into an editor.** Tabs and long lines get altered. Copy files (`scp`, `git`), and check before applying:
  ```bash
  git apply --check change.patch      # fails? it may already be applied:
  git apply -R --check change.patch   # succeeds → already applied, nothing to do
  ```

## Recovering from a mistake

**A version tag was pushed by mistake.** If the release workflow failed, nothing was published. To remove the tag, an admin disables the tag ruleset for a moment:

```bash
R=repos/letkode/selves-cc
ID=$(gh api $R/rulesets --jq '.[] | select(.name=="releases") | .id')
gh api -X PUT $R/rulesets/$ID -f enforcement=disabled >/dev/null
gh release delete X.Y.Z --repo letkode/selves-cc --yes 2>/dev/null; true
git push origin :refs/tags/X.Y.Z && git tag -d X.Y.Z
gh api -X PUT $R/rulesets/$ID -f enforcement=active >/dev/null      # never skip this
gh api $R/rulesets --jq '.[] | "\(.name): \(.enforcement)"'         # all three: active
```

Then restore the previous `VERSION` in `bin/selves` with a new commit (`chore: back to X.Y.Z …`).

**The release workflow failed on a real version.** Read why:

```bash
ID=$(gh run list --repo letkode/selves-cc --workflow release -L1 --json databaseId --jq '.[0].databaseId')
gh run view $ID --repo letkode/selves-cc --log-failed | tail -20
```

The tag cannot be moved. Either publish that release by hand from the tagged files, or fix the problem and release the next patch version.

**A release is missing for an existing tag.** Publish it from the tagged files without making it Latest:

```bash
mkdir -p /tmp/rel && git show X.Y.Z:bin/selves > /tmp/rel/selves && git show X.Y.Z:bin/selves-dotfiles > /tmp/rel/selves-dotfiles
(cd /tmp/rel && sha256sum selves selves-dotfiles > SHA256SUMS)
gh release create X.Y.Z /tmp/rel/* --repo letkode/selves-cc --verify-tag --latest=false \
  --title "selves-lite X.Y.Z" --notes "…"
```

## Dependabot

Every week Dependabot opens pull requests that update the GitHub Actions used by the workflows. When CI is green on one:

```bash
gh pr checks <number> --repo letkode/selves-cc
gh pr merge <number> --repo letkode/selves-cc --squash --delete-branch
git pull
```

## Repository security settings (keep them on)

| Setting | Where |
|---|---|
| Rulesets `main-protection`, `main-ci`, `releases` | Settings → Rules |
| Secret scanning with push protection | Settings → Security |
| Dependabot alerts and security updates | Settings → Security |
| Private vulnerability reporting | Settings → Security |

Check them with:

```bash
gh api repos/letkode/selves-cc/rulesets --jq '.[] | "\(.name): \(.enforcement)"'
gh api repos/letkode/selves-cc --jq '.security_and_analysis.secret_scanning_push_protection.status'
```

## Before pushing anything public

```bash
git grep -niE '/home/|/Users/|<your-username>|<your-company>' || echo "clean"
```

Replace the placeholders with the personal or company names that must never appear in the repository.

## The Go edition (planned)

- Develop it on a branch (`go-edition`) in this repository, using the dev container (`scripts/dev`, `scripts/check`).
- Build to `build/selves`. It must pass the same suite: `scripts/dev bash -c 'SELVES_BIN="$PWD/build/selves" bats tests/'`.
- Keep the command names, `doctor` codes, file formats (`.selves`, `.selves-entries`, the `dotfiles` layout) and exit codes identical to selves-lite.
