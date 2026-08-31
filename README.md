# Hydrogen

Hydrogen é um shell tradicional e leve para Sway, construído com Quickshell. O desenvolvimento segue sequencialmente os marcos definidos em `Especificacao_Inicial_Hydrogen_0.1.md`; o repositório contém atualmente o **Marco 5 — Launcher completo**, pronto para verificação independente.

## Estado atual

Além dos quatro marcos já aprovados, o Marco 5 completa o launcher:

- uma barra por saída com workspaces reais e aplicativos do workspace visível;
- descoberta de janelas Wayland e XWayland pelo IPC binário do Sway, sem depender de `swaymsg` em produção;
- identidade por regra manual, `sandbox_app_id`, `app_id`, `StartupWMClass`, classe/instância XWayland e fallback não agrupável;
- grupos com ordem estável, contador, foco ativo e urgência;
- lista de janelas com foco e fechamento, operável por teclado e ponteiro;
- overflow que preserva o aplicativo ativo sempre que possível;
- workspaces por saída com clique, clique do meio e navegação circular pela roda;
- um único overlay principal compartilhado por launcher, grupos e overflow.
- catálogo de aplicativos baseado em Desktop Entries, respeitando `NoDisplay`;
- pesquisa por nome e metadados sem distinguir maiúsculas ou acentos;
- ranking determinístico por qualidade do nome, frequência e recência, limitado a 20 resultados;
- lista vazia preenchida por aplicativos e arquivos efetivamente mais usados, sem comandos fora do modo `>`;
- execução por argumentos estruturados, incluindo `Terminal=true` com terminal configurado ou seleção automática;
- histórico persistente, limitado e podado, além de falhas acionáveis que mantêm o launcher aberto.
- busca sob demanda com `fd` após três caracteres nas pastas XDG existentes;
- cancelamento da busca anterior e descarte de qualquer resposta obsoleta;
- abertura de arquivos como URLs `file://` escapadas pelo manipulador XDG padrão;
- modo `>` com argumentos estruturados, executáveis do `PATH`, histórico e ações internas;
- modificadores `!` para execução privada e `_` para o terminal configurado, em qualquer ordem;
- histórico compartilhado de aplicativos, arquivos e comandos, com restauração e limpeza imediata.

As ações internas seguras — recarregar configuração, alternar não perturbe e limpar histórico — já funcionam. Sair, reiniciar e desligar são apresentados como indisponíveis até o Marco 6, quando receberão a confirmação incontornável exigida para ações de sessão. Indicadores, painéis contextuais e demais recursos continuam nos marcos posteriores.

## Ambiente de desenvolvimento e testes

O `shell.nix` é a fonte normativa da toolchain. Ele fixa as revisões do `nixpkgs`, Quickshell 0.3.1, Qt 6.10.1 e Sway 1.12, além de fornecer `fd`, Node.js e Python para os testes, bridges estruturados e launcher. `foot`, XTerm, Xwayland, `xdg-utils` e `wtype` são usados na demonstração headless isolada.

Entre no ambiente antes de desenvolver, executar ou testar:

```sh
nix-shell --pure
```

Para executar diretamente a árvore de desenvolvimento em uma sessão Sway:

```sh
qs -p ./hydrogen
```

O Hydrogen não modifica a configuração do Sway. Comandos de navegação, Desktop Entries e o modo `>` são iniciados como vetores de argumentos, nunca como texto bruto entregue a um shell. Operadores como `|`, `>`, `$()` e globs são argumentos literais.

## Verificação

Todos os testes devem ser executados no ambiente fixado:

```sh
nix-shell --pure --run './scripts/check.sh'
```

Para etapas individuais, entre primeiro em `nix-shell --pure` e use:

```sh
./scripts/test-unit.sh
./scripts/lint.sh
./scripts/test-system.sh
```

`test-unit.sh` executa Qt Quick Test, Node.js e testes Python dos bridges. `test-system.sh` isola integralmente os diretórios XDG e o `PATH`, inicia duas saídas Sway headless e valida aplicativos, arquivos com nomes especiais, URL XDG, comandos diretos/privados/em terminal, restauração/limpeza do histórico, privacidade, navegação de janelas e hotplug.

Os relatórios e a matriz de evidências ficam em `docs/reports/` e [docs/requirements-tests.md](docs/requirements-tests.md).
