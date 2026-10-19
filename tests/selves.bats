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
