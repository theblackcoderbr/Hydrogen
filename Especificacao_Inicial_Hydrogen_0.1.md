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

- O MVP usa somente NetworkManager por meio de `Quickshell.Networking`. A detecção consulta o backend da API e não procura `nmcli`; o Hydrogen não inicia, reinicia nem configura o serviço.
- Quando não houver backend compatível, indicador e painel são ocultados silenciosamente.
- O indicador representa, em ordem de prioridade visual: conexão cabeada ativa, Wi-Fi conectado, Wi-Fi disponível porém desconectado e ausência de conexão. Conectividade limitada, portal cativo, Wi-Fi desativado e bloqueio físico recebem estados próprios quando informados pelo backend.
- A prioridade visual não afirma qual interface contém a rota padrão. Se Ethernet e Wi-Fi estiverem conectados, o indicador mostra Ethernet e o painel apresenta ambas.
- Todos os adaptadores cabeados e Wi-Fi são mostrados. Nomes técnicos ficam ocultos quando houver somente um dispositivo de cada tipo; com vários adaptadores equivalentes, as redes são agrupadas por dispositivo.
- A varredura Wi-Fi permanece ativa somente enquanto o painel estiver aberto. Mudanças na lista preservam seleção e foco quando possível; abrir o painel já inicia a atualização, sem botão separado.
- Redes aparecem na ordem: conectada, conhecidas, desconhecidas; dentro de cada grupo, sinal decrescente e nome como desempate.
- Cada item Wi-Fi mostra SSID, sinal, estado, segurança e indicação de perfil conhecido. SSIDs vazios ou redes ocultas não podem ser configurados no MVP.
- O fluxo tenta `connect()` primeiro. Somente uma falha `NoSecrets` em WPA/WPA2-Personal ou SAE abre o pedido de senha e usa `connectWithPsk()`.
- A senha existe somente em memória durante a tentativa, nunca entra em logs ou arquivos e é limpa após falha. O NetworkManager decide se a credencial será armazenada.
- Redes abertas conectam sem senha. Perfis já configurados externamente podem ser usados quando a API permitir; novas redes empresariais, WEP, OWE ou incomuns exigem configuração externa.
- O painel permite ativar ou desativar Wi-Fi, conectar e desconectar redes. Não permite esquecer perfis, alterar `autoconnect`, editar IP, DNS, VPN, hotspot ou configurações avançadas.
- Bloqueio físico é exibido como estado indisponível e não pode ser contornado. Ethernet pode ser desconectada quando o backend oferecer a ação, sem desativação permanente do dispositivo.
- Portal cativo ou acesso limitado podem ser informados, mas o Hydrogen não incorpora navegador nem adivinha URL de autenticação. Reabrir o painel após autenticação solicita nova verificação quando suportada.
- Uma tentativa em andamento bloqueia somente seu item. Erros são apresentados resumidamente em português, detalhes ficam no log, e remover um dispositivo ou rede cancela somente a interação correspondente.
- Alterações externas feitas pelo NetworkManager ou outra ferramenta atualizam o painel reativamente.

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

#### Contrato IPC público v1

O transporte usa `IpcHandler` do Quickshell e o target versionado `hydrogen.v1`, chamado por `qs ipc call hydrogen.v1 <função> [argumentos...]`. O número identifica a versão do contrato, não a versão do aplicativo. Adições compatíveis permanecem no v1; remover, renomear ou alterar o significado de uma chamada exige novo target e, quando viável, convivência temporária com a versão anterior. Nomes de objetos QML, singletons e componentes internos nunca integram a API.

| Grupo | Formas aceitas |
|---|---|
| Painéis | `panel show|hide|toggle launcher|notifications|network|session` |
| Não perturbe | `dnd get|toggle` e `dnd set true|false` |
| Áudio | `audio volume set|change <percentual>` e `audio mute toggle` |
| Microfone | `microphone mute toggle` |
| Brilho | `brightness get`, `brightness set <percentual>` e `brightness change <pontos>` |
| Mídia | `media play-pause|play|pause|next|previous` |
| Perfil de energia | `power-profile get|cycle` e `power-profile set power-saver|balanced|performance` |
| Sessão | `session show` e `session request logout|reboot|poweroff` |
| Notificações | `notifications show|clear|mark-all-read` |
| Configuração | `reload config` |
| Diagnóstico | `version`, `status` e `capabilities` |

Painéis abrem na saída focada; `hide` também os encontra em outra saída. Abrir um painel fecha outro mutuamente exclusivo naquela saída. Ações de áudio usam o dispositivo padrão do PipeWire, brilho usa o dispositivo selecionado pela configuração e percentuais são inteiros limitados ao intervalo válido. Não há seleção pública de dispositivos no v1. Operações só são confirmadas depois de o backend publicar o valor efetivo, que também alimenta o OSD.

Mídia seleciona primeiro o player em reprodução, depois o usado mais recentemente e, por fim, o primeiro em ordem estável, sempre respeitando capacidades MPRIS. `power-profile cycle` percorre `power-saver`, `balanced` e `performance`, pulando perfis indisponíveis. Chamadas `session request` apenas abrem a confirmação visual; nenhuma variante pública pode contorná-la. Limpar notificações também pede confirmação quando houver itens, e `mark-all-read` não remove o histórico. O IPC não injeta notificações nem executa ações antigas por identificador.

`reload config` valida uma nova fotografia antes de ativá-la, preserva a última configuração válida e não recarrega a instância QML. `version` informa versões do Hydrogen, IPC e Quickshell; `status` resume saúde, saída focada, painel aberto, Não Perturbe, backends e erros acionáveis; `capabilities` enumera apenas recursos disponíveis. Consultas nunca retornam senhas, históricos, comandos, caminhos usados, corpos de notificações, MACs ou dados desnecessários de processos.

Toda resposta é uma string JSON compacta com `ok`, `code`, `message` e `data`. Clientes dependem de `code`, nunca da mensagem traduzível. O v1 reconhece `success`, `invalid_arguments`, `unknown_command`, `feature_unavailable`, `operation_unsupported`, `backend_not_ready`, `backend_failure`, `confirmation_required`, `configuration_invalid`, `busy` e `internal_error`. Operações incompatíveis sobre o mesmo recurso são serializadas; chamadas rápidas de volume e brilho podem ser consolidadas; durante o encerramento novas mutações são recusadas.

O IPC é local à sessão, registrado apenas depois que o núcleo estiver pronto e encaminha todas as ações aos mesmos controladores usados pela interface. Argumentos usam tipos, limites e listas fechadas; nenhum deles passa por shell. Não existem métodos genéricos `exec`, `run`, `eval` ou acesso a objetos QML, edição de TOML, escuta de rede, ações forçadas ou comandos arbitrários. Os nomes, argumentos, respostas e efeitos fazem parte da interface técnica e devem ser documentados e cobertos por testes.

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

### 8.2 Estado e históricos persistentes

Históricos usam JSON e ficam em `$XDG_STATE_HOME/hydrogen/`, com fallback para `~/.local/state/hydrogen/`:

```text
hydrogen/
├── launcher-history.json
├── notification-history.json
└── state.json
```

O diretório usa permissão `0700` e os arquivos `0600`. O caminho é estável, não depende do identificador interno do shell e nunca é substituído por `/tmp` em caso de falha.

Cada arquivo contém `schema_version`, `updated_at` em ISO 8601 UTC e seus dados. Campos desconhecidos são ignorados, versões antigas exigem migração explícita e uma versão futura desconhecida suspende a persistência daquele arquivo sem sobrescrevê-lo.

#### Histórico do launcher

- Aplicativos armazenam `desktop_entry`, `use_count` e `last_used_at`.
- Arquivos armazenam caminho absoluto normalizado, contador e data; links simbólicos não precisam ser resolvidos.
- Comandos armazenam a linha sem o prefixo `>`, a indicação de terminal, contador e data.
- Repetir um item atualiza seu registro. Comandos privados não criam nem alteram registros.
- O limite compartilhado continua sendo 100 itens ou 30 dias. Entradas desktop removidas e arquivos inexistentes deixam de aparecer e são eliminados na limpeza seguinte.
- Limpar o histórico remove todos os registros e solicita gravação imediata.

#### Histórico de notificações

São persistidos identificador interno, aplicativo, `desktop_entry`, resumo, corpo em texto simples, nome do ícone, urgência, data, estado de leitura, agrupamento e indicação de restauração. Não são persistidos objetos DBus, ações executáveis, resposta rápida, imagens binárias ou temporárias, hints desconhecidos nem credenciais.

- Uma notificação restaurada mantém conteúdo e estado de leitura, pode ser descartada, não reaparece como pop-up e não oferece ações antigas.
- Durante a vida do processo, inclusive em recarga QML, ações continuam disponíveis enquanto o objeto acompanhado pelo Quickshell for válido.
- Ícones por nome e caminhos persistentes ainda existentes podem ser restaurados; o Hydrogen não cria cache próprio de anexos no MVP.
- Os limites continuam sendo 50 notificações ou 7 dias.

#### Estado geral e gravação

`state.json` armazena inicialmente o modo não perturbe. Painéis abertos, foco e posição de rolagem não sobrevivem ao encerramento completo.

- `FileView.atomicWrites` permanece ativo e as gravações são assíncronas.
- Alterações próximas são consolidadas por 250 ms; limpeza manual grava imediatamente.
- Antes de sair, reiniciar ou desligar, o Hydrogen aguarda uma gravação pendente por até 2 segundos.
- Apenas o singleton de estado escreve os arquivos, que não são configuração editável nem observados durante a execução.
- Limpeza ocorre ao carregar, modificar, antes de gravar e ao reabrir a superfície após longo período: remove expirados e referências inválidas verificáveis, ordena e aplica o limite.
- JSON inválido é renomeado para `nome.corrupt-<timestamp>.json`; um arquivo vazio é criado atomicamente, o usuário recebe um aviso acionável e no máximo três cópias corrompidas são mantidas.
- Falha de escrita preserva o estado em memória, limita mensagens repetidas no log e avisa somente quando houver ação possível, como corrigir permissões ou liberar espaço.

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

## 10. Arquitetura interna

O Hydrogen permanece uma aplicação QML/Quickshell no MVP, sem daemon próprio, biblioteca C++ ou sistema genérico de plugins. A separação é lógica e modular: apresentação envia intenções a controladores; controladores usam interfaces internas; adaptadores conversam com Quickshell, Sway e o sistema; stores recebem somente estados normalizados e confirmados; a apresentação reage a esses stores. Componentes visuais nunca usam diretamente `Process`, sysfs, Sway IPC ou APIs externas.

### 10.1 Camadas e responsabilidades

- **Composição e ciclo de vida:** `shell.qml` instancia configuração, persistência, adaptadores, stores, controladores, superfícies e IPC na ordem correta, sem acumular regras de domínio.
- **Domínio:** modelos e stores representam janelas, aplicativos, workspaces, launcher, notificações, áudio, mídia, brilho, rede, energia, configuração, capacidades e overlays sem criar superfícies nem executar comandos.
- **Controladores:** recebem ações da interface e do IPC e coordenam stores e providers. Cada recurso possui controlador próprio; interface e IPC percorrem exatamente o mesmo caminho.
- **Interfaces internas:** contratos documentados de propriedades, estados, sinais, métodos e tipos para gerenciador de janelas, áudio, mídia, brilho, rede, energia, bateria, notificações, sessão, entradas desktop e busca de arquivos.
- **Adaptadores:** implementam os contratos com Sway IPC, PipeWire, MPRIS, UPower, PowerProfiles, Networking, SystemTray, NotificationServer, DesktopEntries, sysfs, `brightnessctl`, `fd` e comandos estruturados de sessão. Somente eles conhecem objetos externos, acessam sysfs, analisam respostas ou usam `Process`.
- **Apresentação:** barra, launcher, central, OSDs, painéis, menus e diálogos recebem modelos normalizados e desconhecem a tecnologia do backend.

`AppContext` reúne referências, não regras, e cada componente recebe apenas os stores e controladores necessários. Os serviços são instâncias únicas em sentido lógico, mas não precisam ser singletons QML globais. Dependências são fornecidas explicitamente para permitir providers e contextos falsos em testes; componentes não procuram objetos por `objectName` ou pela árvore QML.

### 10.2 Organização inicial do código

```text
hydrogen/
├── shell.qml
├── core/          # composição, ciclo de vida, capacidades, overlays e erros
├── domain/        # models, stores, controllers e eventos
├── providers/     # adaptadores agrupados por integração
├── features/      # bar, launcher, notifications, osd, network e session
├── ui/            # controles, ícones, menus e diálogos compartilhados
├── config/        # leitura, validação, padrões e esquemas
├── persistence/   # repositories dos arquivos de estado
├── ipc/           # PublicIpcV1, respostas e códigos
├── diagnostics/   # logger, limitação e fotografia diagnóstica
└── tests/         # unitários, integração, componentes, mocks e fixtures
```

Uma feature não importa partes internas de outra. Lógica compartilhada sobe para `domain/`; elementos visuais compartilhados, para `ui/`. JavaScript é reservado a funções puras de transformação, ordenação, normalização, formatação e validação, nunca a serviços globais mutáveis.

### 10.3 Estado, eventos e múltiplos monitores

Cada domínio possui uma única fonte autoritativa: stores próprios para gerenciador de janelas, identidades de aplicativos, overlays, áudio, mídia, brilho, rede, energia, notificações, launcher e configuração, além do registro de capacidades. Views mantêm apenas estado efêmero, como foco, consulta, rolagem e animação; não copiam volume, rede, janelas, notificações ou configuração.

Há uma única conexão lógica com cada backend e um único conjunto de stores para todas as saídas. Cada monitor recebe uma instância visual da barra que filtra o modelo global pela saída. O `OverlayCoordinator` mantém uma superfície principal ativa, fixa-a à saída focada no momento da abertura e a recria quando solicitada em outra saída; mudar o foco não teletransporta uma superfície aberta. OSDs e pop-ups usam a saída focada no momento do evento.

Um barramento interno é permitido somente para eventos transitórios normalizados — OSD, aviso acionável, mudança de disponibilidade, recarga e encerramento. Estado consultável permanece em stores, e decisões de domínio não dependem de mensagens informais.

### 10.4 Configuração, persistência e IPC

Somente o repository de configuração lê arquivos. Parsing, validação e combinação com padrões antecedem uma fotografia efetiva imutável; cada componente recebe apenas seu namespace validado, e falhas preservam a fotografia anterior. Stores decidem o conteúdo persistível e repositories cuidam do envelope, esquema e gravação atômica; nenhuma feature escreve diretamente no diretório XDG. O gerenciador de ciclo de vida solicita o flush final.

`PublicIpcV1` é apenas um adaptador de entrada: valida argumentos, chama controladores e serializa respostas. Não acessa providers ou elementos visuais diretamente e não duplica lógica de domínio.

### 10.5 Disponibilidade e isolamento de falhas

Providers publicam `initializing`, `ready`, `unavailable`, `degraded` ou `failed`. Ausência esperada de hardware ou serviço torna apenas o recurso indisponível; erro inesperado entra no registro de erros, com repetição limitada nos logs. Reconexões estabelecem uma fotografia inicial antes de emitir eventos e providers não reiniciam serviços externos automaticamente.

Somente falha do núcleo QML, ausência de sessão Sway utilizável, impossibilidade de criar qualquer superfície ou padrões internos inválidos impedem a inicialização. Falhas em mídia, rede, bateria, brilho, bandeja ou notificações permanecem locais. Uma falha visual em uma saída não deve encerrar as demais barras.

### 10.6 Desenvolvimento por componente

Cada componente segue: contrato e modelo, provider falso, store, controlador, interface, provider real, testes de integração e documentação. Ele só está apto a liberar o próximo quando funciona com provider falso e backend real aplicável, cobre estados vazio, carregando, indisponível e erro, opera por teclado, respeita fronteiras, possui testes principais e não deixa erros recorrentes no log. Desenvolvimento conjunto ocorre apenas diante de dependência ou interseção técnica inseparável.

## 11. Logs e diagnóstico

O Hydrogen usa o mecanismo normal de logging do Qt/Quickshell, consultável por `qs log`, e não mantém um arquivo `hydrogen.log`, escreve em `/var/log` ou depende de journald. Não há telemetria, crash reporter ou envio automático. Três canais permanecem distintos: log técnico; `ErrorRegistry` em memória, que alimenta diagnóstico e estado; e avisos visuais, mostrados somente quando o usuário tentou usar o recurso, existe impacto relevante ou há ação possível.

### 11.1 Níveis, categorias e eventos

Os níveis são `debug`, `info`, `warning`, `error` e `fatal`. `debug` é opt-in; `info` registra marcos do ciclo de vida, não cada ação cotidiana; ausência esperada de recurso opcional não é warning; `fatal` limita-se ao núcleo QML, padrões internos, sessão Sway ou superfícies essenciais. Providers opcionais nunca elevam sua própria falha a fatal.

Categorias estáveis usam o prefixo `hydrogen.`: `lifecycle`, `config`, `persistence`, `ipc`, `sway`, `desktop`, `bar`, `launcher`, `notifications`, `tray`, `osd`, `audio`, `media`, `brightness`, `network`, `power`, `session` e `ui`. Cada evento tem uma categoria, código estável em inglês e `snake_case`, mensagem breve, operação e estado quando aplicáveis, campos técnicos permitidos e identificador de correlação local para ações assíncronas. Timestamps e instância ficam a cargo do Quickshell. Componentes visuais não duplicam erros do provider.

São registrados: fases de inicialização e encerramento, versões, configuração aceita ou rejeitada, backend selecionado, mudanças de disponibilidade, falhas, timeouts, processos externos malsucedidos, corrupção ou incompatibilidade de estado, conflitos D-Bus, reconexões e superfícies inesperadamente perdidas. Mudanças normais de volume, brilho, sinal, foco ou workspace não geram log por valor.

Nunca são registrados senhas, conteúdo ou ações de notificações, consultas, comandos ou histórico do launcher, títulos de janelas, SSIDs por padrão, MACs, caminhos pessoais completos, valores sensíveis de TOML, ambiente completo, saída bruta, argumentos arbitrários ou credenciais. Caminhos indispensáveis sob a home viram `$HOME/...`; erros de configuração mostram arquivo e chave, não o valor; processos registram operação lógica, executável esperado, duração e código de saída. `stderr` só pode aparecer sanitizado e truncado em debug; conteúdo sensível continua proibido nesse nível.

### 11.2 Deduplicação, erros e avisos

A impressão digital combina categoria, código, recurso e operação. A primeira ocorrência é emitida; repetições ficam suprimidas por 30 segundos; persistência produz resumo, no máximo, a cada cinco minutos; recuperação gera uma mensagem e reinicia o ciclo. O `ErrorRegistry` mantém até 50 registros com código, categoria, gravidade, datas, contagem, componente, ação, mensagem, recuperação e descarte. Ele não é persistido. Um aviso dispensado não retorna enquanto a mesma condição durar, mas pode voltar depois de recuperação e nova falha.

Ausência de bateria, player, backlight, NetworkManager ou bandeja é silenciosa. Conflito do servidor de notificações, configuração inválida, corrupção, falha de gravação, erro de conexão solicitado, comando de sessão ausente ou entrada desktop inexequível podem produzir aviso curto em português, ação segura de uma lista interna, descarte e detalhe técnico resumido. Erros externos nunca fornecem comandos arbitrários à interface.

### 11.3 Diagnóstico público

O IPC v1 recebe a adição compatível `diagnostics`. Ela retorna versões, uptime, ciclo de vida, quantidade e características básicas das saídas, validade da configuração, estados de providers, capacidades, saúde da persistência, contagens sem conteúdo, erros recentes sanitizados e total de repetições suprimidas. Não executa `uname`, `lspci`, `inxi`, `journalctl` ou consultas novas; usa o último estado confirmado.

`status` permanece pequeno e próprio para scripts; `diagnostics` é detalhado para suporte. Nenhum inclui históricos, arquivos pessoais, janelas ou aplicativos abertos, notificações, SSIDs, comandos, segredos ou ambiente do processo. O usuário pode redirecionar a resposta para arquivo. O modo debug acrescenta transições, duração, seleção de backend, validação e reconexões, sem alterar comportamento, segurança, timeouts ou privacidade. Falhas nativas de Qt/Quickshell podem impedir o registro final e ficam a cargo dos mecanismos externos existentes.

## 12. Estratégia de testes

A suíte combina análise estática, testes unitários, componentes, integração e uma camada menor de sistema. A maior parte roda sem Sway; somente fluxos dependentes de Wayland, Sway IPC e superfícies reais usam sessão completa.

### 12.1 Ferramentas e níveis

- `qmllint`, configurado por `.qmllint.ini`, trata imports e tipos não resolvidos, propriedades obrigatórias, ciclos, acesso não qualificado, incompatibilidades, APIs obsoletas e exceções injustificadas como erro; `qmlformat` verifica formato.
- Qt Quick Test e `qmltestrunner -platform offscreen` exercitam funções puras, stores, controladores, ordenação, agrupamento, ranking, validação, persistência, respostas IPC, seleção de players e deduplicação.
- Testes de componentes instanciam views com providers falsos e cobrem estado, foco, teclado, mouse, menus, overflow, confirmações, atualização, ausência e falha.
- Integração combina stores, controladores e adaptadores para configuração, OSD, histórico, IPC, rede, persistência e encerramento.
- Sistema inicia Hydrogen real em Sway headless com duas saídas virtuais e exercita Sway IPC, superfícies, foco, multimonitor, IPC do Quickshell, recarga, reinício e conflitos D-Bus.

O produto não depende de `swaymsg`, mas testes podem usá-lo como observador e instrumento externo. A árvore `tests/` separa `unit`, `components`, `integration`, `system`, `mocks`, `fixtures` e `helpers`; arquivos executáveis seguem `tst_*.qml`.

### 12.2 Fakes, fixtures e assincronia

Cada interface interna possui fake controlável capaz de definir estado inicial, emitir mudanças, confirmar, falhar, atrasar, desconectar, recuperar e contar chamadas. Fakes implementam o contrato, não copiam a lógica real. Uma abstração de relógio permite avançar consolidação, gravação, polling, expiração, timeout e limitação de logs sem sleeps fixos. Testes assíncronos usam sinais ou espera por condição com timeout curto e verificam estados antes e depois da confirmação.

Fixtures versionadas e sem dados pessoais cobrem árvores Sway, múltiplas saídas, Wayland/XWayland, diálogos, urgência, identificadores ambíguos, `.desktop`, Flatpak, Steam, web apps, AppImage, TOML válido e inválido, JSON corrompido ou futuro, notificações, MPRIS, PipeWire, redes, UPower, perfis e backlights. Testes nunca usam configuração ou home reais: recebem diretórios XDG e barramento D-Bus temporários e teardown garantido.

### 12.3 Casos obrigatórios

Multimonitor verifica uma barra por saída, backend único, filtragem correta, migração de workspace, painel na saída focada sem teletransporte, reabertura em outra saída, OSD e pop-up no monitor do evento, hotplug e ausência de duplicação. Todos os comandos, argumentos, códigos, falhas, indisponibilidades e respostas sanitizadas de `hydrogen.v1` usam testes orientados a dados e também são chamados no target real; confirmações não podem ser contornadas e nenhum argumento chega a shell.

Integrações automatizáveis incluem Sway, DesktopEntries, `fd`, IPC, persistência temporária, D-Bus isolado e comandos inofensivos de sessão. PipeWire, UPower, power-profiles-daemon, NetworkManager, brilho real e energia usam fakes no CI principal e entram na verificação manual de release, junto de Flatpak, XWayland, Steam e bandejas reais. Resultado manual distingue aprovado, falhou e não disponível.

Toda correção de bug ganha regressão quando possível. Permanecem obrigatórios casos para agrupamento sem título/PID, primeira regra exata, recarga sem duplicação, inicialização e reconexão sem OSD falso, ações próprias sem OSD duplicado, notificações restauradas sem ação, esquema futuro preservado, histórico privado ausente, senha fora dos logs, hotplug sem queda, provider opcional isolado, sessão sempre confirmada, execução sem shell, deduplicação e configuração inválida preservando o estado anterior.

### 12.4 Ambientes, cobertura e CI

O repositório fornece comandos únicos para análise, unitários, componentes, sistema e suíte completa; declara versões e oferece ambiente reproduzível, configuração mínima do Sway e receita de VM Arch Linux com Sway, Quickshell 0.3.1, dependências, usuário sem privilégios e aplicativos representativos. A receita é a fonte de verdade; imagens prontas podem acompanhar marcos ou releases, sem credenciais e usando snapshots descartáveis.

Screenshots são complementares e limitados a estados estáveis, com fonte, tema, escala e renderer fixos, tolerância documentada, diff como artefato e atualização humana. Não substituem testes de comportamento ou acessibilidade.

Não há porcentagem global artificial. A matriz requisito-teste exige cobertura integral dos comandos e códigos IPC, regras de segurança, migrações e critérios automatizáveis, além de cada estado de provider e ao menos uma falha e recuperação por integração. Código novo sem teste exige justificativa.

Cada contribuição executa lint, unitários, componentes, integração sem hardware e validação de fixtures. Sistema headless é obrigatório antes de merge, possui timeout, duas saídas e conserva logs, diagnóstico e imagens somente em falha. Hardware real é obrigatório na preparação de release. Teste instável é defeito; retry pode coletar dados, não converter falha em sucesso. Skip requer capacidade realmente ausente e motivo explícito; testes são independentes e restauram o estado.

## 13. Limites e não objetivos do MVP

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

## 14. Requisitos de robustez

- Uma falha localizada não deve encerrar o shell inteiro.
- Processos externos devem ter execução, cancelamento e tempo limite controlados.
- Pesquisas de arquivos obsoletas devem ser canceladas enquanto o usuário digita.
- A configuração nova deve ser validada antes de substituir o estado ativo.
- Históricos permanecem locais, limitados e sem telemetria.
- Ações destrutivas de sessão exigem confirmação explícita.
- Recursos ausentes devem desaparecer sem deixar espaços vazios incoerentes.
- OSDs automáticos não devem capturar foco nem interromper a entrada dirigida a outro aplicativo.

## 15. Critérios de aceitação do Hydrogen 0.1

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
42. Com NetworkManager disponível, o painel representa todos os dispositivos, atualiza redes durante sua abertura e preserva a interação quando a lista mudar.
43. Redes conhecidas conectam sem solicitar novamente credenciais válidas; redes pessoais desconhecidas pedem senha somente após `NoSecrets`, sem persistir ou registrar seu conteúdo.
44. NetworkManager ausente oculta toda a integração, bloqueio físico permanece incontornável e uma falha de conexão afeta somente o item envolvido.
45. Os três arquivos de estado usam esquema versionado, permissões restritas e gravações atômicas, sem bloquear a interface durante operações normais.
46. Histórico do launcher e de notificações sobrevivem ao reinício, aplicam simultaneamente seus limites de idade e quantidade e não recriam entradas privadas ou inválidas.
47. Notificações restauradas não reaparecem como pop-up nem oferecem ações DBus obsoletas; o modo não perturbe conserva seu estado após reiniciar.
48. Arquivo corrompido é isolado sem derrubar o shell, versão futura desconhecida não é sobrescrita e falha de gravação preserva o estado em memória.
49. O target `hydrogen.v1` implementa todas as chamadas, respostas e códigos documentados, valida argumentos sem shell e não oferece forma de contornar confirmações de sessão.
50. Interface e IPC usam os mesmos controladores; uma mudança solicitada só é publicada e exibida após confirmação do provider correspondente.
51. Cada backend possui uma única instância lógica compartilhada entre monitores, enquanto cada barra representa corretamente apenas sua saída.
52. Componentes visuais funcionam com providers falsos, não acessam diretamente APIs externas, processos, sysfs, persistência ou arquivos de configuração.
53. A falha ou ausência de um provider opcional desativa somente seu recurso e não interrompe barra, launcher ou providers independentes.
54. Logs usam categorias, níveis e códigos normalizados, não expõem dados sensíveis e limitam ocorrências repetidas com resumo e recuperação.
55. Recursos opcionais normalmente ausentes não produzem ruído; avisos visuais aparecem somente diante de impacto, tentativa do usuário ou ação possível.
56. `status` e `diagnostics` retornam fotografias sanitizadas sem executar comandos externos nem revelar conteúdo pessoal.
57. Stores, controladores e componentes são exercitados offscreen com providers e relógio falsos, cobrindo estados pronto, vazio, indisponível, degradado, falho e recuperado.
58. Todos os comandos, argumentos, códigos e regras de segurança de `hydrogen.v1` são testados tanto no controlador quanto no target IPC real.
59. A suíte de sistema inicia Sway headless com duas saídas, valida hotplug e overlays por monitor e isola integralmente diretórios XDG e D-Bus.
60. Cada requisito automatizável possui ligação com teste, cada correção recebe regressão quando possível e skips informam uma capacidade realmente ausente.
61. A receita da VM de referência é reproduzível, não contém credenciais e permite executar os cenários manuais de release.

## 16. Marcos de desenvolvimento

| Marco | Resultado esperado |
|---|---|
| 1. Fundação | Estrutura do Quickshell, configuração, logging, diagnóstico, infraestrutura básica de testes, ciclo de vida e conexão com o IPC do Sway |
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
| 12. Polimento | Animações, multimonitor, teclado, tolerância a falhas, suíte de sistema, VM de referência, empacotamento e documentação |

Cada componente deve ser concluído e testável antes do início do seguinte, exceto quando uma dependência ou interseção técnica exigir desenvolvimento conjunto.

## 17. Decisões ainda abertas

Os tópicos abaixo foram deliberadamente adiados e não devem ser fechados por conveniência durante a implementação:

1. empacotamento e instalação;
2. ciclo de inicialização, recarga e encerramento;
3. acessibilidade além da navegação por teclado;
4. documentação de configuração e migração entre versões;
5. critérios para considerar cada marco concluído;
6. matriz de compatibilidade e testes com aplicativos reais.

Novas decisões não devem ser fechadas por conveniência durante a implementação. Questões de viabilidade devem ser tratadas como pesquisa técnica, sem reintroduzir recursos declarados como não objetivos.

> **Definição e regra de escopo:** o Hydrogen é a camada visual cotidiana entre o Sway e o usuário de desktop tradicional: painel inferior, acesso a aplicativos, representação das janelas abertas, indicadores essenciais, launcher e controles contextuais. Uma nova função só deve entrar quando fizer parte dessa interação cotidiana; ser tecnicamente possível ou visualmente interessante não é justificativa suficiente.

## 18. Orientação para implementação assistida por IA

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
