# Relatório de implementação — Marco 1: Fundação

## Escopo recebido

- Requisito: iniciar a implementação integral do Hydrogen conforme a especificação.
- Escopo aplicado: Marco 1, porque a especificação exige conclusão e validação sequencial antes do Marco 2.
- Critérios: estrutura modular, ciclo de vida, configuração, stores/repositories/controlador, fakes, relógio controlável, logging, `ErrorRegistry`, persistência básica, Sway, fotografias iniciais, IPC mínimo, `status`, `diagnostics`, lint e testes.
- Decisões abertas preservadas: empacotamento, acessibilidade além do teclado, migração pública de configuração e matriz formal de aplicativos reais.

## Alterações realizadas

| Arquivo/componente | Alteração | Justificativa |
|---|---|---|
| `hydrogen/shell.qml` | raiz de composição e coordenação de superfícies | mantém regras no controlador e dependências explícitas |
| `hydrogen/core/` e `hydrogen/domain/` | ciclo, erros, eventos, stores e controlador | fontes únicas de estado e fluxo testável |
| `hydrogen/config/` e `hydrogen/logic/` | padrões, parser TOML e recarga geracional | primeira execução e publicação transacional |
| `hydrogen/persistence/` | três envelopes JSON, permissões e escrita atômica | estado isolado da configuração e resistente a corrupção |
| `hydrogen/providers/` | provider Sway real e fakes | uma instância lógica e testes sem compositor |
| `hydrogen/diagnostics/` e `hydrogen/ipc/` | logging, fotografias sanitizadas e target inicial | observabilidade sem dados pessoais |
| `tests/` e `scripts/` | testes offscreen, lint e Sway headless | evidência reproduzível e home isolada |
| `shell.nix` | toolchain fixada para desenvolvimento e testes | elimina descoberta global no Nix store e divergência entre Qt, Quickshell e ferramentas |

## Decisões técnicas

- Decisão: usar `Quickshell.I3` e `I3IpcListener` dentro de um único provider lógico.
  - Evidência: a API 0.3.1 fornece fotografias de monitores/workspaces e eventos IPC; um listener estreito de `shutdown` é necessário porque o singleton não expõe sinal de desconexão.
  - Consequência: nenhuma view ou controlador conhece sockets ou JSON do Sway.
- Decisão: parser TOML restrito ao esquema usado pelo Hydrogen.
  - Evidência: Quickshell 0.3.1 não fornece parser TOML; construções desconhecidas são rejeitadas, nunca inferidas.
  - Consequência: ampliar o esquema com outros tipos TOML exige teste e extensão explícita.
- Decisão: `IpcHandler` fica encapsulado dentro do adaptador `PublicIpcV1`.
  - Evidência: propriedades auxiliares diretamente no handler são interpretadas como API pública pelo Quickshell.
  - Consequência: somente as funções intencionais são registradas.
- Decisão: executar a automação somente no ambiente fixado por `shell.nix`.
  - Evidência: descoberta recursiva no `/nix/store` é lenta e pode combinar ferramentas de revisões incompatíveis.
  - Consequência: os scripts usam exclusivamente o `PATH` e os imports QML fornecidos pelo ambiente, recusando execução externa.

## Testes e verificações

| Comando/procedimento | Resultado | Evidência |
|---|---|---|
| `nix-shell --pure --run './scripts/test-unit.sh'` | aprovado | 26 testes Qt e 13 testes Node, 0 falhas |
| `nix-shell --pure --run './scripts/lint.sh'` | aprovado | `qmllint` sem saída/avisos, imports fixados do Qt e Quickshell 0.3.1 |
| `qmlformat -i ...` | aprovado | todos os QML formatados pela ferramenta Qt 6 |
| `nix-shell --pure --run './scripts/test-system.sh'` | aprovado | Sway 1.12 fixado, duas saídas, superfícies, gerações 1→2, rejeição preservando 2, recuperação em 3, remoção de componente em 4, corrupção, permissões, IPC e shutdown |
| `nix-shell --pure --run './scripts/check.sh'` | aprovado | unitários, lint e sistema executados na mesma toolchain reproduzível |

## Fontes e evidências técnicas

| Afirmação ou decisão | Fonte | Versão/estado | Evidência obtida | Certeza |
|---|---|---|---|---|
| `FileView` oferece escrita atômica, sinais e observação | <https://quickshell.org/docs/v0.3.1/types/Quickshell.Io/FileView/> | 0.3.1 | API usada e exercitada com arquivos temporários | Confirmado |
| `IpcHandler` registra funções tipadas em target único | <https://quickshell.org/docs/v0.3.1/types/Quickshell.Io/IpcHandler/> | 0.3.1 | target real chamado por `qs ipc call` | Confirmado |
| `I3` expõe socket, monitores, workspaces e eventos | <https://quickshell.org/docs/v0.3.1/types/Quickshell.I3/I3/> | 0.3.1 | duas saídas normalizadas no Sway 1.12 | Confirmado |
| `Variants.model` cria uma instância por valor | <https://quickshell.org/docs/v0.3.1/types/Quickshell/Variants/> | 0.3.1 | `surface_count=2` em duas saídas | Confirmado |
| `PanelWindow` oferece anchors e zona exclusiva | <https://quickshell.org/docs/v0.3.1/types/Quickshell/PanelWindow/> | 0.3.1 | duas layer surfaces criadas no Sway headless | Confirmado |
| Processos recebem argumentos estruturados sem shell | <https://quickshell.org/docs/v0.3.1/types/Quickshell.Io/Process/> | 0.3.1 | todos os comandos usam listas; nenhum `sh -c` | Confirmado |

Ambiente normativo: `shell.nix` com revisões e hashes fixos; Quickshell 0.3.1 oficial (revisão `1a4716cde794a59928d9d9fc15f2afc7a95de360`), Qt/QtTest 6.10.1, Node.js 24.12.0 e Sway 1.12 não encapsulado. Sistema hospedeiro da validação: NixOS 26.11.

## Critérios de aceitação

| Critério do Marco 1 | Estado | Evidência |
|---|---|---|
| Estrutura modular e fronteiras | Conforme | árvore `hydrogen/` e arquitetura documentada |
| Ciclo explícito e controlador | Conforme | testes de transições e execução real |
| Configuração aceita/rejeitada transacionalmente | Conforme | gerações verificadas no teste headless, inclusive retorno aos padrões após remover componente |
| Stores, repository, fakes e relógio | Conforme | 24 testes offscreen |
| Logging, erros e diagnóstico sanitizado | Conforme | testes de deduplicação e privacidade |
| Persistência básica e flush | Conforme | modos, corrupção, retenção máxima de três cópias e encerramento exercitados |
| Único provider lógico Sway e fotografias | Conforme | duas saídas no provider real e fake |
| IPC após prontidão mínima | Conforme | target responde somente em `running`/`degraded` |
| Lint e sistema headless | Conforme | comandos aprovados acima |

## Limitações e riscos conhecidos

- O target v1 expõe nesta etapa somente `version`, `status`, `diagnostics`, `capabilities` e `reload config`; o contrato completo pertence ao Marco 11.
- A superfície de fundação é transparente e não reserva espaço; a barra visual e responsiva pertence ao Marco 2.

## Hipóteses assumidas

- Utilitários POSIX básicos estão disponíveis no ambiente Linux suportado; os comandos são sempre estruturados e não recebem entrada do usuário.

## Arquivos não relacionados

- Os quatro documentos fonte do projeto não foram alterados.

## Estado final

- [x] Pronto para verificação independente
- [ ] Bloqueado — requer decisão ou ação do responsável
