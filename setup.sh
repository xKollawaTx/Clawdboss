#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Clawdboss Setup Wizard
# Pre-hardened, multi-agent OpenClaw setup by NanoFlow
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/templates"
OPENCLAW_DIR="${OPENCLAW_STATE_DIR:-$HOME/.openclaw}"
ENV_FILE="$OPENCLAW_DIR/.env"
CONFIG_FILE="$OPENCLAW_DIR/openclaw.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

banner() {
  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║${NC}  ${BOLD}🦞 Clawdboss Setup Wizard${NC}                    ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}  Pre-hardened OpenClaw by NanoFlow            ${CYAN}║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
  echo ""
}

info()    { echo -e "${BLUE}ℹ${NC}  $1"; }
success() { echo -e "${GREEN}✅${NC} $1"; }
warn()    { echo -e "${YELLOW}⚠️${NC}  $1"; }
error()   { echo -e "${RED}❌${NC} $1"; }
ask()     { echo -en "${CYAN}?${NC}  $1: "; }

# Generate a random token
random_token() {
  openssl rand -hex 32 2>/dev/null || python3 -c "import secrets; print(secrets.token_hex(32))" 2>/dev/null || head -c 64 /dev/urandom | xxd -p -c 64
}

# ============================================================
# Pre-flight checks
# ============================================================

preflight() {
  info "Running pre-flight checks..."

  if ! command -v node &>/dev/null; then
    error "Node.js not found. Install it first:"
    echo "  curl -fsSL https://openclaw.ai/install.sh | bash"
    exit 1
  fi

  NODE_VERSION=$(node -v | sed 's/v//' | cut -d. -f1)
  if [ "$NODE_VERSION" -lt 22 ]; then
    error "Node.js 22+ required (found v$(node -v))"
    exit 1
  fi
  success "Node.js $(node -v)"

  if ! command -v openclaw &>/dev/null; then
    warn "OpenClaw not found. Installing..."
    npm install -g openclaw@latest
  fi
  success "OpenClaw $(openclaw --version 2>/dev/null | head -1)"

  mkdir -p "$OPENCLAW_DIR"
  success "State directory: $OPENCLAW_DIR"
  echo ""
}

# ============================================================
# Collect user info
# ============================================================

collect_user_info() {
  echo -e "${BOLD}--- Your Info ---${NC}"
  echo ""

  ask "Your name"
  read -r USER_NAME
  USER_NAME="${USER_NAME:-User}"

  ask "Your timezone (e.g., America/Los_Angeles, Europe/London)"
  read -r USER_TIMEZONE
  USER_TIMEZONE="${USER_TIMEZONE:-UTC}"

  echo ""
}

# ============================================================
# Collect agent info
# ============================================================

collect_agent_info() {
  echo -e "${BOLD}--- Main Agent ---${NC}"
  echo ""

  ask "Agent name (e.g., Atlas, Nova, Jarvis)"
  read -r AGENT_NAME
  AGENT_NAME="${AGENT_NAME:-Assistant}"

  ask "Agent pronouns (e.g., they/them, she/her, he/him)"
  read -r AGENT_PRONOUNS
  AGENT_PRONOUNS="${AGENT_PRONOUNS:-they/them}"

  ask "Agent emoji (e.g., 🤖, 🦊, ⚡)"
  read -r AGENT_EMOJI
  AGENT_EMOJI="${AGENT_EMOJI:-🤖}"

  echo ""
  echo -e "${BOLD}--- Agent Tier ---${NC}"
  echo ""
  echo "  1) Solo     — Main agent only (simplest)"
  echo "  2) Team     — Main + Comms + Research agents"
  echo "  3) Squad    — Main + Comms + Research + Security agents"
  echo ""
  ask "Choose tier [1/2/3]"
  read -r TIER_CHOICE
  TIER_CHOICE="${TIER_CHOICE:-1}"

  DEPLOY_COMMS=false
  DEPLOY_RESEARCH=false
  DEPLOY_SECURITY=false

  case "$TIER_CHOICE" in
    3)
      DEPLOY_COMMS=true
      DEPLOY_RESEARCH=true
      DEPLOY_SECURITY=true
      ;;
    2)
      DEPLOY_COMMS=true
      DEPLOY_RESEARCH=true
      ;;
    *)
      ;;
  esac

  # Collect specialist agent names if deploying
  if [ "$DEPLOY_COMMS" = true ]; then
    ask "Comms agent name (default: Knox)"
    read -r COMMS_NAME
    COMMS_NAME="${COMMS_NAME:-Knox}"
  fi

  if [ "$DEPLOY_RESEARCH" = true ]; then
    ask "Research agent name (default: Trace)"
    read -r RESEARCH_NAME
    RESEARCH_NAME="${RESEARCH_NAME:-Trace}"
  fi

  if [ "$DEPLOY_SECURITY" = true ]; then
    ask "Security agent name (default: Sentinel)"
    read -r SECURITY_NAME
    SECURITY_NAME="${SECURITY_NAME:-Sentinel}"
  fi

  echo ""
}

# ============================================================
# Collect API keys
# ============================================================

collect_keys() {
  echo -e "${BOLD}--- API Keys ---${NC}"
  echo ""
  info "Keys are stored in $ENV_FILE (gitignored, never committed)"
  echo ""

  # LLM Provider
  echo -e "${BOLD}LLM Provider:${NC}"
  echo "  1) GitHub Copilot proxy (free with Copilot subscription)"
  echo "  2) OpenAI API direct"
  echo "  3) Anthropic API direct"
  echo "  4) Other (manual config later)"
  echo ""
  ask "Choose provider [1/2/3/4]"
  read -r PROVIDER_CHOICE
  PROVIDER_CHOICE="${PROVIDER_CHOICE:-1}"

  case "$PROVIDER_CHOICE" in
    1)
      LLM_PROVIDER="copilot"
      info "Copilot proxy will be configured on localhost:4141"
      info "Make sure copilot-api is running: npx copilot-api start --port 4141"
      COPILOT_API_KEY="copilot-proxy-local"
      ;;
    2)
      LLM_PROVIDER="openai"
      ask "OpenAI API key (sk-...)"
      read -rs OPENAI_DIRECT_KEY
      echo ""
      ;;
    3)
      LLM_PROVIDER="anthropic"
      ask "Anthropic API key (sk-ant-...)"
      read -rs ANTHROPIC_KEY
      echo ""
      ;;
    4)
      LLM_PROVIDER="manual"
      warn "You'll need to configure the model provider in openclaw.json manually"
      ;;
  esac

  echo ""

  # Discord
  echo -e "${BOLD}Discord:${NC}"
  ask "Discord bot token"
  read -rs DISCORD_TOKEN
  echo ""

  ask "Discord guild (server) ID"
  read -r DISCORD_GUILD

  ask "Your Discord user ID"
  read -r DISCORD_OWNER

  # Channel IDs
  ask "Main agent channel ID (the channel your bot talks in)"
  read -r DISCORD_MAIN_CHANNEL

  if [ "$DEPLOY_COMMS" = true ]; then
    ask "Comms agent channel ID"
    read -r DISCORD_COMMS_CHANNEL
  fi

  if [ "$DEPLOY_RESEARCH" = true ]; then
    ask "Research agent channel ID"
    read -r DISCORD_RESEARCH_CHANNEL
  fi

  if [ "$DEPLOY_SECURITY" = true ]; then
    ask "Security agent channel ID"
    read -r DISCORD_SECURITY_CHANNEL
  fi

  echo ""

  # Brave Search
  echo -e "${BOLD}Web Search (optional):${NC}"
  ask "Brave Search API key (press Enter to skip)"
  read -rs BRAVE_KEY
  echo ""

  # OpenAI for skills/embeddings
  if [ "$LLM_PROVIDER" != "openai" ]; then
    echo ""
    echo -e "${BOLD}OpenAI (for image gen / whisper / embeddings — optional):${NC}"
    ask "OpenAI API key (press Enter to skip)"
    read -rs OPENAI_SKILLS_KEY
    echo ""
  else
    OPENAI_SKILLS_KEY="$OPENAI_DIRECT_KEY"
  fi

  # ElevenLabs
  echo ""
  echo -e "${BOLD}ElevenLabs TTS (optional):${NC}"
  ask "ElevenLabs API key (press Enter to skip)"
  read -rs ELEVENLABS_KEY
  echo ""

  echo ""
}

# ============================================================
# Generate .env file
# ============================================================

generate_env() {
  info "Generating $ENV_FILE..."

  GATEWAY_TOKEN=$(random_token)

  cat > "$ENV_FILE" << ENVEOF
# ============================================================
# Clawdboss Environment — Generated $(date +%Y-%m-%d)
# DO NOT COMMIT THIS FILE
# ============================================================

# LLM Provider
COPILOT_API_KEY=${COPILOT_API_KEY:-}
ENVEOF

  if [ "$LLM_PROVIDER" = "openai" ]; then
    echo "OPENAI_API_KEY=${OPENAI_DIRECT_KEY}" >> "$ENV_FILE"
  elif [ "$LLM_PROVIDER" = "anthropic" ]; then
    echo "ANTHROPIC_API_KEY=${ANTHROPIC_KEY}" >> "$ENV_FILE"
  fi

  cat >> "$ENV_FILE" << ENVEOF

# Discord
DISCORD_BOT_TOKEN=${DISCORD_TOKEN}

# Web Search
BRAVE_API_KEY=${BRAVE_KEY:-}

# Skills
OPENAI_API_KEY=${OPENAI_SKILLS_KEY:-}
ELEVENLABS_API_KEY=${ELEVENLABS_KEY:-}

# Embeddings (memory-hybrid)
EMBEDDING_API_KEY=${OPENAI_SKILLS_KEY:-}

# Gateway
GATEWAY_AUTH_TOKEN=${GATEWAY_TOKEN}
ENVEOF

  chmod 600 "$ENV_FILE"
  success "Environment file created (permissions: 600)"
}

# ============================================================
# Generate openclaw.json from template
# ============================================================

generate_config() {
  info "Generating $CONFIG_FILE..."

  local WORKSPACE_DIR="$OPENCLAW_DIR/workspace"
  mkdir -p "$WORKSPACE_DIR"

  # Start from template
  local CONFIG
  CONFIG=$(cat "$TEMPLATES_DIR/openclaw.template.json")

  # Replace placeholders
  CONFIG=$(echo "$CONFIG" | sed "s|__WORKSPACE_DIR__|$WORKSPACE_DIR|g")
  CONFIG=$(echo "$CONFIG" | sed "s|__DISCORD_GUILD_ID__|$DISCORD_GUILD|g")
  CONFIG=$(echo "$CONFIG" | sed "s|__DISCORD_OWNER_ID__|$DISCORD_OWNER|g")

  # Add main channel to allowed channels
  CONFIG=$(echo "$CONFIG" | python3 -c "
import json, sys
config = json.load(sys.stdin)
guild = config['channels']['discord']['guilds']['$DISCORD_GUILD']
guild['channels']['$DISCORD_MAIN_CHANNEL'] = {'allow': True}
" 2>/dev/null || echo "$CONFIG")

  # Use python3 to properly build the config with agent tiers
  python3 << PYEOF > "$CONFIG_FILE"
import json

with open("$TEMPLATES_DIR/openclaw.template.json") as f:
    config = json.load(f)

# Fix workspace
config['agents']['list'][0]['workspace'] = "$WORKSPACE_DIR"

# Fix guild/owner placeholders
guild_id = "$DISCORD_GUILD"
owner_id = "$DISCORD_OWNER"

config['channels']['discord']['allowFrom'] = [owner_id]
config['channels']['discord']['execApprovals']['approvers'] = [owner_id]

# Replace guild placeholder
old_guilds = config['channels']['discord']['guilds']
config['channels']['discord']['guilds'] = {
    guild_id: {
        "requireMention": False,
        "users": [owner_id],
        "channels": {
            "$DISCORD_MAIN_CHANNEL": {"allow": True}
        }
    }
}

# Fix bindings
config['bindings'] = [{
    "agentId": "main",
    "match": {"channel": "discord", "guildId": guild_id}
}]

# Agent allow list starts with main
allow_agents = ["main"]

# Add specialist agents based on tier
if "$DEPLOY_COMMS" == "true":
    comms_id = "${COMMS_NAME:-Knox}".lower()
    comms_workspace = "$OPENCLAW_DIR/workspace-" + comms_id
    allow_agents.append(comms_id)

    config['agents']['list'].append({
        "id": comms_id,
        "name": "${COMMS_NAME:-Knox}",
        "workspace": comms_workspace,
        "agentDir": "$OPENCLAW_DIR/agents/" + comms_id + "/agent",
        "model": {"primary": "copilot/claude-sonnet-4.5"},
        "identity": {"name": "${COMMS_NAME:-Knox}", "emoji": "📡"}
    })

    config['bindings'].insert(0, {
        "agentId": comms_id,
        "match": {"channel": "discord", "peer": {"kind": "channel", "id": "${DISCORD_COMMS_CHANNEL:-}"}}
    })

    config['channels']['discord']['guilds'][guild_id]['channels']["${DISCORD_COMMS_CHANNEL:-}"] = {"allow": True}

if "$DEPLOY_RESEARCH" == "true":
    research_id = "${RESEARCH_NAME:-Trace}".lower()
    research_workspace = "$OPENCLAW_DIR/workspace-" + research_id
    allow_agents.append(research_id)

    config['agents']['list'].append({
        "id": research_id,
        "name": "${RESEARCH_NAME:-Trace}",
        "workspace": research_workspace,
        "agentDir": "$OPENCLAW_DIR/agents/" + research_id + "/agent",
        "model": {"primary": "copilot/claude-sonnet-4.5"},
        "identity": {"name": "${RESEARCH_NAME:-Trace}", "emoji": "🔍"}
    })

    config['bindings'].insert(0, {
        "agentId": research_id,
        "match": {"channel": "discord", "peer": {"kind": "channel", "id": "${DISCORD_RESEARCH_CHANNEL:-}"}}
    })

    config['channels']['discord']['guilds'][guild_id]['channels']["${DISCORD_RESEARCH_CHANNEL:-}"] = {"allow": True}

if "$DEPLOY_SECURITY" == "true":
    security_id = "${SECURITY_NAME:-Sentinel}".lower()
    security_workspace = "$OPENCLAW_DIR/workspace-" + security_id
    allow_agents.append(security_id)

    config['agents']['list'].append({
        "id": security_id,
        "name": "${SECURITY_NAME:-Sentinel}",
        "workspace": security_workspace,
        "agentDir": "$OPENCLAW_DIR/agents/" + security_id + "/agent",
        "model": {"primary": "copilot/claude-sonnet-4.5"},
        "identity": {"name": "${SECURITY_NAME:-Sentinel}", "emoji": "🛡️"}
    })

    config['bindings'].insert(0, {
        "agentId": security_id,
        "match": {"channel": "discord", "peer": {"kind": "channel", "id": "${DISCORD_SECURITY_CHANNEL:-}"}}
    })

    config['channels']['discord']['guilds'][guild_id]['channels']["${DISCORD_SECURITY_CHANNEL:-}"] = {"allow": True}

# Set allow lists
config['agents']['list'][0]['subagents']['allowAgents'] = allow_agents

if len(allow_agents) > 1:
    config['tools']['agentToAgent'] = {
        "enabled": True,
        "allow": allow_agents
    }

# LLM provider config
provider = "$LLM_PROVIDER"
if provider == "openai":
    config['models']['providers'] = {
        "openai": {
            "apiKey": "\${OPENAI_API_KEY}",
            "models": [
                {"id": "gpt-4o", "name": "GPT-4o", "input": ["text", "image"], "contextWindow": 128000, "maxTokens": 16384},
                {"id": "gpt-4o-mini", "name": "GPT-4o Mini", "input": ["text", "image"], "contextWindow": 128000, "maxTokens": 16384}
            ]
        }
    }
    config['agents']['defaults']['model']['primary'] = "openai/gpt-4o"
    config['agents']['defaults']['heartbeat']['model'] = "openai/gpt-4o-mini"
elif provider == "anthropic":
    config['models']['providers'] = {
        "anthropic": {
            "apiKey": "\${ANTHROPIC_API_KEY}",
            "models": [
                {"id": "claude-sonnet-4-5-20250514", "name": "Claude Sonnet 4.5", "input": ["text", "image"], "contextWindow": 200000, "maxTokens": 16384}
            ]
        }
    }
    config['agents']['defaults']['model']['primary'] = "anthropic/claude-sonnet-4-5-20250514"

# Skills with keys
if "${OPENAI_SKILLS_KEY:-}":
    config['skills']['entries']['openai-image-gen'] = {"apiKey": "\${OPENAI_API_KEY}"}
    config['skills']['entries']['openai-whisper-api'] = {"apiKey": "\${OPENAI_API_KEY}"}

if "${ELEVENLABS_KEY:-}":
    config['skills']['entries']['sag'] = {"apiKey": "\${ELEVENLABS_API_KEY}"}

print(json.dumps(config, indent=2))
PYEOF

  chmod 600 "$CONFIG_FILE"
  success "Config generated with \${VAR} references (permissions: 600)"
}

# ============================================================
# Deploy workspace files
# ============================================================

deploy_workspaces() {
  info "Deploying workspace files..."

  local WORKSPACE_DIR="$OPENCLAW_DIR/workspace"
  mkdir -p "$WORKSPACE_DIR/memory"

  # Main workspace — copy and personalize
  for f in AGENTS.md SOUL.md USER.md IDENTITY.md TOOLS.md HEARTBEAT.md; do
    if [ -f "$TEMPLATES_DIR/workspace/$f" ]; then
      sed -e "s|__AGENT_NAME__|$AGENT_NAME|g" \
          -e "s|__AGENT_PRONOUNS__|$AGENT_PRONOUNS|g" \
          -e "s|__AGENT_EMOJI__|$AGENT_EMOJI|g" \
          -e "s|__USER_NAME__|$USER_NAME|g" \
          -e "s|__USER_TIMEZONE__|$USER_TIMEZONE|g" \
          "$TEMPLATES_DIR/workspace/$f" > "$WORKSPACE_DIR/$f"
    fi
  done
  success "Main workspace: $WORKSPACE_DIR"

  # Specialist workspaces
  if [ "$DEPLOY_COMMS" = true ]; then
    local COMMS_ID
    COMMS_ID=$(echo "$COMMS_NAME" | tr '[:upper:]' '[:lower:]')
    local COMMS_WS="$OPENCLAW_DIR/workspace-$COMMS_ID"
    mkdir -p "$COMMS_WS/memory"
    mkdir -p "$OPENCLAW_DIR/agents/$COMMS_ID/agent"

    cp "$TEMPLATES_DIR/workspace/AGENTS.md" "$COMMS_WS/AGENTS.md"
    sed "s|__AGENT_NAME__|$COMMS_NAME|g" "$TEMPLATES_DIR/agents/comms/SOUL.md" > "$COMMS_WS/SOUL.md"
    sed -e "s|__USER_NAME__|$USER_NAME|g" -e "s|__USER_TIMEZONE__|$USER_TIMEZONE|g" "$TEMPLATES_DIR/workspace/USER.md" > "$COMMS_WS/USER.md"
    cp "$TEMPLATES_DIR/workspace/TOOLS.md" "$COMMS_WS/TOOLS.md"
    success "Comms workspace: $COMMS_WS"
  fi

  if [ "$DEPLOY_RESEARCH" = true ]; then
    local RESEARCH_ID
    RESEARCH_ID=$(echo "$RESEARCH_NAME" | tr '[:upper:]' '[:lower:]')
    local RESEARCH_WS="$OPENCLAW_DIR/workspace-$RESEARCH_ID"
    mkdir -p "$RESEARCH_WS/memory"
    mkdir -p "$OPENCLAW_DIR/agents/$RESEARCH_ID/agent"

    cp "$TEMPLATES_DIR/workspace/AGENTS.md" "$RESEARCH_WS/AGENTS.md"
    sed "s|__AGENT_NAME__|$RESEARCH_NAME|g" "$TEMPLATES_DIR/agents/research/SOUL.md" > "$RESEARCH_WS/SOUL.md"
    sed -e "s|__USER_NAME__|$USER_NAME|g" -e "s|__USER_TIMEZONE__|$USER_TIMEZONE|g" "$TEMPLATES_DIR/workspace/USER.md" > "$RESEARCH_WS/USER.md"
    cp "$TEMPLATES_DIR/workspace/TOOLS.md" "$RESEARCH_WS/TOOLS.md"
    success "Research workspace: $RESEARCH_WS"
  fi

  if [ "$DEPLOY_SECURITY" = true ]; then
    local SECURITY_ID
    SECURITY_ID=$(echo "$SECURITY_NAME" | tr '[:upper:]' '[:lower:]')
    local SECURITY_WS="$OPENCLAW_DIR/workspace-$SECURITY_ID"
    mkdir -p "$SECURITY_WS/memory"
    mkdir -p "$OPENCLAW_DIR/agents/$SECURITY_ID/agent"

    cp "$TEMPLATES_DIR/workspace/AGENTS.md" "$SECURITY_WS/AGENTS.md"
    sed "s|__AGENT_NAME__|$SECURITY_NAME|g" "$TEMPLATES_DIR/agents/security/SOUL.md" > "$SECURITY_WS/SOUL.md"
    sed -e "s|__USER_NAME__|$USER_NAME|g" -e "s|__USER_TIMEZONE__|$USER_TIMEZONE|g" "$TEMPLATES_DIR/workspace/USER.md" > "$SECURITY_WS/USER.md"
    cp "$TEMPLATES_DIR/workspace/TOOLS.md" "$SECURITY_WS/TOOLS.md"
    success "Security workspace: $SECURITY_WS"
  fi
}

# ============================================================
# Summary
# ============================================================

show_summary() {
  echo ""
  echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║${NC}  ${BOLD}✅ Clawdboss Setup Complete!${NC}                 ${GREEN}║${NC}"
  echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  ${BOLD}Agent:${NC}     $AGENT_NAME $AGENT_EMOJI"
  echo -e "  ${BOLD}Tier:${NC}      $([ "$TIER_CHOICE" = "1" ] && echo "Solo" || ([ "$TIER_CHOICE" = "2" ] && echo "Team" || echo "Squad"))"
  echo -e "  ${BOLD}Provider:${NC}  $LLM_PROVIDER"
  echo -e "  ${BOLD}Config:${NC}    $CONFIG_FILE"
  echo -e "  ${BOLD}Secrets:${NC}   $ENV_FILE"
  echo -e "  ${BOLD}Workspace:${NC} $OPENCLAW_DIR/workspace"
  echo ""

  if [ "$DEPLOY_COMMS" = true ]; then
    echo -e "  ${BOLD}Comms:${NC}     $COMMS_NAME 📡"
  fi
  if [ "$DEPLOY_RESEARCH" = true ]; then
    echo -e "  ${BOLD}Research:${NC}  $RESEARCH_NAME 🔍"
  fi
  if [ "$DEPLOY_SECURITY" = true ]; then
    echo -e "  ${BOLD}Security:${NC} $SECURITY_NAME 🛡️"
  fi

  echo ""
  echo -e "  ${BOLD}Next steps:${NC}"

  if [ "$LLM_PROVIDER" = "copilot" ]; then
    echo "    1. Start copilot proxy:  npx copilot-api start --port 4141"
    echo "    2. Start OpenClaw:       openclaw gateway start"
  else
    echo "    1. Start OpenClaw:       openclaw gateway start"
  fi

  echo "    2. Check status:         openclaw status"
  echo "    3. Open dashboard:       openclaw dashboard"
  echo ""
  echo -e "  ${BOLD}Security:${NC}"
  echo "    • API keys stored in $ENV_FILE (600 permissions)"
  echo "    • Config uses \${VAR} references — no plaintext keys"
  echo "    • All agents have prompt injection defense pre-configured"
  echo "    • Anti-loop rules prevent token-burning attacks"
  echo ""
}

# ============================================================
# Main
# ============================================================

main() {
  banner

  # Check for existing config
  if [ -f "$CONFIG_FILE" ]; then
    warn "Existing config found at $CONFIG_FILE"
    ask "Overwrite? This will backup the current config [y/N]"
    read -r OVERWRITE
    if [[ ! "$OVERWRITE" =~ ^[Yy] ]]; then
      info "Aborting. Your existing config is untouched."
      exit 0
    fi
    cp "$CONFIG_FILE" "${CONFIG_FILE}.bak.$(date +%s)"
    success "Backup created"
    echo ""
  fi

  preflight
  collect_user_info
  collect_agent_info
  collect_keys
  generate_env
  generate_config
  deploy_workspaces
  show_summary
}

main "$@"
