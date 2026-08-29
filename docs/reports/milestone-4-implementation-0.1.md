# Relatório de implementação — Marco 4: Launcher de aplicativos

## Escopo recebido

- Requisito: iniciar o Marco 4 após a aprovação formal do Marco 3.
- Critérios de aceitação: Desktop Entries válidas, busca, ranking determinístico, limite global, mais usados, teclado e ponteiro, execução estruturada, `Terminal=true`, histórico de aplicativos e falhas acionáveis.
- Demonstração obrigatória: aplicativo comum, Flatpak, Steam ou aplicação representativa, aplicação de terminal e entrada inexequível.
- Decisões abertas preservadas: pesquisa de arquivos, abertura XDG, modo `>`, modificadores de comandos, ações internas e limpeza do histórico completo pertencem ao Marco 5.

## Alterações realizadas

| Arquivo/componente | Alteração | Justificativa |
|---|---|---|
| `hydrogen/logic/Launcher.js` | normalização de catálogo, busca tolerante a caixa/acentos, ranking, limite, uso e persistência | concentrar regras determinísticas e testáveis sem alterar o texto apresentado |
| `hydrogen/domain/LauncherStore.qml` | fonte autoritativa para catálogo, consulta, resultados, histórico e falha corrente | impedir cópia de estado entre provider, controlador e view |
| `hydrogen/domain/LauncherController.qml` | coordenação da busca, ativação, confirmação, histórico, poda, fechamento e erros | fechar somente após a aceitação do processo e manter falhas locais |
| `hydrogen/providers/desktop/DesktopEntriesProvider.qml` | adaptação do catálogo `DesktopEntries` e envio de comando estruturado ao runner | usar a descoberta e os campos processados pelo Quickshell sem parser `.desktop` próprio |
| `hydrogen/providers/desktop/desktop_entry_runner.py` | validação e criação de processo com vetor de argumentos, diretório de trabalho e terminal | suprir `Terminal=true` sem interpretar `Exec` como shell |
| `hydrogen/features/panel/LauncherSurface.qml` e `LauncherContent.qml` | painel real com ícone/nome, busca, lista, seleção, clique, Enter, setas, Escape e foco layer-shell | tornar o launcher operável por teclado e ponteiro mantendo a view sem processos externos |
| `hydrogen/persistence/StateRepository.qml` | leitura, escrita atômica, suspensão por versão futura e flush coordenado de `launcher-history.json` | fazer frequência e recência sobreviverem ao reinício com as permissões já definidas |
| `hydrogen/logic/Foundation.js` e diagnóstico | validação dos limites/terminal e métricas agregadas do launcher | rejeitar configuração inválida e fornecer evidência sem conteúdo pessoal |
| `hydrogen/shell.qml` e arquivos `qmldir` | composição e registro dos novos tipos | integrar uma única instância lógica de cada responsabilidade |
| `shell.nix` | inclusão de `wtype` na toolchain de teste | exercitar teclado real pelo protocolo Wayland no Sway headless |
| `tests/unit/`, `tests/qml/` e `tests/system/` | domínio, componentes, runner e demonstração real isolada | ligar os portões do Marco 4 a evidências automatizadas |
| `README.md`, `docs/architecture.md` e `docs/requirements-tests.md` | estado, arquitetura e matriz dos Marcos 1–4 | permitir reprodução e revisão independentes |

## Decisões técnicas

- Decisão: usar `DesktopEntries` do Quickshell como catálogo e fonte do comando estruturado.
  - Evidência ou necessidade: a especificação proíbe parser improvisado de Desktop Entries e exige nome, ícone, diretório e comando fornecidos pela integração oficial.
  - Alternativas consideradas: percorrer e analisar arquivos `.desktop` no Hydrogen; isso duplicaria regras Freedesktop e foi descartado.
  - Consequência: o provider apenas normaliza o modelo publicado e respeita `NoDisplay`; entradas sem comando seguro continuam pesquisáveis como inexequíveis.
- Decisão: executar por um runner estreito com lista de argumentos e `shell=False`.
  - Evidência ou necessidade: `DesktopEntry.execute()` 0.3.1 não aplica `Terminal=true`, enquanto o requisito proíbe passar `Exec` bruto a um shell.
  - Alternativas consideradas: chamar `execute()` e ignorar terminal, ou concatenar uma linha de comando; ambas violariam um portão do marco.
  - Consequência: diretório e argumentos permanecem estruturados; falhas imediatas retornam códigos estáveis ao controlador.
- Decisão: prefixar entradas `Terminal=true` com `terminal.command`, usando seleção automática curta somente quando a configuração estiver vazia.
  - Evidência ou necessidade: o terminal é configurável, e os padrões do projeto explicitam que a lista vazia habilita seleção automática.
  - Consequência: `foot`, Alacritty, Kitty, WezTerm e XTerm podem ser detectados sem introduzir dependência obrigatória de distribuição no produto.
- Decisão: separar qualidade da correspondência e desempates de uso.
  - Evidência ou necessidade: nome é o fator principal; frequência e recência são apenas desempates.
  - Consequência: correspondência exata, prefixo, início de palavra, ocorrência no nome e metadados formam níveis estáveis; frequência, recência, nome normalizado e ID fecham a ordenação.
- Decisão: persistir desde este marco somente a variante de aplicação do histórico compartilhado.
  - Evidência ou necessidade: “mais usados” exige sobrevivência ao reinício, enquanto arquivos e comandos ainda não existem antes do Marco 5.
  - Consequência: o envelope já usa `kind: application` e poderá receber as variantes posteriores sem inventá-las agora.
- Decisão: usar foco exclusivo da camada e `FocusScope` no launcher.
  - Evidência ou necessidade: a superfície pode ser aberta pelo IPC sem clique anterior; `PanelWindow.focusable` sob demanda não garante foco nesse fluxo.
  - Consequência: o painel recebe teclado enquanto está aberto e libera o foco quando destruído.

## Testes e verificações

| Comando ou procedimento | Resultado | Evidência relevante |
|---|---|---|
| `nix-shell --pure --run './scripts/test-unit.sh'` | aprovado | 49 testes Qt/QML, 32 testes Node.js e 5 testes Python |
| `nix-shell --pure --run './scripts/lint.sh'` | aprovado | imports, tipos e escopos QML validados por `qmllint` |
| `nix-shell --pure --run './scripts/test-system.sh'` | aprovado | catálogo XDG isolado, busca/Enter por `wtype`, processo comum, `Terminal=true`, falha inexequível, histórico e regressões anteriores |
| `nix-shell --pure --run './scripts/check.sh'` | aprovado | suíte normativa conjunta dos Marcos 1–4 |

## Fontes e evidências técnicas

| Afirmação ou decisão | Fonte | Versão/estado | Evidência obtida | Certeza |
|---|---|---|---|---|
| `DesktopEntries` publica Desktop Entries e `DesktopEntry` oferece nome, ícone, comando, diretório, `noDisplay` e `runInTerminal` | documentação e qmltypes oficiais do Quickshell | 0.3.1 fixado no `shell.nix` | catálogo temporário contém oito entradas visíveis e exclui a fixture `NoDisplay` | Confirmado |
| `DesktopEntry.execute()` usa o comando estruturado, mas não envolve `Terminal=true` nessa versão | código-fonte oficial de `desktopentry.cpp` da revisão fixada | Quickshell 0.3.1 | runner próprio foi necessário e a fixture terminal iniciou por `foot` no Sway headless | Confirmado |
| `WlrLayershell.keyboardFocus` oferece foco `Exclusive` | documentação/qmltypes e fonte oficial do módulo layer-shell | Quickshell 0.3.1 | `wtype` digitou a consulta e ativou o resultado sem clique prévio | Confirmado |
| Desktop Entries possuem `NoDisplay`, `Terminal`, `Path` e `Exec` com códigos de campo | especificação Desktop Entry da Freedesktop | especificação oficial aplicável | Quickshell fornece os campos processados; o Hydrogen não analisa `Exec` bruto | Confirmado |
| Criação com `subprocess.Popen` aceita sequência de argumentos e pode desabilitar shell | documentação oficial do Python e implementação inspecionada | Python 3 da toolchain fixada | teste cria marcador e falhas inexistentes retornam código acionável sem shell | Confirmado |
| O ambiente executado corresponde à matriz fixada | `shell.nix`, executáveis e testes locais | Qt 6.10.1, Quickshell 0.3.1, Sway 1.12 | suítes unitária, lint e headless executadas em `nix-shell --pure` | Confirmado |

## Critérios de aceitação

| Critério do Marco 4 | Estado | Evidência |
|---|---|---|
| Desktop Entries válidas | Conforme | catálogo oficial, normalização e exclusão de `NoDisplay` testadas |
| Busca por caixa/acentos | Conforme | teste preserva “Éditeur de Texto” e encontra por `EDITEUR` |
| Nome como fator principal | Conforme | níveis de nome vencem frequência/recência maiores |
| Ranking determinístico | Conforme | desempates completos e fixtures repetíveis |
| Limite global de 20 | Conforme | solicitação de 99 resultados retorna exatamente 20 |
| Mais usados com consulta vazia | Conforme | somente entradas presentes no histórico aparecem, ordenadas por uso |
| Ícone e nome | Conforme | delegate visual usa os campos normalizados e fallback de ícone |
| Teclado e ponteiro | Conforme | testes QML cobrem setas/Enter/Escape e clique; Sway headless usa teclado Wayland real |
| Ativação e fechamento | Conforme | marcador comum é criado e o overlay fecha somente após aceitação |
| Execução estruturada | Conforme | Quickshell fornece `command`; runner usa lista com `shell=False` |
| `Terminal=true` | Conforme | terminal configurado/automático coberto e fixture real iniciada via `foot` |
| Entrada inexequível e falha acionável | Conforme | item permanece pesquisável, gera erro/log e não fecha o launcher |
| Fixtures representativas | Conforme | comum, Flatpak, Steam, terminal, escondida e inexequível cobertas entre unidade e sistema |
| Histórico persistente | Conforme | frequência/recência podadas e envelope de duas aplicações verificado com modo `0600` |
| Privacidade | Conforme | consulta, comando e caminhos não entram em status, diagnóstico ou contexto de log |

## Limitações e riscos conhecidos

- A compatibilidade integral com códigos de campo que exigem arquivos ou URLs não é prometida no MVP, conforme a própria especificação; o launcher deste marco inicia aplicações sem fornecer esses argumentos.
- A seleção automática de terminal depende de ao menos um terminal compatível no `PATH`; a ausência produz aviso acionável e mantém o launcher aberto.
- O histórico compartilhado ainda contém somente aplicações. Arquivos, comandos privados e limpeza completa pertencem ao Marco 5.

## Hipóteses assumidas

- A sessão alvo fornece o protocolo layer-shell e o catálogo XDG que o Quickshell 0.3.1 expõe; ambos foram confirmados no Sway 1.12 headless da toolchain.

## Arquivos não relacionados

- A especificação, as instruções operacionais e os relatórios de verificação anteriores não foram alterados.
- O relatório recebido `docs/reports/milestone-3-verification-0.1.md` foi preservado sem alterações.

## Estado final

- [x] Pronto para verificação independente
- [ ] Bloqueado — requer decisão ou ação do responsável
