# LG ThinQ Universal - Setup Script (Windows/PowerShell)
# Automated setup for device discovery and skill generation

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = $ScriptDir
$VenvDir = Join-Path $ProjectRoot "venv"
$RequirementsFile = Join-Path $ProjectRoot "requirements.txt"
$EnvFile = Join-Path $ProjectRoot ".env"
$SkillDir = $ProjectRoot

function Write-Info { Write-Host "[INFO] $args" -ForegroundColor Green }
function Write-Warn { Write-Host "[WARN] $args" -ForegroundColor Yellow }
function Write-Err { Write-Host "[ERROR] $args" -ForegroundColor Red }

function Install-Deps {
    Write-Info "Setting up Python virtual environment..."
    
    if (Test-Path $VenvDir) {
        Write-Warn "Virtual environment exists, skipping creation"
    } else {
        python -m venv $VenvDir
        Write-Info "Virtual environment created at $VenvDir"
    }
    
    Write-Info "Installing dependencies..."
    & (Join-Path $VenvDir "Scripts\pip") install -q -r $RequirementsFile
    Write-Info "Dependencies installed"
}

function Check-Env {
    Write-Info "Checking environment configuration..."
    
    $pipExe = Join-Path $VenvDir "Scripts\python"
    $ConfigOutput = & $pipExe "$ScriptDir\lg_api_tool.py" check-config 2>$null
    
    Write-Host $ConfigOutput
    
    if ($ConfigOutput -match "❌") {
        Write-Err "Environment configuration incomplete"
        Write-Info "Please set LG_PAT and LG_COUNTRY in your environment or .env file"
        Write-Host ""
        Write-Host "Example .env content:"
        Write-Host "LG_PAT=your_personal_access_token_here"
        Write-Host "LG_COUNTRY=IN"
        exit 1
    }
    
    Write-Info "Environment configuration OK"
}

function Save-ApiRoute {
    Write-Info "Saving API route..."
    
    $pipExe = Join-Path $VenvDir "Scripts\python"
    $RouteOutput = & $pipExe "$ScriptDir\lg_api_tool.py" save-route 2>$null | ConvertFrom-Json
    
    if ($RouteOutput.success) {
        $script:ApiServer = $RouteOutput.apiServer
        Write-Info "API route saved: $ApiServer"
    } else {
        Write-Err "Failed to save API route"
        Write-Host $RouteOutput
        exit 1
    }
}

function Fetch-Profiles {
    Write-Info "Fetching device list..."
    
    $pipExe = Join-Path $VenvDir "Scripts\python"
    $DevicesOutput = & $pipExe "$ScriptDir\lg_api_tool.py" list-devices 2>$null | ConvertFrom-Json
    
    if (-not $DevicesOutput.success) {
        Write-Err "Failed to fetch devices"
        Write-Host $DevicesOutput
        exit 1
    }
    
    $DeviceList = $DevicesOutput.response.deviceList
    if ($DeviceList.Count -eq 0) {
        Write-Warn "No devices found"
        return
    }
    
    Write-Info "Found $($DeviceList.Count) device(s), fetching profiles..."
    
    $ProfilesDir = Join-Path $SkillDir "profiles"
    if (-not (Test-Path $ProfilesDir)) {
        New-Item -ItemType Directory -Path $ProfilesDir | Out-Null
    }
    
    $DeviceInfo = @()
    
    foreach ($Device in $DeviceList) {
        $DeviceId = $Device.deviceId
        $ProfileFile = Join-Path $ProfilesDir "device_$DeviceId.json"
        
        Write-Info "Fetching profile for: $DeviceId"
        $ProfileOutput = & $pipExe "$ScriptDir\lg_api_tool.py" get-profile $DeviceId 2>$null | ConvertFrom-Json
        
        if ($ProfileOutput.success) {
            $ProfileOutput | ConvertTo-Json -Depth 10 | Set-Content $ProfileFile
            Write-Info "  Saved to: $ProfileFile"
            
            # Extract device info
            $Props = $ProfileOutput.response.property
            $Name = $Props.basic.alias.thirdParty, $Props.basic.alias.device | Where-Object { $_ } | Select-Object -First 1
            if (-not $Name) { $Name = "Unknown" }
            
            $Type = $Props.basic.modelName
            if (-not $Type) { $Type = "Unknown" }
            
            $DeviceInfo += @{
                id = $DeviceId
                name = $Name
                type = $Type
                profilePath = $ProfileFile
            }
        } else {
            Write-Warn "  Failed to fetch profile for: $DeviceId"
        }
    }
    
    # Output summary JSON
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Info "Setup Complete - Devices Ready"
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    $Result = @{
        success = $true
        apiServer = $script:ApiServer
        profilesDir = $ProfilesDir
        devices = $DeviceInfo
    }
    
    $Result | ConvertTo-Json -Depth 10
    
    Write-Host ""
    Write-Host "Next steps for OpenClaw:"
    Write-Host "1. Select a device from the list above"
    Write-Host "2. Generate control script: python scripts/generate_control_script.py <profile_path> > lg_control.py"
    Write-Host "3. Create skill directory and move generated files"
}

# Main execution
function Main {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "LG ThinQ Universal - Setup (Windows)"
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    Install-Deps
    Check-Env
    Save-ApiRoute
    Fetch-Profiles
    
    Write-Info "Setup complete!"
}

Main
