#!/usr/bin/env python3
"""Classifica os exportadores de cada pipeline publicada no Fleet.

Separado do verificar-fleet.sh porque a logica precisa de regex sobre endpoint, e
heredoc aninhado em bash e fragil — a primeira tentativa de embutir isto quebrou o
script inteiro.

Saida, uma linha por pipeline com exportador, campos separados por TAB:

    nome <TAB> habilitada(sim|nao) <TAB> papel(ponte|fuga) <TAB> detalhe

⚠️ O CRITERIO E PARA ONDE O EXPORTADOR APONTA, nao o fato de existir.

O modo ponte exige exportador: o modulo publicado recebe o log, mascara, e devolve
ao fluxo local. Um exportador para `localhost:<porta de retorno>` e a ponte
funcionando; para qualquer endereco externo, e caminho de fuga que escapa da
allowlist e do perimetro.

Medido nesta frente: 82 series de kube_replicaset_owner — que a allowlist CORTA —
chegaram na Grafana Cloud por um pipeline de teste com exportador proprio. E o que
este passo existe para pegar.
"""
import json
import os
import re
import sys

PORTA = os.environ.get("PORTA", "4320")

# Devolucao ao fluxo local: SO localhost/127.0.0.1 na porta de retorno declarada
# pelo chart. Outra porta em localhost nao tem receptor — e erro ou desvio.
DEVOLVE = re.compile(
    r"https?://(?:localhost|127\.0\.0\.1):" + re.escape(PORTA) + r"(?:/|$)"
)

# `debug` escreve no log do proprio agente: nao sai do processo, nao e fuga.
NAO_E_SAIDA = {"otelcol.exporter.debug"}

try:
    dados = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    sys.exit(0)

for pipeline in dados.get("pipelines", []):
    conteudo = pipeline.get("contents", "") or ""

    exportadores = set(
        re.findall(
            r"(prometheus\.remote_write|loki\.write|otelcol\.exporter\.\w+)", conteudo
        )
    )
    exportadores -= NAO_E_SAIDA
    if not exportadores:
        continue

    # Endpoints com esquema http(s) sao de exportador; receptor usa host:porta nu.
    endpoints = re.findall(r'endpoint\s*=\s*"([^"]+)"', conteudo)
    externos = [
        e
        for e in endpoints
        if e.startswith(("http://", "https://")) and not DEVOLVE.match(e)
    ]

    # ⚠️ Exportador declarado SEM endpoint visivel conta como externo: pode estar
    # usando o padrao do componente, que nao e localhost. Na duvida, bloqueia.
    if not endpoints and exportadores:
        externos = sorted(exportadores)

    habilitada = pipeline.get("enabled", True)
    papel = "fuga" if externos else "ponte"
    detalhe = ",".join(sorted(externos)) if externos else f"devolve p/ localhost:{PORTA}"

    print(
        "\t".join(
            [
                pipeline.get("name", "(sem nome)"),
                "sim" if habilitada else "nao",
                papel,
                detalhe,
            ]
        )
    )
