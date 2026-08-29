# Relatório de correções da verificação — Marco 1: Fundação

## Origem

- Verificação: `docs/reports/milestone-1-verification-0.1.md`.
- Avaliação técnica: `docs/reports/milestone-1-verification-assessment-0.1.md`.
- Escopo: corrigir V-001, V-002 e a lacuna S-001, com regressões e ambiente reproduzível.

## Correções aplicadas

### V-001 — executor Node.js

- `tests/helpers/load-qml-js.mjs` converte objetos `URL` com `fileURLToPath` e sempre fornece uma string a `vm.Script.filename`.
- `scripts/test-unit.sh` executa as suítes Qt e Node em toda validação; nenhuma delas funciona como fallback silencioso da outra.
- Node.js 24.12.0 é fornecido pelo `shell.nix`.

### V-002 — descoberta de ferramentas e imports

- `shell.nix` fixa revisões e hashes do `nixpkgs`, Quickshell 0.3.1 e Sway 1.12.
- Qt, QtTest, módulos QML, Mesa e Fontconfig são fornecidos pelo mesmo ambiente declarado.
- Os scripts não percorrem `/nix/store`; usam somente ferramentas no `PATH` do ambiente.
- A execução externa é recusada com instrução para usar `nix-shell --pure`.

### S-001 — retenção de arquivos corrompidos

- `StateRepository` observa somente `state.corrupt-*.json`.
- A política valida e deduplica nomes, ordena pelos timestamps normalizados no nome, conserva os três mais recentes e agenda remoções sequenciais.
- Cada remoção usa `rm` com uma lista estruturada de argumentos e caminho construído somente a partir de nomes internos validados.
- Falha de remoção produz `corrupt_retention_failed`, severidade `warning` e ação `check_permissions`, sem mudar o estado do repository para terminal e sem interromper o restante da fila.

## Regressões

| Evidência | Cobertura |
|---|---|
| `tests/qml/tst_foundation.qml` | seleção das três cópias mais recentes e política de falha acionável/não terminal |
| `tests/unit/foundation.test.mjs` | mesmas regras puras executadas no Node.js 24 |
| `tests/system/run-headless.sh` | inicia com cinco cópias antigas e um `state.json` corrompido, exige exatamente três cópias e confirma quais antigas foram removidas |
| `scripts/test-unit.sh` | executa obrigatoriamente Qt e Node |

## Comando normativo

```sh
nix-shell --pure --run './scripts/check.sh'
```

## Resultado

- Qt Quick Test: 26 aprovados, 0 falhas.
- Node.js: 13 aprovados, 0 falhas.
- `qmllint`: aprovado sem avisos.
- Sistema Sway headless: aprovado com duas saídas, recarga transacional, poda, persistência, IPC e encerramento coordenado.
- Descoberta recursiva no `/nix/store`: removida dos scripts.

## Estado

- Correções V-001, V-002 e S-001 concluídas.
- Pronto para nova verificação independente do Marco 1.
