# Projeto Hydrogen — Fontes e Política de Pesquisa

> **Finalidade:** definir onde pesquisar, como validar informações técnicas e como impedir que implementadores e verificadores inventem APIs, comportamentos ou requisitos.  
> **Aplicação:** toda implementação, correção, revisão técnica ou decisão arquitetural do Projeto Hydrogen.

## 1. Regra fundamental

Nenhuma afirmação técnica relevante deve ser tratada como verdadeira apenas porque parece plausível, é comum em projetos semelhantes ou corresponde à memória da IA.

Antes de implementar ou reprovar uma solução, a IA deve confirmar o comportamento por pelo menos uma destas formas:

1. documentação normativa ou oficial compatível com a versão usada;
2. código-fonte ou manual do projeto upstream;
3. comportamento observado em teste reproduzível no ambiente do projeto;
4. decisão explícita registrada na especificação ou pelo responsável pelo Hydrogen.

Quando nenhuma confirmação for possível, a informação deve ser declarada como hipótese, com o nível de incerteza e a verificação necessária.

## 2. Hierarquia de autoridade

### 2.1 Decisões do Hydrogen

1. solicitação atual e explícita do responsável pelo projeto;
2. `Especificacao_Inicial_Hydrogen_0.1.md`;
3. decisões arquiteturais e documentação vigentes no repositório;
4. critérios de aceitação do marco atual;
5. instruções do implementador e do verificador.

Essas fontes definem **o que o Hydrogen deve fazer**. Uma documentação externa não pode redefinir o produto.

### 2.2 Fontes técnicas primárias

1. documentação oficial da versão realmente usada;
2. especificação oficial do protocolo ou padrão;
3. manual oficial instalado ou mantido pelo upstream;
4. código-fonte e testes do upstream;
5. notas de versão e changelog do upstream.

Essas fontes definem **como a tecnologia realmente funciona**.

### 2.3 Fontes técnicas secundárias

1. ArchWiki;
2. documentação oficial da distribuição usada para reproduzir um problema;
3. manuais empacotados pela distribuição;
4. relatórios de bugs e discussões do upstream com evidência reproduzível.

Essas fontes ajudam a entender integração, empacotamento, limitações práticas e diferenças entre ambientes.

### 2.4 Fontes usadas somente como pistas

- fóruns;
- Reddit;
- blogs pessoais;
- vídeos;
- respostas de Stack Overflow;
- exemplos de configurações de terceiros;
- respostas produzidas por outra IA.

Essas fontes podem indicar onde investigar, mas não confirmam sozinhas uma API, requisito, compatibilidade ou defeito.

## 3. Regra de compatibilidade de versão

Antes de consultar uma API, a IA deve identificar:

- versão do Quickshell usada pelo projeto;
- versão principal do Qt;
- versão do Sway disponível no ambiente de desenvolvimento;
- versão relevante da ferramenta ou serviço externo;
- distribuição e forma de empacotamento quando isso afetar nomes, caminhos ou recursos.

Regras:

- Prefira a documentação correspondente à versão detectada.
- Não copie exemplos da documentação `latest` para uma versão anterior sem conferir disponibilidade.
- Não presuma que uma API antiga permaneça igual numa versão nova.
- Se o projeto ainda não fixou uma versão, registre essa ausência como decisão técnica pendente antes de depender de uma API específica.
- Sempre que a versão mudar, revalide as integrações afetadas.

## 4. Catálogo de fontes aprovadas

### 4.1 Produto e arquitetura do Hydrogen

| Tema | Fonte principal | Uso |
|---|---|---|
| Escopo e comportamento | `Especificacao_Inicial_Hydrogen_0.1.md` | Requisitos, não objetivos, critérios de aceitação e decisões abertas |
| Implementação | `INSTRUCOES_IMPLEMENTADOR_CODEX.md` | Processo de trabalho, testes, entrega e tratamento de achados |
| Verificação | `INSTRUCOES_VERIFICADOR_GEMINI.md` | Evidência, classificação, severidade e parecer |
| Estado real | Código, testes, histórico e documentação do repositório | Confirmar o que já existe e evitar duplicação ou regressão |

### 4.2 Sway

| Fonte | Endereço | Prioridade |
|---|---|---|
| Site oficial | <https://swaywm.org/> | Primária |
| Repositório oficial | <https://github.com/swaywm/sway> | Primária |
| Protocolo IPC oficial | <https://github.com/swaywm/sway/blob/master/sway/sway-ipc.7.scd> | Primária |
| Manuais do Sway | `man sway`, `man swaymsg`, `man sway-ipc`, `man sway-output`, `man sway-input` | Primária e vinculada à versão instalada |
| ArchWiki — Sway | <https://wiki.archlinux.org/title/Sway> | Secundária operacional |

Para formatos JSON, eventos e comandos IPC, prefira `sway-ipc(7)`, `swaymsg(1)` e o código da versão usada. Não derive o contrato IPC de exemplos encontrados em dotfiles de terceiros.

### 4.3 Quickshell

| Fonte | Endereço | Prioridade |
|---|---|---|
| Site oficial | <https://quickshell.org/> | Primária |
| Documentação oficial versionada | <https://quickshell.org/docs/> | Primária |
| Repositório upstream | <https://git.outfoxxed.me/quickshell/quickshell> | Primária |
| Espelho oficial no GitHub | <https://github.com/quickshell-mirror/quickshell> | Primária |

Sempre selecione na documentação a versão compatível com o projeto. Confirme nomes de módulos, propriedades, sinais e tipos na referência de tipos; não os deduza por semelhança com Qt, Hyprland ou configurações de terceiros.

### 4.4 Qt, QML e Qt Quick

| Fonte | Endereço | Prioridade |
|---|---|---|
| Qt QML | <https://doc.qt.io/qt-6/qtqml-index.html> | Primária |
| Qt Quick | <https://doc.qt.io/qt-6/qtquick-index.html> | Primária |
| Referência da linguagem QML | <https://doc.qt.io/qt-6/qmlreference.html> | Primária |

Use a documentação da versão de Qt vinculada ao Quickshell instalado. Não presuma que comportamento de Qt Widgets, CSS ou JavaScript de navegador se aplique ao QML.

### 4.5 Wayland e protocolos de shell

| Fonte | Endereço | Prioridade |
|---|---|---|
| `wayland-protocols` | <https://gitlab.freedesktop.org/wayland/wayland-protocols> | Normativa |
| Protocolos wlroots | <https://gitlab.freedesktop.org/wlroots/wlr-protocols> | Normativa para extensões wlroots |
| Wayland Explorer | <https://wayland.app/protocols/> | Leitura auxiliar do XML normativo |
| wlr layer shell | <https://wayland.app/protocols/wlr-layer-shell-unstable-v1> | Referência auxiliar específica |

O Wayland Explorer facilita a leitura, mas o XML do protocolo e o suporte efetivo do Sway/Quickshell prevalecem em caso de divergência.

### 4.6 Padrões de desktop e XDG

| Tema | Fonte oficial |
|---|---|
| Catálogo de especificações | <https://specifications.freedesktop.org/> |
| Desktop Entry | <https://specifications.freedesktop.org/desktop-entry/latest/> |
| Associações MIME | <https://specifications.freedesktop.org/mime-apps/latest-single/> |
| MPRIS | <https://specifications.freedesktop.org/mpris/latest/> |
| Base Directory | <https://specifications.freedesktop.org/basedir-spec/latest/> |
| Ícones | <https://specifications.freedesktop.org/icon-theme/latest/> |
| System Tray / Status Notifier | verificar a especificação adotada e a implementação do Quickshell antes de decidir |

Use essas fontes para localizar aplicativos, interpretar arquivos `.desktop`, abrir arquivos, selecionar ícones e interagir com players. A ArchWiki pode explicar a operação prática, mas não substitui a especificação.

### 4.7 Áudio e mídia

| Tema | Fonte principal |
|---|---|
| PipeWire | <https://docs.pipewire.org/> |
| WirePlumber | <https://pipewire.pages.freedesktop.org/wireplumber/> |
| `wpctl` | manual `wpctl(1)` da versão instalada e documentação do WirePlumber |
| MPRIS | <https://specifications.freedesktop.org/mpris/latest/> |
| Integração do Quickshell | documentação versionada de `Quickshell.Services.Pipewire` e `Quickshell.Services.Mpris` |

Antes de escolher entre executar `wpctl`/`playerctl` e usar uma API nativa do Quickshell, compare suporte, sinais, robustez e versão disponível. A especificação define o comportamento; a solução técnica deve ser justificada por evidência.

### 4.8 Energia e bateria

| Tema | Fonte principal |
|---|---|
| UPower D-Bus API | <https://upower.freedesktop.org/docs/ref-dbus.html> |
| power-profiles-daemon D-Bus API | <https://upower.pages.freedesktop.org/power-profiles-daemon/gdbus-org.freedesktop.UPower.PowerProfiles.html> |
| Integração do Quickshell | documentação versionada de `Quickshell.Services.UPower` |
| ArchWiki | páginas de UPower e gerenciamento de energia, apenas como apoio operacional |

Não presuma que toda máquina possui bateria, UPower ou perfis de desempenho. Descubra capacidades em tempo de execução e degrade graciosamente.

### 4.9 Busca de arquivos

| Fonte | Endereço | Prioridade |
|---|---|---|
| Repositório e documentação do `fd` | <https://github.com/sharkdp/fd> | Primária |
| Manual instalado | `man fd` ou `man fdfind` | Primária para o ambiente atual |

Considere diferenças de empacotamento: em algumas distribuições o binário pode se chamar `fdfind`. Confirme o executável disponível; não o presuma.

### 4.10 Brilho

| Fonte | Endereço | Prioridade |
|---|---|---|
| Repositório do `brightnessctl` | <https://github.com/Hummer12007/brightnessctl> | Primária |
| Manual instalado | `man brightnessctl` | Primária para a versão instalada |
| ArchWiki — Backlight | <https://wiki.archlinux.org/title/Backlight> | Secundária operacional |

Não presuma que o primeiro dispositivo listado corresponde à tela desejada. Verifique dispositivos, permissões, múltiplas saídas e ausência de backlight controlável.

### 4.11 Integração Linux e empacotamento

| Fonte | Uso |
|---|---|
| ArchWiki | Integração prática entre componentes, permissões, sessões Wayland, PipeWire, D-Bus, XDG e empacotamento no Arch |
| Documentação da distribuição-alvo | Nomes de pacotes, caminhos, patches e diferenças de empacotamento |
| Manuais instalados | Comportamento da versão realmente disponível |
| Repositórios upstream | Fonte final para bugs, APIs e diferenças de versão |

A ArchWiki é uma referência excelente, mas não deve ser usada para concluir que todas as distribuições possuem os mesmos pacotes, nomes de binário, serviços ou caminhos.

## 5. Procedimento obrigatório de pesquisa

Para cada questão técnica relevante:

1. **Defina a pergunta concreta.** Exemplo: “Como receber eventos de mudança de foco do Sway nesta versão?”, não “Como integrar com Sway?”.
2. **Identifique versões e ambiente.** Registre versões, distribuição e backend envolvidos.
3. **Consulte a fonte de maior autoridade aplicável.** Comece pela documentação do projeto ou especificação normativa.
4. **Confirme a disponibilidade real.** Verifique código, imports, executáveis, D-Bus, IPC ou teste mínimo.
5. **Procure evidência contrária.** Confira limitações, changelog, bugs conhecidos e diferenças de versão.
6. **Registre a conclusão.** Inclua fonte, versão e impacto na decisão.
7. **Classifique a certeza.** Confirmado, hipótese a testar ou decisão de produto pendente.

## 6. Matriz mínima de evidência

| Tipo de afirmação | Evidência mínima |
|---|---|
| Propriedade, tipo ou sinal QML existe | Referência oficial da versão e, quando possível, teste mínimo |
| Evento ou comando IPC existe | `sway-ipc(7)`/`swaymsg(1)` da versão ou código upstream correspondente |
| Protocolo permite determinado comportamento | XML/especificação do protocolo e suporte do compositor/toolkit |
| Comando externo aceita determinada opção | `--help` ou manual da versão instalada |
| Recurso é portátil entre distribuições | Documentação upstream mais validação nos ambientes declarados como suportados |
| Defeito está confirmado | Reprodução, teste que falha ou caminho de código inequívoco |
| Solução atende ao Hydrogen | Requisito/critério da especificação e evidência de execução |

## 7. Registro obrigatório no relatório

Toda implementação ou verificação que dependa de pesquisa deve registrar:

```markdown
## Fontes e evidências técnicas

| Afirmação ou decisão | Fonte | Versão/estado | Evidência obtida | Certeza |
|---|---|---|---|---|
| | | | | Confirmado / Hipótese / Decisão pendente |
```

Links sozinhos não bastam. A IA deve explicar qual afirmação cada fonte sustenta.

## 8. Tratamento de conflitos

Quando duas fontes divergirem:

1. confira se tratam da mesma versão;
2. prefira a fonte normativa ou oficial mais próxima do código executado;
3. verifique changelog e código upstream;
4. reproduza o comportamento no ambiente do projeto;
5. registre a divergência e a decisão adotada;
6. não esconda a incerteza para continuar implementando.

Um issue antigo, tutorial ou configuração de terceiros não prevalece sobre a documentação e o comportamento da versão atual.

## 9. Instruções anti-invenção

É proibido:

- inventar módulos, imports, propriedades, sinais, métodos ou tipos QML;
- inventar campos do JSON do IPC do Sway;
- presumir que APIs do Hyprland existem para Sway;
- copiar código de outra versão sem confirmar compatibilidade;
- deduzir comandos pela semelhança do nome;
- inventar caminhos de configuração ou nomes de pacotes;
- afirmar portabilidade com base em uma única distribuição;
- apresentar uma resposta de IA como evidência técnica;
- transformar exemplo de terceiros em comportamento oficialmente suportado;
- omitir uma limitação conhecida para manter uma solução aparentemente simples;
- implementar uma hipótese silenciosamente;
- declarar um bug sem reprodução ou evidência suficiente;
- citar uma fonte que não sustenta diretamente a afirmação feita.

Quando a documentação não responder:

1. diga explicitamente o que não foi confirmado;
2. inspecione o código ou testes upstream;
3. crie uma reprodução mínima;
4. solicite decisão ou informação quando necessário;
5. mantenha o ponto como hipótese até obter evidência.

## 10. Uso de issues e discussões upstream

Issues e discussões podem ser usadas para:

- confirmar que um comportamento foi reconhecido pelo upstream;
- localizar regressões e limitações de versão;
- encontrar reproduções e workarounds;
- entender decisões de manutenção.

Elas não devem ser usadas isoladamente para:

- definir o contrato estável de uma API;
- provar que um bug afeta a versão do projeto;
- justificar uma solução sem reproduzi-la;
- substituir documentação normativa.

Registre estado, data, versão afetada e se a conclusão foi incorporada ao upstream.

## 11. Regra final

Se a IA souber, ela deve mostrar como confirmou. Se apenas suspeitar, deve dizer que suspeita. Se não souber, deve pesquisar ou pedir informação. Inventar uma resposta para manter o trabalho em movimento é uma falha de processo.
