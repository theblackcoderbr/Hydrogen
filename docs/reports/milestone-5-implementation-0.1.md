# Relatório de implementação — Marco 5: Launcher completo

## Escopo recebido

- Requisito: iniciar o Marco 5 após a aprovação formal do Marco 4.
- Critérios de aceitação: pesquisa `fd` sob demanda, cancelamento e descarte de respostas antigas, abertura XDG por URL, modo `>`, modificadores, ações internas, histórico compartilhado limitado e privacidade.
- Demonstração obrigatória: consultas fora de ordem, caminhos especiais, comandos com argumentos, execução privada, terminal, limpeza e restauração.
- Decisões abertas preservadas: calendário, menu de sessão e suas confirmações, bateria, rede e demais painéis contextuais pertencem ao Marco 6.

## Alterações realizadas

| Arquivo/componente | Alteração | Justificativa |
|---|---|---|
| `hydrogen/logic/Launcher.js` | resultados combinados, arquivos, parser de prefixos, sugestões e histórico compartilhado | manter ranking, privacidade e persistência determinísticos fora da interface |
| `hydrogen/domain/LauncherStore.qml` | gerações de busca, arquivos válidos, executáveis, ações e operações unificadas de histórico | impedir publicação obsoleta e conservar uma única fonte autoritativa |
| `hydrogen/domain/LauncherController.qml` | coordenação de arquivos, comandos, ações, confirmação de processo, poda e erros | reutilizar stores/controladores existentes sem integrações na view |
| `hydrogen/providers/launcher/LauncherBackend.qml` | raízes XDG, processos canceláveis, varredura do `PATH`, abertura externa e execução | concentrar integrações externas do launcher em um provider lógico |
| `hydrogen/providers/launcher/launcher_backend.py` | `fd`, validação de arquivos, executáveis e execução com `shlex`/`shell=False` | manter entradas estruturadas e resultados JSON estreitos |
| `hydrogen/features/panel/LauncherContent.qml` | apresentação combinada de aplicativos, arquivos, comandos e ações | completar a interação por teclado/ponteiro sem processos externos |
| `hydrogen/persistence/StateRepository.qml` | flush imediato solicitado pela limpeza do histórico | garantir que limpar sobreviva mesmo a encerramento logo após a ação |
| `hydrogen/shell.qml` e `providers/launcher/qmldir` | composição do backend e contratos do controlador | integrar exatamente uma instância compartilhada |
| `shell.nix` | inclusão fixada de `fd` e `xdg-utils` | fornecer busca normativa e demonstração XDG reproduzível |
| `tests/unit/launcher.test.mjs` | ranking combinado, mais usados mistos, ausência de comandos no modo normal, URLs, modificadores, sugestões, privacidade e poda | cobrir regras puras e respostas fora de processos |
| `tests/qml/tst_launcher.qml` | respostas e erros fora de ordem, aceitação/rejeição XDG, falha de comando, privado, terminal e ações internas | testar store/controlador/view com providers falsos |
| `tests/unit/test_launcher_backend.py` | `fd`, ocultos, caminhos especiais, argumentos literais, `$HOME`, terminal configurado, falha imediata, `PATH` e validação | provar os limites de segurança do helper real |
| `tests/system/run-headless.sh` | arquivo XDG real, handler falso, comandos, reinício, restauração, limpeza e logs | exercer o fluxo completo sem home/configuração reais |
| `README.md`, `docs/architecture.md` e `docs/requirements-tests.md` | estado, fronteiras e rastreabilidade dos Marcos 1–5 | permitir reprodução e verificação independentes |

## Decisões técnicas

- Decisão: obter as raízes pelas `StandardPaths` do Qt e delegar apenas a busca ao `fd`.
  - Evidência ou necessidade: as pastas XDG são resolvidas pelo toolkit; o helper precisa somente ignorar inexistentes e iniciar `fd` com argumentos estruturados.
  - Alternativas consideradas: pesquisar toda a home ou interpretar `user-dirs.dirs` no Hydrogen. A primeira ampliaria o escopo e a segunda duplicaria resolução já fornecida pelo Qt.
  - Consequência: Desktop, Documents, Downloads, Music, Movies, Pictures, PublicShare e Templates existentes formam o universo de busca.
- Decisão: usar simultaneamente cancelamento físico e geração lógica.
  - Evidência ou necessidade: encerrar o processo economiza trabalho, mas somente a comparação de geração prova que uma saída tardia nunca é publicada.
  - Consequência: qualquer alteração invalida a geração anterior; testes emitem deliberadamente a resposta velha depois da nova solicitação.
- Decisão: converter caminhos no helper com `Path.as_uri()` e chamar `Qt.openUrlExternally()` no provider.
  - Evidência ou necessidade: a especificação exige URL `file://` escapada e proíbe selecionar internamente a aplicação associada.
  - Consequência: espaços, `#`, Unicode e outros bytes são codificados; a view nunca recebe um comando de abertura.
- Decisão: analisar somente argumentos com `shlex.split()` e executar com `shell=False`.
  - Evidência ou necessidade: o modo aceita aspas/argumentos, mas operadores de shell não podem adquirir semântica especial.
  - Consequência: `|`, `$HOME`, `*.txt` e `$()` chegam literalmente ao processo; aspas inválidas falham antes da criação.
- Decisão: armazenar a linha sem prefixo e distinguir comandos diretos/de terminal na chave do histórico.
  - Evidência ou necessidade: a mesma linha pode representar dois modos operacionais; `!` deve impedir qualquer criação ou incremento.
  - Consequência: aplicativos, arquivos e comandos compartilham de verdade os limites globais de 100 itens e 30 dias.
- Decisão: disponibilizar agora somente ações internas não destrutivas.
  - Evidência ou necessidade: recarga, não perturbe e limpeza já possuem controladores seguros; logout, reboot e poweroff exigem a confirmação incontornável cuja implementação pertence ao Marco 6.
  - Alternativas consideradas: ocultar as ações de sessão ou executá-las sem confirmação. A segunda violaria diretamente a especificação; a primeira esconderia o motivo da indisponibilidade.
  - Consequência: as três ações de sessão aparecem desabilitadas com explicação e não oferecem contorno provisório.

## Testes e verificações

| Comando ou procedimento | Resultado | Evidência relevante |
|---|---|---|
| `nix-shell --pure --run './scripts/test-unit.sh'` | aprovado | 53 testes Qt/QML, 39 testes Node.js e 10 testes Python |
| `nix-shell --pure --run './scripts/lint.sh'` | aprovado | todos os imports, tipos, sinais e escopos QML sem avisos |
| `nix-shell --pure --run './scripts/test-system.sh'` | aprovado | arquivo especial, URL XDG, argumentos literais, privado, terminal, reinício 5→5, limpeza 5→0 e ausência de sentinelas nos logs |
| `nix-shell --pure --run './scripts/check.sh'` | aprovado | suíte normativa conjunta dos Marcos 1–5 |

## Fontes e evidências técnicas

| Afirmação ou decisão | Fonte | Versão/estado | Evidência obtida | Certeza |
|---|---|---|---|---|
| `StandardPaths.standardLocations()` e os tipos Desktop/Documents/Download/etc. existem em QML | qmltypes e documentação oficial QtCore | Qt 6.10.1 fixado | Documents isolado em `user-dirs.dirs` foi localizado no processo real | Confirmado |
| `Qt.openUrlExternally()` entrega uma URL ao handler externo | qmltypes/documentação oficial Qt QML e execução real | Qt 6.10.1 | handler isolado recebeu exatamente a URL produzida para espaço, `#` e “ação” | Confirmado |
| `Process.running = false` encerra o processo e `Process` publica saída/exit assíncronos | qmltypes e fonte oficial Quickshell Io | Quickshell 0.3.1 | consulta seguinte cancela a anterior; geração antiga emitida no fake é descartada | Confirmado |
| `fd` aceita tipo arquivo, caminho absoluto, texto fixo, saída NUL e máximo de resultados | manual/`--help` instalado e projeto upstream | fd 10.3.0 fixado | teste real exclui oculto e retorna somente o arquivo especial |
| `QStandardPaths` segue diretórios XDG do usuário | documentação oficial Qt | Qt 6.10.1 | `XDG_DOCUMENTS_DIR` temporário foi a única raiz com a fixture encontrada | Confirmado |
| `shlex.split()` separa argumentos sem executar shell e `Popen(shell=False)` preserva o vetor | documentação oficial Python e implementação testada | Python 3 da toolchain | gravador recebeu operadores/expansões como cinco argumentos literais e nenhum efeito colateral ocorreu | Confirmado |
| `Path.as_uri()` produz URL absoluta escapada | documentação oficial Python e teste local | Python 3 da toolchain | URL do helper coincide com `pathToFileURL` independente no teste de sistema | Confirmado |

## Critérios de aceitação

| Critério do Marco 5 | Estado | Evidência |
|---|---|---|
| Busca `fd` a partir de três caracteres | Conforme | controlador não solicita com dois; helper real pesquisa com três ou mais |
| Pastas XDG existentes | Conforme | `StandardPaths` fornece raízes e helper descarta inexistentes |
| Sem arquivos/diretórios ocultos | Conforme | flags padrão do `fd`, `--type f` e fixture oculta ausente |
| Cancelamento e respostas obsoletas | Conforme | término físico mais request ID validado no provider e store; resposta velha forçada não publica |
| Aplicativos antes dos arquivos, máximo 20 | Conforme | composição reserva primeiro posições para apps e limita arquivos ao restante |
| Abertura por URL XDG | Conforme | `Qt.openUrlExternally()` aceita URL escapada e fecha o launcher |
| Caminhos especiais | Conforme | espaço, `#` e Unicode exercitados no helper e Sway headless |
| Modo `>` com argumentos | Conforme | linha direta e aspas exercitadas; teste dedicado confirma que o processo nasce na home |
| Sem interpretação de shell | Conforme | operadores, variável, glob e substituição chegam literais; `shell=False` explícito |
| Modificadores `!` e `_` combináveis | Conforme | `!`, `_`, `!_` e `_!` cobertos; privado não altera histórico e o vetor do terminal configurado foi confirmado |
| Sugestões | Conforme | ações internas, histórico por uso e executáveis do `PATH` combinados e limitados |
| Ações internas do Marco 5 | Conforme | recarga, DND e limpeza funcionam, inclusive por teclado; a limpeza solicita persistência imediata |
| Ações de sessão dependentes do Marco 6 | Fora do escopo deste marco | logout, reinício e desligamento não possuem caminho executável antes da confirmação incontornável definida para os painéis contextuais |
| Histórico compartilhado e limitado | Conforme | três tipos, chave estável, 100/30 globais, inválidos eliminados e privado rejeitado na restauração |
| Limpeza imediata | Conforme | ação por teclado produz memória e arquivo com zero itens antes do restante do teste |
| Restauração | Conforme | processo Hydrogen reiniciado na mesma sessão restaura cinco itens válidos |
| Privacidade | Conforme | status/diagnóstico só têm contagens; consulta, comando e caminho-sentinela não aparecem nos logs de ambas as execuções |

## Limitações e riscos conhecidos

- Logout, reinício e desligamento aparecem desabilitados até o Marco 6 fornecer o menu de sessão e a confirmação incontornável. Essa fronteira está documentada e não existe execução direta temporária; ela não é contabilizada como implementação concluída pelo Marco 5.
- A descoberta de executáveis reflete o `PATH` herdado no início do provider; mudanças posteriores exigem reinicialização/recarregamento do shell para atualizar sugestões.
- A pesquisa usa a semântica padrão de ignore do `fd`, além de excluir ocultos. Arquivos ignorados por regras do usuário não aparecem, comportamento coerente com a ferramenta escolhida pela especificação.

## Hipóteses assumidas

- O handler XDG padrão está corretamente configurado na sessão do usuário. Ausência ou rejeição mantém o launcher aberto com aviso acionável.

## Arquivos não relacionados

- A especificação, instruções operacionais e relatórios anteriores não foram alterados.

## Estado final

- [x] Pronto para verificação independente
- [ ] Bloqueado — requer decisão ou ação do responsável
