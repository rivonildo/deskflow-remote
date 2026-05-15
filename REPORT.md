# 📊 Relatório Técnico — Barrier Remote Control

**Data:** 15/05/2026  
**Autor:** Rivonildo (assistido por IA)  
**Projeto:** Controle remoto de teclado/mouse entre notebooks via rede

---

## 1. Objetivo

Controlar o **teclado e mouse** do Notebook A no Notebook B remotamente via rede, permitindo que uma única pessoa opere dois computadores com um único par de teclado/mouse.

## 2. Ambiente

| Item | PC A (Servidor) | PC B (Cliente) |
|---|---|---|
| **Hostname** | DESKTOP-M1PCNBO | DESKTOP-E2MKULO |
| **Usuário Windows** | Usuário | Moisés |
| **Windows** | 10 22H2 | 10 22H2 |
| **IP Tailscale** | 100.122.131.29 | 100.117.172.86 |
| **IP Wi-Fi** | — | 192.168.1.75 |
| **Função Barrier** | Servidor (barriers.exe) | Cliente (barrierc.exe) |

## 3. Tecnologias Utilizadas

### 3.1 Barrier v2.4.0
- **O que é:** Software open source para compartilhamento de teclado/mouse entre computadores (fork do Synergy)
- **Como funciona:** O servidor captura inputs do teclado/mouse e transmite via TCP (porta 24800) para o cliente
- **Licença:** GPLv2
- **Link:** https://github.com/debauchee/barrier

### 3.2 Tailscale v1.96-1.98
- **O que é:** VPN mesh peer-to-peer baseada no WireGuard
- **Como funciona:** Cria uma rede privada virtual entre dispositivos, mesmo em redes diferentes, com NAT traversal automático
- **Por que usar:** Os dois notebooks estavam em redes Wi-Fi diferentes/conflitantes — ping direto não funcionava
- **Criptografia:** WireGuard (já criptografa todo o tráfego)
- **Link:** https://tailscale.com

## 4. Problemas Encontrados e Soluções

### 4.1 Redes Wi-Fi conflitantes
- **Problema:** Ping direto entre os notebooks via Wi-Fi falhava (100% perda)
- **Causa:** Notebooks em redes diferentes sem roteamento entre elas
- **Solução:** Tailscale como camada de rede (VPN mesh)

### 4.2 Erro de encoding no arquivo de configuração
- **Problema:** `invalid character 0xffffffef` ao ler barrier.sgc
- **Causa:** PowerShell salvou o arquivo com BOM (Byte Order Mark) UTF-8
- **Solução:** Usar `System.Text.UTF8Encoding($false)` para salvar sem BOM

### 4.3 Falha na verificação de certificado SSL
- **Problema:** `failed to verify server certificate fingerprint`
- **Causa:** Arquivos TrustedServers.txt e TrustedClients.txt não existiam
- **Solução:** Desabilitar SSL do Barrier (redundante sobre Tailscale que já usa WireGuard)

### 4.4 Firewall bloqueando conexões (GPO)
- **Problema:** Regras de firewall locais ignoradas — `LocalFirewallRules: N/D (apenas repositório GPO)`
- **Causa:** Política de grupo sobrescrevendo regras locais
- **Solução:** Adicionar regras via `netsh advfirewall` como administrador

### 4.5 Tailscale não conectado no PC B
- **Problema:** PC B instalou Tailscale mas não completou o login
- **Causa:** Comando `tailscale up` foi cancelado antes de abrir o link de autenticação no navegador
- **Solução:** Executar `tailscale up`, copiar URL gerada, abrir no navegador e autorizar o dispositivo

### 4.6 Nome do PC B desconhecido
- **Problema:** Config do Barrier usava placeholder "NotebookB"
- **Causa:** Nome real do PC B (DESKTOP-E2MKULO) só foi descoberto durante a configuração
- **Solução:** Atualizar barrier.sgc com o hostname real

## 5. Configuração Final

### 5.1 Servidor (PC A)
```powershell
barriers.exe --config barrier.sgc --name DESKTOP-M1PCNBO --disable-crypto --no-tray --debug INFO
```

### 5.2 Cliente (PC B)
```powershell
barrierc.exe --name DESKTOP-E2MKULO --disable-crypto --no-tray --debug INFO 100.122.131.29:24800
```

### 5.3 Layout de Telas
```
[DESKTOP-M1PCNBO] ←→ [DESKTOP-E2MKULO]
     (esquerda)           (direita)
```
Mouse sai pela borda direita do A → aparece na borda esquerda do B.

## 6. Validação

| Teste | Resultado |
|---|---|
| Tailscale ping A→B | ✅ 8ms via WireGuard |
| Servidor escutando porta 24800 | ✅ `0.0.0.0:24800 LISTENING` |
| Cliente conectou ao servidor | ✅ `client "DESKTOP-E2MKULO" has connected` |
| Clipboard compartilhado | ✅ Clipboard 0 e 1 sincronizados |
| Mouse passando entre telas | ✅ Funcional |
| Teclado enviando inputs | ✅ Funcional |

### Logs de Validação

**Servidor (PC A):**
```
[2026-05-15T18:35:22] NOTE: accepted client connection
[2026-05-15T18:35:22] NOTE: client "DESKTOP-E2MKULO" has connected
[2026-05-15T18:35:29] INFO: screen "DESKTOP-E2MKULO" grabbed clipboard 0 from "DESKTOP-M1PCNBO"
[2026-05-15T18:35:29] INFO: screen "DESKTOP-E2MKULO" updated clipboard 0
```

**Cliente (PC B):**
```
[2026-05-15T18:35:22] NOTE: started client
[2026-05-15T18:35:22] NOTE: connecting to '100.122.131.29': 100.122.131.29:24800
connected to server
```

## 7. Segurança

- **Criptografia:** Todo o tráfego passa pelo Tailscale (WireGuard) — criptografia ponta-a-ponta
- **SSL Barrier:** Desabilitado (redundante sobre WireGuard)
- **Exposição:** Nenhuma porta exposta à internet — apenas acessível via rede Tailscale privada
- **Autenticação:** Dispositivos autenticados via conta Tailscale (rivonildo@github)

## 8. Limitações

1. **Bloqueio de digitação local:** O Barrier NÃO bloqueia digitação no PC A quando o cursor está no A. Só redireciona quando o cursor está no PC B.
2. **Dependência do Tailscale:** Ambos os PCs precisam do Tailscale ativo para comunicação
3. **Latência:** ~8ms via Tailscale (imperceptível para uso normal)

## 9. Arquivos do Projeto

```
barrier-remote-control/
├── README.md              → Documentação de uso
├── REPORT.md              → Este relatório
├── setup_server.ps1       → Script automático PC A (servidor)
├── setup_client.ps1       → Script automático PC B (cliente)
└── config/
    └── barrier.sgc        → Configuração de layout das telas
```
