[CmdletBinding()]
param(
    [ValidateSet('install','doctor')][string]$Command = 'install',
    [ValidateSet('server','client')][string]$Role,
    [string]$Server,
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,62}$')][string]$ScreenName = $env:COMPUTERNAME,
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,62}$')][string[]]$Client = @(),
    [ValidateSet('lan','tailscale')][string]$Transport = 'lan',
    [ValidateRange(1,65535)][int]$Port = 24800,
    [switch]$NonInteractive,
    [switch]$NoStart,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$DeskflowPackageId = 'Deskflow.Deskflow'
$TailscalePackageId = 'Tailscale.Tailscale'
$StateDir = Join-Path $env:LOCALAPPDATA 'DeskflowRemote'

function Write-Step([string]$Message) { Write-Host "==> $Message" -ForegroundColor Cyan }
function Assert-Value([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Invoke-Checked([string]$File, [string[]]$Arguments) {
    if ($DryRun) { Write-Host ('+ {0} {1}' -f $File, ($Arguments -join ' ')); return }
    & $File @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$File failed with exit code $LASTEXITCODE" }
}
function Find-Deskflow {
    $commands = @('deskflow.exe')
    foreach ($name in $commands) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    $roots = @(
        (Join-Path $env:ProgramFiles 'Deskflow'),
        (Join-Path ${env:ProgramFiles(x86)} 'Deskflow'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Deskflow')
    ) | Where-Object { $_ }
    foreach ($root in $roots) {
        foreach ($name in $commands) {
            $path = Join-Path $root $name
            if (Test-Path -LiteralPath $path) { return $path }
        }
    }
    return $null
}
function Find-DeskflowNamed([string]$Name) {
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $roots = @(
        (Join-Path $env:ProgramFiles 'Deskflow'),
        (Join-Path ${env:ProgramFiles(x86)} 'Deskflow'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Deskflow')
    ) | Where-Object { $_ }
    foreach ($root in $roots) {
        $path = Join-Path $root $Name
        if (Test-Path -LiteralPath $path) { return $path }
    }
    return $null
}
function Install-Deskflow {
    if (Find-Deskflow) { Write-Step 'Deskflow is already installed'; return }
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    Assert-Value ($null -ne $winget) 'WinGet is required. Install App Installer from Microsoft Store or Deskflow from its official releases.'
    Write-Step 'Installing the maintained Deskflow package through WinGet'
    Invoke-Checked $winget.Source @('install','--id',$DeskflowPackageId,'--exact','--silent','--accept-package-agreements','--accept-source-agreements','--disable-interactivity')
    if (-not $DryRun) { Assert-Value ($null -ne (Find-Deskflow)) 'Deskflow installation completed, but its executable was not found.' }
}
function Install-TailscaleIfApproved {
    if ($Transport -ne 'tailscale' -or (Get-Command tailscale.exe -ErrorAction SilentlyContinue)) { return }
    if ($NonInteractive) { throw 'Tailscale was selected but is not installed. Install and authenticate it before a non-interactive run.' }
    $answer = Read-Host 'Tailscale is optional and missing. Install it now? [y/N]'
    if ($answer -notmatch '^(y|yes|s|sim)$') { throw 'Tailscale is required for the selected transport.' }
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    Assert-Value ($null -ne $winget) 'WinGet is required to install Tailscale.'
    Invoke-Checked $winget.Source @('install','--id',$TailscalePackageId,'--exact','--silent','--accept-package-agreements','--accept-source-agreements','--disable-interactivity')
    Write-Step 'Tailscale installed. Sign in using its official application; this script never accepts or stores auth keys.'
}
function New-ServerConfig {
    if (-not $DryRun) { New-Item -Path $StateDir -ItemType Directory -Force | Out-Null }
    $path = Join-Path $StateDir 'server.conf'
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('section: screens'); $lines.Add("`t${ScreenName}:")
    foreach ($name in $Client) { $lines.Add("`t${name}:") }
    $lines.Add('end'); $lines.Add(''); $lines.Add('section: links')
    $previous = $ScreenName
    foreach ($name in $Client) {
        $lines.Add("`t${previous}:"); $lines.Add("`t`tright = $name")
        $lines.Add("`t${name}:"); $lines.Add("`t`tleft = $previous")
        $previous = $name
    }
    $lines.Add('end'); $lines.Add(''); $lines.Add('section: options'); $lines.Add('end')
    if ($DryRun) { Write-Step "Would write $path"; $lines | ForEach-Object { Write-Host $_ } }
    else { [IO.File]::WriteAllLines($path, $lines, [Text.UTF8Encoding]::new($false)) }
    return $path
}
function Add-ScopedFirewallRule {
    if ($Role -ne 'server') { return }
    $exe = Find-DeskflowNamed 'deskflow-server.exe'
    if (-not $exe) {
        Write-Step 'No firewall rule was created because deskflow-server.exe could not be identified. Allow the server only after its exact executable path is known.'
        return
    }
    $remote = if ($Transport -eq 'tailscale') { '100.64.0.0/10' } else { 'LocalSubnet' }
    if ($DryRun) { Write-Host "+ New-NetFirewallRule DeskflowRemote TCP/$Port RemoteAddress=$remote"; return }
    $admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
    Assert-Value $admin 'Server firewall configuration requires an Administrator PowerShell window.'
    $existing = Get-NetFirewallRule -DisplayName 'Deskflow Remote (scoped)' -ErrorAction SilentlyContinue
    if ($existing) { $existing | Remove-NetFirewallRule }
    New-NetFirewallRule -DisplayName 'Deskflow Remote (scoped)' -Direction Inbound -Action Allow -Protocol TCP -LocalPort $Port -Program $exe -RemoteAddress $remote -Profile Private | Out-Null
}
function Open-Deskflow {
    if ($NoStart) { return }
    $exe = Find-Deskflow
    if (-not $exe) { if ($DryRun) { Write-Host '+ open Deskflow GUI'; return }; throw 'Deskflow GUI executable was not found.' }
    Write-Step "Opening the Deskflow GUI; select the $Role role and keep the default TLS/fingerprint settings enabled"
    if ($Role -eq 'server') { Write-Step "Import the generated layout from: $(Join-Path $StateDir 'server.conf')" }
    if ($Role -eq 'client') { Write-Step "Set the Deskflow server address to: $Server" }
    Write-Step "Set the Deskflow TCP port to: $Port"
    if (-not $DryRun) { Start-Process -FilePath $exe }
}
function Show-Doctor {
    Write-Host 'Deskflow Remote diagnostics'
    Write-Host "Windows: $([Environment]::OSVersion.VersionString)"
    Write-Host "Deskflow: $(if (Find-Deskflow) { Find-Deskflow } else { 'not found' })"
    Write-Host "Tailscale: $(if (Get-Command tailscale.exe -ErrorAction SilentlyContinue) { 'found' } else { 'optional / not found' })"
    Write-Host "State directory: $StateDir"
}

if ($Command -eq 'doctor') { Show-Doctor; exit 0 }
if (-not $Role) {
    if ($NonInteractive) { throw '-Role is required in non-interactive mode.' }
    $Role = Read-Host 'Role [server/client]'
}
Assert-Value ($Role -in @('server','client')) 'Role must be server or client.'
foreach ($name in $Client) {
    Assert-Value ($name -match '^[A-Za-z0-9][A-Za-z0-9._-]{0,62}$') "Invalid client name: $name"
    Assert-Value ($name -ne $ScreenName) 'Client and server names must differ.'
}
Assert-Value (($Client | Select-Object -Unique).Count -eq $Client.Count) 'Duplicate client names are not allowed.'
if ($Role -eq 'client' -and -not $Server) {
    if ($NonInteractive) { throw '-Server is required for a client in non-interactive mode.' }
    $Server = Read-Host 'Server hostname or IP'
}
if ($Server) { Assert-Value ($Server -match '^[A-Za-z0-9][A-Za-z0-9.:-]{0,252}$') 'Invalid server address.' }

Install-TailscaleIfApproved
Install-Deskflow
if ($Role -eq 'server') { $null = New-ServerConfig; Add-ScopedFirewallRule }
Open-Deskflow
Write-Step 'Setup files are ready. In Deskflow, select the role, import/apply the settings above, and verify the TLS fingerprint before accepting input.'
