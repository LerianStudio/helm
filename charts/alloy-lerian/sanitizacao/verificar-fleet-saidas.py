#!/usr/bin/env python3
"""Classifica os exportadores de cada pipeline publicada no Fleet.

Separado do verificar-fleet.sh porque a logica precisa de regex sobre endpoint, e
heredoc aninhado em bash e fragil — a primeira tentativa de embutir isto quebrou o
script inteiro.

Saida, uma linha por pipeline com exportador, campos separados por TAB:

    nome <TAB> habilitada(sim|nao) <TAB> papel(legitimo|fuga) <TAB> detalhe

⚠️ O CRITERIO E PARA ONDE O EXPORTADOR APONTA, nao o fato de existir.

Com a configuracao COMPLETA vindo do Fleet, a pipeline publicada exporta para o
nosso destino — e isso e o funcionamento normal, nao uma fuga. O que caracteriza
fuga e apontar para OUTRO lugar.

Medido nesta frente, e a razao de este passo existir: 82 series de
kube_replicaset_owner — que a allowlist CORTA — chegaram na Grafana Cloud por um
pipeline de teste com exportador proprio, apontando para fora.

⚠️ Este passo e a SEGUNDA camada. A primeira e o passo 5 do verificador, que
compara a config publicada inteira com o render do chart: trocar o endpoint por
outro seria acusado la tambem.
"""
import json
import os
import re
import sys

# Destino legitimo: o `destination.endpoint` do chart. Vem do ambiente porque
# varia por instalacao; sem ele, so localhost e considerado legitimo.
DESTINO = os.environ.get("DESTINO_ESPERADO", "").rstrip("/")

# A porta de retorno da ponte. Mantida por compatibilidade: pipelines de ponte
# publicadas antes da migracao para o Fleet completo ainda existem em alguns
# ambientes, e acusa-las como fuga seria falso positivo.
PORTA = os.environ.get("PORTA", "4320")

LOCAL = re.compile(r"https?://(?:localhost|127\.0\.0\.1):" + re.escape(PORTA) + r"(?:/|$)")

# `debug` escreve no log do proprio agente: nao sai do processo, nao e fuga.
NAO_E_SAIDA = {"otelcol.exporter.debug"}


def e_legitimo(endpoint: str) -> bool:
    """O destino e o nosso, ou a devolucao interna da ponte?"""
    if LOCAL.match(endpoint):
        return True
    if DESTINO and endpoint.rstrip("/") == DESTINO:
        return True
    return False


def main() -> None:
    try:
        dados = json.load(open(sys.argv[1], encoding="utf-8"))
    except Exception:
        return

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

        endpoints = re.findall(r'endpoint\s*=\s*"([^"]+)"', conteudo)
        externos = [
            e
            for e in endpoints
            if e.startswith(("http://", "https://")) and not e_legitimo(e)
        ]

        # ⚠️ Exportador declarado SEM endpoint visivel conta como externo: pode
        # estar usando o padrao do componente, que nao e o nosso destino. Na
        # duvida, bloqueia.
        if not endpoints and exportadores:
            externos = sorted(exportadores)

        habilitada = pipeline.get("enabled", True)
        papel = "fuga" if externos else "legitimo"
        if externos:
            detalhe = ",".join(sorted(externos))
        elif any(LOCAL.match(e) for e in endpoints):
            detalhe = f"devolve p/ localhost:{PORTA}"
        else:
            detalhe = f"exporta p/ o destino esperado"

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


if __name__ == "__main__":
    main()
