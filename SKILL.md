---
name: lg-thinq-universal
description: Universal LG ThinQ device manager. Discovers appliances (AC, Refrigerator, Washer, etc.) and generates secure, device-specific OpenClaw skills. Use when the user wants to: (1) Integrate LG ThinQ devices, (2) Know how to get an LG PAT token, (3) Discover new LG appliances, (4) Create specialized control skills for their home automation.
version: 0.5.0
requires:
  env:
    - LG_PAT
    - LG_COUNTRY
---

# LG ThinQ Universal Manager

## 🎯 Goal
Provide a secure, automated gateway for LG ThinQ device integration. This skill acts as a **discovery engine** and **skill generator**, allowing users to control their appliances via OpenClaw without duplicating sensitive credentials across multiple files.

## 🔑 Obtaining Credentials
If the user asks how to get their tokens, provide these instructions:

1.  **Visit the Portal**: [https://connect-pat.lgthinq.com](https://connect-pat.lgthinq.com)
2.  **Log In**: Use your official LG ThinQ account.
3.  **Create Token**: Click "ADD NEW TOKEN", give it a name (e.g., "OpenClaw"), and select the required features.
4.  **Copy PAT**: Copy the generated Personal Access Token (PAT) immediately.
5.  **Identify Country**: Use your 2-letter ISO country code (e.g., `US`, `IN`, `GB`).

## 🛠️ Prerequisites
The agent **MUST** ensure the following are set before proceeding:
1.  **`LG_PAT`**: Stored in shell environment or `.env`.
2.  **`LG_COUNTRY`**: Stored in shell environment or `.env`.

## 🔄 Agent Workflow (Mandatory)

Follow these steps in order when a user requests setup:

### Step 1: Verify Configuration
Check if `LG_PAT` and `LG_COUNTRY` are present. Use the tool to verify:
```bash
python scripts/lg_api_tool.py check-config
```

### Step 2: Run Automated Discovery
Execute the setup script to prepare the environment and fetch profiles:
```bash
./setup.sh
```
*Note: If on Windows, use `.\setup.ps1`.*

### Step 3: Parse and Present Devices
Review the output from `setup.sh`. Present the list of discovered devices (`name`, `type`, `id`) to the user and ask which ones to integrate.

### Step 4: Generate Device-Specific Skills
For each selected device, follow `references/skill-creation.md`:
1.  **Generate Script**: Use `scripts/generate_control_script.py` with the fetched profile.
2.  **Create Skill Directory**: Target `~/.openclaw/workspaces/skills/lg-{type}-{location}`.
3.  **Deploy Files**: Move `lg_control.py`, copy `scripts/lg_api_tool.py`, and create a local `.env` with **ONLY** the `LG_DEVICE_ID`.
4.  **Create SKILL.md**: Use `references/skill-generation-guide.md` to build the device skill.

## ⌨️ Universal Management Commands

Use these commands for maintenance and discovery:

| Command | Description | Use Case |
|---------|-------------|----------|
| `python scripts/lg_api_tool.py list-devices` | List all linked appliances | Verify connectivity |
| `python scripts/lg_api_tool.py save-route` | Discover regional server | Fix "Route not found" errors |
| `python scripts/lg_api_tool.py get-state <id>` | Get raw device state | Deep debugging |
| `python scripts/lg_api_tool.py --help` | Show all API tool options | Explore advanced features |

## 🛡️ Security Mandates
1.  **Zero-Leak Policy**: NEVER ask the user to paste their `LG_PAT` into the chat.
2.  **Credential Isolation**: NEVER copy `LG_PAT` into generated device skill directories.
3.  **Confirmation Protocol**: Use `ask_user` before every network call, file write, or memory entry.
4.  **Local-Only**: All API communication must remain local.

## 📚 References

| Document | Purpose |
|----------|---------|
| `references/skill-creation.md` | Detailed post-setup workflow for creating device skills |
| `references/skill-generation-guide.md` | Instructions for building device-specific SKILL.md files |
| `references/manual-setup.md` | Manual installation steps (without setup scripts) |
| `references/api-reference.md` | Technical details on API headers and control logic |
| `references/device-example.md` | Complete example of a generated device skill |
| `references/public_api_constants.json` | Public API keys and constants used by the scripts |

## 🚨 Error Handling

| Symptom | Resolution |
|---------|------------|
| `401 Unauthorized` | Token expired. Guide user to [https://connect-pat.lgthinq.com](https://connect-pat.lgthinq.com). |
| `No devices found` | Verify device is added to the official **LG ThinQ App** on mobile first. |
| `Permission denied` | Run `chmod +x setup.sh`. |
