# ============================================
# BARRIER REMOTE CONTROL - CLIENTE (PC B)
# Rode como ADMINISTRADOR
# ============================================
#
# Configuração — ajuste conforme sua rede:
$ClientName        = $env:COMPUTERNAME          # Nome deste PC (auto-detecta)
$ServerTailscaleIP = "100.122.131.29"           # IP Tailscale do PC servidor
$BarrierPort       = 24800                      # Porta padrão do Barrier
$BarrierPath       = "C:\Program Files\Barrier"
$TailscalePath     = "C:\Program Files\Tailscale"
# ============================================

function Write-Step($step, $total, $msg, $color) {
    Write-Host "[$step/$total] $msg" -ForegroundColor $color
}

function Write-Ok($msg)   { Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Fail($msg) { Write-Host "  ✗ $msg" -ForegroundColor Red }
function Write-Info($msg) { Write-Host "  → $msg" -ForegroundColor White }

$totalSteps = 6

Write-Host ""
Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║    BARRIER REMOTE CONTROL - CLIENTE    ║" -ForegroundColor Cyan
Write-Host "║    PC: $ClientName" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ─── PASSO 1: Verificar Barrier ───
Write-Step 1 $totalSteps "Verificando Barrier..." Yellow
if (Test-Path "$BarrierPath\barrierc.exe") {
    $version = & "$BarrierPath\barrierc.exe" --version 2>&1 | Select-Object -First 1
    Write-Ok "Barrier encontrado: $version"
} else {
    Write-Fail "Barrier NÃO encontrado em $BarrierPath"
    Write-Info "Baixe em: https://github.com/debauchee/barrier/releases/download/v2.4.0/BarrierSetup-2.4.0-release.exe"
    
    $install = Read-Host "Deseja baixar agora? (S/N)"
    if ($install -eq "S" -or $install -eq "s") {
        Write-Info "Baixando Barrier..."
        Invoke-WebRequest -Uri "https://github.com/debauchee/barrier/releases/download/v2.4.0/BarrierSetup-2.4.0-release.exe" -OutFile "$env:USERPROFILE\Downloads\BarrierSetup.exe"
        Write-Info "Instalando..."
        Start-Process "$env:USERPROFILE\Downloads\BarrierSetup.exe" -Wait
        Write-Ok "Instalação concluída!"
    } else {
        exit 1
    }
}

# ─── PASSO 2: Verificar Tailscale ───
Write-Step 2 $totalSteps "Verificando Tailscale..." Yellow
$tsExe = "$TailscalePath\tailscale.exe"
if (Test-Path $tsExe) {
    $tsStatus = & $tsExe status 2>&1
    if ($tsStatus -match "Logged out" -or $tsStatus -match "stopped") {
        Write-Fail "Tailscale não está conectado!"
        Write-Info "Rodando 'tailscale up'..."
        & $tsExe up
        Write-Info "Abra o link no navegador e faça login!"
        Start-Sleep -Seconds 10
        $tsStatus = & $tsExe status 2>&1
    }
    
    $myIP = (& $tsExe ip -4 2>&1).Trim()
    Write-Ok "Tailscale ativo - IP: $myIP"
} else {
    Write-Fail "Tailscale NÃO encontrado!"
    Write-Info "Baixando Tailscale..."
    
    $install = Read-Host "Deseja baixar agora? (S/N)"
    if ($install -eq "S" -or $install -eq "s") {
        Invoke-WebRequest -Uri "https://pkgs.tailscale.com/stable/tailscale-setup-latest.exe" -OutFile "$env:USERPROFILE\Downloads\tailscale-setup.exe"
        Start-Process "$env:USERPROFILE\Downloads\tailscale-setup.exe" -Wait
        Write-Info "Após instalar, rode este script novamente!"
    }
    exit 1
}

# ─── PASSO 3: Testar conexão com servidor ───
Write-Step 3 $totalSteps "Testando conexão com servidor ($ServerTailscaleIP)..." Yellow
$pingResult = & $tsExe ping --c 2 $ServerTailscaleIP 2>&1
if ($pingResult -match "pong") {
    $latency = ($pingResult | Select-String "pong" | Select-Object -First 1).ToString()
    Write-Ok "Servidor acessível! $latency"
} else {
    Write-Fail "Não foi possível conectar ao servidor!"
    Write-Info "Verifique se o servidor está online no Tailscale"
    Write-Info "Resultado: $pingResult"
    exit 1
}

# ─── PASSO 4: Configurar Firewall ───
Write-Step 4 $totalSteps "Configurando Firewall..." Yellow
netsh advfirewall firewall delete rule name="Barrier Client" >$null 2>&1
netsh advfirewall firewall delete rule name="Barrier Port $BarrierPort OUT" >$null 2>&1
netsh advfirewall firewall add rule name="Barrier Client" dir=in action=allow program="$BarrierPath\barrierc.exe" enable=yes >$null 2>&1
netsh advfirewall firewall add rule name="Barrier Port $BarrierPort OUT" dir=out action=allow protocol=TCP remoteport=$BarrierPort enable=yes >$null 2>&1
Write-Ok "Firewall configurado"

# ─── PASSO 5: Parar processos antigos ───
Write-Step 5 $totalSteps "Limpando processos antigos..." Yellow
Get-Process barrier* -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Write-Ok "Processos antigos finalizados"

# ─── PASSO 6: Conectar ao servidor ───
Write-Step 6 $totalSteps "Conectando ao servidor..." Yellow
Write-Info "Servidor: ${ServerTailscaleIP}:${BarrierPort}"
Write-Info "Nome desta tela: $ClientName"

Write-Host ""
Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║        CONECTANDO AO SERVIDOR...       ║" -ForegroundColor Green
Write-Host "║   Ctrl+C para desconectar              ║" -ForegroundColor Yellow
Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

& "$BarrierPath\barrierc.exe" --name $ClientName --disable-crypto --no-tray --debug INFO ${ServerTailscaleIP}:${BarrierPort}
