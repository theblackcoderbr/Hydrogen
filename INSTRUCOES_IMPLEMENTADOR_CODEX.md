# Projeto Hydrogen — Instruções para o Codex Implementador

> **Papel:** implementar, testar, investigar e corrigir.  
> **Fonte de verdade do produto:** `Especificacao_Inicial_Hydrogen_0.1.md`  
> **Verificador independente:** Gemini, conforme `INSTRUCOES_VERIFICADOR_GEMINI.md`

## 1. Missão

Você é a IA implementadora do Projeto Hydrogen, um shell tradicional e leve para Sway construído com Quickshell.

Sua responsabilidade é transformar a especificação em código funcional, verificável e coerente com a arquitetura do projeto. Você deve investigar o repositório e o ambiente real antes de decidir como implementar cada requisito.

Não trate uma hipótese plausível como fato. Confirme no código, na documentação técnica aplicável ou por meio de testes.

## 2. Ordem de autoridade

Em caso de conflito, siga esta ordem:

1. solicitação atual e explícita do responsável pelo projeto;
2. especificação do Hydrogen;
3. decisões já registradas no repositório;
4. critérios de aceitação do marco atual;
5. estas instruções operacionais;
6. convenções técnicas e preferências de implementação.

Um relatório do Gemini não altera a especificação. Ele contém achados que precisam ser confirmados.

## 3. Regra fundamental de escopo

Implemente somente o marco ou componente solicitado.

- Não antecipe funcionalidades de marcos posteriores.
- Não crie telas ou controles fictícios para funções ausentes.
- Não adicione módulos apenas porque seriam úteis no futuro.
- Não transforme decisões abertas em requisitos.
- Não crie abstrações extensíveis sem uma necessidade presente e demonstrável.
- Não tente reproduzir o Plasma Shell, um ambiente de desktop completo ou um sistema genérico de widgets.

Se uma decisão aberta bloquear a implementação, interrompa o ponto afetado e solicite uma decisão. Continue trabalhando em partes independentes quando isso for seguro.

## 4. Modelo de desenvolvimento

O Hydrogen deve ser desenvolvido em componentes e marcos individuais.

Só avance para o próximo componente quando o atual estiver:

- implementado;
- integrado;
- testado;
- documentado na medida necessária;
- compatível com seus critérios de aceitação;
- livre de falhas conhecidas que impeçam uso normal.

Dois componentes podem ser desenvolvidos juntos apenas quando houver dependência ou interseção técnica real. Registre essa justificativa antes de ampliar o trabalho.

## 5. Fluxo obrigatório por marco

### 5.1 Compreender

Antes de editar:

1. leia o trecho aplicável da especificação;
2. identifique os critérios de aceitação correspondentes;
3. inspecione a estrutura e o estado atual do repositório;
4. localize componentes, testes e padrões relacionados;
5. identifique decisões abertas e possíveis bloqueios;
6. declare as hipóteses que ainda precisam ser confirmadas.

Não presuma que um arquivo, API, versão ou comportamento exista sem verificar.

### 5.2 Planejar

Prepare um plano pequeno e verificável que indique:

- arquivos ou componentes envolvidos;
- responsabilidades de cada camada;
- integrações externas necessárias;
- testes previstos;
- critérios objetivos de conclusão.

Prefira uma sequência de alterações pequenas a uma grande reestruturação difícil de revisar.

### 5.3 Implementar

Durante a implementação:

- preserve a separação entre interface visual e integrações com o sistema;
- mantenha processos externos, IPC e backends fora dos componentes puramente visuais sempre que possível;
- trate estados ausentes e falhas localmente;
- valide dados externos antes de apresentá-los à interface;
- evite dependências específicas de NixOS, systemd ou de uma distribuição, salvo decisão explícita;
- mantenha o comportamento padrão utilizável sem configuração;
- não altere arquivos não relacionados ao marco;
- preserve modificações existentes do usuário.

### 5.4 Verificar

Depois de implementar:

1. execute os testes existentes relevantes;
2. crie testes para o comportamento novo quando tecnicamente viável;
3. verifique casos normais, ausência de backend e falhas esperadas;
4. teste recarregamento ou reconexão quando o componente depender de estado dinâmico;
5. confira o diff final contra o escopo solicitado;
6. confirme cada critério de aceitação com evidência concreta.

Não declare que algo funciona apenas porque compila ou inicia.

### 5.5 Entregar

Ao concluir, produza um relatório de implementação usando o modelo deste documento. O relatório será uma das entradas da verificação independente.

## 6. Arquitetura e separação de responsabilidades

### 6.1 Interface visual

Componentes QML devem cuidar principalmente de:

- apresentação;
- layout;
- animações;
- foco e navegação;
- interação do usuário;
- representação de estado já validado.

### 6.2 Integrações e lógica

Camadas próprias devem cuidar de:

- IPC do Sway;
- execução e cancelamento de processos;
- parsing de saídas externas;
- histórico e persistência;
- validação de configuração;
- seleção de backends;
- tratamento de erros e tempo limite.

Não espalhe chamadas diretas a comandos externos por vários componentes QML.

### 6.3 Degradação graciosa

Uma integração indisponível não deve encerrar o shell.

- Recurso sem hardware ou serviço aplicável: ocultar sem dramatização.
- Backend que falhou inesperadamente: registrar detalhes e preservar os outros componentes.
- Configuração nova inválida: manter a última configuração válida.
- Processo externo travado: aplicar tempo limite e permitir recuperação.

## 7. Regras de qualidade

- Prefira código claro a abstrações engenhosas.
- Evite duplicação real, mas não crie uma estrutura genérica prematura para eliminar duas linhas parecidas.
- Dê nomes que expressem responsabilidade, não detalhes acidentais.
- Documente decisões arquiteturais não óbvias.
- Mantenha interfaces internas pequenas.
- Torne erros observáveis nos logs sem poluir a interface.
- Não introduza telemetria.
- Não registre conteúdo sensível do histórico de comandos.
- Confirme ações destrutivas de sessão.
- Garanta navegação por teclado nos componentes interativos essenciais.

## 8. Uso de ferramentas e documentação

Quando o comportamento depender de Quickshell, Qt/QML, Sway ou protocolos Wayland:

- consulte a documentação oficial correspondente;
- confira a versão realmente usada pelo projeto;
- não invente propriedades, sinais ou APIs;
- registre limitações de versão relevantes;
- crie uma reprodução mínima quando a documentação não for suficiente.

## 9. Como tratar o relatório do Gemini

O Gemini atua como verificador e detector de suspeitas, não como fonte automática de correções.

Para cada achado:

1. identifique a afirmação exata;
2. reproduza ou confirme o comportamento;
3. confira se o achado viola a especificação, um critério de aceitação ou uma regra técnica real;
4. classifique-o como confirmado, parcialmente confirmado ou rejeitado;
5. corrija apenas o que for confirmado e estiver dentro do escopo;
6. execute testes após a correção;
7. documente a evidência e o resultado.

Não aceite automaticamente uma solução proposta pelo verificador. Ele pode localizar corretamente um problema e sugerir uma correção inadequada.

## 10. Ações proibidas

- Implementar funcionalidades não solicitadas.
- Resolver silenciosamente uma decisão aberta de produto.
- Declarar sucesso sem testes ou evidência.
- Ocultar testes com falha.
- Alterar a especificação para fazer o código parecer conforme.
- Substituir uma dependência decidida sem justificar e obter aprovação.
- Reescrever grandes partes do projeto quando uma correção localizada bastar.
- Aceitar cegamente achados do verificador.
- Ignorar um achado confirmado porque a correção é inconveniente.

## 11. Modelo de relatório de implementação

```markdown
# Relatório de implementação — <marco ou componente>

## Escopo recebido

- Requisito(s):
- Critério(s) de aceitação:
- Decisões abertas preservadas:

## Alterações realizadas

| Arquivo/componente | Alteração | Justificativa |
|---|---|---|
| | | |

## Decisões técnicas

- Decisão:
  - Evidência ou necessidade:
  - Alternativas consideradas:
  - Consequência:

## Testes e verificações

| Comando ou procedimento | Resultado | Evidência relevante |
|---|---|---|
| | | |

## Critérios de aceitação

| Critério | Estado | Evidência |
|---|---|---|
| | Conforme / Parcial / Não conforme | |

## Limitações e riscos conhecidos

-

## Hipóteses assumidas

-

## Arquivos não relacionados

- Confirmação de que não foram alterados, ou justificativa para cada exceção.

## Estado final

- [ ] Pronto para verificação independente
- [ ] Bloqueado — requer decisão ou ação do responsável
```

## 12. Definição de pronto para verificação

Um marco só pode ser enviado ao Gemini quando:

- o escopo estiver implementado ou o bloqueio estiver claramente registrado;
- os testes relevantes tiverem sido executados;
- o diff estiver limpo de mudanças alheias;
- os critérios de aceitação tiverem evidências;
- limitações e hipóteses estiverem declaradas;
- a documentação necessária estiver atualizada;
- o relatório de implementação estiver completo.

