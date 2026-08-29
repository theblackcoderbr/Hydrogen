# Relatório de verificação — Marco 4: Launcher de aplicativos

## Parecer

**Resultado:** Aprovado

**Resumo:** O Marco 4 entrega o launcher de aplicativos completo conforme a especificação: catálogo Freedesktop oficial via Quickshell, busca tolerante a caixa e acentos com preservação do texto original, ranking determinístico onde a correspondência de nome prevalece estritamente sobre estatísticas de uso, exibição de mais usados quando o campo está vazio, limite global de 20 resultados, execução estruturada de comandos (`shell=False`) com suporte a `Terminal=true`, tratamento acionável de entradas inexequíveis e persistência transacional de histórico em `launcher-history.json` (`0600`).

## Materiais examinados

- **Especificação:** `Especificacao_Inicial_Hydrogen_0.1.md` (versão 0.1, seções 6.1, 8.2, 16 e 18.2).
- **Escopo e critérios:** Marco 4 (Launcher de aplicativos).
- **Relatório do implementador:** `docs/reports/milestone-4-implementation-0.1.md`.
- **Código-fonte:**
  - `hydrogen/logic/Launcher.js`;
  - `hydrogen/domain/LauncherStore.qml` e `LauncherController.qml`;
  - `hydrogen/providers/desktop/DesktopEntriesProvider.qml` e `desktop_entry_runner.py`;
  - `hydrogen/features/panel/LauncherSurface.qml` e `LauncherContent.qml`;
  - `hydrogen/persistence/StateRepository.qml`;
  - `hydrogen/shell.qml` e `DiagnosticSnapshot.qml`.
- **Testes e saídas:**
  - `scripts/test-unit.sh` (49 testes Qt Quick Test, 32 testes unitários Node.js e 5 testes Python);
  - `scripts/lint.sh` (`qmllint` sem erros ou avisos);
  - `tests/system/run-headless.sh` (Sway 1.12 headless com injeção de teclas reais via `wtype`, lançamento de app comum, lançamento em terminal com `foot`, falha inexequível sem fechamento de overlay, persistência de histórico e validação de regressões dos Marcos 1–3).

---

## Matriz de conformidade

| Requisito ou critério | Estado | Evidência |
|---|---|---|
| Catálogo de Desktop Entries oficiais | Conforme | [DesktopEntriesProvider.qml](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/hydrogen/providers/desktop/DesktopEntriesProvider.qml) utiliza `DesktopEntries.applications` e respeita `NoDisplay=true`. |
| Busca tolerante a maiúsculas/minúsculas e acentos | Conforme | Decomposição NFD em [Launcher.js](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/hydrogen/logic/Launcher.js#L7-L9); busca por `EDITEUR` encontra “Éditeur de Texto” preservando o nome original. |
| Precedência do nome sobre frequência e recência | Conforme | Tiers de correspondência de nome (exato → prefixo → início de palavra → substring → metadados) prevalecem sobre contagens maiores em [launcher.test.mjs](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/tests/unit/launcher.test.mjs#L37-L46). |
| Ranking determinístico e desempate estável | Conforme | Desempate por: tier → `use_count` decrescente → `last_used_at` decrescente → nome normalizado crescente → ID crescente. |
| Limite global de 20 resultados | Conforme | Clamping em `searchApplications` no [Launcher.js](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/hydrogen/logic/Launcher.js#L67) garantindo no máximo 20 itens. |
| Mais usados quando a consulta está vazia | Conforme | Exibe somente aplicativos com histórico registrado quando `query === ""` em [Launcher.js](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/hydrogen/logic/Launcher.js#L76-L77). |
| Apresentação com ícone e nome | Conforme | [LauncherContent.qml](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/hydrogen/features/panel/LauncherContent.qml#L117-L147) com resolução de ícones Freedesktop e fallback seguro. |
| Operação por teclado e ponteiro | Conforme | Foco inicial no campo de busca, setas Cima/Baixo, ativação por Enter/Return, clique por ponteiro e fechamento por Escape. |
| Execução estruturada de comandos (`shell=False`) | Conforme | [desktop_entry_runner.py](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/hydrogen/providers/desktop/desktop_entry_runner.py#L55-L64) cria processos via `subprocess.Popen` com vetor de argumentos sem invocação de shell. |
| Suporte a `Terminal=true` | Conforme | Prefixo automático ou configurado via `terminal.command`; teste real no Sway headless executando comando em terminal via `foot`. |
| Entradas inexequíveis e falha acionável | Conforme | Entradas sem executável permanecem pesquisáveis; tentativa de execução gera aviso no registro de erros e log, exibindo mensagem inline sem fechar o launcher. |
| Fechamento condicionado à aceitação | Conforme | Launcher fecha somente após confirmação do runner (`launchAccepted`), conforme testado em [tst_launcher.qml](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/tests/qml/tst_launcher.qml#L114-L125). |
| Histórico de uso persistente | Conforme | Gravação atômica em `launcher-history.json` (`0600`) com poda por validade (30 dias) e limite (100 itens), sobrevivendo ao ciclo de vida do shell. |
| Privacidade e segurança | Conforme | Nenhuma consulta, comando bruto ou caminho pessoal é exposto nos snapshots de diagnóstico ou status IPC. |

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

- Nenhum. A pesquisa de arquivos do usuário, abertura de URLs/arquivos XDG, modo `>` para comandos diretos e limpeza completa do histórico permanecem preservados para o Marco 5.

---

## Cobertura dos testes

- **Comportamentos cobertos:**
  - Filtragem de `NoDisplay` e normalização de catálogo;
  - Busca de aplicações comuns, Flatpak e Steam;
  - Normalização NFD para insensibilidade a caixa e acentos;
  - Ordenação por níveis de correspondência e desempate por uso;
  - Limite estrito de 20 itens e exibição de mais usados com consulta vazia;
  - Atualização e poda de histórico (`use_count`, `last_used_at`, expiração de 30 dias e bound de 100 itens);
  - Preservação de versões futuras de esquema em `launcher-history.json`;
  - Execução estruturada sem shell e imunidade a injeção de comandos;
  - Envolvimento com terminal (`Terminal=true`) via configuração ou fallback (`foot`, `alacritty`, etc.);
  - Tratamento acionável de executáveis inexistentes e terminal ausente;
  - Teste de sistema integrado com digitação e ativação de teclas via `wtype` no Sway 1.12 headless.
- **Lacunas relevantes:**
  - Nenhuma para o escopo do Marco 4.

---

## Auditoria das fontes técnicas

| Afirmação avaliada | Fonte usada pelo implementador | Fonte conferida pelo verificador | Resultado |
|---|---|---|---|
| `DesktopEntries` expõe `id`, `name`, `command`, `runInTerminal`, `noDisplay` | Documentação Quickshell v0.3.1 (`Quickshell/DesktopEntries`) | Quickshell 0.3.1 docs / catálogo QML | Confirmada |
| `WlrLayershell.keyboardFocus: Exclusive` garante foco de teclado para layer surface | Documentação Quickshell v0.3.1 (`Quickshell.Wayland`) | Quickshell 0.3.1 / Sway 1.12 layer-shell | Confirmada |
| `subprocess.Popen` com vetor e `shell=False` impede injeção | Documentação padrão Python 3 | `desktop_entry_runner.py` / testes | Confirmada |
| `wtype` injeta teclas e eventos Wayland no Sway headless | Manual e binário `wtype(1)` | Execução real no `run-headless.sh` | Confirmada |

---

## Conclusão

- **Problemas confirmados:** 0
- **Suspeitas:** 0
- **Resultado final:** O **Marco 4 — Launcher de aplicativos** cumpre integralmente todos os requisitos, regras arquiteturais e portões de aceitação especificados. Está formalmente **Aprovado** e apto a liberar o início do **Marco 5 — Arquivos, comandos e histórico**.
