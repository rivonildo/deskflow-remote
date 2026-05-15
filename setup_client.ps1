# BARRIER REMOTE CONTROL - CLIENTE (100% AUTOMATICO)
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
    Start-Sleep 5
    $dir = Find-Exe $name
    Remove-Item $installer -Force -ErrorAction SilentlyContinue
    if ($dir) { Write-Ok "Instalado!" } else { Write-Fail "Instalacao falhou." }
    return $dir
}

function Ensure-TailscaleUp($tsExe) {
    $status = & $tsExe status 2>&1 | Out-String
    if ($status -match "Logged out|stopped|NeedsLogin") {
        Write-Warn "Tailscale desconectado. Iniciando login..."
        Start-Job -ScriptBlock { param($e) & $e up 2>&1 } -ArgumentList $tsExe | Out-Null
        Start-Sleep 3
        $loginOut = & $tsExe status 2>&1 | Out-String
        if ($loginOut -match "(https://login\.tailscale\.com/\S+)") {
            Write-Info "Abrindo navegador para autorizacao..."
            Start-Process $Matches[1]
            for ($i = 0; $i -lt 12; $i++) {
                Start-Sleep 5
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

function Find-BarrierServer($tsExe, $peers, $port) {
    $myHost = $env:COMPUTERNAME.ToLower()
    $candidates = $peers | Where-Object { $_.OS -eq "windows" -and $_.Host -ne $myHost -and $_.Status -notmatch "offline.*ago" }
    
    Write-Info "Procurando servidor Barrier (porta $port) nos peers..."
    
    foreach ($c in $candidates) {
        Write-Host "    Testando $($c.Host) ($($c.IP))..." -NoNewline -ForegroundColor Gray
        
        # Primeiro verifica se peer responde via Tailscale
        $ping = & $tsExe ping --c 1 --timeout 5s $c.IP 2>&1 | Out-String
        if ($ping -notmatch "pong") { Write-Host " offline" -ForegroundColor DarkGray; continue }
        
        # Tenta conectar na porta do Barrier
        $tcp = New-Object System.Net.Sockets.TcpClient
        try {
            $result = $tcp.BeginConnect($c.IP, $port, $null, $null)
            $waited = $result.AsyncWaitHandle.WaitOne(3000, $false)
            if ($waited -and $tcp.Connected) {
                $tcp.Close()
                Write-Host " SERVIDOR ENCONTRADO!" -ForegroundColor Green
                return $c
            }
            $tcp.Close()
            Write-Host " sem Barrier" -ForegroundColor DarkGray
        } catch {
            Write-Host " erro" -ForegroundColor DarkGray
        }
    }
    return $null
}

# ════════════════════════════════════════
#            INICIO DO SCRIPT
# ════════════════════════════════════════
Clear-Host
Write-Host "`n╔══════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  BARRIER REMOTE CONTROL - CLIENTE        ║" -ForegroundColor Cyan
Write-Host "║  PC: $($env:COMPUTERNAME.PadRight(36))║" -ForegroundColor Cyan
Write-Host "║  Modo: 100% Automatico                   ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor Cyan

$ClientName = $env:COMPUTERNAME
$Port = 24800
$total = 7

# PASSO 1: Barrier
Write-Step 1 $total "Verificando Barrier..."
$bp = Install-IfMissing "barrierc.exe" "https://github.com/debauchee/barrier/releases/download/v2.4.0/BarrierSetup-2.4.0-release.exe" "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART"
if (-not $bp) { Read-Host "Enter para sair"; exit 1 }

# PASSO 2: Tailscale
Write-Step 2 $total "Verificando Tailscale..."
$tp = Install-IfMissing "tailscale.exe" "https://pkgs.tailscale.com/stable/tailscale-setup-latest.exe" "/install /quiet"
if (-not $tp) { Read-Host "Enter para sair"; exit 1 }
$tsExe = "$tp\tailscale.exe"

# PASSO 3: Conectar Tailscale
Write-Step 3 $total "Conectando Tailscale..."
if (-not (Ensure-TailscaleUp $tsExe)) { Write-Fail "Tailscale nao conectou."; Read-Host "Enter"; exit 1 }
$myIP = (& $tsExe ip -4 2>&1).Trim()
Write-Ok "IP Tailscale: $myIP"

# PASSO 4: Descobrir servidor
Write-Step 4 $total "Descobrindo servidor Barrier na rede..."
$peers = Get-Peers $tsExe

Write-Info "PCs na rede Tailscale:"
foreach ($p in $peers) {
    $icon = if ($p.Status -match "offline") { "OFFLINE" } else { "ONLINE" }
    $c = if ($p.Status -match "offline") { "DarkGray" } else { "Green" }
    Write-Host "    [$icon] $($p.Host) ($($p.IP)) [$($p.OS)]" -ForegroundColor $c
}

$server = Find-BarrierServer $tsExe $peers $Port

if (-not $server) {
    Write-Warn "Servidor Barrier nao encontrado automaticamente."
    Write-Info "Tentando com todos os peers Windows online..."
    
    $myHost = $env:COMPUTERNAME.ToLower()
    $winOnline = $peers | Where-Object { $_.OS -eq "windows" -and $_.Host -ne $myHost -and $_.Status -notmatch "offline.*ago" }
    
    if ($winOnline.Count -ge 1) {
        # Usar o primeiro peer Windows online que responde ao ping
        foreach ($w in $winOnline) {
            $ping = & $tsExe ping --c 1 --timeout 5s $w.IP 2>&1 | Out-String
            if ($ping -match "pong") { $server = $w; break }
        }
    }
    
    if (-not $server) {
        Write-Fail "Nenhum servidor encontrado!"
        Write-Info "Certifique-se que setup_server.ps1 esta rodando no PC A."
        Read-Host "Enter para sair"
        exit 1
    }
    Write-Warn "Usando $($server.Host) ($($server.IP)) - servidor pode ainda estar iniciando."
}

$ServerIP = $server.IP
$ServerHost = $server.Host.ToUpper()
Write-Ok "Servidor: $ServerHost ($ServerIP)"

# PASSO 5: Firewall
Write-Step 5 $total "Configurando Firewall..."
netsh advfirewall firewall delete rule name="Barrier Client" >$null 2>&1
netsh advfirewall firewall delete rule name="Barrier Port 24800 OUT" >$null 2>&1
netsh advfirewall firewall add rule name="Barrier Client" dir=in action=allow program="$bp\barrierc.exe" enable=yes >$null 2>&1
netsh advfirewall firewall add rule name="Barrier Port 24800 OUT" dir=out action=allow protocol=TCP remoteport=$Port enable=yes >$null 2>&1
Write-Ok "Firewall configurado"

# PASSO 6: Limpar processos
Write-Step 6 $total "Limpando processos antigos..."
Get-Process barrier* -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep 2
Write-Ok "Processos limpos"

# PASSO 7: Conectar ao servidor
Write-Step 7 $total "Conectando ao servidor..."
Write-Info "Servidor: ${ServerIP}:${Port}"
Write-Info "Nome desta tela: $ClientName"

# Tentar conectar com retry automatico
$maxRetries = 5
$connected = $false

for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
    Write-Info "Tentativa $attempt/$maxRetries..."
    
    $logFile = "$env:LOCALAPPDATA\Barrier\client.log"
    
    # Iniciar cliente em background
    $proc = Start-Process "$bp\barrierc.exe" `
        -ArgumentList "--name $ClientName --disable-crypto --no-tray --debug INFO --no-restart ${ServerIP}:${Port}" `
        -NoNewWindow -PassThru `
        -RedirectStandardOutput $logFile `
        -RedirectStandardError "$env:LOCALAPPDATA\Barrier\client_err.log"
    
    # Aguardar ate 20 segundos por conexao
    for ($w = 0; $w -lt 20; $w++) {
        Start-Sleep 1
        if ($proc.HasExited) { break }
        if (Test-Path $logFile) {
            $log = Get-Content $logFile -Raw -ErrorAction SilentlyContinue
            if ($log -match "connected to server") {
                $connected = $true
                break
            }
        }
    }
    
    if ($connected) { break }
    
    # Se nao conectou, matar e tentar de novo
    if (-not $proc.HasExited) { $proc | Stop-Process -Force -ErrorAction SilentlyContinue }
    
    if ($attempt -lt $maxRetries) {
        Write-Warn "Timeout. Aguardando 5s antes de tentar novamente..."
        Start-Sleep 5
    }
}

if ($connected) {
    Write-Host "`n╔══════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║         CONECTADO COM SUCESSO!           ║" -ForegroundColor Green
    Write-Host "╠══════════════════════════════════════════╣" -ForegroundColor Green
    Write-Host "║  Cliente: $($ClientName.PadRight(31))║" -ForegroundColor Green
    Write-Host "║  IP:      $($myIP.PadRight(31))║" -ForegroundColor Green
    Write-Host "║  Server:  $("$ServerHost ($ServerIP)".PadRight(31))║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host "`n  Teclado e mouse compartilhados!" -ForegroundColor Cyan
    Write-Host "  Mova o mouse para a borda esquerda para voltar ao servidor.`n" -ForegroundColor DarkGray
    
    # Monitorar conexao
    Write-Host "Monitorando conexao... (Ctrl+C para desconectar)" -ForegroundColor DarkGray
    $lastSz = 0
    while ($true) {
        Start-Sleep 3
        # Se o processo morreu, reconectar
        if ($proc.HasExited) {
            Write-Warn "Conexao perdida! Reconectando..."
            $proc = Start-Process "$bp\barrierc.exe" `
                -ArgumentList "--name $ClientName --disable-crypto --no-tray --debug INFO ${ServerIP}:${Port}" `
                -NoNewWindow -PassThru `
                -RedirectStandardOutput $logFile `
                -RedirectStandardError "$env:LOCALAPPDATA\Barrier\client_err.log"
            Start-Sleep 5
            if (-not $proc.HasExited) { Write-Ok "Reconectado!" }
        }
    }
} else {
    Write-Host "`n╔══════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║         FALHA NA CONEXAO                 ║" -ForegroundColor Red
    Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    Write-Info "Verifique:"
    Write-Info "  1. O setup_server.ps1 esta rodando no PC A?"
    Write-Info "  2. Os dois PCs estao na mesma rede Tailscale?"
    Write-Info "  3. O firewall do servidor permite porta $Port?"
    Write-Host ""
    if (Test-Path $logFile) {
        Write-Info "Log do cliente:"
        Get-Content $logFile | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    }
    Read-Host "`nPressione Enter para sair"
    exit 1
}
