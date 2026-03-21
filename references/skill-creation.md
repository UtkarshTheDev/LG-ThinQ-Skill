# Skill Creation Workflow (Autonomous Assembly)

This guide describes the automated workflow for creating a specialized device skill using the workspace assembler.

## 🛡️ Security Protocol (Strict Mandates)

Always follow these mandates to ensure user privacy and system integrity:
1.  **Explain First**: Tell the user what you are about to do before doing it.
2.  **Ask First**: Use `ask_user` before every network call or file system operation.
3.  **Zero-Leak**: Never ask the user to paste their `LG_PAT` into the chat.
4.  **Credential Isolation**: Only `LG_DEVICE_ID` belongs in the device skill's `.env`. **NEVER** copy the `LG_PAT` or `LG_COUNTRY` into these sub-folders.

---

## Step 1: Select Device

From the `setup.sh` summary output, identify the device to integrate. 
*   **Action**: Ask the user which device ID from the list they wish to use.

---

## Step 2: Assemble Workspace

Run the master assembly script. This one command performs 90% of the manual labor.

```bash
python3 scripts/assemble_device_workspace.py --id <DEVICE_ID>
```

**What the script does for you:**
1.  **Lookup**: Automatically identifies the model and alias from the discovery database.
2.  **Naming**: Sets the folder name using the first 8 characters of the ID (e.g., `lg-ac-2f33f241`).
3.  **Engine Generation**: Builds a bug-free `lg_control.py` specialized for that hardware.
4.  **Credential Isolation**: Creates a local `.env` with ONLY the `LG_DEVICE_ID`.
5.  **Environment Setup**: Creates a `venv` and installs all `requirements.txt` dependencies.
6.  **Verification**: Automatically runs a `status` check to prove the connection works.

---

## Step 3: Create SKILL.md (Documentation)

The assembly script will output the `[AVAILABLE COMMANDS]` and `[ENGINE CODE]`. Use this output along with the local `profile.json` to write the documentation.

1.  **Template**: Refer to `references/device-skill-template.md` for the structure.
2.  **Details**: Include temperature ranges (e.g., 16-30°C) and supported modes (e.g., COOL, FAN) found in the profile.
3.  **Location**: Save the file as `SKILL.md` in the newly created directory.

---

## Step 4: Memory & Persistence (MEMORY.md)

This is the final step to ensure OpenClaw "remembers" your device in future sessions. The agent **MUST** record the following details in your global `MEMORY.md`:

1.  **Trigger Phrase**: The natural language command to activate the skill (e.g., "OpenClaw, manage my Living Room AC").
2.  **Path**: The exact location of the skill (`~/.openclaw/workspaces/skills/lg-{type}-{short_id}`).
3.  **Command List**: A summary of key commands like `on`, `off`, `temp`, and `status`.

**Workflow:**
- Ask permission: *"May I save the commands and location for this new skill in your memory for future recall?"*
- Save data: Use the `save_memory` tool to write the entry.

---

## Complete Example Session

```bash
# 1. Run Setup
./setup.sh

# 2. Assemble (User provides ID)
python3 scripts/assemble_device_workspace.py --id 2f33f241...

# 3. Create SKILL.md (using printed context)

# 4. Persistence
# Ask user permission to save to MEMORY.md
```
