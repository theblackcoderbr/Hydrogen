# Matriz requisito–teste — Marcos 1 a 3

| Requisito | Evidência automatizada |
|---|---|
| Ciclo de vida, configuração transacional, persistência, erros e diagnóstico | `tests/qml/tst_foundation.qml`, `tst_components.qml`, testes Node.js e `tests/system/run-headless.sh` |
| Barra por saída, layout responsivo, relógio, zona exclusiva e overlay único | `tests/qml/tst_panel.qml`, `tests/unit/panel.test.mjs`, Sway headless |
| Hotplug, escalas 1 e 1,25 e overlay sem teletransporte | `tests/system/run-headless.sh` |
| Protocolo IPC Sway sem `swaymsg` no produto | `tests/unit/test_sway_bridge.py` e conexão real exercitada no sistema headless |
| Descoberta Wayland/XWayland e exclusão do scratchpad | `tests/unit/window-navigation.test.mjs`, clientes `foot`/XTerm no sistema headless |
| Identidade manual, Flatpak/sandbox, `app_id`, `StartupWMClass`, classe e instância | `tests/unit/window-navigation.test.mjs`; regra manual e XWayland reais no sistema headless |
| Regras inválidas isoladas, ordem declarada e reavaliação após recarga | testes Node.js e transições de configuração 5→6→7 no sistema headless |
| Título e PID nunca agrupam; desconhecidos permanecem acessíveis | fixture Node.js e duas janelas reais de mesmo título sem Desktop Entry |
| Agrupamento confiável, contador, foco/fechamento e diálogo transitório | testes Node.js, `tests/qml/tst_window_navigation.qml` e `WindowMenuSurface.qml` |
| Ordem estável, fechamento/reabertura ao final | `tests/qml/tst_window_navigation.qml` |
| Urgência de janela, grupo e workspace | fixture Node.js e urgência aplicada no Sway headless |
| Overflow com aplicativo ativo preservado | `window-navigation.test.mjs` e 14 grupos reais sob capacidade visual de 10 |
| Workspaces atuais/ocupados por saída, ordenação e urgência | `window-navigation.test.mjs` e fotografias reais de duas saídas |
| Clique, clique do meio, roda e comandos numéricos sem shell | `WindowNavigationController.qml`, `BarSurface.qml` e testes QML de comandos estruturados |
| Privacidade de `status`/`diagnostics` | testes de fundação; o sistema expõe apenas contagens agregadas de janelas |
| Perda do Sway e flush/saída coordenada | etapa final de `tests/system/run-headless.sh` |
| Imports e tipos QML | `scripts/lint.sh` com `qmllint` sem avisos |

Todos os comandos completos são descritos no `README.md`. Nenhum teste usa configuração, estado, dados pessoais ou home reais.
