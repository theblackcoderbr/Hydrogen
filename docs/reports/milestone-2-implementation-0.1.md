# Relatório de implementação — Marco 2: Painel básico

## Escopo recebido

- Requisito: prosseguir ao Marco 2 após a aprovação formal do Marco 1 pelo verificador independente.
- Critérios de aceitação: barra inferior responsiva por saída, regiões esquerda/centro/direita, relógio central, zona exclusiva, launcher estrutural na saída focada, hotplug, dimensões e escalas diferentes, um único overlay principal e ausência de teletransporte após a abertura.
- Decisões abertas preservadas: descoberta e pesquisa de aplicativos, representação de janelas, seletor funcional de workspaces, indicadores reais e painéis contextuais continuam pertencendo aos marcos posteriores.

## Alterações realizadas

| Arquivo/componente | Alteração | Justificativa |
|---|---|---|
| `hydrogen/features/panel/BarSurface.qml` | barra inferior visual por saída, três regiões estruturais, launcher acionável e relógio central | substitui a superfície neutra do Marco 1 sem antecipar dados do Marco 3 |
| `hydrogen/features/panel/LauncherSurface.qml` | overlay estrutural responsivo, navegação por teclado, fechamento por `Escape` e mensagem explícita de indisponibilidade da pesquisa | demonstra o fluxo real sem resultados fictícios |
| `hydrogen/domain/OverlayStore.qml` | fonte global do painel aberto, saída fixada e geração | impede estado duplicado entre monitores |
| `hydrogen/domain/OverlayCoordinator.qml` | abertura, alternância, fechamento, seleção de saída e reconciliação após hotplug | mantém decisões de overlay fora das views |
| `hydrogen/logic/Panel.js` | cálculo responsivo, relógio e seleção validada de saída | torna as regras determinísticas e testáveis offscreen |
| `hydrogen/shell.qml` | composição de uma barra por `Quickshell.screens` e de no máximo um launcher | integra superfícies somente após o ciclo de fundação estar pronto |
| `hydrogen/providers/sway/SwayProvider.qml` | publicação da saída focada a partir do evento oficial de workspace | mantém o store sincronizado durante troca de foco real |
| `hydrogen/diagnostics/DiagnosticSnapshot.qml` e `hydrogen/logic/Foundation.js` | estado sanitizado do painel e contagem de overlays | permite verificar unicidade e fixação sem inspecionar conteúdo pessoal |
| `hydrogen/ipc/PublicIpcV1.qml` | comando estreito `panel open|close|toggle` para o launcher estrutural | fornece acionamento reproduzível da demonstração headless; o contrato completo continua no Marco 11 |
| `tests/qml/tst_panel.qml` e `tests/unit/panel.test.mjs` | testes de layout compacto, relógio, ciclo do overlay, hotplug lógico e fixação de saída | cobre a lógica sem compositor nem sleeps |
| `tests/system/run-headless.sh` e `tests/system/sway-headless.conf` | duas saídas 1280×720@1 e 1024×768@1,25, zona exclusiva, troca de foco, overlay único e hotplug | prova os portões dependentes de Sway/layer-shell na toolchain real |

## Decisões técnicas

- Decisão: manter um `OverlayStore` único e um `OverlayCoordinator` anterior às superfícies.
  - Evidência ou necessidade: a especificação exige um único overlay principal e proíbe que uma superfície aberta acompanhe mudanças posteriores de foco.
  - Alternativas consideradas: derivar a saída diretamente do foco em cada frame ou manter estado em cada barra; ambas moveriam ou duplicariam o overlay.
  - Consequência: o foco só é consultado na abertura; hotplug fecha o overlay se a saída fixada desaparecer.
- Decisão: modelar o launcher como uma única `PanelWindow` criada por um `Variants` filtrado.
  - Evidência ou necessidade: `Variants` 0.3.1 cria uma instância para cada item do modelo e o teste real observa `overlay_surface_count=1`.
  - Alternativas consideradas: criar um launcher invisível por saída; isso manteria múltiplas layer surfaces principais.
  - Consequência: solicitar outra saída altera a geração e recria a única superfície.
- Decisão: usar `PanelWindow.exclusiveZone` igual à altura validada da barra.
  - Evidência ou necessidade: o Sway headless reduziu os workspaces de 720 para 676 pixels e de 614 para 570 pixels lógicos.
  - Alternativas consideradas: margem visual sem zona exclusiva; ela permitiria sobreposição de janelas.
  - Consequência: a barra preserva 44 pixels lógicos em cada saída ativa.
- Decisão: manter vazias as regiões destinadas a aplicações, workspaces e indicadores ainda não implementados.
  - Evidência ou necessidade: o Marco 2 exige a estrutura, enquanto o Marco 3 introduz dados reais de aplicativos e workspaces.
  - Alternativas consideradas: itens demonstrativos; foram rejeitados porque seriam resultados fictícios.
  - Consequência: a interface é honesta quanto às capacidades atuais.

## Testes e verificações

| Comando ou procedimento | Resultado | Evidência relevante |
|---|---|---|
| `nix-shell --pure --run './scripts/test-unit.sh'` | aprovado | 34 testes Qt e 16 testes Node.js, 0 falhas |
| `nix-shell --pure --run './scripts/lint.sh'` | aprovado | `qmllint` sem erros ou avisos |
| `nix-shell --pure --run './scripts/test-system.sh'` | aprovado | duas barras, escalas 1 e 1,25, zona exclusiva, launcher único fixado, hotplug 2→1→2 e shutdown coordenado |
| `nix-shell --pure --run './scripts/check.sh'` | aprovado | suíte completa aprovada na toolchain fixada |

## Fontes e evidências técnicas

| Afirmação ou decisão | Fonte | Versão/estado | Evidência obtida | Certeza |
|---|---|---|---|---|
| `Variants.model` materializa uma instância por item | <https://quickshell.org/docs/v0.3.1/types/Quickshell/Variants/> | Quickshell 0.3.1 fixado | duas barras para duas telas e uma superfície para modelo filtrado de um item | Confirmado |
| `PanelWindow` fornece anchors, foco, camada superior e zona exclusiva | <https://quickshell.org/docs/v0.3.1/types/Quickshell/PanelWindow/> | Quickshell 0.3.1 fixado | layer surfaces reais e redução de 44 pixels na área dos workspaces | Confirmado |
| `I3IpcListener` entrega eventos subscritos com tipo e dados | <https://quickshell.org/docs/v0.3.1/types/Quickshell.I3/I3IpcListener/> | Quickshell 0.3.1 fixado | evento de workspace atualiza a saída focada durante o teste headless | Confirmado |
| Sway aceita configuração de modo, posição e escala por saída | manual e execução de `sway-output(5)`/`swaymsg(1)` da toolchain | Sway 1.12 fixado | saída física 1024×768 publicada como 819×614 pixels lógicos em escala 1,25 | Confirmado |
| O ambiente normativo contém versões reproduzíveis | `shell.nix` | Qt 6.10.1, Quickshell 0.3.1, Node.js 24.12.0 e Sway 1.12 | suíte completa executada com `--pure` | Confirmado |

## Critérios de aceitação

| Critério | Estado | Evidência |
|---|---|---|
| Barra inferior responsiva por saída | Conforme | `BarSurface` por `Quickshell.screens`; layouts compacto e amplo testados |
| Regiões esquerda, centro e direita | Conforme | três regiões estruturais independentes; launcher à esquerda e relógio central absoluto |
| Relógio central | Conforme | formato 24 horas testado e posição independente da largura das laterais |
| Zona exclusiva | Conforme | workspaces reduzidos em exatamente 44 pixels lógicos nas duas saídas |
| Launcher estrutural na saída focada | Conforme | abertura IPC e acionamento da barra consultam o foco no instante da abertura |
| Dimensões e escalas diferentes | Conforme | 1280×720@1 e 1024×768@1,25 validados no Sway e no diagnóstico normalizado |
| Hotplug | Conforme | desativação e reativação de `HEADLESS-2` alteram `surface_count` de 2→1→2 |
| Um único overlay principal | Conforme | contagem observada permanece em 1 enquanto aberto e retorna a 0 ao fechar |
| Overlay não teletransporta | Conforme | foco muda de saída com o launcher aberto e `panel_output` permanece original |
| Sem resultados falsos | Conforme | nenhuma aplicação, janela, workspace ou indicador fictício é criado |

## Limitações e riscos conhecidos

- O launcher é deliberadamente estrutural: ainda não recebe texto nem pesquisa aplicativos; isso pertence ao Marco 3.
- As regiões de workspaces, aplicações e indicadores permanecem vazias até seus providers e comportamentos reais serem implementados nos marcos correspondentes.
- O comando IPC de painel existe apenas para o launcher deste marco; a consolidação do contrato público completo permanece no Marco 11.

## Hipóteses assumidas

- Nenhuma hipótese técnica não confirmada permanece na implementação do marco; os comportamentos dependentes de compositor foram exercitados no Sway 1.12 real em backend headless.

## Arquivos não relacionados

- A especificação, as instruções do implementador, a política de pesquisa e os relatórios de verificação anteriores não foram alterados.

## Estado final

- [x] Pronto para verificação independente
- [ ] Bloqueado — requer decisão ou ação do responsável
