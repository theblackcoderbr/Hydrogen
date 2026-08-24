# Projeto Hydrogen

> **Especificação de produto — versão 0.1**  
> **Estado:** rascunho de produto  
> **Data:** 24 de agosto de 2026

**Shell tradicional, leve e coeso para Sway, construído com Quickshell.**

> **Síntese:** o Hydrogen não pretende reinventar o desktop nem reproduzir o Plasma Shell dentro do Sway. Seu objetivo é oferecer a experiência cotidiana e reconhecível de um desktop tradicional usando uma camada visual pequena, opinativa e integrada.

## 1. Propósito e identidade

O Hydrogen nasce para preencher a distância entre o compositor Sway, deliberadamente enxuto, e a experiência esperada de um desktop pessoal. Ele adiciona as superfícies visuais usadas no dia a dia sem assumir a administração completa do sistema.

O nome possui dois sentidos complementares: o hidrogênio é o elemento mais simples e também o combustível das estrelas. A metáfora orienta o projeto: uma base pequena, capaz de dar vida e coesão à experiência gráfica sem se tornar uma estrutura excessiva.

## 2. Visão do produto

> **Visão:** transformar o Sway em um desktop tradicional, familiar e agradável sem transformá-lo em um ambiente de desktop completo.

A interação principal deve ser compreensível sem aprendizado específico de *tiling window managers*: uma barra inferior contém o launcher, representa os aplicativos abertos e concentra informações essenciais. O Sway continua responsável por composição, foco, workspaces e organização das janelas.

## 3. Público inicial

A primeira versão será desenvolvida para o sistema e o fluxo de trabalho do próprio autor. Isso permite decisões opinativas e um escopo controlado.

A arquitetura, porém, não deverá depender de NixOS, systemd ou de uma distribuição específica: o ambiente suportado é Sway em distribuições Linux de modo geral.

## 4. Princípios de projeto

- **Não reinventar o desktop:** adotar convenções conhecidas quando elas já resolvem bem o problema.
- **Funcionar bem sem configuração:** a instalação padrão deve produzir uma experiência utilizável.
- **Poucas dependências e serviços:** preferir ferramentas pequenas, já estabelecidas e acionadas conforme necessário.
- **Interface visual coesa:** barra, launcher, menus e OSDs devem parecer partes do mesmo produto.
- **Separação de responsabilidades:** a interface representa e aciona capacidades do sistema, mas não precisa implementá-las internamente.
- **Degradação graciosa:** a ausência de hardware ou backend opcional não deve derrubar o shell.
- **Falhas localizadas:** um provedor com erro não deve interromper os demais componentes.
- **Tradicional sem imitação:** seguir o modelo conhecido de desktop sem copiar integralmente Windows, Plasma, Cinnamon ou Xfce.

## 5. Experiência central

### 5.1 Painel inferior

O núcleo visual do Hydrogen é uma barra contínua na parte inferior da tela. Ela deve permanecer visível, inclusive quando uma janela ocupar a área útil em tela cheia, e reservar seu próprio espaço por meio do protocolo layer-shell.

| Região | Conteúdo previsto | Responsabilidade |
|---|---|---|
| Esquerda | Ícone do launcher e seletor de workspaces | Abrir o launcher e navegar pelos workspaces do monitor |
| Centro / área expansível | Aplicativos e janelas abertas | Representar, focar, selecionar e fechar as janelas gerenciadas pelo Sway |
| Direita | Indicadores essenciais, bateria, sessão e relógio | Exibir estado e abrir painéis contextuais pequenos |

A barra não será um sistema genérico de painéis. No MVP, sua posição, estrutura principal e função são fixas. O arquivo de configuração poderá ajustar aparência e alguns comportamentos, mas não reconstruir livremente o layout.

### 5.2 Aplicativos abertos

A área expansível da barra representa de modo tradicional os aplicativos abertos no workspace atualmente visível naquele monitor. A lista é alimentada pelo IPC do Sway e cada aplicativo ocupa um único item, exibido somente por seu ícone.

- Janelas do mesmo aplicativo são agrupadas em um único item.
- Quando o grupo possuir mais de uma janela, o item exibe um contador.
- Um grupo com apenas uma janela transfere o foco para ela quando ativado.
- Ativar o item da janela que já está focada não executa nenhuma ação. O Hydrogen não simula minimização por meio do scratchpad.
- Ativar um grupo com várias janelas abre uma lista compacta acima da barra. Cada entrada mostra o ícone e o título da janela e permite focá-la ou fechá-la.
- O fechamento não exige confirmação do Hydrogen; o aplicativo continua responsável por impedir ou confirmar o encerramento quando necessário.
- A lista agrupada deve ser completamente operável por teclado e ponteiro.
- O aplicativo que contém a janela focada recebe o estado visual ativo.
- Uma janela urgente acrescenta um pequeno indicador ao item do aplicativo. Na lista agrupada, a janela responsável pela urgência também é identificada.
- Os aplicativos mantêm a ordem em que apareceram no workspace. Mudanças de foco não reorganizam a barra, e um aplicativo fechado e reaberto retorna ao final da lista.
- Quando não houver espaço horizontal, os itens excedentes são deslocados para um menu de overflow, preservando a operação normal de grupos e janelas.
- A janela ativa deve permanecer visível na barra sempre que possível; para isso, um item inativo pode ser deslocado para o menu de overflow.
- Janelas presentes no scratchpad não são representadas como minimizadas pelo Hydrogen.

#### 5.2.1 Identificação e agrupamento

Cada janela continua sendo uma entidade distinta, identificada internamente pelo contêiner informado pelo Sway. O agrupamento visual ocorre somente quando o Hydrogen consegue associar as janelas a uma mesma identidade de aplicativo com confiança suficiente.

A identificação deve usar os dados documentados pelo IPC do Sway e as entradas Freedesktop indexadas pelo Quickshell. A resolução segue esta ordem, interrompendo-se na primeira correspondência confiável:

1. regra manual configurada pelo usuário;
2. `sandbox_app_id`, quando informado pelo Sway, comparado a uma entrada desktop;
3. `app_id` de aplicações Wayland, comparado exatamente ao identificador de uma entrada desktop;
4. `StartupWMClass` da entrada desktop, comparado ao identificador fornecido pela janela;
5. `class` e depois `instance` de `WM_CLASS` para janelas XWayland;
6. identificador bruto estável da janela como fallback não resolvido.

- O identificador de uma entrada desktop é usado sem a extensão `.desktop` na configuração do Hydrogen.
- Janelas somente são agrupadas automaticamente quando a resolução for confiável. Em caso de dúvida, o Hydrogen cria itens separados em vez de unir aplicações diferentes.
- Uma heurística, incluindo `DesktopEntries.heuristicLookup()`, pode sugerir nome ou ícone em baixa confiança, mas não basta por si só para agrupar janelas.
- Título e PID nunca são chaves de agrupamento. O título muda conforme o documento ou conteúdo, enquanto aplicativos multiprocesso tornam o PID inadequado para representar sua identidade.
- Quando o Sway fornecer uma relação explícita entre um diálogo e sua janela, o diálogo integra o grupo da janela principal.
- Uma janela não identificada permanece visível com ícone genérico e título. Ela não pode ser ocultada por regra no MVP.
- Recarregar a configuração reavalia as identidades e os grupos. Remover uma correção faz as janelas afetadas retornarem à identificação automática.

Casos especiais seguem estas regras:

- `sandbox_app_id` é a identidade preferencial para aplicações Flatpak. Empacotamentos que exponham identificadores incorretos podem ser corrigidos manualmente.
- Cada jogo iniciado pela Steam aparece como aplicativo independente quando possuir identidade própria. As janelas da Steam permanecem no grupo da própria Steam.
- Uma aplicação web instalada aparece separadamente quando possuir `app_id` ou entrada desktop própria; sem identidade própria, ela integra o grupo do navegador.
- Programas portáteis, AppImages e aplicações locais sem entrada desktop podem receber nome e ícone por configuração.

### 5.3 Workspaces

O seletor de workspaces aparece entre o launcher e a área de aplicativos. Workspaces continuam sendo administrados pelo Sway; o Hydrogen apenas representa seu estado e aciona operações por meio do IPC.

- Cada barra representa os workspaces que estão efetivamente em seu monitor, ainda que a configuração normalmente associe cada workspace a uma saída específica.
- O estado real informado pelo Sway prevalece sobre a associação configurada. Se um workspace aparecer em outra saída, ele é mostrado na barra dessa saída.
- São exibidos o workspace atual, mesmo vazio, e os demais workspaces que contenham janelas. Workspaces vazios e inativos permanecem ocultos.
- Cada item exibe somente o número do workspace, e os itens são ordenados numericamente.
- O MVP pressupõe workspaces com identificação numérica determinável. Nomes adicionais podem ser ignorados visualmente, desde que o número possa ser obtido de forma segura.
- Clique esquerdo troca para o workspace selecionado.
- Clique do meio move a janela focada para o workspace selecionado sem acompanhar a janela. No workspace atual, essa ação não produz efeito.
- A roda do mouse percorre somente os workspaces visíveis naquela barra, seguindo a ordem numérica e continuando pelo extremo oposto após o primeiro ou o último item.
- O workspace atual recebe o destaque principal; workspaces ocupados e inativos usam o estado visual normal.
- Um workspace contendo uma janela urgente recebe uma cor de destaque no item inteiro. Quando ele também for o atual, o estilo preserva simultaneamente as indicações de seleção e urgência.
- Workspaces vazios e ocultos continuam acessíveis pelos atalhos configurados diretamente no Sway.

## 6. Componentes do MVP

### 6.1 Launcher

O launcher aparece como painel compacto e centralizado no monitor focado. Ele é otimizado para teclado, sem excluir interação por ponteiro, e oferece pesquisa normal e um modo explícito de comandos.

#### Pesquisa normal

- A pesquisa ignora diferenças entre maiúsculas e minúsculas e tolera diferenças de acentuação sem alterar o texto exibido.
- Aplicativos sempre aparecem antes dos arquivos.
- O limite global é de 20 resultados: aplicativos ocupam primeiro as posições disponíveis e arquivos usam o restante.
- A correspondência com o nome é o principal fator de ordenação; frequência e uso recente servem como desempate.
- Quando o campo está vazio, são mostrados aplicativos e arquivos mais usados. Comandos não aparecem fora do modo `>`.

#### Aplicativos

- Aplicativos são descobertos e iniciados por meio de entradas `.desktop` e das regras Freedesktop correspondentes.
- Entradas ocultas ou marcadas para não exibição são respeitadas conforme a especificação aplicável.
- Cada resultado mostra ícone e nome do aplicativo.
- A ativação inicia o aplicativo e fecha o launcher.
- Localização, ações e execução de entradas desktop não devem depender de um parser improvisado ou de heurísticas apresentadas como comportamento garantido.
- A descoberta, o nome, o ícone, o diretório de trabalho e o comando estruturado usam `DesktopEntries` do Quickshell.
- Como `DesktopEntry.execute()` do Quickshell 0.3.1 ignora `Terminal=true` e códigos de campo, o Hydrogen envolve entradas de terminal com o terminal configurado e não promete conformidade integral com todos os códigos de campo no MVP.
- Códigos que fornecem arquivos ou URLs podem ser omitidos porque o launcher inicia a aplicação sem fornecer esses argumentos. O conteúdo bruto de `Exec` nunca é entregue a um shell.
- Uma entrada que não possa ser iniciada com segurança permanece pesquisável, mas sua falha produz aviso acionável e registro no log.

#### Arquivos

- A pesquisa com `fd` começa a partir do terceiro caractere digitado.
- Uma alteração na consulta cancela a pesquisa anterior ou invalida seus resultados antes que eles alcancem a interface.
- Por padrão, são pesquisadas as pastas XDG existentes do usuário.
- Pastas XDG inexistentes são ignoradas, e arquivos ou diretórios ocultos não são incluídos.
- O arquivo selecionado é convertido em uma URL `file://` corretamente escapada e entregue por `Qt.openUrlExternally()` ao manipulador padrão do sistema. O launcher fecha após aceitar a solicitação.
- O Hydrogen não escolhe internamente o aplicativo associado ao arquivo nem concatena o caminho em uma linha de shell.

#### Histórico

- O histórico é compartilhado entre aplicativos, arquivos e comandos.
- São conservados no máximo 100 itens e somente registros dos últimos 30 dias. A limpeza automática aplica os dois limites.
- Frequência e uso recente são armazenados localmente e sem telemetria.
- Uma ação interna do modo `>` permite limpar todo o histórico.
- Comandos executados em modo privado não são armazenados nem alteram contadores de frequência.

#### Modo de comandos

| Prefixo | Comportamento |
|---|---|
| `>` | Executa sem terminal e registra no histórico |
| `>!` | Executa sem terminal e não registra |
| `>_` | Executa no terminal configurado e registra |
| `>!_` ou `>_!` | Executa no terminal configurado e não registra |

- O modo aceita um executável e seus argumentos sem invocar implicitamente um shell.
- Pipelines, redirecionamentos, substituições, globbing e outros operadores de shell não são interpretados.
- O processo usa a pasta pessoal do usuário como diretório de trabalho inicial.
- O terminal usado pelos modificadores `_` é definido na configuração.
- O launcher fecha assim que a criação do processo é aceita.
- Falhas imediatas, como executável inexistente, são registradas e produzem aviso quando houver ação possível.
- As sugestões combinam ações internas, comandos anteriores e executáveis disponíveis no `PATH`.
- Ao digitar somente `>`, aparecem ações internas e comandos mais usados.

As ações internas iniciais são: recarregar o Hydrogen, alternar o modo não perturbe, sair do Sway, reiniciar, desligar e limpar o histórico do launcher. As ações de sessão reutilizam as mesmas confirmações e a mesma camada de integração do menu de sessão.

### 6.2 Relógio e calendário

O relógio permanece na região direita do painel. Sua ativação abre um calendário simples, destinado à consulta de datas. Agenda, compromissos e integração com calendários externos não pertencem ao MVP.

### 6.3 Energia, bateria e sessão

Quando houver bateria, o painel exibirá um indicador e permitirá consultar informações detalhadas. O menu de sessão oferecerá:

- sair do Sway;
- reiniciar;
- desligar.

Reiniciar e desligar exigem confirmação.

Sair usa diretamente o comando `exit` do IPC do Sway e não depende de `swaymsg` quando a conexão interna puder enviá-lo. Para reiniciar e desligar, o Hydrogen seleciona uma integração disponível uma única vez durante a inicialização:

1. comandos personalizados configurados pelo usuário;
2. `systemctl poweroff` e `systemctl reboot` quando `systemctl` estiver disponível;
3. `loginctl poweroff` e `loginctl reboot` somente quando o próprio `loginctl` anunciar esses verbos, como ocorre no elogind.

Essa verificação é necessária porque o `loginctl` do elogind possui comandos de energia que não estão presentes em todas as versões fornecidas pelo systemd. A seleção não tenta novamente outro backend depois que uma ação falha.

```toml
[session]
# Empty arrays enable automatic backend selection.
poweroff_command = []
reboot_command = []
```

- Os comandos são vetores de executável e argumentos e nunca são interpretados por um shell.
- O usuário pode substituir os comandos em `components/integrations.toml` para adaptar o Hydrogen a outro init ou gerenciador de sessão.
- O Hydrogen não tenta `sudo`, `doas`, operações forçadas nem uma sequência automática de backends alternativos.
- Se nenhum backend compatível for detectado e não houver comando alternativo, reiniciar e desligar são ocultados; sair do Sway continua disponível.
- Falhas mantêm a sessão e o menu utilizáveis, produzem aviso quando houver ação possível e registram os detalhes no log.

O suporte geral é, portanto, Sway em qualquer distribuição que ofereça uma integração detectável ou comandos de energia configurados pelo usuário. Os componentes visuais dependem apenas da camada interna de sessão, e não diretamente de systemd ou de uma distribuição específica.

### 6.4 OSDs e controles contextuais

Os OSDs aparecem na lateral direita do monitor focado e representam alterações observadas pelos backends, independentemente de terem sido iniciadas pelo Hydrogen ou por outra ferramenta.

- Cada OSD expira 3 segundos após o último evento ou interação.
- Eventos repetidos do mesmo tipo atualizam o cartão existente, preservam sua posição na pilha e reiniciam o temporizador.
- Tipos diferentes formam uma pilha de até três cartões.
- O cartão mais recente entra na parte inferior, próximo à barra.
- Quando um quarto tipo aparece, o cartão mais antigo é removido imediatamente.
- Passagem do ponteiro, foco obtido por ação explícita ou manipulação de um controle pausa o temporizador. Ao terminar a interação, a contagem recomeça com 3 segundos completos.
- Um OSD surgido automaticamente nunca solicita foco nem interrompe a janela ativa.
- Um clique explícito pode conceder foco ao cartão para permitir interação.

#### Observação e emissão de eventos

Os provedores publicam alterações em um barramento interno normalizado. A interface do OSD consome esses eventos sem depender da origem da mudança.

- Cada provedor aguarda seu backend ficar pronto, registra uma fotografia inicial e somente então começa a emitir eventos. Iniciar ou recarregar o Hydrogen não exibe OSDs com o estado inicial.
- Uma ação do Hydrogen não cria antecipadamente um cartão. O provedor solicita a alteração e o observador publica apenas o valor efetivamente confirmado pelo backend.
- Eventos repetidos do mesmo tipo recebidos em até 100 ms podem ser consolidados antes da apresentação; depois disso, novas alterações atualizam o cartão já existente.
- Áudio e microfone são observados reativamente pela API PipeWire do Quickshell; mídia usa MPRIS; perfis de energia usam `PowerProfiles`.
- Desconexão e reconexão de backend não produzem eventos falsos: o primeiro valor após a reconexão apenas restabelece a referência inicial.
- Erros repetidos equivalentes são limitados nos logs.

Para brilho, `brightnessctl` é usado para descobrir o dispositivo e aplicar alterações. A observação lê `brightness` e `max_brightness` da interface estável em `/sys/class/backlight` a cada 500 ms, sem iniciar processos periódicos. Quando houver mais de um dispositivo, `brightness_device` em `components/integrations.toml` permite escolher explicitamente um deles.

O MVP suporta somente dispositivos expostos em `/sys/class/backlight`. Monitores controlados exclusivamente por DDC/CI não fazem parte do escopo, embora possam funcionar quando um driver os expuser como backlight do kernel.

| OSD | Conteúdo | Interação |
|---|---|---|
| Volume | Nível e estado de mudo | Ajustar nível e alternar mudo |
| Microfone | Nível e estado de mudo | Ajustar nível e alternar mudo |
| Brilho | Nível atual | Ajustar brilho |
| Mídia | Título e controles | Anterior, reproduzir/pausar e próxima |
| Energia | Perfil ativo | Selecionar perfil disponível |

#### Limites dos controles

- O volume é limitado entre 0% e 100% nas ações iniciadas pelo Hydrogen.
- Volume e microfone são alterados em passos de 5 pontos percentuais.
- O brilho é alterado em passos de 5 pontos percentuais e limitado entre 1% e 100%, evitando apagar totalmente a iluminação da tela.
- Alternar o mudo preserva o nível anterior para sua posterior restauração.
- Valores externos fora desses intervalos podem ser normalizados na apresentação, mas não são sobrescritos apenas por terem sido observados.

#### Mídia

- O OSD controla prioritariamente um player que esteja reproduzindo. Se houver mais de um, prevalece o usado mais recentemente.
- Ele aparece quando um player é iniciado, quando a reprodução é iniciada ou pausada e após uma ação de faixa anterior ou seguinte.
- Uma troca automática de faixa não faz o OSD aparecer por si só.
- O cartão exibe o título e somente os controles efetivamente oferecidos pelo player.
- Controles indisponíveis são ocultados, e não apresentados como ações inoperantes.

### 6.5 Bandeja e indicadores permanentes

O MVP inclui uma bandeja compatível com StatusNotifierItem. Ela deve preservar, conforme fornecido por cada aplicativo, o ícone, a ativação primária e secundária, a rolagem e os menus DBus. A bandeja completa aparece em todas as barras.

- Uma única instância lógica de `SystemTray` acompanha os itens e é compartilhada por todas as barras; não são criados watchers independentes por monitor.
- Itens ativos e urgentes têm prioridade na área visível.
- Quando não houver espaço, os itens excedentes são movidos para um menu expansível.
- A ausência de itens não deixa um espaço vazio reservado na barra.
- O suporte deve usar a API do Quickshell compatível com a versão adotada pelo projeto e ser verificado com aplicativos reais.
- Um item malformado não pode derrubar toda a bandeja. Se ela não puder ser observada por conflito ou falha, somente esse componente é ocultado e o problema é registrado.
- O MVP suporta StatusNotifierItem e DBusMenu, mas não a bandeja legada XEmbed.

Além da bandeja, a região direita mantém indicadores próprios de volume, rede e bateria quando os respectivos recursos estiverem disponíveis.

#### Volume

- O indicador representa o volume geral e o estado de mudo da saída padrão.
- A roda do mouse altera o volume em passos de 5 pontos percentuais.
- Sua ativação abre um painel simples com volume geral, mudo e seleção da saída padrão.
- Controle individual por aplicativo e mixer avançado não pertencem ao MVP.

#### Rede

- O indicador representa o estado da conexão atual.
- Sua ativação abre um painel simples de conexões.
- O painel permite ligar ou desligar o Wi-Fi, conectar e desconectar redes e informar a senha necessária para uma conexão Wi-Fi.
- Edição de IP, DNS, VPN, hotspot e perfis avançados não pertence ao MVP.
- Quando não houver backend de rede compatível, indicador e painel são ocultados silenciosamente.

#### Bateria

- O indicador aparece somente quando houver uma bateria compatível.
- Seu painel mostra, quando fornecidos pelo backend, carga, estado, tempo restante estimado e perfil de energia atual.
- Microfone, mídia e perfil de energia não possuem indicadores permanentes próprios no MVP; continuam disponíveis pelos OSDs e controles já definidos.

### 6.6 Múltiplos monitores

- Cada monitor recebe uma barra completa.
- Launcher e menus aparecem no monitor atualmente focado.
- OSDs aparecem somente no monitor focado.
- A desconexão de uma saída não pode interromper o shell.

### 6.7 Notificações

O Hydrogen atuará como servidor de notificações da sessão, implementando a especificação Desktop Notifications do Freedesktop por meio da API de notificações do Quickshell. Não haverá dependência de um daemon externo como Mako, Dunst ou SwayNotificationCenter, e a documentação de instalação deverá informar que outro servidor de notificações não pode disputar essa responsabilidade na mesma sessão.

O servidor anuncia suporte a corpo de texto, ações, imagem principal e persistência. Não anuncia markup, hyperlinks no corpo, imagens embutidas no texto, ícones de ações, resposta rápida nem extensões não implementadas. O corpo é sempre renderizado como texto simples, inclusive quando um cliente envia marcação sem que a capacidade tenha sido anunciada.

- `keepOnReload` permanece ativo. Notificações recuperadas da geração anterior restauram o acompanhamento, mas não reaparecem como pop-up nem são duplicadas no histórico persistente.
- Notificações marcadas como `transient` podem gerar pop-up, mas não entram no histórico.
- Se outro processo já possuir `org.freedesktop.Notifications`, somente o componente de notificações é desativado. O Hydrogen apresenta uma vez um aviso acionável sobre o conflito e mantém o restante do shell funcional.

#### Pop-ups

- Os pop-ups aparecem no canto inferior direito do monitor focado no momento do recebimento, imediatamente acima da barra.
- Notificações do mesmo aplicativo são agrupadas. O pop-up do grupo exibe a notificação mais recente e a quantidade de notificações contidas nele.
- Notificações de urgência baixa permanecem visíveis por 3 segundos.
- Notificações de urgência normal permanecem visíveis por 6 segundos.
- Notificações críticas permanecem visíveis até serem descartadas ou até que uma de suas ações seja executada.
- Foco por teclado, passagem do ponteiro ou outra interação com o pop-up pausa seu temporizador. A contagem é retomada quando a interação termina.
- Clicar no corpo executa a ação padrão fornecida pelo aplicativo, quando ela existir.
- As demais ações fornecidas pelo aplicativo são apresentadas como controles acessíveis por teclado e ponteiro.
- Cada notificação pode ser descartada individualmente.

#### Central e histórico

- Um indicador na região direita da barra exibe a quantidade de notificações não lidas.
- A ativação do indicador abre uma central de notificações em um painel ancorado acima dele.
- O histórico mantém no máximo 50 notificações e somente notificações recebidas nos últimos 7 dias. A limpeza automática aplica os dois limites.
- As notificações são agrupadas por aplicativo na central.
- Grupos com itens não lidos aparecem antes dos grupos totalmente lidos; dentro de cada categoria, prevalece a atividade mais recente.
- Uma notificação é marcada como lida quando seu item se torna visível na área exibida da central. Apenas abrir a central não marca automaticamente itens ainda não visualizados.
- A central permite descartar itens individuais e limpar todo o histórico.
- O histórico permanece local e não realiza sincronização ou telemetria.

#### Modo não perturbe

- A central permite ativar e desativar o modo não perturbe.
- Enquanto ele estiver ativo, nenhum pop-up será exibido, inclusive para notificações críticas.
- As notificações continuam sendo recebidas, armazenadas no histórico e contabilizadas como não lidas.
- O modo não perturbe controla somente a apresentação dos pop-ups e não descarta nem marca notificações como lidas.

### 6.8 Atalhos globais e IPC

O Sway permanece responsável pelo registro de atalhos globais. O Hydrogen expõe ações estáveis, com nomes em inglês, por meio do IPC oficial do Quickshell; não tenta registrar atalhos por protocolos específicos de outro compositor.

- `Super + Space` é a combinação recomendada para alternar entre launcher aberto e fechado.
- `Super + Escape` é a combinação recomendada para alternar entre menu de sessão aberto e fechado.
- `Escape`, quando uma superfície temporária do Hydrogen possui foco, fecha essa superfície.
- Central de notificações, modo não perturbe, rede e volume permanecem acessíveis pela barra e por ações IPC, mas não recebem combinações recomendadas no MVP.
- O exemplo do projeto não declara teclas multimídia, de brilho ou volume.
- O Hydrogen nunca modifica automaticamente a configuração existente do Sway.
- O projeto fornece um arquivo de configuração pronto para uso com `include` e reproduz o mesmo trecho, com explicações, no README.
- Launcher e menu de sessão são abertos no monitor focado, conforme as regras gerais de múltiplos monitores.

Os nomes, argumentos e efeitos das ações IPC fazem parte da interface técnica do projeto e devem ser documentados e cobertos por testes. Mudanças incompatíveis nesses nomes exigem tratamento explícito de compatibilidade.

## 7. Aparência e interação

- Barra contínua na parte inferior, ocupando toda a largura da saída.
- Superfícies translúcidas e atmosfera visual leve.
- Cores fixas no MVP; integração futura possível com Matugen.
- Animações curtas, discretas e associadas a mudanças de estado.
- Layout responsivo, sem resolução mínima fixa.
- Navegação completa por teclado nos componentes interativos.
- Interface e mensagens inicialmente somente em português.
- Arquivos, seções e chaves de configuração em inglês desde a primeira versão, para formar uma interface técnica estável e independente do idioma da interface gráfica.

## 8. Configuração e estado

O Hydrogen usa TOML com arquivos, seções e chaves em inglês. A intenção é permitir adaptação sem expor toda a estrutura interna do shell como uma API QML e sem exigir uma futura migração quando outros idiomas forem adicionados à interface.

O diretório padrão é `$XDG_CONFIG_HOME/hydrogen/`, com fallback para `~/.config/hydrogen/` quando `XDG_CONFIG_HOME` não estiver definido. Sua organização inicial é:

```text
hydrogen/
├── config.toml
├── config.example.toml
└── components/
    ├── appearance.toml
    ├── bar.toml
    ├── integrations.toml
    ├── launcher.toml
    ├── notifications.toml
    └── osd.toml
```

- `config.toml` contém opções globais.
- Cada componente possui seu próprio arquivo dentro de `components/`.
- Todos os arquivos `.toml` de `components/` são descobertos automaticamente.
- A primeira execução cria a estrutura completa com opções, nomes e comentários em inglês.
- A precedência é: padrões internos, arquivo principal e, por último, arquivo específico do componente.
- Arquivos de componentes usam namespaces próprios. Uma colisão incompatível com o esquema é um erro, não uma precedência implícita pela ordem dos arquivos.
- Opções desconhecidas produzem aviso e são ignoradas; as opções reconhecidas do mesmo arquivo continuam válidas.
- Um arquivo sintaticamente inválido não substitui a última versão válida daquele componente e não impede que outros componentes sejam recarregados.
- Remover um arquivo durante a execução faz somente aquele componente retornar aos padrões internos, combinados com opções globais aplicáveis.
- Atualizações podem gerar ou substituir `config.example.toml` com o esquema e os exemplos atuais, mas nunca alteram automaticamente os arquivos ativos do usuário.
- O arquivo de exemplo não participa da descoberta nem do carregamento da configuração.

Alterações válidas são recarregadas automaticamente. Quando houver ação possível, o usuário recebe um aviso objetivo; os detalhes e a origem do arquivo ficam registrados nos logs.

### 8.1 Correções de identidade de aplicativos

Regras manuais de identificação ficam em `components/bar.toml`, são avaliadas na ordem declarada e usam somente correspondência exata no MVP. A primeira regra correspondente vence.

```toml
[[app_matching.rules]]
app_id = "example-app"
wm_class = "ExampleApp"
desktop_entry = "org.example.Application"

[[app_matching.rules]]
app_id = "portable-program"
name = "Programa portátil"
icon = "application-x-executable"
```

Campos de correspondência aceitos inicialmente:

- `sandbox_app_id`;
- `app_id`;
- `wm_class`;
- `wm_instance`.

Campos de identidade aceitos:

- `desktop_entry`, contendo o identificador sem `.desktop`;
- `name`, como nome explícito ou fallback;
- `icon`, como nome de ícone compatível com o tema ou caminho admitido pela implementação.

Uma regra deve possuir ao menos um campo de correspondência. Quando houver vários campos na mesma regra, todos precisam corresponder; alternativas são expressas por regras separadas. Expressões regulares não pertencem ao MVP.

Uma regra pode apontar para uma entrada desktop ou fornecer `name` e `icon` para um programa sem entrada própria. Regras inválidas são ignoradas com aviso no log, sem invalidar as demais regras válidas do componente. Nenhuma regra pode ocultar uma janela.

## 9. Integrações e dependências

A versão mínima e normativa do Quickshell para o Hydrogen 0.1 é a **0.3.1**. Implementação e revisão devem consultar a documentação oficial versionada dessa release. `master`, `quickshell-git` e exemplos escritos para outras versões não são fontes normativas. Versões posteriores somente podem ser declaradas compatíveis após validação explícita.

Como o Quickshell pode depender da compatibilidade binária com a versão de Qt usada em sua compilação, a documentação de instalação e diagnóstico deve orientar a reconstrução ou reinstalação do pacote quando uma atualização de Qt produzir incompatibilidade.

| Capacidade | Integração prevista |
|---|---|
| Janelas, foco, saídas e workspaces | IPC do Sway |
| Interface | Quickshell e Qt/QML |
| Busca de arquivos | `fd` |
| Áudio e microfone | API PipeWire do Quickshell |
| Mídia | API MPRIS do Quickshell |
| Brilho | `brightnessctl` para descoberta e controle; sysfs para observação |
| Perfis de energia | API `PowerProfiles` do Quickshell e `power-profiles-daemon` |
| Aplicativos e abertura de arquivos | `DesktopEntries`, Qt e especificações Freedesktop/XDG |
| Notificações | API de notificações do Quickshell e especificação Desktop Notifications do Freedesktop |
| Bandeja | API StatusNotifierItem e DBusMenu do Quickshell |
| Rede | `Quickshell.Networking` com NetworkManager no MVP |
| Bateria | UPower e integração correspondente do Quickshell |
| Sessão | IPC do Sway para sair; `systemctl`, `loginctl` compatível ou comandos configurados para energia |
| Atalhos globais | `bindsym` do Sway acionando handlers IPC do Quickshell |

As únicas ferramentas externas obrigatórias do MVP são `fd` e `brightnessctl`. `wpctl`, `playerctl` e `powerprofilesctl` não são dependências nem fallbacks paralelos. PipeWire é requisito para áudio; UPower, `power-profiles-daemon` e NetworkManager são serviços opcionais para seus respectivos componentes.

Quando um recurso não estiver disponível no hardware ou no serviço ativo, seu controle será ocultado silenciosamente. A ausência de um recurso não utilizado não deve produzir uma interface repleta de estados de erro. Cada integração fica atrás de uma interface interna para permitir evolução sem acoplar os componentes visuais ao backend.

## 10. Limites e não objetivos do MVP

- Não configurar graficamente o Sway.
- Não oferecer área de trabalho com ícones.
- Não recriar o sistema de widgets e painéis do Plasma.
- Não fornecer um editor visual completo para a barra.
- Não implementar gerenciamento de wallpaper.
- Não administrar monitores, Bluetooth ou dispositivos em geral.
- Não controlar brilho de monitores exclusivamente por DDC/CI.
- Não oferecer configuração avançada de rede, incluindo IP, DNS, VPN, hotspot ou edição completa de perfis.
- Não substituir bloqueador de tela, login manager ou agente de autenticação.
- Não criar indexador próprio de arquivos.
- Não detectar nem exibir estados de Caps Lock, Num Lock ou Scroll Lock no MVP.
- Não gerar paleta dinâmica no MVP.
- Não oferecer plugins ou módulos arbitrários no MVP.
- Não oferecer suporte formal a outros compositores Wayland.
- Não oferecer bandeja legada XEmbed.

## 11. Requisitos de robustez

- Uma falha localizada não deve encerrar o shell inteiro.
- Processos externos devem ter execução, cancelamento e tempo limite controlados.
- Pesquisas de arquivos obsoletas devem ser canceladas enquanto o usuário digita.
- A configuração nova deve ser validada antes de substituir o estado ativo.
- Históricos permanecem locais, limitados e sem telemetria.
- Ações destrutivas de sessão exigem confirmação explícita.
- Recursos ausentes devem desaparecer sem deixar espaços vazios incoerentes.
- OSDs automáticos não devem capturar foco nem interromper a entrada dirigida a outro aplicativo.

## 12. Critérios de aceitação do Hydrogen 0.1

1. O Hydrogen inicia com uma configuração padrão utilizável em uma sessão Sway usando Quickshell 0.3.1.
2. Uma barra inferior completa é criada em cada saída ativa.
3. O botão do launcher abre o painel no monitor focado.
4. Aplicativos do workspace visível são agrupados na barra, podem ser focados ou selecionados pela lista de janelas e mantêm ordem estável.
5. A pesquisa normal encontra e inicia entradas desktop, prioriza aplicativos e limita a lista completa a 20 resultados.
6. A partir de três caracteres, arquivos não ocultos das pastas XDG são encontrados com `fd` e abertos pelo aplicativo XDG padrão.
7. O modo `>` sugere ações internas, histórico e executáveis do `PATH`, executando argumentos sem interpretar operadores de shell.
8. Relógio, calendário, sessão e bateria funcionam quando aplicáveis.
9. Os OSDs definidos respondem aos respectivos eventos e controles.
10. A configuração é recarregada sem reinício e erros preservam o último estado válido.
11. Todos os componentes interativos essenciais podem ser operados por teclado.
12. Notificações de teste aparecem no monitor focado, respeitam urgência, agrupamento, ações e pausa do temporizador.
13. A central mantém e ordena o histórico, marca somente itens visualizados como lidos e aplica os limites de 50 itens e 7 dias.
14. O modo não perturbe suprime todos os pop-ups sem impedir o armazenamento e a contagem das notificações.
15. O menu de overflow preserva acesso aos aplicativos excedentes e mantém o aplicativo ativo visível sempre que possível.
16. Cada barra mostra o workspace atual e os ocupados de sua saída real, em ordem numérica, e permite trocar de workspace com clique ou roda.
17. O clique do meio em um workspace move a janela focada sem mudar para o destino, e estados de urgência são distinguíveis do estado ativo.
18. A bandeja aparece em todas as barras, preserva as ações fornecidas pelos aplicativos e move itens excedentes para um menu expansível.
19. O indicador de volume ajusta o nível em passos de 5% e seu painel controla volume geral, mudo e saída padrão.
20. O painel de rede executa as ações básicas definidas quando houver backend compatível e desaparece completamente quando ele estiver ausente.
21. Na primeira execução, a estrutura TOML completa é criada com nomes e comentários em inglês.
22. A recarga isola erros por componente, ignora opções desconhecidas com aviso e restaura padrões quando um arquivo de componente é removido.
23. Os modificadores `!` e `_`, isolados ou combinados, controlam respectivamente a persistência no histórico e a execução no terminal configurado.
24. O histórico compartilhado aplica os limites de 100 itens e 30 dias, não registra comandos privados e pode ser limpo por uma ação interna.
25. Consultas de arquivos obsoletas nunca substituem os resultados da consulta atual, mesmo quando processos `fd` terminam fora de ordem.
26. Até três tipos de OSD formam uma pilha ordenada; o quarto remove o mais antigo, e eventos repetidos atualizam a instância existente.
27. O temporizador dos OSDs pausa durante interação e recomeça em 3 segundos sem que uma aparição automática capture foco.
28. Ações de volume, microfone e brilho respeitam os passos e limites definidos, sem sobrescrever automaticamente valores externos apenas por estarem fora desses limites.
29. O OSD de mídia seleciona corretamente o player em reprodução mais recente e oculta controles não oferecidos por ele.
30. Os exemplos para Sway alternam launcher com `Super + Space` e menu de sessão com `Super + Escape` usando ações IPC documentadas, sem modificar a configuração do usuário.
31. Duas janelas com a mesma identidade resolvida de modo confiável formam um único grupo, enquanto uma correspondência apenas heurística não provoca agrupamento.
32. Títulos iguais ou PIDs relacionados não bastam para agrupar janelas; uma janela não identificada continua acessível com ícone genérico e título.
33. Regras exatas em `components/bar.toml` corrigem identidades, respeitam a ordem declarada e são reaplicadas após a recarga automática.
34. Flatpaks, jogos da Steam, aplicações web, aplicativos Wayland e janelas XWayland são exercitados nos testes de identificação, incluindo casos sem entrada desktop válida.
35. Alterações externas de volume, mudo, microfone e perfil de energia geram um único OSD com o valor confirmado, mas a sincronização inicial e a reconexão dos backends não geram cartões falsos.
36. O brilho é observado sem processos periódicos, respeita o dispositivo configurado e desaparece quando nenhum backlight compatível estiver disponível.
37. Sair usa o IPC do Sway; reiniciar e desligar usam comandos estruturados configuráveis, permanecem ocultos quando indisponíveis e nunca tentam elevação ou operações forçadas automaticamente.
38. Um servidor de notificações concorrente desativa somente as notificações do Hydrogen e produz uma única orientação acionável; recarregar o shell não duplica pop-ups nem o histórico.
39. O corpo de notificações é tratado como texto simples e somente capacidades realmente implementadas são anunciadas aos clientes.
40. Todas as barras compartilham a mesma coleção lógica da bandeja, e um item inválido não interrompe os demais.
41. Arquivos são entregues ao manipulador padrão como URLs escapadas, e comandos de entradas desktop nunca são executados como texto bruto por um shell.

## 13. Marcos de desenvolvimento

| Marco | Resultado esperado |
|---|---|
| 1. Fundação | Estrutura do Quickshell, configuração, logs, ciclo de vida e conexão com o IPC do Sway |
| 2. Painel básico | Barra inferior por saída, launcher, relógio e estrutura responsiva |
| 3. Navegação de janelas | Descoberta e agrupamento das janelas, foco, lista de seleção, overflow e seletor de workspaces |
| 4. Launcher de aplicativos | Entradas desktop, pesquisa normal, ranking, teclado e itens mais usados |
| 5. Launcher completo | `fd`, cancelamento de consultas, abertura XDG, modo `>`, modificadores, ações internas e histórico |
| 6. Painéis contextuais | Calendário, bateria, sessão, volume, rede e confirmações |
| 7. Bandeja e indicadores | StatusNotifierItem, DBusMenu, overflow e indicadores permanentes |
| 8. Infraestrutura de OSD | Pilha, posicionamento, foco, temporizador, atualização e interação compartilhada |
| 9. Provedores de OSD | Áudio, microfone, brilho, mídia e perfis de energia |
| 10. Notificações | Servidor Freedesktop, pop-ups, ações, agrupamento, central, histórico e modo não perturbe |
| 11. IPC e atalhos | Ações públicas, arquivo para `include`, exemplos e documentação do contrato IPC |
| 12. Polimento | Animações, multimonitor, teclado, tolerância a falhas, empacotamento e documentação |

Cada componente deve ser concluído e testável antes do início do seguinte, exceto quando uma dependência ou interseção técnica exigir desenvolvimento conjunto.

## 14. Decisões ainda abertas

Nenhuma decisão funcional conhecida permanece aberta para o escopo atual. Novas decisões não devem ser fechadas por conveniência durante a implementação. Questões de viabilidade e escolha de backend devem ser tratadas como pesquisa técnica, sem reintroduzir recursos declarados como não objetivos.

> **Definição e regra de escopo:** o Hydrogen é a camada visual cotidiana entre o Sway e o usuário de desktop tradicional: painel inferior, acesso a aplicativos, representação das janelas abertas, indicadores essenciais, launcher e controles contextuais. Uma nova função só deve entrar quando fizer parte dessa interação cotidiana; ser tecnicamente possível ou visualmente interessante não é justificativa suficiente.

## 15. Orientação para implementação assistida por IA

Ao usar este documento como contexto para uma IA implementadora:

- trate os requisitos e não objetivos como limites do trabalho;
- não transforme decisões abertas em requisitos sem confirmação;
- implemente apenas um marco por vez;
- só avance quando o marco atual estiver funcional e testável;
- desenvolva componentes em conjunto apenas quando houver dependência ou interseção técnica real;
- não crie telas, provedores ou módulos fictícios para funções futuras;
- mantenha integrações e lógica de sistema separadas dos componentes visuais QML;
- preserve a possibilidade de substituir comandos e backends sem redesenhar a interface;
- prefira mudanças pequenas, verificáveis e fáceis de revisar;
- registre qualquer hipótese necessária antes de implementá-la.
