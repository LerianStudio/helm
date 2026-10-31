#!/usr/bin/env python3
"""Devolve o id de uma pipeline publicada, ou vazio se ela nao existe.

Uso: publicar-fleet-id.py <resposta-listpipelines.json> <nome>

Existe porque `CreatePipeline` falha se o nome ja existe e `DeletePipeline` exige
o id — o publicador precisa saber qual caminho tomar.
"""
import json
import sys

if len(sys.argv) < 3:
    sys.exit(0)

try:
    dados = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    print("")
    sys.exit(0)

for pipeline in dados.get("pipelines", []):
    if pipeline.get("name") == sys.argv[2]:
        print(pipeline.get("id", ""))
        sys.exit(0)
print("")
