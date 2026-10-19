# Shared harness for the selves acceptance suite (SPEC.md §13).
# Black-box: only the binary in $SELVES_BIN is invoked.

setup_home() {
    export SELVES_BIN="${SELVES_BIN:-$BATS_TEST_DIRNAME/../bin/selves}"
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME/bin"
    unset XDG_CONFIG_HOME SELVES_CONFIG_DIR SELVES_QUIET SELVES_SHARED SELVES_CLAUDE_BIN \
          SELVES_NO_REPAIR CLAUDE_CONFIG_DIR ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN
    export NO_COLOR=1 SHELL=/bin/bash

    # Fake claude: records how it was launched
    cat > "$HOME/bin/claude" <<'FAKE'
#!/usr/bin/env bash
if [ "${1:-} ${2:-}" = "mcp add-json" ]; then echo "MCP=${5:-} CONFIG_DIR=${CLAUDE_CONFIG_DIR-<unset>}" >> "$HOME/claude-calls.log"; exit 0; fi
echo "CONFIG_DIR=${CLAUDE_CONFIG_DIR-<unset>} ACTIVE=${SELVES_ACTIVE_PROFILE:-} ARGS=$*" >> "$HOME/claude-calls.log"
FAKE
    chmod +x "$HOME/bin/claude"
    export PATH="$HOME/bin:$PATH"

    # A typical base: shared skills and instructions
    mkdir -p "$HOME/.claude/skills/generic" "$HOME/.claude/rules"
    echo "# global" > "$HOME/.claude/CLAUDE.md"
    echo "x" > "$HOME/.claude/skills/generic/SKILL.md"
    cd "$HOME"
}

sv()        { "$SELVES_BIN" "$@"; }
last_call() { tail -n1 "$HOME/claude-calls.log"; }
calls()     { [ -f "$HOME/claude-calls.log" ] && wc -l < "$HOME/claude-calls.log" | tr -d ' ' || echo 0; }
is_lite()   { "$SELVES_BIN" version | grep -q '^selves-lite'; }
skip_if_lite() { if is_lite; then skip "full edition only"; fi; }
mode_of()   { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }
