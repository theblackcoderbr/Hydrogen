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

A identificação confiável de grupos, a associação entre janelas e arquivos `.desktop` e os fallbacks para ícones ausentes deverão ser determinados por pesquisa e testes com aplicativos Wayland e XWayland. Esses mecanismos não devem depender de heurísticas não documentadas apresentadas como garantias.

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

O Hydrogen terá um arquivo de configuração simples e em português. A intenção é permitir adaptação sem expor toda a estrutura interna do shell como uma AP# Projeto Hydrogen

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

A identificação confiável de grupos, a associação entre janelas e arquivos `.desktop` e os fallbacks para ícones ausentes deverão ser determinados por pesquisa e testes com aplicativos Wayland e XWayland. Esses mecanismos não devem depender de heurísticas não documentadas apresentadas como garantias.

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

### 6.5 Bandeja e indicadores permanentes

O MVP inclui uma bandeja compatível com StatusNotifierItem. Ela deve preservar, conforme fornecido por cada aplicativo, o ícone, a ativação primária e secundária, a rolagem e os menus DBus. A bandeja completa aparece em todas as barras.

- Itens ativos e urgentes têm prioridade na área visível.
- Quando não houver espaço, os itens excedentes são movidos para um menu expansível.
- A ausência de itens não deixa um espaço vazio reservado na barra.
- O suporte deve usar a API do Quickshell compatível com a versão adotada pelo projeto e ser verificado com aplicativos reais.

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
| Bandeja | API StatusNotifierItem e DBusMenu do Quickshell |
| Rede | API de rede do Quickshell e backend compatível detectado em execução |
| Bateria | UPower e integração correspondente do Quickshell |

Quando um recurso não estiver disponível no hardware ou no serviço ativo, seu controle será ocultado silenciosamente. A ausência de um recurso não utilizado não deve produzir uma interface repleta de estados de erro.

## 10. Limites e não objetivos do MVP

- Não configurar graficamente o Sway.
- Não oferecer área de trabalho com ícones.
- Não recriar o sistema de widgets e painéis do Plasma.
- Não fornecer um editor visual completo para a barra.
- Não implementar gerenciamento de wallpaper.
- Não administrar monitores, Bluetooth ou dispositivos em geral.
- Não oferecer configuração avançada de rede, incluindo IP, DNS, VPN, hotspot ou edição completa de perfis.
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
4. Aplicativos do workspace visível são agrupados na barra, podem ser focados ou selecionados pela lista de janelas e mantêm ordem estável.
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
15. O menu de overflow preserva acesso aos aplicativos excedentes e mantém o aplicativo ativo visível sempre que possível.
16. Cada barra mostra o workspace atual e os ocupados de sua saída real, em ordem numérica, e permite trocar de workspace com clique ou roda.
17. O clique do meio em um workspace move a janela focada sem mudar para o destino, e estados de urgência são distinguíveis do estado ativo.
18. A bandeja aparece em todas as barras, preserva as ações fornecidas pelos aplicativos e move itens excedentes para um menu expansível.
19. O indicador de volume ajusta o nível em passos de 5% e seu painel controla volume geral, mudo e saída padrão.
20. O painel de rede executa as ações básicas definidas quando houver backend compatível e desaparece completamente quando ele estiver ausente.
21. Na primeira execução, a estrutura TOML completa é criada com nomes e comentários em inglês.
22. A recarga isola erros por componente, ignora opções desconhecidas com aviso e restaura padrões quando um arquivo de componente é removido.

## 13. Marcos de desenvolvimento

| Marco | Resultado esperado |
|---|---|
| 1. Fundação | Estrutura do Quickshell, configuração, logs, ciclo de vida e conexão com o IPC do Sway |
| 2. Painel básico | Barra inferior por saída, launcher, relógio e estrutura responsiva |
| 3. Navegação de janelas | Descoberta e agrupamento das janelas, foco, lista de seleção, overflow e seletor de workspaces |
| 4. Launcher de aplicativos | Entradas desktop, pesquisa, teclado e itens mais usados |
| 5. Launcher completo | `fd`, abertura XDG, modo `>`, ações internas e histórico |
| 6. Painéis contextuais | Calendário, bateria, sessão, volume, rede e confirmações |
| 7. Bandeja e indicadores | StatusNotifierItem, DBusMenu, overflow e indicadores permanentes |
| 8. Infraestrutura de OSD | Posicionamento, tempo de permanência, atualização e interação compartilhada |
| 9. Provedores de OSD | Áudio, microfone, brilho, mídia, teclado e perfis de energia |
| 10. Notificações | Servidor Freedesktop, pop-ups, ações, agrupamento, central, histórico e modo não perturbe |
| 11. Polimento | Animações, multimonitor, teclado, tolerância a falhas, empacotamento e documentação |

Cada componente deve ser concluído e testável antes do início do seguinte, exceto quando uma dependência ou interseção técnica exigir desenvolvimento conjunto.

## 14. Decisões ainda abertas

Estas decisões não devem ser fechadas por conveniência durante a implementação; cada uma altera de forma perceptível a experiência do painel tradicional.

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
I QML.

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
4. Aplicativos do workspace visível são agrupados na barra, podem ser focados ou selecionados pela lista de janelas e mantêm ordem estável.
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
15. O menu de overflow preserva acesso aos aplicativos excedentes e mantém o aplicativo ativo visível sempre que possível.
16. Cada barra mostra o workspace atual e os ocupados de sua saída real, em ordem numérica, e permite trocar de workspace com clique ou roda.
17. O clique do meio em um workspace move a janela focada sem mudar para o destino, e estados de urgência são distinguíveis do estado ativo.

## 13. Marcos de desenvolvimento

| Marco | Resultado esperado |
|---|---|
| 1. Fundação | Estrutura do Quickshell, configuração, logs, ciclo de vida e conexão com o IPC do Sway |
| 2. Painel básico | Barra inferior por saída, launcher, relógio e estrutura responsiva |
| 3. Navegação de janelas | Descoberta e agrupamento das janelas, foco, lista de seleção, overflow e seletor de workspaces |
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
