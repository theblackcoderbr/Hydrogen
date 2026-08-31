# Relatório de verificação — Marco 5: Arquivos, comandos e histórico

## Parecer

**Resultado:** Aprovado

**Resumo:** O Marco 5 conclui a implementação do launcher multifuncional com busca sob demanda de arquivos via `fd` nas pastas XDG (ignorando arquivos ocultos e cancelando requisições obsoletas), abertura externa de arquivos por URL XDG (`file://`), modo de comando (`>`) com argumentos estruturados (`shell=False`), modificadores de privacidade (`!`) e terminal (`_`), sugestões contextualizadas, ações internas imediatas, histórico compartilhado e limitado (100 itens / 30 dias) e estrita preservação da privacidade nos logs e diagnósticos.

## Materiais examinados

- **Especificação:** `Especificacao_Inicial_Hydrogen_0.1.md` (versão 0.1, seções 6.1, 8.2, 16 e 18.2).
- **Escopo e critérios:** Marco 5 (Launcher completo: arquivos, comandos e histórico).
- **Relatório do implementador:** `docs/reports/milestone-5-implementation-0.1.md`.
- **Código-fonte:**
  - `hydrogen/logic/Launcher.js`;
  - `hydrogen/domain/LauncherStore.qml` e `LauncherController.qml`;
  - `hydrogen/providers/launcher/LauncherBackend.qml` e `launcher_backend.py`;
  - `hydrogen/features/panel/LauncherContent.qml`;
  - `hydrogen/persistence/StateRepository.qml`;
  - `hydrogen/shell.qml` e `DiagnosticSnapshot.qml`.
- **Testes e saídas:**
  - `scripts/test-unit.sh` (53 testes Qt Quick Test, 39 testes unitários Node.js e 10 testes Python);
  - `scripts/lint.sh` (`qmllint` sem erros ou avisos);
  - `tests/system/run-headless.sh` (Sway 1.12 headless com busca e abertura XDG de arquivo com caracteres especiais, comandos estruturados sem expansão de shell, modificadores `!` e `_`, reinicialização e restauração do histórico, limpeza imediata e verificação de ausência de sentinelas nos logs).

---

## Matriz de conformidade

| Requisito ou critério | Estado | Evidência |
|---|---|---|
| Pesquisa sob demanda de arquivos via `fd` (mínimo 3 caracteres) | Conforme | [LauncherController.qml](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/hydrogen/domain/LauncherController.qml#L39-L45) e [launcher_backend.py](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/hydrogen/providers/launcher/launcher_backend.py#L51-L106); consultas com 2 caracteres não disparam busca. |
| Restrição às pastas do usuário XDG e exclusão de ocultos | Conforme | `StandardPaths` fornece raízes válidas; `--type f` e regras padrão do `fd` ignoram arquivos/pastas iniciados com ponto (`.`). |
| Cancelamento e descarte de respostas obsoletas | Conforme | Cancelamento do processo via `Process.running = false` e validação por `request_id` lógico em [LauncherStore.qml](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/hydrogen/domain/LauncherStore.qml#L54-L60) e [tst_launcher.qml](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/tests/qml/tst_launcher.qml). |
| Aplicativos precedem arquivos no limite global de 20 | Conforme | [Launcher.js](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/hydrogen/logic/Launcher.js#L260-L266); posições restantes reservadas a arquivos até completar 20 itens. |
| Abertura de arquivos via URL XDG (`file://`) | Conforme | [LauncherBackend.qml](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/hydrogen/providers/launcher/LauncherBackend.qml#L102-L104) usa `Qt.openUrlExternally()` com URL devidamente escapada (`Path.as_uri()`), fechando o launcher. |
| Suporte a caminhos especiais (espaços, `#`, acentos) | Conforme | Validado no teste de sistema com arquivo `hydrogen-special # ação.txt` e verificação da URL enviada ao `xdg-open`. |
| Modo de comando (`>`) com argumentos estruturados | Conforme | Argumentos separados por `shlex.split()`, sem interpolação de shell (`shell=False`); teste confirma que operadores `|`, `$HOME`, `*.txt` chegam literais ao processo executado em `$HOME`. |
| Modificadores `!` (privado) e `_` (terminal) | Conforme | Parser em [Launcher.js](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/hydrogen/logic/Launcher.js#L182-L197); `!` impede persistência no histórico e `_` envolve comando no terminal configurado. Suporta `!_` e `_!`. |
| Sugestões de comandos | Conforme | Combina entrada do usuário, ações internas, histórico e executáveis descobertos no `PATH` em [Launcher.js](file:///home/arthur/Projetos/Projeto%20Hydrogen/Hydrogen/hydrogen/logic/Launcher.js#L199-L258). |
| Ações internas seguras | Conforme | Recarregar configuração (`reload_config`), alternar DND (`toggle_dnd`) e limpar histórico (`clear_history`) funcionam por teclado/clique. Ações de sessão destrutivas permanecem desabilitadas aguardando o diálogo do Marco 6. |
| Histórico compartilhado com limites (100 itens / 30 dias) | Conforme | Envelope unificado em `launcher-history.json` (`0600`) armazenando aplicações, arquivos e comandos com chave estável e poda transacional. |
| Limpeza imediata do histórico | Conforme | Ação "Limpar histórico do launcher" zera o histórico em memória e grava imediatamente `items: []` em disco. |
| Restauração íntegra de histórico | Conforme | Reinício do processo Hydrogen restaura os itens válidos e valida a existência de arquivos em disco. |
| Privacidade e segurança | Conforme | Sentinelas de teste, termos de busca, caminhos e comandos executados não vazam nos logs nem em `status`/`diagnostics`. |

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

- O implementador manteve corretamente desabilitadas as ações internas de logout, reinício e desligamento no launcher, uma vez que tais operações dependem do diálogo de confirmação modal a ser construído no Marco 6.

---

## Cobertura dos testes

- **Comportamentos cobertos:**
  - Busca de arquivos com `fd` a partir de 3 caracteres e exclusão de arquivos ocultos;
  - Descarte de respostas com ID de requisição desatualizado e cancelamento de processos concorrentes;
  - Limite global de 20 itens com prioridade para aplicações sobre arquivos;
  - Abertura de arquivos com URLs formatadas e escapadas (`file://...`);
  - Modos de comando `> `, `>!`, `>_`, `>!_`, `>_!` com separação de argumentos por `shlex.split`;
  - Imunidade a injeção de shell (vetor passado diretamente a `subprocess.Popen` com `shell=False`);
  - Execução no diretório home do usuário (`$HOME`);
  - Sugestões combinadas no modo comando (entrada, ações internas, histórico e binários do `PATH`);
  - Persistência e normalização de histórico com 100 itens / 30 dias de expiração;
  - Limpeza imediata do histórico em memória e em `launcher-history.json`;
  - Restauração de histórico após reinício do processo Hydrogen;
  - Ausência de vazamento de dados sensíveis nos logs e diagnósticos;
  - Validação de regressões dos Marcos 1 a 4.
- **Lacunas relevantes:**
  - Nenhuma para o escopo do Marco 5.

---

## Auditoria das fontes técnicas

| Afirmação avaliada | Fonte usada pelo implementador | Fonte conferida pelo verificador | Resultado |
|---|---|---|---|
| `fd --type f --print0 --fixed-strings` pesquisa arquivos de forma rápida e segura | Manual e binário `fd(1)` | `fd 10.3.0` da toolchain | Confirmada |
| `StandardPaths` resolve pastas XDG do usuário (`Documents`, `Downloads`, etc.) | Documentação oficial QtCore | Qt 6.10.1 / `LauncherBackend.qml` | Confirmada |
| `Qt.openUrlExternally()` entrega URL ao `xdg-open` do sistema | Documentação Qt QML / QtCore | Qt 6.10.1 / teste com handler fake | Confirmada |
| `shlex.split(posix=True)` separa argumentos sem invocar shell | Documentação oficial Python 3 | `launcher_backend.py` / testes | Confirmada |
| `Path.as_uri()` produz URLs `file://` RFC-compatíveis | Documentação oficial Python 3 | `launcher_backend.py` / testes | Confirmada |

---

## Conclusão

- **Problemas confirmados:** 0
- **Suspeitas:** 0
- **Resultado final:** O **Marco 5 — Arquivos, comandos e histórico** cumpre integralmente todos os requisitos funcionais, regras de segurança, restrições de privacidade e portões técnicos da especificação. Está formalmente **Aprovado** e apto a liberar o início do **Marco 6 — Painéis contextuais e sessão**.
