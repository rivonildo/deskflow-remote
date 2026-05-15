# ============================================
# BARRIER REMOTE CONTROL - SERVIDOR (PC A)
# Rode como ADMINISTRADOR
# ============================================
#
# Configuração — ajuste conforme sua rede:
$ServerName       = $env:COMPUTERNAME          # Nome deste PC (auto-detecta)
$ClientName       = "DESKTOP-E2MKULO"          # Nome do PC cliente
$ServerTailscaleIP = ""                        # Deixe vazio para auto-detectar
$BarrierPort      = 24800                      # Porta padrão do Barrier
$BarrierPath      = "C:\Program Files\Barrier"
$TailscalePath    = "C:\Program Files\Tailscale"
# ============================================

function Write-Step($step, $total, $msg, $color) {
    Write-Host "[$step/$total] $msg" -ForegroundColor $color
}

function Write-Ok($msg)   { Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Fail($msg) { Write-Host "  ✗ $msg" -ForegroundColor Red }
function Write-Info($msg) { Write-Host "  → $msg" -ForegroundColor White }

$totalSteps = 7

Write-Host ""
Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   BARRIER REMOTE CONTROL - SERVIDOR    ║" -ForegroundColor Cyan
Write-Host "║   PC: $ServerName" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ─── PASSO 1: Verificar Barrier ───
Write-Step 1 $totalSteps "Verificando Barrier..." Yellow
if (Test-Path "$BarrierPath\barriers.exe") {
    $version = & "$BarrierPath\barriers.exe" --version 2>&1 | Select-Object -First 1
    Write-Ok "Barrier encontrado: $version"
} else {
    Write-Fail "Barrier NÃO encontrado em $BarrierPath"
    Write-Info "Baixe em: https://github.com/debauchee/barrier/releases/download/v2.4.0/BarrierSetup-2.4.0-release.exe"
    exit 1
}

# ─── PASSO 2: Verificar Tailscale ───
Write-Step 2 $totalSteps "Verificando Tailscale..." Yellow
$tsExe = "$TailscalePath\tailscale.exe"
if (Test-Path $tsExe) {
    $tsStatus = & $tsExe status 2>&1
    if ($tsStatus -match "Logged out") {
        Write-Fail "Tailscale não está logado!"
        Write-Info "Rodando 'tailscale up'..."
        & $tsExe up
        Start-Sleep -Seconds 5
        $tsStatus = & $tsExe status 2>&1
    }
    
    # Auto-detectar IP Tailscale
    if ([string]::IsNullOrEmpty($ServerTailscaleIP)) {
        $ServerTailscaleIP = (& $tsExe ip -4 2>&1).Trim()
    }
    Write-Ok "Tailscale ativo - IP: $ServerTailscaleIP"
    
    # Mostrar peers online
    $tsStatus | ForEach-Object {
        if ($_ -notmatch "offline" -and $_ -match "\d+\.\d+\.\d+\.\d+") {
            Write-Info $_
        }
    }
} else {
    Write-Fail "Tailscale NÃO encontrado!"
    Write-Info "Baixe em: https://tailscale.com/download/windows"
    exit 1
}

# ─── PASSO 3: Gerar Certificado SSL ───
Write-Step 3 $totalSteps "Configurando SSL..." Yellow
$sslDir = "$env:LOCALAPPDATA\Barrier\SSL"
$fingerDir = "$sslDir\Fingerprints"
New-Item -Path $fingerDir -ItemType Directory -Force | Out-Null

if (-not (Test-Path "$sslDir\Barrier.pem")) {
    $tempDir = "C:\BarrierTemp"
    New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
    
    $opensslConf = "[req]`ndefault_bits = 2048`ndistinguished_name = dn`nprompt = no`n[dn]`nCN = Barrier"
    $opensslConf | Out-File -FilePath "$tempDir\openssl.cnf" -Encoding ascii
    
    & "$BarrierPath\openssl.exe" req -config "$tempDir\openssl.cnf" -x509 -nodes -days 3650 -newkey rsa:2048 -keyout "$tempDir\Barrier.pem" -out "$tempDir\Barrier.pem" 2>&1 | Out-Null
    Copy-Item "$tempDir\Barrier.pem" "$sslDir\Barrier.pem" -Force
    
    $fp = & "$BarrierPath\openssl.exe" x509 -fingerprint -sha256 -noout -in "$tempDir\Barrier.pem" 2>&1
    $fpClean = ($fp -replace ".*=","").Trim()
    
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText("$fingerDir\Local.txt", "v2:sha256:$fpClean", $utf8)
    [System.IO.File]::WriteAllText("$fingerDir\TrustedServers.txt", "v2:sha256:$fpClean", $utf8)
    [System.IO.File]::WriteAllText("$fingerDir\TrustedClients.txt", "v2:sha256:$fpClean", $utf8)
    
    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Ok "Certificado SSL gerado!"
} else {
    Write-Ok "Certificado SSL já existe"
}

# ─── PASSO 4: Criar Configuração ───
Write-Step 4 $totalSteps "Criando configuração de telas..." Yellow
$configPath = "$env:LOCALAPPDATA\Barrier\barrier.sgc"

$config = @"
section: screens
	${ServerName}:
		halfDuplexCapsLock = false
		halfDuplexNumLock = false
		halfDuplexScrollLock = false
		switchCorners = none
		switchCornerSize = 0
	${ClientName}:
		halfDuplexCapsLock = false
		halfDuplexNumLock = false
		halfDuplexScrollLock = false
		switchCorners = none
		switchCornerSize = 0
end

section: aliases
end

section: links
	${ServerName}:
		right = ${ClientName}
	${ClientName}:
		left = ${ServerName}
end

section: options
	relativeMouseMoves = false
	screenSaverSync = true
	win32KeepForeground = false
	clipboardSharing = true
	switchCorners = none
	switchCornerSize = 0
end
"@

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($configPath, $config, $utf8NoBom)
Write-Ok "Config criada: $configPath"
Write-Info "Servidor: $ServerName (direita) → Cliente: $ClientName"

# ─── PASSO 5: Configurar Firewall ───
Write-Step 5 $totalSteps "Configurando Firewall..." Yellow
netsh advfirewall firewall delete rule name="Barrier Server In" >$null 2>&1
netsh advfirewall firewall delete rule name="Barrier Port $BarrierPort" >$null 2>&1
netsh advfirewall firewall add rule name="Barrier Server In" dir=in action=allow program="$BarrierPath\barriers.exe" enable=yes >$null 2>&1
netsh advfirewall firewall add rule name="Barrier Port $BarrierPort" dir=in action=allow protocol=TCP localport=$BarrierPort enable=yes >$null 2>&1
Write-Ok "Firewall configurado (porta $BarrierPort aberta)"

# ─── PASSO 6: Parar processos antigos ───
Write-Step 6 $totalSteps "Limpando processos antigos..." Yellow
Get-Process barrier* -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Write-Ok "Processos antigos finalizados"

# ─── PASSO 7: Iniciar Servidor ───
Write-Step 7 $totalSteps "Iniciando servidor Barrier..." Yellow
$logFile = "$env:LOCALAPPDATA\Barrier\server.log"

Start-Process -FilePath "$BarrierPath\barriers.exe" `
    -ArgumentList "--config `"$configPath`" --name $ServerName --disable-crypto --no-tray --debug INFO" `
    -NoNewWindow `
    -RedirectStandardOutput $logFile `
    -RedirectStandardError "$env:LOCALAPPDATA\Barrier\server_err.log"

Start-Sleep -Seconds 3

# Validar
$listening = netstat -an | Select-String ":$BarrierPort.*LISTENING"
if ($listening) {
    Write-Ok "Servidor rodando na porta $BarrierPort!"
} else {
    Write-Fail "Servidor NÃO está escutando!"
    Write-Info "Verifique o log: $logFile"
    exit 1
}

# ─── RESULTADO FINAL ───
Write-Host ""
Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║        SERVIDOR PRONTO! ✓              ║" -ForegroundColor Green
Write-Host "╠════════════════════════════════════════╣" -ForegroundColor Green
Write-Host "║  Nome:  $ServerName" -ForegroundColor Green
Write-Host "║  IP:    ${ServerTailscaleIP}:${BarrierPort}" -ForegroundColor Green
Write-Host "║  Log:   $logFile" -ForegroundColor Green
Write-Host "╠════════════════════════════════════════╣" -ForegroundColor Green
Write-Host "║  Aguardando cliente: $ClientName" -ForegroundColor Yellow
Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "No PC B ($ClientName), rode:" -ForegroundColor Cyan
Write-Host "  .\setup_client.ps1" -ForegroundColor White
Write-Host ""

# Monitorar conexões
Write-Host "Monitorando conexões (Ctrl+C para sair)..." -ForegroundColor Gray
$lastSize = 0
while ($true) {
    Start-Sleep -Seconds 2
    if (Test-Path $logFile) {
        $content = Get-Content $logFile -Raw
        if ($content.Length -gt $lastSize) {
            $newContent = $content.Substring($lastSize)
            if ($newContent -match "has connected") {
                Write-Host ""
                Write-Host "🎉 CLIENTE CONECTADO!" -ForegroundColor Green
                $newContent -split "`n" | Where-Object { $_ -match "connected|client" } | ForEach-Object {
                    Write-Host "  $_" -ForegroundColor Cyan
                }
            }
            $lastSize = $content.Length
        }
    }
}
