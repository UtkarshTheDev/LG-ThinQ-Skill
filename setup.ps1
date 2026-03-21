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
    Write-Info "Installing dependencies globally..."
    
    # On Windows, we install globally to avoid per-skill venv management complexity
    python -m pip install --user -q -r $RequirementsFile
    Write-Info "Dependencies installed"
}

function Check-Env {
    Write-Info "Checking environment configuration..."
    
    # Use global python since we installed deps globally
    $ConfigOutput = python "$ScriptDir\scripts\lg_api_tool.py" check-config 2>$null
    
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
    Write-Info "Resolving API route..."
    
    $CacheFile = Join-Path $ProjectRoot ".api_server_cache"
    
    # Check if cache exists and is not empty
    if (Test-Path $CacheFile) {
        $CachedContent = Get-Content $CacheFile
        if ($null -ne $CachedContent -and $CachedContent.Length -gt 0) {
            $script:ApiServer = $CachedContent.Trim()
            Write-Info "Using cached API route: $ApiServer"
            return
        }
    }

    Write-Info "No valid cache found. Discovering regional API server..."
    $RouteRaw = python "$ScriptDir\scripts\lg_api_tool.py" save-route 2>$null
    $RouteOutput = $RouteRaw | ConvertFrom-Json
    
    if ($RouteOutput.success) {
        $script:ApiServer = $RouteOutput.apiServer
        Write-Info "API route discovered and cached: $ApiServer"
    } else {
        Write-Err "Failed to resolve API route."
        Write-Host $RouteRaw
        exit 1
    }
}

function Fetch-Profiles {
    Write-Info "Fetching device list..."
    
    $DevicesRaw = python "$ScriptDir\scripts\lg_api_tool.py" list-devices 2>$null
    $DevicesOutput = $DevicesRaw | ConvertFrom-Json
    
    # Check for success in response field or success flag
    $DeviceList = $DevicesOutput.response
    if ($null -eq $DeviceList -or $DeviceList.Count -eq 0) {
        Write-Warn "No devices found"
        return
    }
    
    Write-Info "Found $($DeviceList.Count) device(s), fetching profiles..."
    
    $ProfilesDir = Join-Path $SkillDir "profiles"
    if (-not (Test-Path $ProfilesDir)) {
        New-Item -ItemType Directory -Path $ProfilesDir | Out-Null
    }
    
    $DeviceInfo = @()
    $DbFile = Join-Path $ProfilesDir "devices.json"
    
    foreach ($Device in $DeviceList) {
        $DeviceId = $Device.deviceId
        $Name = $Device.deviceInfo.alias
        if (-not $Name) { $Name = "Unknown" }
        $Model = $Device.deviceInfo.modelName
        if (-not $Model) { $Model = "Unknown" }
        
        $ProfileFile = Join-Path $ProfilesDir "device_$DeviceId.json"
        
        Write-Info "Fetching profile for: $Name ($DeviceId)"
        $ProfileRaw = python "$ScriptDir\scripts\lg_api_tool.py" get-profile $DeviceId 2>$null
        $ProfileOutput = $ProfileRaw | ConvertFrom-Json
        
        # Verify by checking for the 'property' key in the response
        if ($null -ne $ProfileOutput.response.property) {
            $ProfileRaw | Set-Content $ProfileFile
            Write-Info "  Saved to: $ProfileFile"
            
            $DeviceInfo += @{
                id = $DeviceId
                name = $Name
                model = $Model
                profile = $ProfileFile
            }
        } else {
            Write-Warn "  Failed to fetch profile for: $Name ($DeviceId)"
        }
    }
    
    # Save Master Database
    $DeviceInfo | ConvertTo-Json -Depth 10 | Set-Content $DbFile
    
    # Output summary JSON
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Info "Setup Complete - Discovered Appliances"
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "The following device profiles have been saved to $ProfilesDir :"
    Write-Host ""
    
    $Result = @{
        success = $true
        apiServer = $script:ApiServer
        devices = $DeviceInfo
    }
    
    $Result | ConvertTo-Json -Depth 10
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "🚀 DISCOVERY COMPLETE" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "1. Choose a device ID from the list above."
    Write-Host "2. Run the assembly script to build the workspace:"
    Write-Host ""
    Write-Host "   python scripts\assemble_device_workspace.py --id <DEVICE_ID>"
    Write-Host ""
    Write-Host "Note: You can also add '--location livingroom' to customize the folder name."
}

# Main execution
function Main {
    # SAFETY CHECK
    $Confirmed = $false
    foreach ($arg in $args) {
        if ($arg -eq "--confirm") { $Confirmed = $true }
    }

    if (-not $Confirmed) {
        Write-Host ""
        Write-Host "🛡️  SAFETY MANIFEST: LG THINQ DISCOVERY" -ForegroundColor Yellow
        Write-Host "========================================"
        Write-Host "This script will perform the following actions:"
        Write-Host "1. [ENV]  Install dependencies from requirements.txt globally"
        Write-Host "2. [NET]  Discover regional API server (uses LG_PAT/LG_COUNTRY)"
        Write-Host "3. [NET]  Fetch list of devices and technical profiles"
        Write-Host "4. [FILE] Save profiles to ./profiles/ and update database"
        Write-Host ""
        Write-Host "[ACTION REQUIRED]" -ForegroundColor Cyan
        Write-Host "Please review these actions. If you approve, run:"
        Write-Host "   .\setup.ps1 --confirm"
        Write-Host "========================================"
        Write-Host ""
        return
    }

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

Main $args
