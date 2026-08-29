# Avaliação dos apontamentos da verificação — Marco 1: Fundação

## Identificação

- Documento avaliado: `docs/reports/milestone-1-verification-0.1.md`
- Marco: 1 — Fundação
- Objeto desta avaliação: confrontar os apontamentos do agente verificador com a especificação e a implementação atual.
- Escopo da atividade: análise somente; nenhuma correção foi aplicada ao código.

## Parecer resumido

Os principais problemas técnicos apontados pelo verificador são sustentados pelo código, com divergências quanto à severidade do V-001, à causalidade completa do V-002 e à classificação do S-001 como mera suspeita.

Há também uma inconsistência processual no parecer `Aprovado com ressalvas`: esse estado não existe no processo definido pela especificação. Se o V-001 permanecer classificado como Médio, o Marco 1 deve permanecer em `validation`; caso seja reclassificado como Baixo, a conclusão ainda precisa ser expressa de maneira binária e coerente com os portões do marco.

## Avaliação consolidada

| Item | Posição | Avaliação |
|---|---|---|
| Conformidade geral do Marco 1 | Concordância | A matriz do verificador corresponde à implementação e às evidências disponíveis. |
| V-001 — helper Node.js | Concordância com o defeito; discordância da severidade Média | O erro de tipo é real, mas afeta um fallback adicional. A ferramenta normativa da seção 12.1 é `qmltestrunner`, cuja suíte passou integralmente. A severidade mais proporcional é Baixa. |
| V-002 — varreduras no `/nix/store` | Concordância | As buscas são amplas, potencialmente lentas e podem selecionar versões arbitrárias das ferramentas. |
| V-002 — import do `QtTest` | Concordância parcial | O caminho não é injetado explicitamente, mas pode ser resolvido pelos caminhos compilados do próprio Qt. Trata-se de fragilidade de portabilidade, não de falha universal. |
| S-001 — retenção de arquivos corrompidos | Concordância com a lacuna; discordância da classificação como suspeita | A implementação não limita a retenção a três cópias. A ausência é confirmável no código, embora possa ser tratada como defeito Baixo e não bloqueador da persistência básica do Marco 1. |
| G-001 — centralização das versões | Concordância | É melhoria válida de reprodutibilidade, mas não requisito isoladamente bloqueador. |
| Resultado `Aprovado com ressalvas` | Discordância | A especificação determina conclusão binária e rejeita expressamente aprovação parcial ou com ressalvas. |

## V-001 — incompatibilidade de tipo no helper Node.js

### Constatação

Em `tests/helpers/load-qml-js.mjs`, o valor recebido como `path` é repassado diretamente para a propriedade `filename` de `vm.Script`:

```js
new vm.Script(source, { filename: path }).runInContext(context);
```

Os testes em `tests/unit/` chamam o helper com instâncias de `URL`. Em versões do Node.js que exigem uma string para `filename`, isso produz o erro de tipo descrito pelo verificador. Portanto, o defeito está confirmado.

### Divergência de severidade e requisito

A seção 12.1 da especificação estabelece Qt Quick Test e `qmltestrunner` como ferramentas normativas. Essa suíte executou 24 testes sem falhas. O executor Node.js é um fallback adicional, embora esteja publicamente prometido no `README.md` e, por isso, também deva funcionar.

Assim, o defeito é funcional e precisa de regressão, mas sua classificação mais proporcional é Baixa, salvo decisão explícita que torne Node.js um ambiente obrigatório do projeto.

### Imprecisão na condição sugerida

O script `scripts/test-unit.sh` executa a suíte Node somente quando não encontra `qmltestrunner`. Corrigir o helper não fará, por si só, que as duas suítes sejam executadas em ambientes que já possuem Qt. A regressão precisa chamar a suíte Node diretamente ou mudar deliberadamente a política do script.

## V-002 — automação e descoberta de ferramentas

### Varreduras do Nix store

Os scripts `scripts/test-unit.sh` e `scripts/lint.sh` recorrem a buscas profundas iniciadas na raiz de `/nix/store`. A observação procede por dois motivos:

1. o custo cresce com o tamanho do store;
2. `-print -quit` seleciona a primeira ocorrência encontrada, sem garantir versão ou compatibilidade entre Qt, Quickshell e suas ferramentas.

Logo, o problema não é apenas desempenho: também existe risco de descoberta não determinística.

### Importação do QtTest

O `QML_IMPORT_PATH` de `scripts/test-unit.sh` adiciona explicitamente apenas a árvore QML do Hydrogen. O módulo `QtTest` pode continuar disponível pelos caminhos compilados no `qmltestrunner`, como ocorreu no ambiente de implementação, mas isso depende do empacotamento e do runner selecionado.

Concorda-se, portanto, com a necessidade de tornar a resolução explícita e reproduzível. Não se conclui, contudo, que a ausência de uma entrada explícita sempre provoque `Type TestCase unavailable`; a seleção arbitrária de uma versão incompatível do runner pode integrar a causa observada pelo verificador.

## S-001 — retenção de arquivos corrompidos

A especificação determina que no máximo três cópias `*.corrupt-<timestamp>.json` sejam mantidas. `StateRepository.qml` gera o nome de quarentena e move o arquivo inválido, mas não enumera nem remove cópias excedentes.

Essa ausência é verificável diretamente e deve ser tratada como lacuna confirmada, não apenas suspeita. Ainda assim, a classificação como Baixa e não bloqueadora do Marco 1 é defensável porque o portão específico exige persistência básica e o isolamento funcional já ocorre.

O adiamento exclusivo para os Marcos 5 ou 10 é frágil: a regra pertence ao estado persistente geral e `state.json` já integra o Marco 1. A implementação da poda deve ser incorporada à infraestrutura compartilhada antes que outros históricos dependam dela.

## G-001 — centralização das versões

Concorda-se com a sugestão. Uma definição única ou ambiente reproduzível reduziria divergências entre lint, testes unitários e teste de sistema. No estado atual, porém, ela permanece melhoria de manutenção e não constitui, isoladamente, falha de aceitação.

## Inconsistência processual do parecer

A especificação, na seção 18, determina que:

- a conclusão de um marco é binária: `completed` ou ainda não concluído;
- `validation` não libera o marco seguinte;
- não existe conclusão parcial ou `com ressalvas`;
- defeito Médio que contradiga critério de aceitação impede `completed`.

O relatório do verificador classifica V-001 como Médio, estabelece condições antes da liberação do Marco 2 e, simultaneamente, declara `Aprovado com ressalvas`. As três afirmações não podem coexistir sob o processo normativo do projeto.

Se a severidade Média for mantida, o estado coerente é `validation` até a correção e nova verificação. Se V-001 for reclassificado como Baixo, ainda será necessário registrar um resultado binário: `completed`, caso os defeitos baixos estejam documentados e sem perda funcional incompatível, ou `validation`, se a validação exigir sua correção.

## Conclusão

- V-001: defeito confirmado; severidade Média considerada excessiva, com recomendação de Baixa.
- V-002, varreduras: defeito confirmado de desempenho e determinismo.
- V-002, QtTest: fragilidade confirmada, mas causalidade apresentada de forma excessivamente ampla.
- S-001: lacuna confirmada, de baixa severidade e escopo de conclusão discutível para o Marco 1.
- G-001: sugestão válida e não bloqueadora.
- Parecer formal: `Aprovado com ressalvas` é incompatível com a especificação e deve constar como divergência processual, sem ser tratado como defeito de implementação.

Nenhum arquivo de código ou documento fonte foi modificado durante a análise original dos apontamentos.
