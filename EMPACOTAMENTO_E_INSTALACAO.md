# Hydrogen — Empacotamento e instalação

> **Estado:** decisão normativa para o Hydrogen 0.1  
> **Revisão:** 1  
> **Data:** 31 de agosto de 2026

## 1. Objetivo

Este documento define como o Hydrogen é identificado, versionado, distribuído, instalado, iniciado, atualizado e removido. Ele complementa a especificação geral e prevalece sobre exemplos antigos de execução quando o assunto for empacotamento.

O modelo deve preservar quatro propriedades: funcionar sem configuração pessoal, não depender de NixOS ou systemd, manter código e dados do usuário separados e oferecer a mesma aplicação em todos os formatos de pacote.

## 2. Identidade pública

| Elemento | Valor |
|---|---|
| Projeto | Hydrogen |
| Pacote | `hydrogen-shell` |
| Executável | `hydrogen` |
| Identificador do Quickshell | `hydrogen` |
| Licença | `GPL-3.0-or-later` |
| Versão inicial prevista | `0.1.0` |
| Repositório | `theblackcoderbr/Hydrogen` |

O nome de pacote reduz colisões com outros projetos chamados Hydrogen. O nome curto permanece reservado à interface de linha de comando e aos diretórios XDG próprios.

## 3. Natureza do produto

O Hydrogen é uma aplicação predominantemente QML executada pelo Quickshell. Sua árvore privada também contém helpers Python 3:

- um bridge persistente e gerenciado para o IPC binário do Sway;
- um helper transitório para executar Desktop Entries;
- um helper transitório para busca de arquivos, validação, enumeração do `PATH` e comandos estruturados.

Os helpers usam somente a biblioteca padrão, não são módulos públicos, não recebem ambiente virtual, não usam `pip`, não invocam shell e permanecem junto dos providers que os possuem. O bridge termina com o Hydrogen e não constitui daemon ou serviço independente.

## 4. Artefato upstream

Cada release estável publica um arquivo versionado, inicialmente:

```text
hydrogen-0.1.0.tar.zst
```

O artefato contém:

```text
hydrogen/
packaging/
docs/
LICENSE
Makefile
README.md
VERSION
```

Ele é a fonte normativa dos pacotes. Pacotes estáveis consomem tag e artefato imutáveis com checksum; a branch `main` não é fonte de uma instalação estável.

`VERSION` contém somente a versão upstream. Revisões de pacote, como `0.1.0-1`, pertencem ao gerenciador da distribuição.

## 5. Layout instalado

O layout lógico é independente do prefixo:

```text
$prefix/bin/hydrogen
$prefix/share/hydrogen/
├── shell.qml
├── config/
├── core/
├── diagnostics/
├── domain/
├── features/
├── ipc/
├── logic/
├── persistence/
└── providers/

$prefix/share/hydrogen/integration/sway.conf
$prefix/share/doc/hydrogen/
$prefix/share/licenses/hydrogen/LICENSE
```

Em distribuições tradicionais, o prefixo esperado é `/usr`. No Nix, é o caminho da derivation. O launcher resolve o diretório de dados no momento do empacotamento e nunca depende do diretório atual.

A árvore QML é privada e somente leitura. Nenhum pacote copia o código para `~/.config/quickshell`, assume a configuração padrão do Quickshell ou habilita observação de código em produção.

## 6. Interface de linha de comando

`hydrogen` é a única interface pública instalada. Seu contrato inicial é:

```text
hydrogen
hydrogen start
hydrogen status
hydrogen diagnostics
hydrogen reload
hydrogen ipc <operação> [argumentos]
hydrogen init [--complete]
hydrogen version
hydrogen help
```

`hydrogen` e `hydrogen start` iniciam `qs -p` contra a árvore instalada. Os subcomandos de estado e controle chamam o target `hydrogen.v1` da mesma instalação. O launcher:

- valida argumentos e retorna códigos de saída úteis;
- não usa `eval` nem concatena entrada em shell;
- não inicia o Sway ou serviços externos;
- não cria unidade systemd;
- não modifica configuração pessoal;
- detecta dependências ausentes com mensagem objetiva;
- não esconde uma segunda instância ou incompatibilidade de versão.

O protocolo IPC continua definido pela especificação geral. O launcher traduz apenas comandos humanos estáveis para chamadas do Quickshell; ele não duplica regras de domínio.

## 7. Configuração inicial

O Hydrogen inicia sem `~/.config/hydrogen`. Padrões internos completos e versionados fornecem a configuração efetiva; ausência de um TOML ou de uma chave faz apenas aquela parte retornar aos padrões atuais.

Nenhuma destas operações cria configuração pessoal:

- instalar;
- atualizar;
- iniciar pela primeira vez;
- remover;
- consultar status ou diagnóstico.

### 7.1 Inicialização mínima

```bash
hydrogen init
```

Cria, quando ausente:

```text
$XDG_CONFIG_HOME/hydrogen/config.toml
```

### 7.2 Inicialização completa

```bash
hydrogen init --complete
```

Cria somente os arquivos ausentes da estrutura:

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

Ambos os modos:

- respeitam `XDG_CONFIG_HOME`, com fallback para `~/.config`;
- nunca sobrescrevem, mesclam ou removem arquivos;
- informam separadamente arquivos criados e preservados;
- não iniciam o Quickshell;
- não exigem Hydrogen em execução;
- usam nomes, chaves e comentários em inglês;
- retornam falha somente quando não conseguem realizar uma operação solicitada.

O exemplo atualizado permanece instalado em `$prefix/share/doc/hydrogen`. Atualizações nunca substituem a cópia pessoal.

## 8. Dados e propriedade

Código do pacote, configuração, estado, dados e cache têm proprietários distintos:

| Classe | Local | Proprietário da remoção |
|---|---|---|
| Código e documentação | `$prefix` | Gerenciador de pacotes |
| Configuração | `$XDG_CONFIG_HOME/hydrogen` | Usuário |
| Estado | `$XDG_STATE_HOME/hydrogen` | Usuário |
| Dados duráveis futuros | `$XDG_DATA_HOME/hydrogen` | Usuário |
| Cache futuro | `$XDG_CACHE_HOME/hydrogen` | Usuário |

O gerenciador remove somente o que instalou no prefixo. Desinstalação e atualização nunca removem nem reescrevem arquivos XDG pessoais. Uma limpeza de dados, se oferecida no futuro, será ação explícita, confirmada e separada do gerenciador de pacotes.

## 9. Dependências

### 9.1 Runtime atual

Os Marcos 1 a 5 exigem:

- Sway;
- Quickshell `>= 0.3.1`, com versões posteriores validadas explicitamente;
- Python 3;
- `fd`;
- coreutils;
- suporte XDG para abertura externa, fornecido por `xdg-utils` nos pacotes tradicionais.

O Hydrogen não depende de `swaymsg`: o bridge Python conversa diretamente com o socket do Sway. Python não possui dependências externas.

### 9.2 Runtime final do MVP

Quando os respectivos marcos forem implementados, acrescentam-se:

- `brightnessctl`, obrigatório para brilho;
- PipeWire, obrigatório para áudio;
- NetworkManager, opcional para rede;
- UPower, opcional para bateria;
- `power-profiles-daemon`, opcional para perfis de energia.

Dependências opcionais ausentes ocultam somente seu componente. `wpctl`, `playerctl` e `powerprofilesctl` não são fallbacks do MVP.

### 9.3 Desenvolvimento e testes

Node.js, `wtype`, Xwayland, terminais de fixture, Sway headless, ferramentas de lint e Nix não integram automaticamente o runtime. Eles permanecem na toolchain ou entram em `checkdepends` e equivalentes.

## 10. Python e processos

Pacotes tradicionais preservam helpers executáveis e o shebang `#!/usr/bin/env python3`. O pacote Nix aplica `patchShebangs` ou substituição equivalente e inclui Python, `fd` e coreutils em seu fechamento.

O ambiente do launcher preserva o `PATH` da sessão para descoberta e execução de aplicativos. Dependências privadas acrescentadas pelo empacotador não devem eliminar executáveis do usuário.

Solicitações contendo comandos ou outros dados privados devem preferir `stdin` a argumentos do processo, evitando exposição transitória em interfaces como `/proc/<pid>/cmdline`. Saídas JSON e logs permanecem sanitizados.

## 11. Integração com Sway

O pacote instala um exemplo em:

```text
$prefix/share/hydrogen/integration/sway.conf
```

Ele demonstra início, `Super + Space` para o launcher e `Super + Escape` para sessão por meio do comando `hydrogen`. O usuário decide entre incluir ou copiar as linhas.

Instalação, atualização e remoção nunca editam `~/.config/sway/config`, não habilitam autostart e não reiniciam o Sway.

## 12. Sistema de instalação

O artefato upstream usa um `Makefile` simples, pois não há compilação nativa. A interface é:

```bash
make
make check
make install PREFIX=/usr DESTDIR="$pkgdir"
```

Regras obrigatórias:

- `PREFIX` e `DESTDIR` são independentes;
- a instalação funciona sem privilégios dentro de `DESTDIR`;
- modos executáveis dos helpers são preservados;
- o launcher recebe o prefixo correto sem caminho absoluto de staging;
- nenhuma regra acessa a home, inicia o shell ou executa `hydrogen init`;
- `make` pode validar a árvore, mas não simula compilação inexistente;
- `make check` falha claramente quando a toolchain de testes não está disponível;
- o conteúdo instalado é enumerável e reproduzível.

CMake, Meson, `pip`, instalação por cópia manual e scripts que usam `sudo` não são mecanismos normativos do MVP.

## 13. Pacote Arch Linux

O pacote estável chama-se `hydrogen-shell`, consome uma release versionada e usa `make install` com `DESTDIR="$pkgdir"`. A lista inicial de dependências inclui:

```text
sway
quickshell
python
fd
coreutils
xdg-utils
```

Dependências de teste ficam em `checkdepends`. O pacote não executa testes que exigem uma sessão gráfica real no computador do usuário durante a instalação. Um eventual `hydrogen-shell-git` é secundário e nunca substitui a release estável como caminho recomendado.

## 14. Pacote e flake Nix

O repositório fornece:

```text
packages.<system>.hydrogen-shell
packages.<system>.default
apps.<system>.hydrogen
devShells.<system>.default
checks.<system>.*
```

A derivation instala a mesma árvore upstream, corrige shebangs e cria um wrapper que fornece dependências sem apagar o ambiente da sessão. O pacote funciona por `nix profile`, Home Manager e NixOS, mas a aplicação não depende de módulos NixOS, systemd ou layout específico da distribuição.

O `shell.nix` atual pode coexistir durante a transição. Quando o flake oferecer equivalência validada, ele se torna a interface normativa de pacote, desenvolvimento e checks.

## 15. Atualização e remoção

Atualização substitui somente arquivos do prefixo. O código QML em execução não é trocado silenciosamente; a nova versão entra no próximo início do Hydrogen.

Antes de declarar compatibilidade entre versões, a suíte verifica:

- configuração ausente;
- configuração parcial;
- opções desconhecidas;
- estado antigo migrável;
- estado futuro preservado;
- helpers e launcher do novo prefixo;
- ausência de mutações na home durante instalação e atualização.

Remoção apaga executável, árvore privada, documentação, integração de exemplo e licença. Configuração e estado pessoais permanecem intactos.

## 16. Licença

O projeto adota `GPL-3.0-or-later`. O repositório e a release incluem o texto integral em `LICENSE`; o pacote o instala no local convencional da distribuição.

Arquivos de produção recebem, quando apropriado, o identificador:

```text
SPDX-License-Identifier: GPL-3.0-or-later
```

Metadados do repositório, releases, pacotes Arch e Nix usam o mesmo identificador. Dependências conservam suas próprias licenças.

## 17. Verificação do pacote

O pacote só é aprovado quando uma árvore instalada em `DESTDIR` ou store isolado comprova:

1. conteúdo e modos corretos;
2. nenhum arquivo fora dos destinos declarados;
3. `hydrogen version` e `hydrogen help` sem sessão gráfica;
4. início por caminho instalado em Sway headless;
5. target IPC e encerramento coordenado;
6. bridge persistente e helpers transitórios com Python do pacote;
7. pesquisa `fd`, Desktop Entry e abertura XDG;
8. execução sem configuração pessoal e sem criação de TOMLs;
9. `hydrogen init` mínimo e completo em XDG isolado;
10. preservação de arquivos existentes;
11. atualização entre versões suportadas;
12. remoção sem alterações nos diretórios pessoais;
13. ausência de conteúdo privado em logs e argumentos de helpers após a migração para `stdin`;
14. licença, documentação e integração de exemplo presentes.

## 18. Não objetivos

Não pertencem ao empacotamento 0.1:

- Flatpak, Snap ou AppImage;
- instalador gráfico;
- atualização automática interna;
- download de dependências em runtime;
- `sudo pip` ou ambiente virtual gerenciado pelo usuário;
- unidade systemd obrigatória;
- modificação automática do Sway;
- remoção automática de configuração ou estado;
- inclusão de Quickshell ou Qt numa cópia privada do Hydrogen;
- suporte oficial a execução direta e permanente da branch `main`.

## 19. Critério de conclusão

O tópico de empacotamento está concluído quando identidade, licença, layout, launcher, configuração inicial, dependências, instalação por prefixo, release upstream, pacotes Arch e Nix, atualização, remoção e testes instalados obedecem a este documento e aos portões do Marco 12.

Até lá, este documento define o destino normativo; não afirma que os artefatos ainda ausentes já estejam implementados.
