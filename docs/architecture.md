# Arquitetura — Marcos 1 a 5

`hydrogen/shell.qml` é somente a raiz de composição. O fluxo de intenção é:

```text
IPC / composição
       │
       ▼
FoundationController
       │
       ├── LifecycleManager
       ├── ConfigurationRepository ──► ConfigurationStore
       ├── StateRepository
       └── SwayProvider ─────────────► SwayStore
                                           │
                                           ▼
                                  FoundationSurface(s)
```

As views não leem arquivos, não executam processos e não acessam o IPC do Sway. `FoundationSurface` recebe apenas a saída do `Variants` e não contém regra de domínio. A conexão Sway real fica em `providers/sway`; o fake implementa o mesmo contrato observável usado pelos testes.

Os fluxos funcionais acrescentados pelos marcos seguintes preservam essa separação:

```text
DesktopEntries ─► DesktopEntriesProvider ────────────────┐
                                                        ▼
LauncherBackend ─► fd / PATH / URL XDG / processos ─► LauncherController
                                                        │       ▲
                                                        ▼       │
                                                  LauncherStore ─┴─► LauncherContent
                                                        │
                                                        └──────────► StateRepository

Sway IPC bridge ─► SwayProvider ─► WindowStore ─► Bar/WindowMenuContent
                                      ▲                    │
                                      └─ WindowNavigationController
```

`LauncherContent` e `WindowMenuContent` são componentes Qt Quick testáveis sem processos externos. As respectivas `PanelWindow` cuidam somente da integração com a superfície Quickshell e o foco Wayland.

## Ciclo de vida

O controlador percorre `starting`, `loading_configuration`, `starting_core`, `starting_providers`, `creating_surfaces` e `running`/`degraded`. Após `shutting_down`, toda mutação é recusada. O encerramento desativa superfícies, para o provider, solicita flush atômico com limite de dois segundos e termina a aplicação.

## Configuração

`ConfigurationRepository` cria a árvore documentada na primeira execução e observa o arquivo principal e todos os TOMLs do diretório `components/`. O parser aceita apenas o subconjunto TOML necessário ao esquema atual e falha fechado para construções não implementadas. Uma recarga cria candidata, valida, compara e publica uma nova geração somente de forma atômica. Erro sintático mantém a geração anterior; remover arquivo faz seu namespace voltar aos padrões.

## Persistência

`StateRepository` é o único escritor de `state.json`, `launcher-history.json` e `notification-history.json`. Diretório e arquivos usam `0700`/`0600`; `FileView.atomicWrites` permanece habilitado. Estado futuro é preservado sem escrita. JSON corrompido é movido para uma cópia `state.corrupt-<timestamp>.json` antes da criação do envelope limpo. A retenção enumera somente nomes internos válidos, preserva as três cópias mais recentes e remove as excedentes com argumentos estruturados; falha na poda gera aviso acionável sem interromper o repository.

O histórico do launcher armazena tipo, chave estável, contador e instante de último uso. Aplicativos usam Desktop Entry, arquivos usam caminho absoluto normalizado e comandos usam linha sem prefixo mais o indicador de terminal. A poda compartilhada combina validade, idade e quantidade configuradas. Comandos privados não chegam ao store; conteúdo de apresentação não é duplicado no arquivo; versões futuras do envelope são preservadas sem sobrescrita.

## Launcher de aplicativos

`DesktopEntriesProvider` converte o modelo do Quickshell em objetos imutáveis de domínio e remove entradas `NoDisplay`. `Launcher.js` normaliza apenas para comparação, preserva nome e ícone exibidos, classifica primeiro a qualidade da correspondência do nome e usa frequência, recência, nome e identificador como desempates determinísticos.

A ativação atravessa `LauncherController` e um runner Python estreito. O runner recebe JSON, valida comando e diretório e chama `subprocess.Popen` com uma lista de argumentos e `shell=False`. Entradas `Terminal=true` recebem como prefixo `terminal.command`; quando ele está vazio, uma lista curta de terminais compatíveis é tentada. O launcher fecha somente depois que o runner aceita a criação do processo. Falhas permanecem visíveis, são registradas sem consulta, argumentos ou caminhos pessoais e não interrompem os demais componentes.

O `LauncherSurface` solicita foco exclusivo pelo protocolo layer-shell enquanto existe. O campo de pesquisa é o foco inicial dentro de um `FocusScope`, garantindo operação por teclado inclusive quando a superfície é aberta por IPC.

## Arquivos e modo de comandos

`LauncherBackend` recebe das `StandardPaths` do Qt somente as pastas XDG aplicáveis. A partir do terceiro caractere, inicia um helper com `fd`; mudar a consulta encerra o processo anterior e incrementa uma geração. Store e provider conferem essa geração antes de publicar, portanto uma resposta antiga não pode substituir a consulta atual. Pastas inexistentes são removidas no helper, `fd` mantém sua exclusão padrão de itens ocultos e somente arquivos regulares são retornados.

O helper converte caminhos absolutos em URLs com `Path.as_uri()`; a integração QML entrega apenas a URL a `Qt.openUrlExternally()`. O Hydrogen não escolhe associação MIME nem concatena o caminho em comando.

No modo `>`, `Launcher.js` interpreta somente os modificadores iniciais `!` e `_`. O helper divide executável e argumentos com `shlex`, chama `subprocess.Popen` com `shell=False` e usa a pasta pessoal como diretório inicial. Pipelines, redirecionamentos, substituições e globbing permanecem argumentos literais. Sugestões combinam ações internas, histórico e nomes executáveis descobertos no `PATH`, sem publicar seus diretórios.

Ações de configuração, não perturbe e limpeza reutilizam os controladores/stores existentes. Ações destrutivas de sessão ficam visíveis porém indisponíveis até o fluxo de confirmação do Marco 6; não existe caminho provisório capaz de contornar confirmação.

## Diagnóstico e privacidade

`status` contém apenas saúde resumida. `diagnostics` deriva exclusivamente da última fotografia confirmada e nunca executa coleta no momento da consulta. A normalização remove conteúdo de janelas, históricos, notificações, comandos, caminhos pessoais e campos arbitrários de providers/erros.
