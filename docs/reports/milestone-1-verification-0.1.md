# Relatório de verificação — Marco 1: Fundação (Rodada 2)

## Parecer

**Resultado:** Aprovado

**Resumo:** Todas as correções aplicadas pelo implementador para os achados V-001, V-002 e S-001 foram conferidas diretamente no código e validadas por testes de regressão automatizados no ambiente reproduzível. O Marco 1 cumpre integralmente todos os portões de aceitação previstos na especificação, sem defeitos abertos ou regressões.

## Materiais examinados

- **Especificação:** `Especificacao_Inicial_Hydrogen_0.1.md` (versão 0.1, 24 de agosto de 2026).
- **Relatório de avaliação da verificação:** `docs/reports/milestone-1-verification-assessment-0.1.md`.
- **Relatório de correções do implementador:** `Relatório de correções da verificação — Marco 1: Fundação`.
- **Código-fonte e ambiente:**
  - `shell.nix` (ambiente Nix puro com Quickshell 0.3.1, Sway 1.12, Qt 6.10.1 e Node.js 24);
  - `hydrogen/persistence/StateRepository.qml` e `hydrogen/logic/Foundation.js`;
  - `tests/helpers/load-qml-js.mjs`;
  - `scripts/check.sh`, `scripts/lint.sh`, `scripts/test-unit.sh`, `scripts/test-system.sh`.
- **Testes e saídas:**
  - `nix-shell --pure --run './scripts/check.sh'`:
    - `qmltestrunner`: 26 testes aprovados, 0 falhas;
    - `node --test`: 13 testes aprovados, 0 falhas;
    - `qmllint`: aprovado sem avisos em todos os componentes QML;
    - `run-headless.sh`: aprovado no Sway headless com 2 saídas virtuais, recarga transacional, poda de quarentena a 3 cópias, permissões restritas e encerramento coordenado.

---

## Avaliação dos achados anteriores

| Identificador | Título | Estado da correção | Evidência de validação |
|---|---|---|---|
| **V-001** | Incompatibilidade de tipo no helper Node.js (`load-qml-js.mjs`) | **Resolvido** | Conversão via `fileURLToPath` e `String()` em `tests/helpers/load-qml-js.mjs`. Execução dos 13 testes unitários no Node.js 24 com 100% de sucesso. |
| **V-002** | Varreduras não podadas no `/nix/store` e resolução de imports | **Resolvido** | Definição declarativa em `shell.nix` com hashes fixos; remoção completa de buscas recursivas em `/nix/store` dos scripts; injeção correta do `QML_IMPORT_PATH` com `QtTest`. |
| **S-001** | Limite de retenção de arquivos corrompidos em quarentena | **Resolvido** | Implementação de `corruptCopiesToDelete` e fila assíncrona de remoção em `StateRepository.qml`. Regressões em `tst_foundation.qml`, `foundation.test.mjs` e `run-headless.sh` (poda validada de 5 para 3 cópias). |

---

## Matriz de conformidade

| Requisito ou critério | Estado | Evidência |
|---|---|---|
| Composição modular em QML e ciclo de vida explícito | Conforme | `LifecycleManager.qml`, `Foundation.js` e validação em `tst_components.qml`. |
| Configuração TOML: primeira execução e geração de templates | Conforme | `ConfigurationRepository.qml`, `Defaults.js`; 7 arquivos gerados em `$XDG_CONFIG_HOME/hydrogen`. |
| Recarga transacional de configuração e isolamento de erros | Conforme | Transições 1→2, rejeição na geração 2, recuperação em 3 e retorno aos padrões em 4 testadas no `run-headless.sh`. |
| Persistência atômica, isolada e com permissões 0700/0600 | Conforme | `StateRepository.qml`, verificação de permissões e escrita atômica em `state.json`. |
| Isolamento e poda de arquivos corrompidos (máximo 3 cópias) | Conforme | `StateRepository.qml`, `Foundation.js`, `run-headless.sh` e testes unitários. |
| Preservação de esquemas futuros sem sobrescrita | Conforme | `StateRepository.qml` e validações em `tst_foundation.qml` e `foundation.test.mjs`. |
| Instância lógica única do provider Sway e fotografias normalizadas | Conforme | `SwayProvider.qml`, `SwayStore.qml` e testes com `FakeSwayProvider.qml`. |
| Superfície neutra por saída sem antecipação da barra | Conforme | `FoundationSurface.qml` instanciada para as 2 saídas virtuais (`surface_count=2`). |
| Logging com deduplicação e ErrorRegistry em memória | Conforme | `Logger.qml` (janela de 30s) e `ErrorRegistry.qml` (limite 50). |
| IPC v1 mínimo com target `hydrogen.v1` e envelope estável | Conforme | `PublicIpcV1.qml` expõe `version`, `status`, `diagnostics`, `capabilities`, `reload config`. |
| Saída coordenada e flush após encerramento do Sway | Conforme | `I3IpcListener` captura `shutdown`, coordena persistência antes de `Qt.quit()` em `run-headless.sh`. |
| Conformidade de tipos e imports (`qmllint`) | Conforme | Execução limpa do `qmllint` sem advertências em todos os arquivos `.qml`. |
| Execução das suítes de testes unitários (Qt e Node.js) | Conforme | 26 testes Qt Quick Test e 13 testes Node.js aprovados obrigatoriamente em `test-unit.sh`. |

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

Nenhum.

---

## Cobertura dos testes

- **Comportamentos cobertos:**
  - Ciclo de vida: fases explícitas, transições legais e bloqueio de mutações em `shutting_down`;
  - TOML: parsing de escalares, tabelas, arrays de tabelas, comentários preservados em strings, falha fechada em chaves duplicadas e valores inválidos;
  - Configuração: validação com limites, sanitização de números, herança de padrões e recarga transacional;
  - Logging e diagnóstico: deduplicação de logs, registro/recuperação de erros, fotografia sem vazamento de dados privados;
  - Persistência: gravação atômica, quarentena e poda mantendo as 3 cópias mais recentes, tolerância a falha não terminal de remoção;
  - Sway headless: inicialização em 2 monitores, criação de superfícies neutras, sincronização de workspaces, chamadas IPC em `hydrogen.v1` e encerramento limpo após saída do Sway.
- **Lacunas relevantes:**
  - Nenhuma para o escopo do Marco 1.

---

## Auditoria das fontes técnicas

| Afirmação avaliada | Fonte usada pelo implementador | Fonte conferida pelo verificador | Resultado |
|---|---|---|---|
| `FileView` oferece escrita atômica, sinais e observação | Documentação Quickshell v0.3.1 (`Quickshell.Io/FileView`) | Quickshell 0.3.1 docs / código QML | Confirmada |
| `IpcHandler` registra funções tipadas em target único | Documentação Quickshell v0.3.1 (`Quickshell.Io/IpcHandler`) | Quickshell 0.3.1 docs / execução IPC real | Confirmada |
| `I3` e `I3IpcListener` expõem monitores e shutdown | Documentação Quickshell v0.3.1 (`Quickshell.I3`) | Quickshell 0.3.1 docs / Sway headless 1.12 | Confirmada |
| `PanelWindow` cria layer surfaces com zona neutra | Documentação Quickshell v0.3.1 (`Quickshell/PanelWindow`) | Quickshell 0.3.1 docs / teste headless | Confirmada |
| Poda e permissões de arquivos via processos estruturados | Padrão POSIX e especificações XDG | Implementação em `StateRepository.qml` | Confirmada |

---

## Conclusão

- **Problemas confirmados:** 0
- **Suspeitas:** 0
- **Resultado final:** O **Marco 1 — Fundação** atende a todos os critérios de aceitação e portões técnicos definidos na especificação. Está formalmente **Aprovado** e apto a liberar o início do **Marco 2 — Painel básico**.
