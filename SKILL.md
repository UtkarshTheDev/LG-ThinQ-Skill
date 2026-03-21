---
name: lg-thinq-universal
description: Universal LG ThinQ device manager. Discovers appliances (AC, Refrigerator, Washer, etc.) and generates secure, device-specific OpenClaw skills. Use when the user wants to: (1) Integrate LG ThinQ devices, (2) Know how to get an LG PAT token, (3) Discover new LG appliances, (4) Create specialized control skills for their home automation.
version: 0.5.0
requires:
  env:
    - LG_PAT
    - LG_COUNTRY
  vars:
    - LG_DEVICE_ID
  install: ./setup.sh
metadata:
  openclaw:
    emoji: "🔐"
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

### Step 2: Audit and Run Setup
The `./setup.sh` script prepares the discovery database.
**Mandatory Safety Flow**: 
1.  **Generate Manifest**: Run `./setup.sh` (without flags) to generate the Safety Manifest.
2.  **Brief User**: Present the Manifest to the user and explain exactly what actions will be performed.
3.  **Ask for Permission**: Use `ask_user` to obtain explicit consent.
4.  **Execute**: Only after approval, run: `./setup.sh --confirm`.

### Step 3: Device Selection
Review the output from setup. Present the list of discovered devices to the user and ask which ID they wish to integrate.

### Step 4: Assemble Workspace
Once an ID is selected, follow the same **Safety Flow**:
1.  **Generate Manifest**: Run `python3 scripts/assemble_device_workspace.py --id <DEVICE_ID>` (without the confirm flag).
2.  **Brief User**: Explain the specific directory and file operations listed in the manifest.
3.  **Ask for Permission**: Use `ask_user` to obtain consent.
4.  **Execute**: Only after approval, run: `python3 scripts/assemble_device_workspace.py --id <DEVICE_ID> --confirm`.
*Note: Use `--location name` to customize the directory.*

### Step 5: Document and Persist
After the assembly script completes:
1.  **Analyze**: Review the `[AVAILABLE COMMANDS]` and `[ENGINE CODE]` printed by the script.
2.  **Generate documentation**: Create a high-quality `SKILL.md` in the new directory using `references/device-skill-template.md` as a guide.
3.  **Persistence**: Save the trigger phrase, skill path, and command summary into the user's `MEMORY.md` file (using `save_memory`).

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
2.  **Credential Isolation**: NEVER copy `LG_PAT` or `LG_COUNTRY` into generated device skill directories. Only `LG_DEVICE_ID` is permitted in those locations.
3.  **Pre-Action Briefing**: Before every network call, file write, or device control command, the agent **MUST** explain exactly what it is about to perform (e.g., "I am going to save the API route to your local cache" or "I am going to create a new directory for your AC").
4.  **Confirmation Protocol**: After the briefing, ask for user permission using `ask_user` before executing the command.
5.  **Local-Only**: All API communication must remain local.

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
