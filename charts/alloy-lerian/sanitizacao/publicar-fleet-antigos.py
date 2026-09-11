#!/usr/bin/env python3
"""Lista versões anteriores da mesma configuração, para remover após publicar.

Uso: publicar-fleet-antigos.py <listpipelines.json> <base> <nome-atual>

Saída: uma linha por pipeline antiga, `id<TAB>nome`.

⚠️ POR QUE EXISTE

O nome da configuração carrega a versão (`config_global_a1b2c3`), porque o agente
NÃO LIBERA o nome de um módulo que já carregou — nem depois de o módulo ser
deletado do Fleet. Republicar com o mesmo nome trava:

    err="a loader exists already for remotecfg/<nome>.default"

Com versão no nome, cada publicação cria um módulo novo. Mas as versões antigas
precisam sair, senão se acumulam — e o matcher casaria todas, fazendo o agente
carregar configurações concorrentes que disputariam as mesmas portas.
"""
import json
import sys

if len(sys.argv) < 4:
    sys.exit(0)

arquivo, base, atual = sys.argv[1:4]

try:
    dados = json.load(open(arquivo, encoding="utf-8"))
except Exception:
    sys.exit(0)

for pipeline in dados.get("pipelines", []):
    nome = pipeline.get("name", "")

    # a versão recém-publicada não é antiga
    if nome == atual:
        continue

    # ⚠️ Só o que é claramente versão da MESMA base. `startswith(base + "_")`
    # evita apagar `config_global_teste` ao publicar `config_globalzinho`, e
    # evita tocar em pipelines de outra finalidade.
    if not nome.startswith(base + "_"):
        continue

    identificador = pipeline.get("id")
    if identificador:
        print(f"{identificador}\t{nome}")
