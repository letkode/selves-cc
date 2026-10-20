# Security policy

## Supported versions

Only the latest release receives fixes. Upgrade before reporting:

```bash
selves version
```

## Reporting a vulnerability

Please **do not open a public issue**. Use GitHub's private reporting instead:
**Security** tab → **Report a vulnerability**.

Include the selves version, your OS and shell, and the steps to reproduce. You should get a first answer within a week.

## What selves does with your accounts

selves is designed to stay out of the way of your credentials:

- It **never reads, copies, prints or sends** credential contents. It only checks whether a credential file exists, to show login status.
- It makes **no network requests** and has no telemetry.
- It launches Claude Code with a different `CLAUDE_CONFIG_DIR`; it does not proxy or modify API traffic.
- It writes only to `~/.claude*`, its config folder, `.selves` files in folders you bind, and the optional shim folder. Startup files are changed only by `selves migrate` and `selves dotfiles install`, after making a backup.
- `selves dotfiles export` never includes credentials, `.claude.json` or history, and warns about literal secrets before you commit.

## Verifying a release

Each release ships a `SHA256SUMS` file:

```bash
sha256sum -c SHA256SUMS
```
