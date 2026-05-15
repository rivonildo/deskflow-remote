# 🖥️ Barrier Remote Control via Tailscale

Controle o teclado e mouse de um notebook remotamente usando **Barrier** (open source) e **Tailscale** (VPN mesh).

## 📋 Visão Geral

| Componente | Descrição |
|---|---|
| **Barrier** | Software open source de compartilhamento de teclado/mouse (fork do Synergy) |
| **Tailscale** | VPN mesh peer-to-peer que cria rede privada entre dispositivos |
| **PC A (Servidor)** | Controla o teclado/mouse — envia inputs |
| **PC B (Cliente)** | Recebe os inputs do PC A |

## 🏗️ Arquitetura

```
┌──────────────────┐      Tailscale VPN       ┌──────────────────┐
│   PC A (Servidor)│◄────────────────────────►│   PC B (Cliente) │
│   DESKTOP-M1PCNBO│      100.122.131.29      │  DESKTOP-E2MKULO │
│                  │         :24800            │  100.117.172.86  │
│  barriers.exe    │◄─── TCP connection ──────│  barrierc.exe    │
│  (envia input)   │                          │  (recebe input)  │
└──────────────────┘                          └──────────────────┘
```

## 🚀 Instalação Rápida

### Pré-requisitos
- Windows 10/11
- [Barrier 2.4.0](https://github.com/debauchee/barrier/releases/download/v2.4.0/BarrierSetup-2.4.0-release.exe)
- [Tailscale](https://tailscale.com/download/windows)

### No PC A (Servidor/Controlador)
```powershell
# Abra o PowerShell como Administrador
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
.\setup_server.ps1
```

### No PC B (Cliente/Controlado)
```powershell
# Abra o PowerShell como Administrador
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
.\setup_client.ps1
```

## ⚙️ Configuração

Edite os parâmetros no início de cada script conforme sua rede:

| Parâmetro | Descrição | Padrão |
|---|---|---|
| `$ServerName` | Hostname do PC servidor | `DESKTOP-M1PCNBO` |
| `$ClientName` | Hostname do PC cliente | `DESKTOP-E2MKULO` |
| `$ServerTailscaleIP` | IP Tailscale do servidor | `100.122.131.29` |
| `$BarrierPort` | Porta do Barrier | `24800` |

## 📁 Estrutura do Projeto

```
barrier-remote-control/
├── README.md              # Este arquivo
├── REPORT.md              # Relatório técnico completo
├── setup_server.ps1       # Script automático para PC A
├── setup_client.ps1       # Script automático para PC B
└── config/
    └── barrier.sgc        # Configuração de telas do Barrier
```

## 🔒 Segurança

- O tráfego é criptografado pelo **Tailscale** (WireGuard)
- SSL do Barrier desabilitado (redundante sobre Tailscale)
- Funciona entre redes diferentes (NAT traversal via Tailscale)

## 📄 Licença

MIT License
