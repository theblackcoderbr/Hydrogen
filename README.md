# Hydrogen

Hydrogen é um shell tradicional e leve para Sway, construído com Quickshell. O desenvolvimento segue sequencialmente os marcos definidos em `Especificacao_Inicial_Hydrogen_0.1.md`; o repositório contém atualmente o **Marco 3 — Navegação de janelas**, pronto para verificação independente.

## Estado atual

Além da fundação e do painel básico já aprovados, o Marco 3 entrega:

- uma barra por saída com workspaces reais e aplicativos do workspace visível;
- descoberta de janelas Wayland e XWayland pelo IPC binário do Sway, sem depender de `swaymsg` em produção;
- identidade por regra manual, `sandbox_app_id`, `app_id`, `StartupWMClass`, classe/instância XWayland e fallback não agrupável;
- grupos com ordem estável, contador, foco ativo e urgência;
- lista de janelas com foco e fechamento, operável por teclado e ponteiro;
- overflow que preserva o aplicativo ativo sempre que possível;
- workspaces por saída com clique, clique do meio e navegação circular pela roda;
- um único overlay principal compartilhado por launcher, grupos e overflow.

A pesquisa do launcher continua deliberadamente indisponível até o Marco 4. Indicadores, painéis contextuais e demais recursos pertencem aos marcos posteriores.

## Ambiente de desenvolvimento e testes

O `shell.nix` é a fonte normativa da toolchain. Ele fixa as revisões do `nixpkgs`, Quickshell 0.3.1, Qt 6.10.1 e Sway 1.12, além de fornecer Node.js e Python para os testes e para o bridge IPC. `foot`, XTerm e Xwayland são usados exclusivamente na demonstração isolada do Marco 3.

Entre no ambiente antes de desenvolver, executar ou testar:

```sh
nix-shell --pure
```

Para executar diretamente a árvore de desenvolvimento em uma sessão Sway:

```sh
qs -p ./hydrogen
```

O Hydrogen não modifica a configuração do Sway e não executa argumentos de navegação por meio de shell.

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

`test-unit.sh` executa Qt Quick Test, Node.js e os testes do protocolo Python. `test-system.sh` isola integralmente os diretórios XDG, inicia duas saídas Sway headless e cria clientes Wayland/XWayland descartáveis para validar descoberta, agrupamento, regras, urgência, overflow e hotplug.

Os relatórios e a matriz de evidências ficam em `docs/reports/` e [docs/requirements-tests.md](docs/requirements-tests.md).
