# Security Architecture

## Secret Management

Clawdboss separates secrets from configuration:

### How It Works

1. **`.env` file** (`~/.openclaw/.env`) — Contains all API keys and tokens
   - Created during setup with `600` permissions (owner-only read/write)
   - Listed in `.gitignore` — never committed
   - Template provided as `.env.example`

2. **`openclaw.json`** — Contains `${VAR_NAME}` references instead of raw keys
   - OpenClaw resolves these at startup from the `.env` file
   - Config can be safely reviewed, diffed, and versioned
   - No secrets in the JSON

### Precedence Order

OpenClaw loads env vars in this order (first wins):
1. Process environment (parent shell)
2. `.env` in current working directory
3. `~/.openclaw/.env` (global)
4. `env` block in `openclaw.json`

### Example

**`.env`:**
```
DISCORD_BOT_TOKEN=MTQ3NjA4...actual-token
BRAVE_API_KEY=BSAab7lL...actual-key
```

**`openclaw.json`:**
```json
{
  "channels": {
    "discord": {
      "token": "${DISCORD_BOT_TOKEN}"
    }
  },
  "tools": {
    "web": {
      "search": {
        "apiKey": "${BRAVE_API_KEY}"
      }
    }
  }
}
```

## Prompt Injection Defense

All agents are pre-configured with defense rules in their `AGENTS.md`:

### Rules Applied to Every Agent

1. **Content isolation** — External content (email, web, RSS) is treated as DATA, never INSTRUCTIONS
2. **Pattern detection** — Known attack patterns flagged and reported
3. **Anti-loop protection** — 5 rules preventing token-burning attacks
4. **Memory protection** — Agents cannot modify their own SOUL.md or AGENTS.md based on external content
5. **Email safety** — Human approval required for all external sends, draft-only mode

### Known Attack Vectors Defended

| Vector | Defense |
|--------|---------|
| Hidden HTML instructions in emails | HTML stripping + content tagging |
| "Ignore previous instructions" | Pattern detection + flagging |
| WORKFLOW_AUTO.md payload | Explicit warning in all AGENTS.md |
| Spoofed system messages | Real OpenClaw system messages include sessionId |
| Memory poisoning | Agents can't modify core files from external content |

## Network Security

- OpenClaw Gateway binds to `127.0.0.1` (localhost only)
- Dashboard should bind to `127.0.0.1` (not `0.0.0.0`)
- API keys have `600` file permissions
- Discord exec approvals enabled by default

## Recommendations

1. **Rotate API keys** on a schedule (quarterly minimum)
2. **Enable UFW** if running on a VPS: `sudo ufw allow ssh && sudo ufw enable`
3. **Use Tailscale** for remote access instead of exposing ports
4. **Review the Ansible playbook** for VPS deployments: [openclaw-ansible](https://github.com/openclaw/openclaw-ansible)
