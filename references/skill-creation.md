# Skill Creation Workflow

After running `setup.sh`, follow this workflow to create a device skill. Do this for **each device** you want to integrate.

## Security Protocol Reminder

Always follow these mandates:
1. **Ask First**: Use `ask_user` before API calls and file operations
2. **Zero-Leak**: Never ask user to paste `LG_PAT` into chat
3. **Minimal Credentials**: Only `LG_DEVICE_ID` in skill's `.env`

---

## Prerequisites

- `setup.sh` completed successfully
- Device profiles fetched in `profiles/` directory
- User has selected which device(s) to integrate

---

## Step 1: Select Device

From setup output, identify the device to integrate:

```json
{
  "success": true,
  "apiServer": "https://api-kic.lgthinq.com",
  "profilesDir": "profiles",
  "devices": [
    {
      "id": "abc123...",
      "name": "Living Room AC",
      "type": "RAC_056905_WW",
      "profilePath": "profiles/device_abc123....json"
    },
    {
      "id": "def456...",
      "name": "Kitchen Fridge",
      "type": "REFRIGERATOR",
      "profilePath": "profiles/device_def456....json"
    }
  ]
}
```

Choose one device at a time for clarity.

---

## Step 2: Generate Control Script

The control script is generated from the device profile and contains all available commands.

```bash
python scripts/generate_control_script.py <profile_path> > lg_control.py
chmod +x lg_control.py
```

**What gets generated:**
- All controllable properties from the profile (read-write properties)
- `status` command - Get current device state
- `on` / `off` commands - Power control (if device supports it)
- Device-specific commands based on capabilities

**Example**: For an AC, the script might include:
- `temp <value>` - Set temperature
- `mode <cool|heat|dry|fan>` - Set operation mode
- `fan <low|medium|high>` - Set fan speed

---

## Step 3: Test Control Script

Before creating the skill, verify the script works:

```bash
# Show all available commands
python lg_control.py --help

# Get current state
python lg_control.py status

# Test a command
python lg_control.py on
```

If errors occur:
- Check `LG_PAT` is set correctly
- Verify `LG_API_SERVER` is cached (run `save-route` if needed)
- Use `--debug` flag for detailed output

---

## Step 4: Create Skill Directory

Create a dedicated directory for this device's skill:

```bash
mkdir -p ~/.config/openclaw/skills/lg-{device-type}-{short-id}
```

**Naming convention:**
- `device-type`: Device category (ac, fridge, washer, etc.)
- `short-id`: Abbreviated device ID for uniqueness

**Examples:**
- `lg-ac-livingroom`
- `lg-ac-bedroom`
- `lg-fridge-kitchen`

---

## Step 5: Move Files to Skill Directory

Copy necessary files into the skill directory:

```bash
# Move the generated control script
mv lg_control.py ~/.config/openclaw/skills/lg-{device-type}-{short-id}/

# Copy the API tool for future use
cp scripts/lg_api_tool.py ~/.config/openclaw/skills/lg-{device-type}-{short-id}/
```

**Note**: Keep the original `lg-api-tool.py` in the universal skill folder. Each device skill gets its own copy.

---

## Step 6: Create Local .env

Create a `.env` file with only `LG_DEVICE_ID`:

```bash
cd ~/.config/openclaw/skills/lg-{device-type}-{short-id}
echo "LG_DEVICE_ID=<device_id>" > .env
chmod 600 .env
```

**Security checklist:**
- [ ] `.env` contains ONLY `LG_DEVICE_ID`
- [ ] `LG_PAT` is NOT in this file
- [ ] `LG_COUNTRY` is NOT in this file
- [ ] File permissions are `600` (owner read/write only)

---

## Step 7: Create Skill SKILL.md

Create `SKILL.md` following:
- `references/skill-generation-guide.md` - Structure and elements
- `references/device-example.md` - Complete example of output

**Required elements:**
- Frontmatter with `name`, `description` (include trigger keywords)
- Command table with all available commands
- Natural language mapping
- Decision logic (power check, sequencing)
- Error handling

**Complete example**: See `references/device-example.md` for full SKILL.md, lg_control.py, and file structure.

---

## Step 8: Verify Skill

Test the skill works end-to-end:

```bash
cd ~/.config/openclaw/skills/lg-{device-type}-{short-id}
python lg_control.py status
```

Expected: Returns current device state
Errors to watch for:
- `LG_PAT is missing` - Check environment
- `401 Unauthorized` - Token expired or invalid
- `Device offline` - Check device connectivity

---

## Step 9: Save to Memory (With Consent)

Ask user for permission:

> "May I record this setup in your memory for future recall? I'll save a trigger phrase so you can control your device easily."

If approved, save to memory:

```
[LG ThinQ Device Setup]
Device: {Device Name}
Trigger: "OpenClaw, manage my {Device Name}"
Skill: ~/.config/openclaw/skills/lg-{device-type}-{short-id}
```

---

## Step 10: Notify User

Inform the user their device is ready:

> "Your {Device Name} is integrated! Try saying: 'OpenClaw, check the status of my {Device Name}'."

---

## Complete Example Session

```bash
# 1. Select device
DEVICE_ID="abc123def456"
DEVICE_TYPE="ac"
DEVICE_NAME="Living Room AC"

# 2. Generate control script
python scripts/generate_control_script.py profiles/device_$DEVICE_ID.json > lg_control.py
chmod +x lg_control.py

# 3. Test
python lg_control.py --help
python lg_control.py status

# 4. Create skill directory
mkdir -p ~/.config/openclaw/skills/lg-$DEVICE_TYPE-livingroom

# 5. Move files
mv lg_control.py ~/.config/openclaw/skills/lg-$DEVICE_TYPE-livingroom/
cp scripts/lg_api_tool.py ~/.config/openclaw/skills/lg-$DEVICE_TYPE-livingroom/

# 6. Create local .env
cd ~/.config/openclaw/skills/lg-$DEVICE_TYPE-livingroom
echo "LG_DEVICE_ID=$DEVICE_ID" > .env
chmod 600 .env

# 7. Create SKILL.md (see references/skill-generation-guide.md)

# 8. Verify
python lg_control.py status

# 9. Memory (with consent via ask_user)

# 10. Notify user
```

---

## Repeat for Multiple Devices

For each additional device, repeat Steps 1-10. Each device gets:
- Its own directory
- Its own `lg_control.py`
- Its own `LG_DEVICE_ID` in `.env`
- Its own `SKILL.md`
- Its own memory entry
