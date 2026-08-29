# Relatório de implementação — Marco 3: Navegação de janelas

## Escopo recebido

- Requisito: iniciar o Marco 3 após a aprovação formal do Marco 2.
- Critérios de aceitação: descoberta Wayland/XWayland, identidade confiável, regras manuais, agrupamento, ordem estável, foco, lista, fechamento, urgência, overflow e workspaces por saída.
- Demonstração obrigatória: grupos, títulos iguais, identidade ausente, XWayland, urgência, overflow e duas saídas.
- Decisões abertas preservadas: pesquisa e execução de Desktop Entries pertencem ao Marco 4; arquivos, comandos e histórico pertencem ao Marco 5; painéis contextuais e indicadores pertencem aos marcos posteriores.

## Alterações realizadas

| Arquivo/componente | Alteração | Justificativa |
|---|---|---|
| `hydrogen/providers/sway/sway_ipc_bridge.py` | conexão persistente com o protocolo binário i3/Sway, snapshots e comandos estruturados | obter `GET_TREE` sem depender de `swaymsg` no produto |
| `hydrogen/providers/sway/SwayProvider.qml` | publicação conjunta de saídas, workspaces e janelas; catálogo Desktop Entries e reavaliação por configuração | manter uma única instância lógica do backend e views sem acesso externo |
| `hydrogen/logic/WindowNavigation.js` | extração da árvore, regras, resolução de identidade, agrupamento, workspaces e overflow | concentrar regras determinísticas e testáveis |
| `hydrogen/domain/WindowStore.qml` | coleção global de janelas e ordem estável por saída/workspace | foco não reordena; grupo fechado e reaberto retorna ao final |
| `hydrogen/domain/WindowNavigationController.qml` | foco, fechamento, troca e movimentação entre workspaces | produzir apenas comandos numéricos estruturados, sem shell |
| `hydrogen/domain/OverlayStore.qml` e `OverlayCoordinator.qml` | contexto para grupo/overflow dentro do overlay principal único | listas compactas obedecem à mesma coordenação do launcher |
| `hydrogen/features/panel/BarSurface.qml` | workspaces reais, grupos por ícone, contador, foco, urgência, roda e overflow | implementar a navegação tradicional por saída |
| `hydrogen/features/panel/WindowMenuSurface.qml` e `WindowMenuContent.qml` | wrapper Quickshell e conteúdo testável da lista/overflow com teclado, ponteiro, foco e fechamento | manter todas as janelas acessíveis e testar as interações sem simular o plugin nativo do Quickshell |
| `hydrogen/diagnostics/DiagnosticSnapshot.qml` | somente métricas agregadas de janelas | oferecer evidência reproduzível sem expor títulos ou identificadores pessoais |
| `shell.nix` | Python para o bridge; foot, XTerm e Xwayland para a demonstração | fixar todas as dependências usadas pelo marco |
| `tests/unit/`, `tests/qml/` e `tests/system/` | fixtures, protocolo, store/controlador e cenário real multimonitor | ligar cada regra do domínio a evidência automatizada |
| `README.md` e `docs/requirements-tests.md` | estado atual, execução e matriz dos Marcos 1–3 | permitir reprodução independente |

## Decisões técnicas

- Decisão: substituir a integração parcial do singleton `I3` por um bridge persistente do protocolo IPC.
  - Evidência ou necessidade: no Quickshell 0.3.1, a API pública `I3` expõe monitores, workspaces e `dispatch`, mas não oferece uma chamada pública para `GET_TREE`; o Marco 3 exige atributos de contêiner que não existem nos modelos resumidos.
  - Alternativas consideradas: `swaymsg`, foreign-toplevel e múltiplas conexões. `swaymsg` é proibido como dependência do produto; foreign-toplevel não fornece workspace, urgência nem identidade XWayland completa; conexões duplicadas violariam a arquitetura.
  - Consequência: um processo Python pequeno mantém exatamente um socket, fala o framing oficial, não usa shell e encerra junto com o provider.
- Decisão: somente identidades resolvidas com confiança formam grupos.
  - Evidência ou necessidade: título e PID são mutáveis ou ambíguos e a especificação determina separação em caso de dúvida.
  - Alternativas consideradas: agrupar por identificador bruto ou heurística; ambas poderiam unir aplicações distintas.
  - Consequência: desconhecidos recebem `unresolved:<container-id>`, ícone genérico e permanecem individualmente acessíveis.
- Decisão: seguir a precedência regra manual → `sandbox_app_id` → `app_id` → `StartupWMClass` → classe → instância.
  - Evidência ou necessidade: ordem normativa da especificação e campos publicados pelo Sway/Quickshell.
  - Consequência: regras exatas vencem; heurísticas não são usadas para agrupamento.
- Decisão: manter a ordem no `WindowStore`, separada da ordem de foco.
  - Evidência ou necessidade: foco não pode reorganizar a barra e reaparecimento deve ir ao final.
  - Consequência: chaves ausentes são removidas; uma chave reintroduzida recebe nova posição.
- Decisão: calcular overflow exclusivamente pela largura disponível.
  - Evidência ou necessidade: a especificação condiciona overflow à falta de espaço horizontal.
  - Consequência: telas amplas usam todo o centro; a demonstração reduz uma saída para 640×480 para provocar overflow real.
- Decisão: mover o relógio para a região direita.
  - Evidência ou necessidade: recomendação G-001 do verificador e arquitetura definitiva das seções 5.1 e 6.2, agora que o centro representa aplicativos.
  - Consequência: preserva-se o requisito definitivo sem regredir a função do relógio.

## Testes e verificações

| Comando ou procedimento | Resultado | Evidência relevante |
|---|---|---|
| `nix-shell --pure --run './scripts/test-unit.sh'` | aprovado | 44 testes Qt, 25 testes Node.js e 2 testes Python |
| `nix-shell --pure --run './scripts/lint.sh'` | aprovado | `qmllint` sem erros ou avisos |
| `qmlformat -i ...` | aprovado | componentes QML alterados formatados pela versão Qt fixada |
| `nix-shell --pure --run './scripts/test-system.sh'` | aprovado | 15 janelas/14 grupos, Wayland, XWayland, regra manual, desconhecidos, urgência, overflow, duas saídas, hotplug e shutdown |
| `nix-shell --pure --run './scripts/check.sh'` | aprovado | suíte normativa conjunta dos Marcos 1–3 |

## Fontes e evidências técnicas

| Afirmação ou decisão | Fonte | Versão/estado | Evidência obtida | Certeza |
|---|---|---|---|---|
| Framing e tipos `GET_TREE`, eventos e `RUN_COMMAND` do IPC | `sway-ipc(7)` e código-fonte oficial do Sway | Sway 1.12 fixado | bridge conecta, subscreve, recebe árvore/eventos e encerra no shutdown real | Confirmado |
| `DesktopEntries.byId`, catálogo, `startupClass`, nome e ícone | <https://quickshell.org/docs/v0.3.1/types/Quickshell/DesktopEntries/> | Quickshell 0.3.1 fixado | Desktop Entries temporárias resolvem grupos Wayland e XWayland no teste real | Confirmado |
| API `I3` não expõe `GET_TREE` publicamente | qmltypes e fonte oficial `src/x11/i3/ipc` da revisão fixada | Quickshell 0.3.1, revisão `1a4716c…` | inspeção mostra apenas `dispatch`, `refreshMonitors` e `refreshWorkspaces` | Confirmado |
| `PanelWindow` e `Variants` permitem superfície única por modelo filtrado | documentação oficial Quickshell 0.3.1 | versão fixada | grupo/overflow mantêm `overlay_surface_count=1` | Confirmado |
| Ações usam critérios `con_id` e comandos de workspace do Sway | `sway(5)`, `swaymsg(1)` e IPC oficial | Sway 1.12 fixado | controlador gera somente inteiros validados; comandos exercitados no compositor | Confirmado |

## Critérios de aceitação

| Critério do Marco 3 | Estado | Evidência |
|---|---|---|
| Descoberta Wayland e XWayland | Conforme | árvore real contém foot e XTerm; métricas confirmam 15 janelas e 1 XWayland |
| Identidade confiável e precedência | Conforme | fixtures cobrem todas as etapas e casos Flatpak, Steam, web app e AppImage; Desktop Entries reais resolvem `app_id` e `StartupWMClass` |
| Regras manuais exatas e ordenadas | Conforme | testes de domínio e regra real removida/reaplicada nas gerações 5→6→7 |
| Título/PID não agrupam | Conforme | duas janelas reais com o mesmo título ficam não resolvidas e separadas |
| Desconhecidos permanecem acessíveis | Conforme | fallback individual preserva título, usa ícone genérico e permanece na barra/overflow |
| Agrupamento e contador | Conforme | duas janelas `org.test.Group` produzem grupo de tamanho 2 |
| Ordem estável | Conforme | teste offscreen cobre mudança de foco e fechamento/reabertura |
| Foco sem falsa minimização | Conforme | grupo unitário focado não despacha ação; demais usam `con_id` |
| Lista, foco e fechamento | Conforme | teste do conteúdo visual exerce clique/Enter para foco, Delete/× para fechamento e urgência por janela |
| Urgência | Conforme | janela real urgente projeta estado para grupo e workspace |
| Overflow | Conforme | divisão preserva o ativo; conteúdo visual abre grupo excedente e exibe título desconhecido; geometria Sway real 640×480 produz pressão com 14 grupos |
| Workspaces por saída | Conforme | current/occupied reais, ordem numérica, clique, clique do meio e roda circular |
| Teclado e ponteiro | Conforme | launcher, workspaces, grupos, lista e overflow possuem fluxos de ambos |
| Duas saídas e hotplug | Conforme | escalas diferentes e ciclo 2→1→2 continuam aprovados |
| Único backend e overlay | Conforme | um socket persistente e no máximo uma superfície principal |

## Limitações e riscos conhecidos

- O bridge IPC introduz Python 3 como dependência de execução nesta árvore de desenvolvimento; a futura decisão de empacotamento deverá incluí-lo ou substituir o bridge por integração nativa equivalente, sem mudar o contrato interno.
- A pesquisa do launcher continua indisponível por definição do Marco 3 e será implementada somente no Marco 4.
- `foot`, XTerm e Xwayland são dependências de teste, não requisitos de execução do shell.

## Hipóteses assumidas

- A sessão alvo é Sway e fornece `SWAYSOCK` ou `I3SOCK`, conforme já exigido pela especificação do produto.

## Arquivos não relacionados

- A especificação, as instruções operacionais e os relatórios de verificação anteriores não foram alterados.

## Estado final

- [x] Pronto para verificação independente
- [ ] Bloqueado — requer decisão ou ação do responsável
