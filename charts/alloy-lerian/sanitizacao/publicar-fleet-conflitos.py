#!/usr/bin/env python3
"""Lista modulos que ja escutam a mesma porta para o mesmo cliente.

Separado do publicar-fleet.sh porque heredoc aninhado em bash e fragil — quebrou o
script duas vezes nesta frente antes de eu parar de tentar embutir.

Uso: publicar-fleet-conflitos.py <resposta-listpipelines.json> <nome> <client_id> <porta>

⚠️ POR QUE ESTA VERIFICACAO EXISTE

MEDIDO na primeira publicacao real: havia um modulo publicado A MAO com outro NOME
e o mesmo matcher. Os dois casaram o mesmo coletor, disputaram a porta 4319, e o
segundo falhou com "address already in use".

O log seguiu funcionando pelo primeiro — a falha era SILENCIOSA do ponto de vista
do dado, aparecendo so no log do agente. E qual dos dois vence depende da ordem de
carga, que nao e deterministica.
"""
import json
import sys

if len(sys.argv) < 5:
    sys.exit(0)

arquivo, nome_meu, client_id, porta = sys.argv[1:5]

try:
    dados = json.load(open(arquivo, encoding="utf-8"))
except Exception:
    sys.exit(0)

for pipeline in dados.get("pipelines", []):
    # o meu proprio sera ATUALIZADO, nao duplicado — nao e conflito
    if pipeline.get("name") == nome_meu:
        continue
    if not pipeline.get("enabled", True):
        continue

    conteudo = pipeline.get("contents", "") or ""
    if porta not in conteudo:
        continue

    # So conflita se o matcher alcancar o mesmo coletor. Matcher SEM client_id
    # alcanca todos — entao conta como conflito por precaucao.
    matchers = " ".join(pipeline.get("matchers", []) or [])
    if f'client_id="{client_id}"' in matchers or "client_id" not in matchers:
        print(pipeline.get("name", "(sem nome)"))
