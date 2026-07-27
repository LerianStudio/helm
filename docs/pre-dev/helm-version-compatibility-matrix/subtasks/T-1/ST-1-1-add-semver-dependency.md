# ST-1-1 — Adicionar dependência `Masterminds/semver/v3 v3.2.1` ao módulo

> **For Agents:** REQUIRED SUB-SKILL: executing-plans

## Goal
Adicionar a dependência semver ao módulo Go em `.github/scripts` na versão EXATA `v3.2.1` (piso Go 1.18, compatível com o piso duro Go 1.21 do módulo). NÃO usar `@latest` (v3.4+ sobe o piso para Go 1.26 = proibido).

## Prerequisites
Rode e confirme a saída:
```bash
cd /home/gauchito/lerian/helm/.github/scripts && head -3 go.mod
```
Saída esperada (exata):
```
module github.com/LerianStudio/helm/.github/scripts

go 1.21
```
Confirme também que o toolchain Go 1.21+ está disponível:
```bash
go version
```
Saída esperada: uma linha começando com `go version go1.` e minor `>= 21` (ex.: `go version go1.24.x linux/amd64`).

## Files
- modify: `/home/gauchito/lerian/helm/.github/scripts/go.mod` (bloco `require`)
- modify: `/home/gauchito/lerian/helm/.github/scripts/go.sum` (gerado por `go mod tidy` — não editar à mão)

## Steps

### Passo 1 — Adicionar a dependência na versão exata
```bash
cd /home/gauchito/lerian/helm/.github/scripts && go get github.com/Masterminds/semver/v3@v3.2.1
```
Saída esperada (contém a linha):
```
go: added github.com/Masterminds/semver/v3 v3.2.1
```

### Passo 2 — Confirmar a versão pinada no go.mod
```bash
cd /home/gauchito/lerian/helm/.github/scripts && grep 'Masterminds/semver' go.mod
```
Saída esperada (EXATA, versão v3.2.1, não v3.4+):
```
	github.com/Masterminds/semver/v3 v3.2.1
```
Se aparecer qualquer versão diferente de `v3.2.1`, PARE e refaça o Passo 1 com a versão exata.

### Passo 3 — Confirmar que o piso Go NÃO subiu
```bash
cd /home/gauchito/lerian/helm/.github/scripts && grep -E '^go |^toolchain ' go.mod
```
Saída esperada (EXATA — só a diretiva `go 1.21`, SEM linha `toolchain`):
```
go 1.21
```
Se aparecer uma linha `toolchain goX.Y.Z` ou `go` diferente de `1.21`, PARE: a versão da dep está errada (subiu o piso). Reverta (ver Rollback) e refaça com `@v3.2.1`.

### Passo 4 — Confirmar que o go.sum foi atualizado
```bash
cd /home/gauchito/lerian/helm/.github/scripts && grep -c 'Masterminds/semver/v3 v3.2.1' go.sum
```
Saída esperada: um número `>= 1` (tipicamente `2` — a linha do módulo e a do `/go.mod`).

## Verification (copiável)
```bash
cd /home/gauchito/lerian/helm/.github/scripts && go build ./... && echo "BUILD_OK"
```
Saída esperada: `BUILD_OK` (o módulo ainda compila com a nova dep; nenhum código a usa ainda).

## Rollback
```bash
cd /home/gauchito/lerian/helm/.github/scripts && git checkout go.mod go.sum
```
Isso remove a dependência recém-adicionada, restaurando o estado anterior do manifest e do lock.
