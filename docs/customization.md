# Customization Guide

## Changing Your Agent's Personality

Edit `~/.openclaw/workspace/SOUL.md`. This is the agent's core identity file — it defines personality, tone, and values.

## Adding Skills

OpenClaw has a skill marketplace. Browse and install:

```bash
# Search for skills
clawhub search "image generation"

# Install a skill
clawhub install openai-image-gen

# Configure the skill
openclaw config set skills.entries.openai-image-gen.apiKey '${OPENAI_API_KEY}'
```

## Adding More Discord Channels

1. Create the channel in Discord
2. Add it to your config:
```bash
openclaw config set channels.discord.guilds.YOUR_GUILD_ID.channels.NEW_CHANNEL_ID.allow true
```
3. Restart: `openclaw gateway restart`

## Binding an Agent to a Channel

Add a binding in `openclaw.json`:
```json
{
  "bindings": [
    {
      "agentId": "your-agent-id",
      "match": {
        "channel": "discord",
        "peer": {
          "kind": "channel",
          "id": "CHANNEL_ID"
        }
      }
    }
  ]
}
```

## Changing Models

```bash
# Set default model
openclaw config set agents.defaults.model.primary "provider/model-name"

# Set model for a specific agent
openclaw config set agents.list.1.model.primary "provider/model-name"
```

## Memory & Context

- **Daily notes:** Agents write to `memory/YYYY-MM-DD.md` automatically
- **Long-term memory:** Create a `MEMORY.md` for curated persistent context
- **Heartbeat tasks:** Add periodic checks to `HEARTBEAT.md`

## Queue Tuning

The default config uses `interrupt` mode which is best for Discord (responds to latest message, drops stale ones). If you want to process all messages in order, change to `collect`:

```bash
openclaw config set messages.queue.mode "collect"
```
