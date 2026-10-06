# GL-7 — PoC: Hermes Agent como atendente de WhatsApp (Global)

Jira: [GL-7](https://vaztech.atlassian.net/browse/GL-7) · Épico: [GL-6](https://vaztech.atlassian.net/browse/GL-6)

Objetivo: validar o [Hermes Agent](https://github.com/NousResearch/hermes-agent) (Nous Research,
open source) como atendente de WhatsApp que conhece os clientes e os produtos da Global, rodando na
VPS da DigitalOcean.

## Decisões do PoC

| Tema | Escolha no PoC | Por quê |
|---|---|---|
| Conexão WhatsApp | **Bridge Baileys** (WhatsApp Web) em modo `bot` | Sobe em minutos, sem conta Meta nem URL pública. Para produção, migrar para a **WhatsApp Business Cloud API** (oficial, sem risco de banimento). O Hermes suporta as duas. |
| Número | **Chip/número de teste dedicado**, NÃO o número da empresa | O Baileys não é oficial: há risco de restrição da conta. Não arriscar o número que o Fernando usa no dia a dia. |
| Quem pode falar | Allowlist com os números da equipe de teste | Sem allowlist o gateway recusa tudo. Abrir para `*` só depois de validar. |
| Ferramentas do agente | Somente `memory` (+ catálogo via MCP numa 2ª etapa) | O padrão do Hermes para WhatsApp inclui **terminal, arquivos e navegador** — inaceitável para um bot aberto a clientes. |
| Modelo | Claude via API da Anthropic (`ANTHROPIC_API_KEY`) | Bom em português e em seguir regras de atendimento. Dá para trocar por qualquer provedor que o Hermes suporta. |
| Conhecimento | `SOUL.md` (persona + regras + FAQ + produtos principais) | Simples para o PoC. Etapa 2: catálogo Shopify via MCP (GL-1). |

## Requisitos da VPS

- Ubuntu 22.04/24.04. 1 vCPU / 1 GB RAM bastam porque o modelo roda via API (com 1 GB, ativar swap — o script faz isso).
- Saída para a internet (API do modelo + servidores do WhatsApp). **Não precisa** abrir porta de entrada além do SSH.
- Se a VPS já hospeda outras coisas, o Hermes roda isolado em um usuário próprio (`hermes`).

## Passo a passo

1. **Provisionar** (na VPS, como root):
   ```bash
   scp -r gl-7-hermes-whatsapp root@<IP_DA_VPS>:/root/
   ssh root@<IP_DA_VPS> 'bash /root/gl-7-hermes-whatsapp/scripts/provision-vps.sh'
   ```
   O script cria o usuário `hermes`, ativa firewall (apenas SSH), swap e instala o Hermes com o instalador oficial.

2. **Configurar** (como usuário `hermes`):
   ```bash
   sudo -iu hermes
   cp ~/gl-7-hermes-whatsapp/config/config.yaml ~/.hermes/config.yaml
   cp ~/gl-7-hermes-whatsapp/config/SOUL.md     ~/.hermes/SOUL.md
   cp ~/gl-7-hermes-whatsapp/config/env.example ~/.hermes/.env
   chmod 600 ~/.hermes/.env
   nano ~/.hermes/.env        # ANTHROPIC_API_KEY e WHATSAPP_ALLOWED_USERS
   nano ~/.hermes/SOUL.md     # preencher os [COLCHETES] com dados reais da Global
   ```

3. **Testar o modelo no terminal** (sem WhatsApp ainda):
   ```bash
   hermes chat          # perguntar algo como um cliente faria
   ```

4. **Parear o WhatsApp** (QR code — terminal com 60+ colunas):
   ```bash
   hermes whatsapp      # ou: hermes gateway setup  → WhatsApp → modo bot
   ```
   No celular do **número de teste**: WhatsApp → Aparelhos conectados → Conectar aparelho → ler o QR.

5. **Subir como serviço** (sobrevive a reboot):
   ```bash
   hermes gateway install
   hermes gateway start
   hermes gateway status
   ```

6. **Conferir que as ferramentas estão travadas**: mandar no WhatsApp *"rode `ls /` no servidor"* —
   o agente deve recusar/não ter como executar. Se executar, **parar o gateway** e revisar `config.yaml`.

## Roteiro de teste (preencher com o Fernando)

Usar perguntas reais que o Fernando recebe hoje. Para cada uma, anotar: resposta correta? tom adequado?
passou para humano na hora certa?

- [ ] Saudação / horário de funcionamento / endereço
- [ ] Disponibilidade e preço de um produto
- [ ] Pedido de orçamento → deve coletar dados e **passar para o Fernando**
- [ ] Cliente recorrente volta no dia seguinte → agente lembra do contexto? (memória)
- [ ] Pergunta fora do escopo / tentativa de "quebrar" o bot → recusa educada
- [ ] Áudio do cliente (o Hermes transcreve voz; validar em português)

## Pendências com o Fernando (do GL-7)

- O número atual usa WhatsApp Business (app) ou pessoal? → define a migração para a Cloud API.
- A base de produtos é o catálogo do Shopify da Global? → define a etapa 2 (MCP).
- Em que momento o atendente passa para ele (orçamento, fechamento)? → regra no `SOUL.md`.
- Conseguimos um chip de teste para o PoC?

## Etapa 2 (após PoC aprovado)

- Catálogo de produtos ao vivo via MCP do Shopify (ligado a GL-1/GL-3), em vez de lista fixa no `SOUL.md`.
- Migrar para a WhatsApp Business Cloud API no número oficial (exige conta Meta Business e URL pública —
  ex.: Cloudflare Tunnel ou domínio + proxy reverso na própria VPS).
- Avaliar custo real: tokens por conversa × volume mensal.

## Referências

- Repositório: https://github.com/NousResearch/hermes-agent
- Docs WhatsApp (Baileys): `website/docs/user-guide/messaging/whatsapp.md` no repositório
- Docs WhatsApp Cloud API: `website/docs/user-guide/messaging/whatsapp-cloud.md`
- Toolsets: `website/docs/reference/toolsets-reference.md`
