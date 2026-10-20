#!/usr/bin/env bats
# selves acceptance suite — see SPEC.md §13.
#   Lite:  SELVES_BIN=bin/selves bats --filter-tags core tests/
#   Full:  SELVES_BIN=./selves   bats tests/

load helpers
setup() { setup_home; }

# bats test_tags=core
@test "T01 create: dir 0700, marker, shared layer linked" {
    run sv create work
    [ "$status" -eq 0 ]
    [ "$(mode_of "$HOME/.claude-work")" = "700" ]
    [ -f "$HOME/.claude-work/.selves-profile" ]
    [ -L "$HOME/.claude-work/skills" ]
    [ -L "$HOME/.claude-work/CLAUDE.md" ]
    [ -L "$HOME/.claude-work/rules" ]
    [ ! -e "$HOME/.claude-work/settings.json" ]
    [ ! -e "$HOME/.claude-work/plugins" ]
}

# bats test_tags=core
@test "T02 create rejects reserved and invalid names" {
    for n in base list default 9x "a b"; do
        run sv create "$n"
        [ "$status" -ne 0 ]
    done
    run ls -d "$HOME"/.claude-*
    [ "$status" -ne 0 ]
}

# bats test_tags=core
@test "T03 create refuses an existing non-profile dir and suggests adopt" {
    mkdir "$HOME/.claude-work"; echo keep > "$HOME/.claude-work/data"
    run sv create work
    [ "$status" -eq 1 ]
    [[ "$output" == *adopt* ]]
    [ "$(cat "$HOME/.claude-work/data")" = "keep" ]
    [ ! -e "$HOME/.claude-work/.selves-profile" ]
}

# bats test_tags=core
@test "T04 adopt writes the marker and touches nothing else" {
    mkdir "$HOME/.claude-work"; echo h > "$HOME/.claude-work/history.jsonl"
    run sv adopt work
    [ "$status" -eq 0 ]
    [ -f "$HOME/.claude-work/.selves-profile" ]
    [ "$(cat "$HOME/.claude-work/history.jsonl")" = "h" ]
    [ ! -e "$HOME/.claude-work/skills" ]
}

# bats test_tags=core
@test "T05 run sets CLAUDE_CONFIG_DIR, active profile and passes args" {
    sv create work >/dev/null
    run sv run work -- --resume
    [ "$status" -eq 0 ]
    [ "$(last_call)" = "CONFIG_DIR=$HOME/.claude-work ACTIVE=work ARGS=--resume" ]
    sv work -p hi
    [ "$(last_call)" = "CONFIG_DIR=$HOME/.claude-work ACTIVE=work ARGS=-p hi" ]
}

# bats test_tags=core
@test "T06 run base removes a leaked CLAUDE_CONFIG_DIR" {
    CLAUDE_CONFIG_DIR=/x run sv run base
    [ "$status" -eq 0 ]
    [ "$(last_call)" = "CONFIG_DIR=<unset> ACTIVE=base ARGS=" ]
}

# bats test_tags=core
@test "T07 binding applies to subdirectories" {
    sv create work >/dev/null
    mkdir -p "$HOME/proj/sub"; cd "$HOME/proj"; sv bind work >/dev/null
    [ "$(cat "$HOME/proj/.selves")" = "work" ]
    cd "$HOME/proj/sub"
    run sv auto
    [ "$status" -eq 0 ]
    [[ "$(last_call)" == "CONFIG_DIR=$HOME/.claude-work ACTIVE=work"* ]]
}

# bats test_tags=core
@test "T08 auto without binding or default launches base" {
    run sv auto
    [ "$status" -eq 0 ]
    [[ "$(last_call)" == "CONFIG_DIR=<unset> ACTIVE=base"* ]]
}

# bats test_tags=core
@test "T09 default profile applies outside bindings" {
    sv create personal >/dev/null
    sv default personal >/dev/null
    [ "$(sv default)" = "personal" ]
    sv auto
    [[ "$(last_call)" == *"ACTIVE=personal"* ]]
    sv default base >/dev/null
    [ "$(sv default)" = "base" ]
}

# bats test_tags=core
@test "T10 binding file ignores comments and blank lines" {
    sv create work >/dev/null
    mkdir -p "$HOME/p"; printf '# team account\n\n  work  \n' > "$HOME/p/.selves"; cd "$HOME/p"
    run sv which
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "work" ]
}

# bats test_tags=core
@test "T11 invalid name in binding fails and names the file" {
    mkdir -p "$HOME/p"; echo "../etc" > "$HOME/p/.selves"; cd "$HOME/p"
    run sv auto
    [ "$status" -eq 1 ]
    [[ "$output" == *"$HOME/p/.selves"* ]]
    [ "$(calls)" = "0" ]
}

# bats test_tags=core
@test "T12 binding to a missing profile suggests create" {
    mkdir -p "$HOME/p"; echo "ghost" > "$HOME/p/.selves"; cd "$HOME/p"
    run sv auto
    [ "$status" -eq 1 ]
    [[ "$output" == *"selves create ghost"* ]]
}

# bats test_tags=core
@test "T13 legacy .claude-profile is honored and reported" {
    sv create work >/dev/null
    mkdir -p "$HOME/p"; echo work > "$HOME/p/.claude-profile"; cd "$HOME/p"
    sv auto
    [[ "$(last_call)" == *"ACTIVE=work"* ]]
    run sv doctor
    [ "$status" -eq 3 ]
    [[ "$output" == *LEGACY_BINDING* ]]
}

# bats test_tags=core
@test "T14 recursion guard when the claude binary is selves itself" {
    SELVES_CLAUDE_BIN="$SELVES_BIN" run sv run base
    [ "$status" -eq 1 ]
    [[ "$output" == *ecursion* ]]
    [ "$(calls)" = "0" ]
}

# bats test_tags=core
@test "T15 corrupt .claude.json is kept and restored from a dot-named backup" {
    command -v python3 >/dev/null || skip "python3 needed for JSON validation"
    sv create work >/dev/null
    d="$HOME/.claude-work"; mkdir -p "$d/backups"
    echo '{"old":1}' > "$d/backups/.claude.json.backup.1"; sleep 1
    echo '{"good":2}' > "$d/backups/.claude.json.backup.2"
    echo '{"broken": ' > "$d/.claude.json"
    run sv run work
    [ "$status" -eq 0 ]
    [ "$(cat "$d/.claude.json")" = '{"good":2}' ]
    ls "$d"/.claude.json.corrupt-* >/dev/null
    [[ "$(last_call)" == *"ACTIVE=work"* ]]
}

# bats test_tags=core
@test "T16 corrupt .claude.json without backups: kept aside, launch proceeds" {
    command -v python3 >/dev/null || skip "python3 needed for JSON validation"
    sv create work >/dev/null
    echo '{"broken": ' > "$HOME/.claude-work/.claude.json"
    run sv run work
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/.claude-work/.claude.json" ]
    ls "$HOME/.claude-work"/.claude.json.corrupt-* >/dev/null
    [[ "$(last_call)" == *"ACTIVE=work"* ]]
}

# bats test_tags=core
@test "T17 unshare copies, rewrites absolute paths, leaves base intact" {
    mkdir -p "$HOME/.claude/plugins/cache/p1"
    printf '{"installPath":"%s/.claude/plugins/cache/p1","root":"%s/.claude/plugins"}\n' "$HOME" "$HOME" \
        > "$HOME/.claude/plugins/installed_plugins.json"
    sv create work >/dev/null
    ln -s "$HOME/.claude/plugins" "$HOME/.claude-work/plugins"
    run sv unshare work plugins
    [ "$status" -eq 0 ]
    [ -d "$HOME/.claude-work/plugins" ] && [ ! -L "$HOME/.claude-work/plugins" ]
    grep -q "\"$HOME/.claude-work/plugins/cache/p1\"" "$HOME/.claude-work/plugins/installed_plugins.json"
    grep -q "\"$HOME/.claude-work/plugins\"" "$HOME/.claude-work/plugins/installed_plugins.json"
    grep -q "\"$HOME/.claude/plugins/cache/p1\"" "$HOME/.claude/plugins/installed_plugins.json"
}

# bats test_tags=core
@test "T18 relink leaves a profile-owned directory untouched" {
    sv create work >/dev/null
    rm "$HOME/.claude-work/skills"; mkdir -p "$HOME/.claude-work/skills/own"
    run sv relink
    [ "$status" -eq 0 ]
    [ -d "$HOME/.claude-work/skills/own" ] && [ ! -L "$HOME/.claude-work/skills" ]
}

# bats test_tags=core
@test "T19 delete --yes removes the profile but never the shared base" {
    sv create work >/dev/null
    run sv delete work --yes
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/.claude-work" ]
    [ -f "$HOME/.claude/skills/generic/SKILL.md" ]
    [ -f "$HOME/.claude/CLAUDE.md" ]
}

# bats test_tags=core
@test "T20 delete without --yes and no terminal is a usage error" {
    sv create work >/dev/null
    run sv delete work < /dev/null
    [ "$status" -eq 2 ]
    [ -d "$HOME/.claude-work" ]
}

# bats test_tags=core
@test "T21 doctor flags an exported CLAUDE_CONFIG_DIR in ~/.bashrc" {
    echo 'export CLAUDE_CONFIG_DIR=$HOME/.claude-work' > "$HOME/.bashrc"
    run sv doctor
    [ "$status" -eq 3 ]
    [[ "$output" == *RC_CONFIG_DIR_EXPORT* ]]
}

# bats test_tags=core
@test "T22 doctor flags shared plugins" {
    mkdir -p "$HOME/.claude/plugins"
    sv create work >/dev/null
    ln -s "$HOME/.claude/plugins" "$HOME/.claude-work/plugins"
    run sv doctor
    [ "$status" -eq 3 ]
    [[ "$output" == *SHARED_PLUGINS* ]]
}

# bats test_tags=core
@test "T23 doctor on a clean setup exits 0" {
    sv create work >/dev/null
    run sv doctor
    [ "$status" -eq 0 ]
}

# bats test_tags=core
@test "T24 init bash: claude wrapper follows the folder binding" {
    sv create work >/dev/null
    mkdir -p "$HOME/proj"; (cd "$HOME/proj" && sv bind work >/dev/null)
    run bash -c 'alias claude="echo OLD"; eval "$("$SELVES_BIN" init bash)"; cd "$HOME/proj" && claude -p hi'
    [ "$status" -eq 0 ]
    [ "$(last_call)" = "CONFIG_DIR=$HOME/.claude-work ACTIVE=work ARGS=-p hi" ]
}

# bats test_tags=core
@test "T25 init bash: claude-<name> forces a profile" {
    sv create work >/dev/null
    run bash -c 'eval "$("$SELVES_BIN" init bash)"; claude-work x'
    [ "$status" -eq 0 ]
    [ "$(last_call)" = "CONFIG_DIR=$HOME/.claude-work ACTIVE=work ARGS=x" ]
}

# bats test_tags=core
@test "T26 migrate converts a claude-switch setup and is idempotent" {
    mkdir -p "$HOME/.claude-lab"; echo lab > "$HOME/.claude-lab/.profile-name"
    mkdir -p "$HOME/code/api"; echo lab > "$HOME/code/api/.claude-profile"
    mkdir -p "$HOME/.config/claude-switch"; echo lab > "$HOME/.config/claude-switch/default"
    printf 'keep\n# >>> claude-switch >>>\nalias claude=x\n# <<< claude-switch <<<\n' > "$HOME/.bashrc"
    run sv migrate --yes
    [ "$status" -eq 0 ]
    [ -f "$HOME/.claude-lab/.selves-profile" ] && [ ! -e "$HOME/.claude-lab/.profile-name" ]
    [ "$(cat "$HOME/code/api/.selves")" = "lab" ] && [ ! -e "$HOME/code/api/.claude-profile" ]
    [ "$(sv default)" = "lab" ]
    [ "$(cat "$HOME/.bashrc")" = "keep" ]
    [ -f "$HOME/.bashrc.selves.bak" ]
    run sv migrate --yes
    [ "$status" -eq 0 ]
    [[ "$output" == *"Nothing to migrate"* ]]
}

# bats test_tags=core
@test "T27 bare profiles are exempt from MISSING_SHARED" {
    sv create sandbox --bare >/dev/null
    [ ! -e "$HOME/.claude-sandbox/skills" ]
    run sv doctor
    [ "$status" -eq 0 ]
    [[ "$output" != *MISSING_SHARED* ]]
}

# bats test_tags=core
@test "T28 which prints only the profile name on stdout" {
    sv create work >/dev/null
    mkdir -p "$HOME/p"; (cd "$HOME/p" && sv bind work >/dev/null); cd "$HOME/p"
    out="$("$SELVES_BIN" which 2>/dev/null)"
    [ "$out" = "work" ]
}

# ── Full edition only ───────────────────────────────────────────────────────

@test "T29 list --json is valid JSON" {
    skip_if_lite
    sv create work >/dev/null
    sv list --json | python3 -c 'import json,sys; d=json.load(sys.stdin); assert any(p["name"]=="work" for p in d)'
}

# bats test_tags=core
@test "T30 dotfiles export / wipe / install round trip" {
    command -v python3 >/dev/null || skip "python3 needed for MCP export"
    # Setup: work with own skills + shared one, bare sandbox, personal default, MCP, binding
    sv create work >/dev/null; sv create personal >/dev/null; sv create sandbox --bare >/dev/null
    W="$HOME/.claude-work"
    rm "$W/skills"; mkdir -p "$W/skills/acme-deploy"; echo x > "$W/skills/acme-deploy/SKILL.md"
    ln -s "$HOME/.claude/skills/generic" "$W/skills/generic"
    echo '{"theme":"dark"}' > "$W/settings.json"
    echo '{"mcpServers":{"jira":{"type":"http","url":"https://jira.example"}}}' > "$W/.claude.json"
    echo '{"secret":"value"}' > "$W/.credentials.json"
    sv default personal >/dev/null
    mkdir -p "$HOME/code/api"; (cd "$HOME/code/api" && sv bind work >/dev/null)

    REPO="$BATS_TEST_TMPDIR/repo"
    run sv dotfiles export "$REPO"
    [ "$status" -eq 0 ]
    ! grep -rq '"secret"' "$REPO"
    [ ! -e "$REPO/profiles/work/.credentials.json" ]

    # Wipe everything selves manages (keep the fake claude and the project folder)
    rm -rf "$HOME"/.claude "$HOME"/.claude-* "$HOME/.config" "$HOME/code/api/.selves"

    run "$REPO/bin/selves" dotfiles install "$REPO" --no-init
    [ "$status" -eq 0 ]
    [ -f "$HOME/.claude/CLAUDE.md" ]
    [ -f "$HOME/.claude-work/.selves-profile" ] && [ -f "$HOME/.claude-personal/.selves-profile" ]
    [ ! -e "$HOME/.claude-sandbox/skills" ]
    [ -f "$HOME/.claude-work/skills/acme-deploy/SKILL.md" ] && [ ! -L "$HOME/.claude-work/skills" ]
    [ -L "$HOME/.claude-work/skills/generic" ]
    [ ! -e "$HOME/.claude-personal/skills/acme-deploy" ]
    [ "$(cat "$HOME/.claude-work/settings.json")" = '{"theme":"dark"}' ]
    grep -qx "MCP=jira CONFIG_DIR=$HOME/.claude-work" "$HOME/claude-calls.log"
    [ "$("$HOME/.local/bin/selves" default)" = "personal" ]
    [ "$(cat "$HOME/code/api/.selves")" = "work" ]
    ! grep -q 'selves init' "$HOME/.bashrc" 2>/dev/null
}

# bats test_tags=core
@test "T31 restore-history refuses paths outside .claude*/" {
    mkdir -p "$BATS_TEST_TMPDIR/evil"; echo x > "$BATS_TEST_TMPDIR/evil/f"
    tar czf "$BATS_TEST_TMPDIR/evil.tgz" -C "$BATS_TEST_TMPDIR" evil
    run sv dotfiles restore-history "$BATS_TEST_TMPDIR/evil.tgz"
    [ "$status" -ne 0 ]
    [ ! -e "$HOME/evil" ]
}

# bats test_tags=core
@test "T33 dotfiles export warns about literal secrets" {
    command -v python3 >/dev/null || skip "python3 needed for MCP export"
    sv create work >/dev/null
    echo '{"mcpServers":{"pg":{"command":"pg-mcp","env":{"PG_PASSWORD":"supersecret123"}}}}' > "$HOME/.claude-work/.claude.json"
    run sv dotfiles export "$BATS_TEST_TMPDIR/repo"
    [ "$status" -eq 0 ]
    [[ "$output" == *"profiles/work/mcp.json"* ]]
    [[ "$output" == *PG_PASSWORD* ]]
}

# bats test_tags=core
@test "T34 history backup and restore round trip" {
    sv create work >/dev/null
    echo base-h > "$HOME/.claude/history.jsonl"
    mkdir -p "$HOME/.claude-work/projects/p"; echo conv > "$HOME/.claude-work/projects/p/s.jsonl"
    run sv dotfiles backup-history "$BATS_TEST_TMPDIR/h.tgz"
    [ "$status" -eq 0 ]
    [ "$(mode_of "$BATS_TEST_TMPDIR/h.tgz")" = "600" ]
    rm -rf "$HOME/.claude/history.jsonl" "$HOME/.claude-work/projects"
    run sv dotfiles restore-history "$BATS_TEST_TMPDIR/h.tgz"
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/.claude/history.jsonl")" = "base-h" ]
    [ "$(cat "$HOME/.claude-work/projects/p/s.jsonl")" = "conv" ]
}

# bats test_tags=core
@test "T35 unshare rewrites paths recorded under another profile" {
    mkdir -p "$HOME/.claude/plugins/cache/p1"
    sv create personal >/dev/null; sv create work >/dev/null
    ln -s "$HOME/.claude/plugins" "$HOME/.claude-personal/plugins"
    ln -s "$HOME/.claude/plugins" "$HOME/.claude-work/plugins"
    # Recorded while "personal" was active, so it uses personal's path
    printf '{"installPath":"%s/.claude-personal/plugins/cache/p1"}\n' "$HOME" > "$HOME/.claude/plugins/installed_plugins.json"
    sv unshare personal plugins >/dev/null
    sv unshare work plugins >/dev/null
    grep -q "\"$HOME/.claude-work/plugins/cache/p1\"" "$HOME/.claude-work/plugins/installed_plugins.json"
    grep -q "\"$HOME/.claude-personal/plugins/cache/p1\"" "$HOME/.claude-personal/plugins/installed_plugins.json"
}

# bats test_tags=core
@test "T36 doctor flags foreign plugin paths and repair fixes them" {
    sv create personal >/dev/null; sv create work >/dev/null
    mkdir -p "$HOME/.claude-work/plugins/cache/p1"
    printf '{"installPath":"%s/.claude-personal/plugins/cache/p1"}\n' "$HOME" > "$HOME/.claude-work/plugins/installed_plugins.json"
    run sv doctor
    [ "$status" -eq 3 ]
    [[ "$output" == *FOREIGN_PATHS* ]]
    run sv repair work
    [ "$status" -eq 0 ]
    grep -q "\"$HOME/.claude-work/plugins/cache/p1\"" "$HOME/.claude-work/plugins/installed_plugins.json"
    run sv doctor
    [[ "$output" != *FOREIGN_PATHS* ]]
}

# bats test_tags=core
@test "T37 entries: per-entry links plus profile-only entries" {
    mkdir -p "$HOME/.claude/skills/other"
    sv create work >/dev/null; sv create personal >/dev/null
    run sv entries work skills
    [ "$status" -eq 0 ]
    [ -d "$HOME/.claude-work/skills" ] && [ ! -L "$HOME/.claude-work/skills" ]
    [ -L "$HOME/.claude-work/skills/generic" ] && [ -L "$HOME/.claude-work/skills/other" ]
    mkdir -p "$HOME/.claude-work/skills/acme"
    [ ! -e "$HOME/.claude/skills/acme" ]
    [ ! -e "$HOME/.claude-personal/skills/acme" ]
    run sv doctor
    [ "$status" -eq 0 ]
}

# bats test_tags=core
@test "T38 claim moves base entries into one profile" {
    mkdir -p "$HOME/.claude/skills/sdd-new" "$HOME/.claude/skills/sdd-apply"
    sv create work >/dev/null; sv create personal >/dev/null
    sv entries personal skills >/dev/null
    run sv claim work 'skills/sdd-*'
    [ "$status" -eq 0 ]
    [ -d "$HOME/.claude-work/skills/sdd-new" ] && [ ! -L "$HOME/.claude-work/skills/sdd-new" ]
    [ ! -e "$HOME/.claude/skills/sdd-new" ] && [ ! -e "$HOME/.claude/skills/sdd-apply" ]
    [ ! -e "$HOME/.claude-personal/skills/sdd-new" ] && [ ! -L "$HOME/.claude-personal/skills/sdd-new" ]
    [ -L "$HOME/.claude-personal/skills/generic" ] && [ -L "$HOME/.claude-work/skills/generic" ]
    run sv claim work 'skills/nothing-*'
    [ "$status" -eq 1 ]
}

# bats test_tags=core
@test "T39 launch syncs per-entry items with base" {
    sv create work >/dev/null; sv entries work skills >/dev/null
    mkdir -p "$HOME/.claude/skills/new-one"
    rm -rf "$HOME/.claude/skills/generic"
    sv run work >/dev/null
    [ -L "$HOME/.claude-work/skills/new-one" ]
    [ ! -L "$HOME/.claude-work/skills/generic" ]
}

# bats test_tags=core
@test "T40 SELVES_ENTRIES creates per-entry items" {
    SELVES_ENTRIES="skills" sv create work >/dev/null
    [ -d "$HOME/.claude-work/skills" ] && [ ! -L "$HOME/.claude-work/skills" ]
    [ -L "$HOME/.claude-work/skills/generic" ]
    [ -L "$HOME/.claude-work/rules" ]
}

# bats test_tags=core
@test "T41 dotfiles round trip keeps per-entry mode" {
    sv create work >/dev/null; sv entries work skills >/dev/null
    mkdir -p "$HOME/.claude-work/skills/acme"; echo x > "$HOME/.claude-work/skills/acme/SKILL.md"
    REPO="$BATS_TEST_TMPDIR/repo"
    sv dotfiles export "$REPO" >/dev/null 2>&1
    grep -qx "skills entries" "$REPO/profiles/work/modes"
    [ ! -e "$REPO/profiles/work/own/skills/generic" ]
    rm -rf "$HOME"/.claude "$HOME"/.claude-*
    run "$REPO/bin/selves" dotfiles install "$REPO" --no-init
    [ "$status" -eq 0 ]
    [ -f "$HOME/.claude-work/skills/acme/SKILL.md" ] && [ ! -L "$HOME/.claude-work/skills/acme" ]
    [ -L "$HOME/.claude-work/skills/generic" ]
    grep -qx skills "$HOME/.claude-work/.selves-entries"
}


# bats test_tags=core
@test "T42 per-entry mode never links skills/synced and drops an existing link" {
    mkdir -p "$HOME/.claude/skills/synced/acct_1"
    sv create work >/dev/null; sv entries work skills >/dev/null
    [ ! -e "$HOME/.claude-work/skills/synced" ] && [ ! -L "$HOME/.claude-work/skills/synced" ]
    [ -L "$HOME/.claude-work/skills/generic" ]
    ln -s "$HOME/.claude/skills/synced" "$HOME/.claude-work/skills/synced"
    sv run work >/dev/null
    [ ! -L "$HOME/.claude-work/skills/synced" ]
    mkdir -p "$HOME/.claude-work/skills/synced/acct_2"      # Claude Code's own sync
    sv relink >/dev/null
    [ -d "$HOME/.claude-work/skills/synced/acct_2" ]
}

# bats test_tags=core
@test "T43 doctor flags synced skills shared through a whole-directory link" {
    mkdir -p "$HOME/.claude/skills/synced/acct_1"
    sv create work >/dev/null
    run sv doctor
    [ "$status" -eq 3 ]
    [[ "$output" == *SHARED_SYNCED* ]]
    sv entries work skills >/dev/null
    run sv doctor
    [ "$status" -eq 0 ]
}

# bats test_tags=core
@test "T44 claim never moves skills/synced" {
    mkdir -p "$HOME/.claude/skills/synced/acct_1" "$HOME/.claude/skills/sync-tool"
    sv create work >/dev/null
    run sv claim work 'skills/sync*'
    [ "$status" -eq 0 ]
    [ -d "$HOME/.claude/skills/synced/acct_1" ]
    [ -d "$HOME/.claude-work/skills/sync-tool" ] && [ ! -e "$HOME/.claude-work/skills/synced" ]
    [[ "$output" == *per-account* ]]
}

# bats test_tags=core
@test "T45 dotfiles export excludes synced skills" {
    mkdir -p "$HOME/.claude/skills/synced/acct_1"
    sv create work >/dev/null; sv entries work skills >/dev/null
    mkdir -p "$HOME/.claude-work/skills/synced/acct_2" "$HOME/.claude-work/skills/own-one"
    REPO="$BATS_TEST_TMPDIR/repo"
    sv dotfiles export "$REPO" >/dev/null 2>&1
    [ ! -e "$REPO/base/shared/skills/synced" ]
    [ ! -e "$REPO/profiles/work/own/skills/synced" ]
    [ -d "$REPO/profiles/work/own/skills/own-one" ]
    [ -d "$REPO/base/shared/skills/generic" ]
}

# bats test_tags=core
@test "T46 doctor flags claude aliases in startup files" {
    printf 'alias ll="ls -l"\nalias claude-lab='"'"'CLAUDE_CONFIG_DIR=~/.claude-lab claude'"'"'\n' > "$HOME/.bash_aliases"
    run sv doctor
    [ "$status" -eq 3 ]
    [[ "$output" == *RC_CLAUDE_ALIAS* ]]
    [[ "$output" == *".bash_aliases:2"* ]]
}

# bats test_tags=core
@test "T47 doctor flags a PATH-dependent init line, not the absolute one" {
    echo 'eval "$(selves init bash)"' > "$HOME/.bashrc"
    run sv doctor
    [ "$status" -eq 3 ]
    [[ "$output" == *RC_INIT_PATH* ]]
    echo '[ -x "$HOME/.local/bin/selves" ] && eval "$("$HOME/.local/bin/selves" init bash)"' > "$HOME/.bashrc"
    run sv doctor
    [ "$status" -eq 0 ]
}

# bats test_tags=core
@test "T48 dotfiles install writes the absolute-path init line" {
    sv create work >/dev/null
    REPO="$BATS_TEST_TMPDIR/repo"
    sv dotfiles export "$REPO" >/dev/null 2>&1
    rm -f "$HOME/.bashrc"
    SHELL=/bin/bash run "$REPO/bin/selves" dotfiles install "$REPO"
    [ "$status" -eq 0 ]
    grep -qF '[ -x "$HOME/.local/bin/selves" ] && eval "$("$HOME/.local/bin/selves" init bash)"' "$HOME/.bashrc"
    run sv doctor
    [[ "$output" != *RC_INIT_PATH* ]]
}

# bats test_tags=core
@test "T49 dotfiles finds bindings outside HOME with SELVES_DOTFILES_ROOTS" {
    sv create work >/dev/null
    DATA="$BATS_TEST_TMPDIR/data"; mkdir -p "$DATA/lab/api"
    (cd "$DATA/lab" && sv bind work >/dev/null)
    REPO="$BATS_TEST_TMPDIR/repo"
    sv dotfiles export "$REPO" >/dev/null 2>&1
    [ ! -s "$REPO/bindings.txt" ]
    SELVES_DOTFILES_ROOTS="$HOME $DATA" sv dotfiles export "$REPO" >/dev/null 2>&1
    grep -qx "$DATA/lab	work" "$REPO/bindings.txt"
    rm -f "$DATA/lab/.selves"; rm -rf "$HOME"/.claude-*
    run "$REPO/bin/selves" dotfiles install "$REPO" --no-init
    [ "$status" -eq 0 ]
    [ "$(cat "$DATA/lab/.selves")" = "work" ]
}

# bats test_tags=core
@test "T50 own-content warning only when the profile has real files" {
    sv create work >/dev/null; sv entries work skills >/dev/null
    run sv dotfiles export "$BATS_TEST_TMPDIR/repo"
    [ "$status" -eq 0 ]
    [[ "$output" != *"own files"* ]]
    mkdir -p "$HOME/.claude-work/skills/acme"; echo x > "$HOME/.claude-work/skills/acme/SKILL.md"
    run sv dotfiles export "$BATS_TEST_TMPDIR/repo"
    [[ "$output" == *"own files"* ]]
}

# bats test_tags=core
@test "T51 dotfiles treats links to base entries as shared even if base entries are links" {
    # Like skill installers do: ~/.claude/skills/x -> ../../.agents/skills/x
    mkdir -p "$HOME/.agents/skills/ext"; echo x > "$HOME/.agents/skills/ext/SKILL.md"
    ln -s ../../.agents/skills/ext "$HOME/.claude/skills/ext"
    sv create work >/dev/null; sv entries work skills >/dev/null
    [ -L "$HOME/.claude-work/skills/ext" ]
    run sv dotfiles export "$BATS_TEST_TMPDIR/repo"
    [ "$status" -eq 0 ]
    [ ! -e "$BATS_TEST_TMPDIR/repo/profiles/work/own/skills/ext" ]
    [[ "$output" != *"own files"* ]]
    grep -qx "skills entries" "$BATS_TEST_TMPDIR/repo/profiles/work/modes"
    [ -f "$BATS_TEST_TMPDIR/repo/base/shared/skills/ext/SKILL.md" ]
}


# bats test_tags=core
@test "T52 shim is opt-in: nothing changes unless installed" {
    sv create work >/dev/null
    run sv init bash
    [[ "$output" != *"/shim"* ]]
    run sv doctor
    [ "$status" -eq 0 ]
    [[ "$output" != *SHIM_* ]]
    run sv shim status
    [ "$status" -eq 0 ]
    [[ "$output" == *"not installed"* ]]
    [ ! -e "$HOME/.local/share/selves" ]
}

# bats test_tags=core
@test "T53 shim routes non-interactive calls through the folder binding" {
    sv create work >/dev/null
    mkdir -p "$HOME/proj"; (cd "$HOME/proj" && sv bind work >/dev/null)
    run sv shim install
    [ "$status" -eq 0 ]
    SHIM="$HOME/.local/share/selves/shim/claude"
    [ -x "$SHIM" ]
    cd "$HOME/proj"
    run "$SHIM" -p hi
    [ "$status" -eq 0 ]
    [ "$(last_call)" = "CONFIG_DIR=$HOME/.claude-work ACTIVE=work ARGS=-p hi" ]
}

# bats test_tags=core
@test "T54 explicit run skips the shim and keeps the requested profile" {
    sv create work >/dev/null; sv create personal >/dev/null
    mkdir -p "$HOME/proj"; (cd "$HOME/proj" && sv bind work >/dev/null)
    sv shim install >/dev/null
    export PATH="$HOME/.local/share/selves/shim:$PATH"
    cd "$HOME/proj"
    run sv run personal -- x
    [ "$status" -eq 0 ]
    [ "$(last_call)" = "CONFIG_DIR=$HOME/.claude-personal ACTIVE=personal ARGS=x" ]
    run sv doctor
    [[ "$output" != *SHIM_* ]]
}

# bats test_tags=core
@test "T55 init puts the shim first in PATH once installed" {
    sv shim install >/dev/null
    run bash -c 'eval "$("$SELVES_BIN" init bash)"; type -P claude'
    [ "$output" = "$HOME/.local/share/selves/shim/claude" ]
    run bash -c 'eval "$("$SELVES_BIN" init bash)"; eval "$("$SELVES_BIN" init bash)"; echo "$PATH" | tr ":" "\n" | grep -c "selves/shim"'
    [ "$output" = "1" ]
}

# bats test_tags=core
@test "T56 shim remove only deletes a selves shim" {
    sv shim install >/dev/null
    run sv shim remove
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/.local/share/selves/shim/claude" ]
    mkdir -p "$HOME/.local/share/selves/shim"; echo "#!/bin/sh" > "$HOME/.local/share/selves/shim/claude"
    run sv shim remove
    [ "$status" -eq 1 ]
    [ -e "$HOME/.local/share/selves/shim/claude" ]
    run sv shim install
    [ "$status" -eq 1 ]
}

# bats test_tags=core
@test "T57 doctor reports a stale or misplaced shim" {
    REAL="$HOME/realbin"; mkdir -p "$REAL"; cp "$HOME/bin/claude" "$REAL/claude"
    SELVES_CLAUDE_BIN="$REAL/claude" sv shim install >/dev/null
    run sv doctor
    [ "$status" -eq 3 ]
    [[ "$output" == *SHIM_NOT_FIRST* ]]
    rm -f "$REAL/claude"
    export PATH="$HOME/.local/share/selves/shim:$PATH"
    run sv doctor
    [[ "$output" == *SHIM_STALE* ]]
    [[ "$output" != *SHIM_NOT_FIRST* ]]
}
