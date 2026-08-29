# Relatório de verificação — Marco 2: Painel básico

## Parecer

**Resultado:** Aprovado

**Resumo:** O Marco 2 entrega a barra inferior visual por saída com zona exclusiva, três regiões estruturais, relógio funcional e launcher estrutural acionável no monitor focado. O overlay principal é único, não teletransporta após aberto e o hotplug de monitores funciona sem duplicar instâncias ou corromper a geometria.

## Materiais examinados

- **Especificação:** `Especificacao_Inicial_Hydrogen_0.1.md` (versão 0.1, seções 5.1, 6.2, 16 e 18.2).
- **Escopo e critérios:** Marco 2 (Painel básico).
- **Relatório do implementador:** `docs/reports/milestone-2-implementation-0.1.md`.
- **Código-fonte:**
  - `hydrogen/features/panel/BarSurface.qml` e `LauncherSurface.qml`;
  - `hydrogen/domain/OverlayCoordinator.qml` e `OverlayStore.qml`;
  - `hydrogen/logic/Panel.js`;
  - `hydrogen/shell.qml`, `PublicIpcV1.qml`, `SwayProvider.qml` e `DiagnosticSnapshot.qml`.
- **Testes e saídas:**
  - `tests/qml/tst_panel.qml` (Qt Quick Test offscreen — 34 testes totais);
  - `tests/unit/panel.test.mjs` (testes Node.js — 16 testes totais);
  - `scripts/lint.sh` (`qmllint` limpo em todos os componentes);
  - `tests/system/run-headless.sh` (Sway 1.12 headless com 2 saídas em escalas 1 e 1.25, hotplug 2→1→2, zona exclusiva e retenção de overlay).

---

## Matriz de conformidade

| Requisito ou critério | Estado | Evidência |
|---|---|---|
| Barra inferior visual contínua por monitor | Conforme | [BarSurface.qml](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/hydrogen/features/panel/BarSurface.qml), ancorada na borda inferior em cada saída ativa de `Quickshell.screens`. |
| Reserva de espaço via protocolo layer-shell (zona exclusiva) | Conforme | `exclusiveZone: implicitHeight` (44 px lógicos); redução demonstrada na área útil dos workspaces no [run-headless.sh](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/tests/system/run-headless.sh#L97-L102). |
| Três regiões estruturais (esquerda, centro, direita) | Conforme | [BarSurface.qml](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/hydrogen/features/panel/BarSurface.qml#L37-L102): `leftSection` (launcher/workspaces), centro (relógio/área expansível) e direita (espaço reservado para indicadores). |
| Relógio funcional e determinístico | Conforme | Formato 24h `HH:mm` atualizado a cada segundo e coberto por testes em [tst_panel.qml](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/tests/qml/tst_panel.qml#L41-L43) e [panel.test.mjs](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/tests/unit/panel.test.mjs#L16-L18). |
| Launcher estrutural no monitor focado no momento da abertura | Conforme | [OverlayCoordinator.qml](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/hydrogen/domain/OverlayCoordinator.qml#L15-L23) e [LauncherSurface.qml](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/hydrogen/features/panel/LauncherSurface.qml); abertura testada via clique e IPC `panel open`. |
| Operação por teclado e fechamento por Escape | Conforme | Foco inicial no campo de busca, fechamento por tecla `Escape` e acionamento do botão do launcher por Tab/Enter/Space em [BarSurface.qml](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/hydrogen/features/panel/BarSurface.qml#L54-L61) e [LauncherSurface.qml](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/hydrogen/features/panel/LauncherSurface.qml#L62-L68). |
| Unicidade do overlay principal (sem superfícies duplicadas) | Conforme | `Variants.model: root.launcherScreens()` instancia no máximo 1 `PanelWindow`; `overlay_surface_count=1` validado no teste de sistema. |
| Overlay fixado (não teletransporta com mudança de foco) | Conforme | Testado em [run-headless.sh](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/tests/system/run-headless.sh#L122-L130): foco transferido para a saída secundária e o launcher permanece ancorado na saída primária original. |
| Tolerância a hotplug e desconexão de monitor | Conforme | Desativação e reativação de saída (2→1→2) testadas no [run-headless.sh](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/tests/system/run-headless.sh#L139-L152) e [tst_panel.qml](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/tests/qml/tst_panel.qml#L67-L74). |
| Suporte a dimensões e escalas fracionárias | Conforme | Saída `HEADLESS-2` em 1024×768 com escala 1.25 normalizada para 819×614 pixels lógicos e testada no Sway headless. |
| Ausência de resultados ou dados fictícios | Conforme | Mensagem explícita informando a disponibilidade futura da pesquisa; nenhuma lista fictícia de aplicativos ou workspaces criada. |

---

## Problemas confirmados

Nenhum.

---

## Suspeitas fundamentadas

Nenhuma.

---

## Sugestões não bloqueadoras

### G-001 — Alinhamento da posição do relógio para os marcos 3 e 6

- **Benefício possível:** A especificação contém uma sutil divergência textual entre o resumo do portão do Marco 2 na seção 18.2 ("relógio central") e as seções 5.1 (tabela do painel inferior) e 6.2 ("o relógio permanece na região direita do painel"). No Marco 2, a posição central atendeu perfeitamente ao critério estrutural de isolamento visual; nos Marcos 3 (aplicativos abertos no centro) e 6 (painel de calendário/relógio na direita), o relógio deverá migrar para a região direita conforme a arquitetura definitiva do produto.
- **Por que não é requisito do Marco 2:** O portão do Marco 2 contemplava explicitamente a validação do "relógio central" como elemento estrutural independente antes da entrada da lista de janelas.

---

## Itens fora do escopo identificados

- Nenhum. O implementador preservou as fronteiras do Marco 2, mantendo vazias as áreas destinadas aos aplicativos (Marco 3) e indicadores contextuais (Marcos 6 e 7).

---

## Cobertura dos testes

- **Comportamentos cobertos:**
  - Layouts compacto (< 720 px) e amplo (> 720 px) em `Panel.layoutForWidth()`;
  - Formatação e estabilidade do relógio em `Panel.formatClock()`;
  - Resolução de saída preferencial: explícita → focada → fallback para primeira saída ativa;
  - Ciclo de vida do `OverlayStore` e `OverlayCoordinator` (bloqueio fora de `running`/`degraded`);
  - Fixação do overlay na saída original após alternância de foco no compositor;
  - Desconexão lógica via hotplug e destruição de superfícies layer-shell associadas;
  - Verificação de zona exclusiva (redução de 44 px nos workspaces) no Sway 1.12 real headless;
  - Abertura, alternância e fechamento via IPC `hydrogen.v1 panel open|close|toggle`.
- **Lacunas relevantes:**
  - Nenhuma para o escopo do Marco 2.

---

## Auditoria das fontes técnicas

| Afirmação avaliada | Fonte usada pelo implementador | Fonte conferida pelo verificador | Resultado |
|---|---|---|---|
| `Variants.model` com modelo de um item instancia exatamente uma janela | Documentação Quickshell v0.3.1 (`Quickshell/Variants`) | Quickshell 0.3.1 docs / `shell.qml` | Confirmada |
| `PanelWindow` aplica `exclusiveZone` reduzindo geometria de janelas no Sway | Documentação Quickshell v0.3.1 (`Quickshell/PanelWindow`) | Quickshell 0.3.1 docs / `swaymsg -t get_tree` | Confirmada |
| `I3IpcListener` recebe evento `workspace` com monitor focado atualizado | Documentação Quickshell v0.3.1 (`Quickshell.I3/I3IpcListener`) | Quickshell 0.3.1 docs / `SwayProvider.qml` | Confirmada |
| Escala fracionária no Sway (1.25) gera dimensões lógicas proporcionais | Manual `sway-output(5)` / `swaymsg` | Execução real no Sway 1.12 headless | Confirmada |

---

## Conclusão

- **Problemas confirmados:** 0
- **Suspeitas:** 0
- **Resultado final:** O **Marco 2 — Painel básico** cumpre integralmente todos os critérios de aceitação, portões de qualidade e requisitos técnicos previstos na especificação. Está formalmente **Aprovado** e apto a liberar o início do **Marco 3 — Navegação de janelas**.
