---
name: lg-thinq-universal
description: Universal LG ThinQ device setup and control. Discovers LG ThinQ appliances and generates secure device skills. Use when: (1) Setting up LG ThinQ integration, (2) Controlling LG AC/refrigerator/devices, (3) Creating device-specific skills.
version: 0.5.0
requires:
  env:
    - LG_PAT
    - LG_COUNTRY
---

# LG ThinQ Universal

## Goal

Provide secure, automated integration for LG ThinQ devices without credential exposure or secret duplication. One-time setup discovers all devices; each device gets its own specialized skill.

## Required Credentials

| Variable | Description |
|----------|-------------|
| `LG_PAT` | Personal Access Token from LG ThinQ app (sensitive) |
| `LG_COUNTRY` | 2-letter ISO code (IN, US, GB, etc.) |

**Security**: Shell environment variables are preferred. A `.env` file in the project root is also supported. API server URL is cached in `.api_server_cache`.

## Quick Start

```bash
./setup.sh    # Linux/macOS
.\setup.ps1   # Windows
```

Setup script: creates venv, installs dependencies, validates config, discovers API server, fetches all device profiles.

## Security Protocol (Mandatory)

The agent **MUST** follow these hard mandates:

1. **Ask First**: Use `ask_user` before every network call, file write, or memory entry
2. **Zero-Leak**: Never ask user to paste `LG_PAT` into chat
3. **Shell Env Preferred**: Set credentials in shell env. `.env` in project root supported but shell takes precedence
4. **Minimal Credentials**: Only `LG_DEVICE_ID` in skill's `.env`. Never duplicate `LG_PAT` or `LG_COUNTRY`

## After Setup

1. **Select Device**: From setup output, choose device(s) to integrate
2. **Generate Control Script**: Create device-specific control script
3. **Create Skill**: Build skill for the device
4. **Verify**: Test the skill works
5. **Memory**: Save trigger phrase to memory (with consent)

See `references/skill-creation.md` for complete workflow.

## API Tool Commands

```bash
python scripts/lg_api_tool.py check-config              # Validate setup
python scripts/lg_api_tool.py list-devices             # List all devices
python scripts/lg_api_tool.py get-profile <id>         # Get device capabilities
python scripts/lg_api_tool.py get-state <id>            # Current state
python scripts/lg_api_tool.py control <id> <cat> <prop> <value>  # Control
python scripts/lg_api_tool.py --help                    # Full help
```

## Generated Control Script

```bash
python lg_control.py --help    # Show all commands
python lg_control.py status    # Current state
python lg_control.py on       # Power on
python lg_control.py off      # Power off
python lg_control.py temp 24  # Set temperature
```

## References

| Document | Purpose |
|----------|---------|
| `references/manual-setup.md` | Manual setup without setup.sh |
| `references/api-reference.md` | API headers, endpoints, x-conditional-control |
| `references/skill-creation.md` | Complete post-setup workflow |
| `references/skill-generation-guide.md` | How to structure device SKILL.md |
| `references/device-example.md` | Complete example of generated skill |
| `references/public_api_constants.json` | API constants (not secrets) |
