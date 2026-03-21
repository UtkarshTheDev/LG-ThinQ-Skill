import os
import sys
import json
import shutil
import subprocess
import argparse
import platform

# Configuration
# ------------------------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
PROFILES_DIR = os.path.join(PROJECT_ROOT, "profiles")
DB_FILE = os.path.join(PROFILES_DIR, "devices.json")
SKILLS_ROOT = os.path.expanduser("~/.openclaw/workspaces/skills")

# Helpers
# ------------------------------------------------------------------------------
def log(msg, type="INFO"):
    print(f"[FACTORY] [{type}] {msg}")

def run_command(cmd, cwd=None, capture=False):
    """Run a shell command safely."""
    try:
        result = subprocess.run(
            cmd, 
            cwd=cwd, 
            shell=True, 
            check=True, 
            stdout=subprocess.PIPE if capture else None, 
            stderr=subprocess.PIPE if capture else None,
            text=True
        )
        return result.stdout.strip() if capture else True
    except subprocess.CalledProcessError as e:
        log(f"Command failed: {cmd}\nError: {e.stderr if capture else 'Check output'}", "ERROR")
        sys.exit(1)

def load_device_db():
    """Load the master device database created by setup.sh."""
    if not os.path.exists(DB_FILE):
        log(f"Database not found at {DB_FILE}. Run setup.sh first.", "ERROR")
        sys.exit(1)
    with open(DB_FILE, 'r') as f:
        return json.load(f)

def get_short_id(full_id):
    """Return the first 8 characters of the device ID."""
    return full_id[:8]

def guess_type(model_name):
    """Guess a simplified type string from the model name."""
    model = model_name.lower()
    if "rac" in model or "air" in model: return "ac"
    if "ref" in model: return "fridge"
    if "wash" in model: return "washer"
    if "dry" in model: return "dryer"
    return "device"

# Main Logic
# ------------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="LG ThinQ Skill Factory")
    parser.add_argument("--id", required=True, help="Full Device ID")
    parser.add_argument("--location", help="Custom location name (e.g. livingroom)")
    parser.add_argument("--force", action="store_true", help="Overwrite existing skill")
    parser.add_argument("--confirm", action="store_true", help="Explicitly confirm all actions in the manifest")
    args = parser.parse_args()

    # 1. Lookup Device
    log(f"Looking up device: {args.id}...")
    devices = load_device_db()
    target_device = next((d for d in devices if d['id'] == args.id), None)
    
    if not target_device:
        log("Device ID not found in local database. Run setup.sh to refresh.", "ERROR")
        sys.exit(1)
    
    short_id = get_short_id(args.id)
    device_type = guess_type(target_device.get('model', 'unknown'))
    location_suffix = args.location if args.location else short_id
    skill_name = f"lg-{device_type}-{location_suffix}"
    skill_path = os.path.join(SKILLS_ROOT, skill_name)

    # SAFETY MANIFEST
    if not args.confirm:
        print("\n" + "!"*60)
        print("🛡️  SAFETY MANIFEST: PENDING ACTIONS")
        print("!"*60)
        print(f"The following actions will be performed for: {target_device.get('name')}")
        print(f"1. [FILE] Create directory: {skill_path}")
        print(f"2. [FILE] Write engine:    {skill_path}/lg_control.py")
        print(f"3. [FILE] Write config:    {skill_path}/.env (Device ID isolation)")
        print(f"4. [FILE] Copy tools:      lg_api_tool.py, requirements.txt")
        print(f"5. [ENV]  Setup venv:      Create venv and install dependencies")
        print(f"6. [NET]  Verification:    Call LG API to verify device status")
        print("\n[ACTION REQUIRED]")
        print("Please review these actions. If you approve, run this command again with the '--confirm' flag.")
        print("!"*60 + "\n")
        sys.exit(0)

    # 2. Proceed with Assembly (Only if --confirm is present)
    log(f"Assembling workspace for {skill_name}...")
    if os.path.exists(skill_path):
        if args.force:
            log("Removing existing skill directory...", "WARN")
            shutil.rmtree(skill_path)
        else:
            log(f"Directory exists. Use --force to overwrite: {skill_path}", "ERROR")
            sys.exit(1)
    
    os.makedirs(skill_path)
    log("Created skill directory.")

    # 4. Generate Control Script
    log("Generating engine (lg_control.py)...")
    
    # We call the generator script as a subprocess to keep environments clean
    # Pass ID in env so the generator knows context
    gen_env = os.environ.copy()
    gen_env["LG_DEVICE_ID"] = args.id
    
    generator_path = os.path.join(SCRIPT_DIR, "generate_control_script.py")
    profile_path = target_device['profile']
    
    lg_control_code = run_command(
        f"python3 \"{generator_path}\" \"{profile_path}\"", 
        capture=True
    )
    
    # Write the generated code
    target_control_path = os.path.join(skill_path, "lg_control.py")
    with open(target_control_path, "w") as f:
        f.write(lg_control_code)
    
    # Make executable
    os.chmod(target_control_path, 0o755)
    log("Engine generated and saved.")

    # 5. Assemble Dependencies
    log("Assembling dependencies...")
    
    # Copy API tool
    shutil.copy(os.path.join(SCRIPT_DIR, "lg_api_tool.py"), skill_path)
    
    # Copy Requirements (if they exist)
    req_src = os.path.join(PROJECT_ROOT, "requirements.txt")
    if os.path.exists(req_src):
        shutil.copy(req_src, skill_path)

    # Create Local .env
    with open(os.path.join(skill_path, ".env"), "w") as f:
        f.write(f"LG_DEVICE_ID={args.id}\n")
    log("Created local .env (Credential Isolation).")

    # 6. Environment Setup (Platform Specific)
    is_windows = platform.system() == "Windows"
    
    if is_windows:
        log("Windows detected. Skipping venv creation (assuming global install).")
    else:
        log("Linux/macOS detected. Creating virtual environment...")
        run_command("python3 -m venv venv", cwd=skill_path)
        log("Installing dependencies into venv...")
        run_command("./venv/bin/pip install -q -r requirements.txt", cwd=skill_path)
        log("Environment ready.")

    # 7. Proof of Life (Verification)
    log("Verifying skill functionality (Proof of Life)...")
    status_cmd = "python lg_control.py status" if is_windows else "./venv/bin/python lg_control.py status"
    try:
        status_output = run_command(status_cmd, cwd=skill_path, capture=True)
        log(f"Status Check: SUCCESS\n{status_output}")
    except Exception as e:
        log("Status Check Failed. The skill was created but may need configuration.", "WARN")

    # 8. Context Handoff
    print("\n" + "="*60)
    print("🤖 FACTORY HANDOFF: CONTEXT FOR DOCUMENTATION")
    print("="*60 + "\n")
    
    print(f"SKILL_NAME: {skill_name}")
    print(f"SKILL_PATH: {skill_path}")
    print(f"DEVICE_NAME: {target_device.get('name')}")
    print(f"DEVICE_MODEL: {target_device.get('type')}")
    
    print("\n[AVAILABLE COMMANDS]")
    help_cmd = "python lg_control.py --help" if is_windows else "./venv/bin/python lg_control.py --help"
    print(run_command(help_cmd, cwd=skill_path, capture=True))
    
    print("\n[ENGINE CODE (lg_control.py)]")
    with open(target_control_path, 'r') as f:
        print(f.read())

    print("\n[TECHNICAL SPECIFICATIONS]")
    print(f"Deep technical details (ranges, modes, enums) are available in: {skill_path}/profile.json")

    print("\n[REQUIRED NEXT STEPS]")
    print(f"The workspace is fully assembled at: {skill_path}")
    print("1. Analyze the COMMANDS and ENGINE CODE above.")
    print("2. Read the local 'profile.json' to identify temperature ranges and allowed values.")
    print("3. Generate a professional 'SKILL.md' in that directory using 'references/device-skill-template.md' as a guide.")
    print("4. IMPORTANT: Save the new skill's usage details, commands, and trigger phrase to your global 'MEMORY.md'.")
    print("="*60)

if __name__ == "__main__":
    main()
