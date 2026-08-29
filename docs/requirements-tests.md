# Matriz requisito–teste — Marcos 1 a 4

| Requisito | Evidência automatizada |
|---|---|
| Ciclo de vida, configuração transacional, persistência, erros e diagnóstico | `tests/qml/tst_foundation.qml`, `tst_components.qml`, testes Node.js e `tests/system/run-headless.sh` |
| Barra por saída, layout responsivo, relógio, zona exclusiva e overlay único | `tests/qml/tst_panel.qml`, `tests/unit/panel.test.mjs`, Sway headless |
| Hotplug, escalas 1 e 1,25 e overlay sem teletransporte | `tests/system/run-headless.sh` |
| Protocolo IPC Sway sem `swaymsg` no produto | `tests/unit/test_sway_bridge.py` e conexão real exercitada no sistema headless |
| Descoberta Wayland/XWayland e exclusão do scratchpad | `tests/unit/window-navigation.test.mjs`, clientes `foot`/XTerm no sistema headless |
| Identidade manual, Flatpak/sandbox, Steam, aplicação web, AppImage, `app_id`, `StartupWMClass`, classe e instância | `tests/unit/window-navigation.test.mjs`; regra manual e XWayland reais no sistema headless |
| Regras inválidas isoladas, ordem declarada e reavaliação após recarga | testes Node.js e transições de configuração 5→6→7 no sistema headless |
| Título e PID nunca agrupam; desconhecidos preservam título e ícone genérico | fixture Node.js, `tests/qml/tst_window_surfaces.qml` e duas janelas reais de mesmo título sem Desktop Entry |
| Agrupamento confiável, contador, foco/fechamento e diálogo transitório | testes Node.js, `tests/qml/tst_window_navigation.qml` e `tests/qml/tst_window_surfaces.qml` sobre `WindowMenuContent.qml` |
| Ordem estável, fechamento/reabertura ao final | `tests/qml/tst_window_navigation.qml` |
| Urgência de janela, grupo e workspace | fixture Node.js e urgência aplicada no Sway headless |
| Overflow com aplicativo ativo preservado | `window-navigation.test.mjs`, interação real de `WindowMenuContent.qml` e 14 grupos no Sway após redução dinâmica da saída para 640×480 |
| Workspaces atuais/ocupados por saída, ordenação e urgência | `window-navigation.test.mjs` e fotografias reais de duas saídas |
| Clique, clique do meio, roda e comandos numéricos sem shell | `WindowNavigationController.qml`, `BarSurface.qml` e testes QML de comandos estruturados |
| Privacidade de `status`/`diagnostics` | testes de fundação; o sistema expõe apenas contagens agregadas de janelas |
| Perda do Sway e flush/saída coordenada | etapa final de `tests/system/run-headless.sh` |
| Catálogo Desktop Entries e respeito a `NoDisplay` | `tests/unit/launcher.test.mjs` e catálogo XDG isolado no sistema headless |
| Busca sem distinção de caixa/acentos e apresentação original | `tests/unit/launcher.test.mjs` e `tests/qml/tst_launcher.qml` |
| Ranking determinístico, nome prioritário, frequência/recência, limite 20 e mais usados | `tests/unit/launcher.test.mjs` |
| Aplicativo comum, Flatpak e Steam/aplicação representativa | fixtures unitárias e Desktop Entries isoladas em `tests/system/run-headless.sh` |
| Teclado, ponteiro, ícone/nome, ativação e fechamento após aceitação | `tests/qml/tst_launcher.qml`; `wtype` e processo real no Sway headless |
| Execução estruturada sem shell e diretório de trabalho | `tests/unit/test_desktop_entry_runner.py` e marcadores reais no sistema headless |
| `Terminal=true` com terminal configurado/automático | testes Python do wrapper e execução real via `foot` no Sway headless |
| Entrada inexequível pesquisável, erro acionável e launcher preservado | testes Node/QML e cenário real `Hydrogen Broken` no sistema headless |
| Histórico de uso persistente, limitado, podado e privado | `launcher.test.mjs`, `StateRepository.qml` e envelope `launcher-history.json` verificado no sistema headless |
| Imports e tipos QML | `scripts/lint.sh` com `qmllint` sem avisos |

Todos os comandos completos são descritos no `README.md`. Nenhum teste usa configuração, estado, dados pessoais ou home reais.
