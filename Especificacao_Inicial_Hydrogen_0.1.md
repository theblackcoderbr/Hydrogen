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
| Esquerda | Ícone do launcher | Abrir o launcher e sinalizar o ponto de entrada do shell |
| Centro / área expansível | Aplicativos e janelas abertas | Representar, focar e alternar as janelas gerenciadas pelo Sway |
| Direita | Indicadores essenciais, bateria, sessão e relógio | Exibir estado e abrir painéis contextuais pequenos |

A barra não será um sistema genérico de painéis. No MVP, sua posição, estrutura principal e função são fixas. O arquivo de configuração poderá ajustar aparência e alguns comportamentos, mas não reconstruir livremente o layout.

### 5.2 Aplicativos abertos

A área principal da barra representa as janelas abertas de modo tradicional. Cada item deverá identificar visualmente o aplicativo e permitir que o usuário encontre e foque uma janela sem depender exclusivamente de atalhos ou da representação dos workspaces.

- A lista é alimentada pelo IPC do Sway.
- O item precisa indicar estado ativo, inativo e urgente quando essa informação estiver disponível.
- A apresentação deve se adaptar ao espaço horizontal sem tornar a barra inutilizável.
- Agrupamento de janelas do mesmo aplicativo e comportamento ao clicar no item já focado permanecem decisões abertas.

### 5.3 Workspaces

Workspaces continuam sendo uma capacidade do Sway, mas não definem a identidade visual do Hydrogen. A presença de um seletor de workspaces no painel, sua posição e sua forma de apresentação serão decididas após o modelo de aplicativos abertos estar validado.

## 6. Componentes do MVP

### 6.1 Launcher

O launcher aparece como painel compacto e centralizado no monitor focado. Ele será otimizado para teclado, sem excluir interação por mouse.

- Pesquisar e iniciar aplicativos instalados por meio de entradas desktop.
- Exibir aplicativos antes dos arquivos na pesquisa normal.
- Pesquisar arquivos sob demanda com `fd`, inicialmente dentro da pasta pessoal ou de diretórios configurados.
- Abrir arquivos com o aplicativo padrão definido pelas associações XDG.
- Usar o prefixo `>` para comandos e ações internas.
- Aceitar executável e argumentos sem interpretar automaticamente operadores de shell.
- Mostrar itens mais usados quando a pesquisa estiver vazia.
- Manter histórico local e limitado de aplicativos, arquivos e comandos, com limpeza automática.

### 6.2 Relógio e calendário

O relógio permanece na região direita do painel. Sua ativação abre um calendário simples, destinado à consulta de datas. Agenda, compromissos e integração com calendários externos não pertencem ao MVP.

### 6.3 Energia, bateria e sessão

Quando houver bateria, o painel exibirá um indicador e permitirá consultar informações detalhadas. O menu de sessão oferecerá:

- sair do Sway;
- reiniciar;
- desligar.

Reiniciar e desligar exigem confirmação.

As ações do sistema deverão passar por uma pequena camada de integração, evitando que os componentes QML dependam diretamente de systemd ou de uma distribuição específica.

### 6.4 OSDs e controles contextuais

Os OSDs aparecem na lateral direita do monitor focado e desaparecem após um período fixo sem interação. Eventos repetidos do mesmo tipo atualizam o painel existente em vez de criar várias instâncias.

| OSD | Conteúdo | Interação |
|---|---|---|
| Volume | Nível e estado de mudo | Ajustar nível e alternar mudo |
| Microfone | Nível e estado de mudo | Ajustar nível e alternar mudo |
| Brilho | Nível atual | Ajustar brilho |
| Mídia | Título e controles | Anterior, reproduzir/pausar e próxima |
| Teclado | Caps Lock e Num Lock | Somente informativo |
| Energia | Perfil ativo | Selecionar perfil disponível |

### 6.5 Múltiplos monitores

- Cada monitor recebe uma barra completa.
- Launcher e menus aparecem no monitor atualmente focado.
- OSDs aparecem somente no monitor focado.
- A desconexão de uma saída não pode interromper o shell.

### 6.6 Notificações

O Hydrogen atuará como servidor de notificações da sessão, implementando a especificação Desktop Notifications do Freedesktop por meio da API de notificações do Quickshell. Não haverá dependência de um daemon externo como Mako, Dunst ou SwayNotificationCenter, e a documentação de instalação deverá informar que outro servidor de notificações não pode disputar essa responsabilidade na mesma sessão.

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

## 7. Aparência e interação

- Barra contínua na parte inferior, ocupando toda a largura da saída.
- Superfícies translúcidas e atmosfera visual leve.
- Cores fixas no MVP; integração futura possível com Matugen.
- Animações curtas, discretas e associadas a mudanças de estado.
- Layout responsivo, sem resolução mínima fixa.
- Navegação completa por teclado nos componentes interativos.
- Interface, mensagens e configuração inicialmente em português.

## 8. Configuração e estado

O Hydrogen terá um arquivo de configuração simples e em português. A intenção é permitir adaptação sem expor toda a estrutura interna do shell como uma API QML.

| Categoria | Exemplos |
|---|---|
| Aparência | Cores, opacidade, altura, raio, espaçamentos e tamanho de fonte |
| Painel | Indicadores habilitados e comportamento da área de aplicativos |
| Launcher | Diretórios de busca, limite de resultados e tempo de espera da pesquisa |
| Integrações | Comandos para sair, reiniciar e desligar |
| OSDs | Duração e disponibilidade dos provedores |
| Notificações | Tempos de exibição, limites do histórico e comportamento do modo não perturbe |

Alterações válidas devem ser recarregadas automaticamente. Uma configuração inválida não substitui a última configuração válida; quando houver ação possível, o usuário recebe um aviso objetivo e os detalhes ficam registrados nos logs.

## 9. Integrações e dependências

| Capacidade | Integração prevista |
|---|---|
| Janelas, foco, saídas e workspaces | IPC do Sway |
| Interface | Quickshell e Qt/QML |
| Busca de arquivos | `fd` |
| Áudio e microfone | `wpctl` |
| Mídia | `playerctl` / MPRIS |
| Brilho | `brightnessctl` |
| Perfis de energia | `powerprofilesctl` |
| Aplicativos e abertura de arquivos | Especificações e ferramentas XDG |
| Notificações | API de notificações do Quickshell e especificação Desktop Notifications do Freedesktop |

Quando um recurso não estiver disponível no hardware ou no serviço ativo, seu controle será ocultado silenciosamente. A ausência de um recurso não utilizado não deve produzir uma interface repleta de estados de erro.

## 10. Limites e não objetivos do MVP

- Não configurar graficamente o Sway.
- Não oferecer área de trabalho com ícones.
- Não recriar o sistema de widgets e painéis do Plasma.
- Não fornecer um editor visual completo para a barra.
- Não implementar gerenciamento de wallpaper.
- Não administrar monitores, rede, Bluetooth ou dispositivos.
- Não substituir bloqueador de tela, login manager ou agente de autenticação.
- Não criar indexador próprio de arquivos.
- Não gerar paleta dinâmica no MVP.
- Não oferecer plugins ou módulos arbitrários no MVP.
- Não oferecer suporte formal a outros compositores Wayland.

## 11. Requisitos de robustez

- Uma falha localizada não deve encerrar o shell inteiro.
- Processos externos devem ter execução, cancelamento e tempo limite controlados.
- Pesquisas de arquivos obsoletas devem ser canceladas enquanto o usuário digita.
- A configuração nova deve ser validada antes de substituir o estado ativo.
- Históricos permanecem locais, limitados e sem telemetria.
- Ações destrutivas de sessão exigem confirmação explícita.
- Recursos ausentes devem desaparecer sem deixar espaços vazios incoerentes.

## 12. Critérios de aceitação do Hydrogen 0.1

1. O Hydrogen inicia com uma configuração padrão utilizável em uma sessão Sway.
2. Uma barra inferior completa é criada em cada saída ativa.
3. O botão do launcher abre o painel no monitor focado.
4. Aplicativos abertos são representados na barra e podem ser focados por ela.
5. Aplicativos podem ser encontrados e iniciados pelo launcher.
6. Arquivos podem ser encontrados com `fd` e abertos pelo aplicativo XDG padrão.
7. O modo `>` executa comandos com argumentos e ações internas predefinidas.
8. Relógio, calendário, sessão e bateria funcionam quando aplicáveis.
9. Os OSDs definidos respondem aos respectivos eventos e controles.
10. A configuração é recarregada sem reinício e erros preservam o último estado válido.
11. Todos os componentes interativos essenciais podem ser operados por teclado.
12. Notificações de teste aparecem no monitor focado, respeitam urgência, agrupamento, ações e pausa do temporizador.
13. A central mantém e ordena o histórico, marca somente itens visualizados como lidos e aplica os limites de 50 itens e 7 dias.
14. O modo não perturbe suprime todos os pop-ups sem impedir o armazenamento e a contagem das notificações.

## 13. Marcos de desenvolvimento

| Marco | Resultado esperado |
|---|---|
| 1. Fundação | Estrutura do Quickshell, configuração, logs, ciclo de vida e conexão com o IPC do Sway |
| 2. Painel básico | Barra inferior por saída, launcher, relógio e estrutura responsiva |
| 3. Aplicativos abertos | Descoberta das janelas, estados, foco e comportamento inicial dos itens da barra |
| 4. Launcher de aplicativos | Entradas desktop, pesquisa, teclado e itens mais usados |
| 5. Launcher completo | `fd`, abertura XDG, modo `>`, ações internas e histórico |
| 6. Painéis contextuais | Calendário, bateria, sessão e confirmações |
| 7. Infraestrutura de OSD | Posicionamento, tempo de permanência, atualização e interação compartilhada |
| 8. Provedores de OSD | Áudio, microfone, brilho, mídia, teclado e perfis de energia |
| 9. Notificações | Servidor Freedesktop, pop-ups, ações, agrupamento, central, histórico e modo não perturbe |
| 10. Polimento | Animações, multimonitor, teclado, tolerância a falhas, empacotamento e documentação |

Cada componente deve ser concluído e testável antes do início do seguinte, exceto quando uma dependência ou interseção técnica exigir desenvolvimento conjunto.

## 14. Decisões ainda abertas

Estas decisões não devem ser fechadas por conveniência durante a implementação; cada uma altera de forma perceptível a experiência do painel tradicional.

- Aplicativos abertos serão agrupados por aplicativo ou representados por janela?
- O clique no item da janela já focada terá alguma ação, como ocultar ou alternar?
- Como várias janelas agrupadas serão escolhidas?
- Workspaces terão representação permanente no painel?
- A bandeja do sistema pertence ao MVP ou a uma versão posterior?
- Quais indicadores, além de bateria, sessão e relógio, são realmente essenciais?
- Qual formato concreto será usado pelo arquivo de configuração?
- Como detectar Caps Lock e Num Lock de forma portátil em sessões Sway?

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
