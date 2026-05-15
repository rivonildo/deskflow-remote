# BARRIER REMOTE CONTROL - SERVIDOR (100% AUTOMATICO)
# Rode como ADMINISTRADOR - Zero configuracao manual

# ─── Auto-elevar privilegios ───
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}
Set-ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ─── Funcoes auxiliares ───
function Write-Ok($m)   { Write-Host "  [OK] $m" -ForegroundColor Green }
function Write-Fail($m) { Write-Host "  [ERRO] $m" -ForegroundColor Red }
function Write-Info($m) { Write-Host "  [i] $m" -ForegroundColor Cyan }
function Write-Warn($m) { Write-Host "  [!] $m" -ForegroundColor DarkYellow }
function Write-Step($s,$t,$m) { Write-Host "`n[$s/$t] $m" -ForegroundColor Yellow; Write-Host ("-"*50) -ForegroundColor DarkGray }

function Find-Exe($name) {
    foreach ($p in @("C:\Program Files","C:\Program Files (x86)","$env:LOCALAPPDATA\Programs")) {
        $dirs = Get-ChildItem $p -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "Barrier|Tailscale" }
        foreach ($d in $dirs) { if (Test-Path "$($d.FullName)\$name") { return $d.FullName } }
    }
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) { return Split-Path $cmd.Source }
    return $null
}

function Install-IfMissing($name, $url, $silentArgs) {
    $dir = Find-Exe $name
    if ($dir) { Write-Ok "$name encontrado em $dir"; return $dir }
    Write-Warn "$name nao encontrado. Instalando..."
    $installer = "$env:TEMP\installer_$name.exe"
    Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing
    Write-Info "Executando instalador..."
    Start-Process $installer -ArgumentList $silentArgs -Wait
    Start-Sleep -Seconds 5
    $dir = Find-Exe $name
    Remove-Item $installer -Force -ErrorAction SilentlyContinue
    if ($dir) { Write-Ok "Instalado com sucesso!" } else { Write-Fail "Instalacao falhou." }
    return $dir
}

function Ensure-TailscaleUp($tsExe) {
    $status = & $tsExe status 2>&1 | Out-String
    if ($status -match "Logged out|stopped|NeedsLogin") {
        Write-Warn "Tailscale desconectado. Iniciando login..."
        Start-Job -ScriptBlock { param($e) & $e up 2>&1 } -ArgumentList $tsExe | Out-Null
        Start-Sleep -Seconds 3
        $loginOut = & $tsExe status 2>&1 | Out-String
        if ($loginOut -match "(https://login\.tailscale\.com/\S+)") {
            Write-Info "Abrindo navegador para autorizacao..."
            Start-Process $Matches[1]
            for ($i = 0; $i -lt 12; $i++) {
                Start-Sleep -Seconds 5
                $check = & $tsExe status 2>&1 | Out-String
                if ($check -notmatch "Logged out" -and $check -match "\d+\.\d+\.\d+\.\d+") { Write-Ok "Tailscale conectado!"; return $true }
                Write-Host "." -NoNewline -ForegroundColor Gray
            }
            Write-Host ""
        }
        return $false
    }
    return $true
}

function Get-Peers($tsExe) {
    $lines = & $tsExe status 2>&1
    $peers = @()
    foreach ($l in $lines) {
        $s = $l.ToString().Trim()
        if ($s -match "^(\d+\.\d+\.\d+\.\d+)\s+(\S+)\s+(\S+)\s+(windows|linux|macos)\s+(.*)$") {
            $peers += [PSCustomObject]@{ IP=$Matches[1]; Host=$Matches[2]; OS=$Matches[4]; Status=$Matches[5].Trim() }
        }
    }
    return $peers
}

# ════════════════════════════════════════
#            INICIO DO SCRIPT
# ════════════════════════════════════════
Clear-Host
Write-Host "`n╔══════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  BARRIER REMOTE CONTROL - SERVIDOR       ║" -ForegroundColor Cyan
Write-Host "║  PC: $($env:COMPUTERNAME.PadRight(36))║" -ForegroundColor Cyan
Write-Host "║  Modo: 100% Automatico                   ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor Cyan

$ServerName = $env:COMPUTERNAME
$Port = 24800
$total = 8

# PASSO 1: Barrier
Write-Step 1 $total "Verificando Barrier..."
$bp = Install-IfMissing "barriers.exe" "https://github.com/debauchee/barrier/releases/download/v2.4.0/BarrierSetup-2.4.0-release.exe" "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART"
if (-not $bp) { Read-Host "Pressione Enter"; exit 1 }

# PASSO 2: Tailscale
Write-Step 2 $total "Verificando Tailscale..."
$tp = Install-IfMissing "tailscale.exe" "https://pkgs.tailscale.com/stable/tailscale-setup-latest.exe" "/install /quiet"
if (-not $tp) { Read-Host "Pressione Enter"; exit 1 }
$tsExe = "$tp\tailscale.exe"

# PASSO 3: Conectar Tailscale
Write-Step 3 $total "Conectando Tailscale..."
if (-not (Ensure-TailscaleUp $tsExe)) { Write-Fail "Tailscale nao conectou."; Read-Host "Pressione Enter"; exit 1 }
$myIP = (& $tsExe ip -4 2>&1).Trim()
Write-Ok "IP Tailscale: $myIP"

# PASSO 4: Descobrir cliente
Write-Step 4 $total "Descobrindo PCs na rede..."
$peers = Get-Peers $tsExe
$myHost = $env:COMPUTERNAME.ToLower()
$winPeers = $peers | Where-Object { $_.OS -eq "windows" -and $_.Host -ne $myHost -and $_.Status -notmatch "offline.*ago" }

Write-Info "PCs Windows na rede Tailscale:"
foreach ($p in ($peers | Where-Object { $_.OS -eq "windows" -and $_.Host -ne $myHost })) {
    $icon = if ($p.Status -match "offline") { "OFFLINE" } else { "ONLINE" }
    $c = if ($p.Status -match "offline") { "DarkGray" } else { "Green" }
    Write-Host "    [$icon] $($p.Host) ($($p.IP))" -ForegroundColor $c
}

$ClientName = $null; $ClientIP = $null
if ($winPeers.Count -ge 1) {
    foreach ($w in $winPeers) {
        $ping = & $tsExe ping --c 1 --timeout 5s $w.IP 2>&1 | Out-String
        if ($ping -match "pong") { $ClientName = $w.Host.ToUpper(); $ClientIP = $w.IP; break }
    }
    if (-not $ClientName) { $ClientName = $winPeers[0].Host.ToUpper(); $ClientIP = $winPeers[0].IP }
    Write-Ok "Cliente detectado: $ClientName ($ClientIP)"
} else {
    Write-Warn "Nenhum PC Windows online. Servidor aguardara qualquer cliente."
    $ClientName = "CLIENT"
}

# PASSO 5: SSL
Write-Step 5 $total "Configurando SSL..."
$sslDir = "$env:LOCALAPPDATA\Barrier\SSL\Fingerprints"
New-Item -Path $sslDir -ItemType Directory -Force | Out-Null
if (-not (Test-Path "$env:LOCALAPPDATA\Barrier\SSL\Barrier.pem")) {
    $td = "$env:TEMP\BarrierSSL"; New-Item $td -ItemType Directory -Force | Out-Null
    [IO.File]::WriteAllText("$td\o.cnf","[req]`ndefault_bits=2048`ndistinguished_name=dn`nprompt=no`n[dn]`nCN=Barrier",[Text.Encoding]::ASCII)
    & "$bp\openssl.exe" req -config "$td\o.cnf" -x509 -nodes -days 3650 -newkey rsa:2048 -keyout "$td\B.pem" -out "$td\B.pem" 2>&1 | Out-Null
    if (Test-Path "$td\B.pem") {
        Copy-Item "$td\B.pem" "$env:LOCALAPPDATA\Barrier\SSL\Barrier.pem" -Force
        $fp=((& "$bp\openssl.exe" x509 -fingerprint -sha256 -noout -in "$td\B.pem" 2>&1) -replace ".*=","").Trim()
        $u8=[Text.UTF8Encoding]::new($false)
        [IO.File]::WriteAllText("$sslDir\Local.txt","v2:sha256:$fp",$u8)
        [IO.File]::WriteAllText("$sslDir\TrustedServers.txt","v2:sha256:$fp",$u8)
        [IO.File]::WriteAllText("$sslDir\TrustedClients.txt","v2:sha256:$fp",$u8)
        Remove-Item $td -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Ok "SSL configurado!"
} else { Write-Ok "SSL ja existe" }

# PASSO 6: Config de telas
Write-Step 6 $total "Criando configuracao de telas..."
$cfgPath = "$env:LOCALAPPDATA\Barrier\barrier.sgc"
$cfg = "section: screens`n`t${ServerName}:`n`t`thalfDuplexCapsLock = false`n`t`thalfDuplexNumLock = false`n`t`thalfDuplexScrollLock = false`n`t`tswitchCorners = none`n`t`tswitchCornerSize = 0`n`t${ClientName}:`n`t`thalfDuplexCapsLock = false`n`t`thalfDuplexNumLock = false`n`t`thalfDuplexScrollLock = false`n`t`tswitchCorners = none`n`t`tswitchCornerSize = 0`nend`n`nsection: aliases`nend`n`nsection: links`n`t${ServerName}:`n`t`tright = ${ClientName}`n`t${ClientName}:`n`t`tleft = ${ServerName}`nend`n`nsection: options`n`trelativeMouseMoves = false`n`tscreenSaverSync = true`n`twin32KeepForeground = false`n`tclipboardSharing = true`n`tswitchCorners = none`n`tswitchCornerSize = 0`nend"
[IO.File]::WriteAllText($cfgPath, $cfg, [Text.UTF8Encoding]::new($false))
Write-Ok "Layout: [$ServerName] <-> [$ClientName]"

# PASSO 7: Firewall
Write-Step 7 $total "Configurando Firewall..."
netsh advfirewall firewall delete rule name="Barrier Server In" >$null 2>&1
netsh advfirewall firewall delete rule name="Barrier Port 24800" >$null 2>&1
netsh advfirewall firewall add rule name="Barrier Server In" dir=in action=allow program="$bp\barriers.exe" enable=yes >$null 2>&1
netsh advfirewall firewall add rule name="Barrier Port 24800" dir=in action=allow protocol=TCP localport=$Port enable=yes >$null 2>&1
Write-Ok "Porta $Port liberada"

# PASSO 8: Iniciar servidor
Write-Step 8 $total "Iniciando servidor..."
Get-Process barrier* -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep 2
$logFile = "$env:LOCALAPPDATA\Barrier\server.log"
Start-Process "$bp\barriers.exe" -ArgumentList "--config `"$cfgPath`" --name $ServerName --disable-crypto --no-tray --debug INFO" -NoNewWindow -RedirectStandardOutput $logFile -RedirectStandardError "$env:LOCALAPPDATA\Barrier\server_err.log"
Start-Sleep 3

$ok = netstat -an | Select-String ":${Port}.*LISTENING"
if ($ok) { Write-Ok "Servidor LISTENING em 0.0.0.0:$Port" } else { Write-Fail "Servidor nao iniciou!"; Read-Host "Enter"; exit 1 }

# ─── RESULTADO ───
Write-Host "`n╔══════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║         SERVIDOR PRONTO!                 ║" -ForegroundColor Green
Write-Host "╠══════════════════════════════════════════╣" -ForegroundColor Green
Write-Host "║  Host:   $($ServerName.PadRight(32))║" -ForegroundColor Green
Write-Host "║  IP:     $("${myIP}:${Port}".PadRight(32))║" -ForegroundColor Green
Write-Host "║  Client: $($ClientName.PadRight(32))║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor Green
Write-Host "`n  Rode setup_client.ps1 no PC B!`n" -ForegroundColor Yellow

# Monitorar
Write-Host "Monitorando... (Ctrl+C para sair)" -ForegroundColor DarkGray
$lastSz=0; $conn=$false
while ($true) {
    Start-Sleep 2
    if (-not (Get-Process barriers -EA SilentlyContinue)) {
        Write-Warn "Servidor caiu! Reiniciando..."
        Start-Process "$bp\barriers.exe" -ArgumentList "--config `"$cfgPath`" --name $ServerName --disable-crypto --no-tray --debug INFO" -NoNewWindow -RedirectStandardOutput $logFile -RedirectStandardError "$env:LOCALAPPDATA\Barrier\server_err.log"
        Start-Sleep 3
    }
    if (Test-Path $logFile) {
        $c = Get-Content $logFile -Raw -EA SilentlyContinue
        if ($c -and $c.Length -gt $lastSz) {
            $new = $c.Substring($lastSz)
            if ($new -match "has connected" -and -not $conn) { $conn=$true; Write-Host "`n"; Write-Ok "CLIENTE CONECTADO! Teclado/mouse compartilhados!"; Write-Info "Hora: $(Get-Date -Format 'HH:mm:ss')" }
            if ($new -match "disconnected") { $conn=$false; Write-Warn "Cliente desconectou." }
            $lastSz=$c.Length
        }
    }
}
