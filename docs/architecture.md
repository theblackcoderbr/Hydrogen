# Arquitetura — Marco 1

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

## Ciclo de vida

O controlador percorre `starting`, `loading_configuration`, `starting_core`, `starting_providers`, `creating_surfaces` e `running`/`degraded`. Após `shutting_down`, toda mutação é recusada. O encerramento desativa superfícies, para o provider, solicita flush atômico com limite de dois segundos e termina a aplicação.

## Configuração

`ConfigurationRepository` cria a árvore documentada na primeira execução e observa o arquivo principal e todos os TOMLs do diretório `components/`. O parser aceita apenas o subconjunto TOML necessário ao esquema atual e falha fechado para construções não implementadas. Uma recarga cria candidata, valida, compara e publica uma nova geração somente de forma atômica. Erro sintático mantém a geração anterior; remover arquivo faz seu namespace voltar aos padrões.

## Persistência

`StateRepository` é o único escritor de `state.json`, `launcher-history.json` e `notification-history.json`. Diretório e arquivos usam `0700`/`0600`; `FileView.atomicWrites` permanece habilitado. Estado futuro é preservado sem escrita. JSON corrompido é movido para uma cópia `state.corrupt-<timestamp>.json` antes da criação do envelope limpo. A retenção enumera somente nomes internos válidos, preserva as três cópias mais recentes e remove as excedentes com argumentos estruturados; falha na poda gera aviso acionável sem interromper o repository.

## Diagnóstico e privacidade

`status` contém apenas saúde resumida. `diagnostics` deriva exclusivamente da última fotografia confirmada e nunca executa coleta no momento da consulta. A normalização remove conteúdo de janelas, históricos, notificações, comandos, caminhos pessoais e campos arbitrários de providers/erros.
