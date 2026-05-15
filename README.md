# 🖥️ Barrier Remote Control via Tailscale

Controle o teclado e mouse de um notebook remotamente — **100% automático, zero configuração**.

## 🚀 Como Usar

### PC A (Servidor — o que controla)
```powershell
# Clique direito no setup_server.ps1 → "Executar com PowerShell"
# Ou abra PowerShell como Admin e rode:
powershell -ExecutionPolicy Bypass -File setup_server.ps1
```

### PC B (Cliente — o que é controlado)
```powershell
# Clique direito no setup_client.ps1 → "Executar com PowerShell"
# Ou abra PowerShell como Admin e rode:
powershell -ExecutionPolicy Bypass -File setup_client.ps1
```

**Pronto!** Os scripts fazem tudo sozinhos. 🎉

## ✨ O que os scripts fazem automaticamente

| Etapa | Descrição |
|---|---|
| 📦 **Instala Barrier** | Baixa e instala silenciosamente se não existir |
| 🔗 **Instala Tailscale** | Baixa e instala silenciosamente se não existir |
| 🔑 **Login Tailscale** | Abre navegador automaticamente para autenticação |
| 🔍 **Descobre peers** | Encontra o outro PC na rede Tailscale automaticamente |
| 🎯 **Encontra servidor** | Cliente escaneia porta 24800 nos peers para achar o servidor |
| 🛡️ **Configura firewall** | Abre porta 24800 automaticamente |
| 🔒 **Gera SSL** | Cria certificados automaticamente |
| ⚙️ **Configura telas** | Cria layout de telas baseado nos hostnames detectados |
| 🔄 **Reconecta** | Se a conexão cair, reconecta automaticamente |
| 📊 **Monitora** | Exibe status em tempo real no terminal |

## 🏗️ Arquitetura

```
┌──────────────────┐      Tailscale VPN       ┌──────────────────┐
│   PC A (Servidor)│◄────────────────────────►│   PC B (Cliente) │
│  setup_server.ps1│      WireGuard           │ setup_client.ps1 │
│                  │         :24800            │                  │
│  barriers.exe    │◄─── TCP connection ──────│  barrierc.exe    │
│  (envia input)   │                          │  (recebe input)  │
└──────────────────┘                          └──────────────────┘
```

## 📋 Requisitos

- Windows 10/11
- Conexão com internet (para download e Tailscale)
- Mesma conta Tailscale nos dois PCs

> **Não precisa instalar nada manualmente!** Os scripts instalam Barrier e Tailscale automaticamente.

## 🔒 Segurança

- Tráfego criptografado via **Tailscale/WireGuard**
- Nenhuma porta exposta à internet
- Funciona entre redes diferentes (NAT traversal)

## 📁 Arquivos

```
barrier-remote-control/
├── README.md           ← Este arquivo
├── REPORT.md           ← Relatório técnico
├── setup_server.ps1    ← Script do servidor (PC A)
├── setup_client.ps1    ← Script do cliente (PC B)
└── config/
    └── barrier.sgc     ← Config de referência
```

## 📄 Licença

MIT
