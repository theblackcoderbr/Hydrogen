# Relatório de verificação — Marco 3: Navegação de janelas

## Parecer

**Resultado:** Aprovado

**Resumo:** O Marco 3 cumpre integralmente os requisitos de navegação de janelas da especificação: descoberta e normalização de janelas Wayland e XWayland via protocolo binário i3/Sway, agrupamento determinístico por identidade confiável, regras manuais exatas, ordem estável independente de foco, lista compacta com fechamento e foco estruturados, propagação de urgência, menu de overflow responsivo e seletor de workspaces por saída com navegação por clique, clique do meio e roda.

## Materiais examinados

- **Especificação:** `Especificacao_Inicial_Hydrogen_0.1.md` (versão 0.1, seções 5.2, 5.2.1, 5.3, 16 e 18.2).
- **Escopo e critérios:** Marco 3 (Navegação de janelas).
- **Relatório do implementador:** `docs/reports/milestone-3-implementation-0.1.md`.
- **Código-fonte:**
  - `hydrogen/providers/sway/sway_ipc_bridge.py` e `SwayProvider.qml`;
  - `hydrogen/logic/WindowNavigation.js`;
  - `hydrogen/domain/WindowStore.qml`, `WindowNavigationController.qml`, `OverlayCoordinator.qml` e `OverlayStore.qml`;
  - `hydrogen/features/panel/BarSurface.qml`, `WindowMenuSurface.qml` e `WindowMenuContent.qml`;
  - `hydrogen/shell.qml` e `DiagnosticSnapshot.qml`.
- **Testes e saídas:**
  - `scripts/test-unit.sh` (44 testes Qt Quick Test offscreen, 25 testes unitários Node.js e 2 testes de protocolo Python);
  - `scripts/lint.sh` (`qmllint` sem erros ou avisos);
  - `tests/system/run-headless.sh` (Sway 1.12 headless com 15 janelas, 14 grupos, Wayland, XWayland, regra manual dinâmica, urgência, overflow com restrição de largura 640×480, hotplug e shutdown).

---

## Matriz de conformidade

| Requisito ou critério | Estado | Evidência |
|---|---|---|
| Descoberta de janelas Wayland e XWayland sem scratchpad | Conforme | [sway_ipc_bridge.py](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/hydrogen/providers/sway/sway_ipc_bridge.py) e [WindowNavigation.js](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/hydrogen/logic/WindowNavigation.js#L34-L72); teste no Sway headless com foot e XTerm. |
| Precedência de resolução de identidade de aplicativos | Conforme | Regra manual → `sandbox_app_id` → `app_id` → `StartupWMClass` → `class` → `instance` → `unresolved:<id>` testada em [window-navigation.test.mjs](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/tests/unit/window-navigation.test.mjs#L59-L104). |
| Agrupamento por identidade confiável com contador | Conforme | [WindowNavigation.js](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/hydrogen/logic/WindowNavigation.js#L175-L204); janelas do mesmo aplicativo formam item único com badge numérico. |
| Título e PID não são chaves de agrupamento | Conforme | Duas janelas sem Desktop Entry e com títulos idênticos formam itens separados com chave `unresolved:<id>` em [window-navigation.test.mjs](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/tests/unit/window-navigation.test.mjs#L49-L57). |
| Janelas não identificadas permanecem acessíveis | Conforme | Itens não resolvidos utilizam ícone padrão (`application-x-executable`) e título na barra e no overflow sem serem descartados. |
| Regras manuais em `bar.toml` e recarga transacional | Conforme | Regras manuais exatas avaliadas na ordem; remoção e reaplicação validadas dinamicamente nas gerações 5→6→7 no [run-headless.sh](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/tests/system/run-headless.sh#L271-L284). |
| Relação de diálogo / janela transitória | Conforme | `window.transientFor` herda o grupo da janela-mãe em [WindowNavigation.js](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/hydrogen/logic/WindowNavigation.js#L167-L172). |
| Ordem estável dos aplicativos na barra | Conforme | [WindowStore.qml](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/hydrogen/domain/WindowStore.qml#L14-L38); foco não altera posições e reaparecimento vai ao final. |
| Foco sem falsa minimização | Conforme | Ativar grupo unitário já focado não executa comando; se inativo, despacha `[con_id=ID] focus`. |
| Lista compacta para grupos múltiplos | Conforme | [WindowMenuSurface.qml](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/hydrogen/features/panel/WindowMenuSurface.qml); foco por clique/Enter e fechamento por botão `×`/Delete despachando `[con_id=ID] kill`. |
| Sinalização de urgência em janelas e workspaces | Conforme | Janela urgente aplica borda destacada (`#ef7e87`) no grupo/lista e cor de destaque no item do workspace no [BarSurface.qml](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/hydrogen/features/panel/BarSurface.qml#L97) e [WindowMenuContent.qml](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/hydrogen/features/panel/WindowMenuContent.qml#L48). |
| Menu de overflow responsivo por capacidade | Conforme | [WindowNavigation.js](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/hydrogen/logic/WindowNavigation.js#L206-L222); mantém o aplicativo ativo visível na barra e transfere excedentes para o menu `⋯`. |
| Seletor de workspaces por saída real | Conforme | Exibe workspace atual + ocupados em ordem numérica; clique esquerdo troca, clique do meio move contêiner sem focar, roda do mouse circula workspaces visíveis. |
| Operação completa por teclado e ponteiro | Conforme | Workspaces, botões de grupos, itens de lista e fechamento navegáveis via Tab, Enter, Space, Delete e Escape. |
| Isolamento e privacidade em diagnóstico | Conforme | [DiagnosticSnapshot.qml](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/hydrogen/diagnostics/DiagnosticSnapshot.qml) expõe apenas contadores agregados sanitizados. |

---

## Problemas confirmados

Nenhum.

---

## Suspeitas fundamentadas

Nenhuma.

---

## Sugestões não bloqueadoras

Nenhuma.

---

## Itens fora do escopo identificados

- Nenhum. O implementador manteve a separação de escopo: busca e execução de aplicativos permanecem no Marco 4 e histórico no Marco 5.

---

## Cobertura dos testes

- **Comportamentos cobertos:**
  - Extração de contêineres e exclusão do scratchpad (`extractWindows`);
  - Resolução de identidade por precedência normativa (regras, Flatpak, Steam, web apps, AppImage, WM_CLASS, WM_INSTANCE);
  - Agrupamento confiável vs separação de títulos/PIDs iguais não resolvidos;
  - Herança de identidade para janelas transitórias/diálogos;
  - Estabilidade de ordem no `WindowStore` diante de mudanças de foco e ciclo de fechamento/reabertura;
  - Despacho seguro de comandos estruturados numéricos no `WindowNavigationController`;
  - Interação de menu de grupo e overflow com teclado (Enter, Delete, Escape) e ponteiro (clique em item e botão fechar);
  - Projeção de workspaces por saída real com detecção de ocupação e urgência;
  - Teste de sistema real com 15 janelas, 14 grupos, Wayland, XWayland, urgência, overflow e duas saídas no Sway 1.12 headless.
- **Lacunas relevantes:**
  - Nenhuma para o escopo do Marco 3.

---

## Auditoria das fontes técnicas

| Afirmação avaliada | Fonte usada pelo implementador | Fonte conferida pelo verificador | Resultado |
|---|---|---|---|
| Protocolo binário i3/Sway para `GET_TREE`, `GET_WORKSPACES`, `GET_OUTPUTS` | `sway-ipc(7)` e código oficial do Sway | Sway 1.12 / `sway_ipc_bridge.py` | Confirmada |
| `DesktopEntries` do Quickshell fornece `startupClass`, `id`, `name`, `icon` | Documentação Quickshell v0.3.1 (`Quickshell/DesktopEntries`) | Quickshell 0.3.1 docs / catálogo QML | Confirmada |
| Comandos de foco e kill via critério `[con_id=...]` | Manual `sway(5)` e `swaymsg(1)` | Sway 1.12 IPC | Confirmada |
| Movimentação entre workspaces via `move container to workspace number X` | Manual `sway(5)` | Sway 1.12 IPC | Confirmada |

---

## Conclusão

- **Problemas confirmados:** 0
- **Suspeitas:** 0
- **Resultado final:** O **Marco 3 — Navegação de janelas** cumpre com rigor todos os critérios de aceitação e portões técnicos definidos na especificação. Está formalmente **Aprovado** e apto a liberar o início do **Marco 4 — Launcher de aplicativos**.
