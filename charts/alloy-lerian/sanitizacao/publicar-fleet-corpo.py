#!/usr/bin/env python3
"""Monta o corpo JSON do CreatePipeline a partir da config renderizada.

Uso: publicar-fleet-corpo.py <arquivo-config> <nome-pipeline> <client_id>

⚠️ O MATCHER DELIMITA O DESTINATARIO, e e a unica separacao entre clientes que
existe: o escopo minimo de uma access policy do Fleet e a STACK INTEIRA. Sem
`client_id` no matcher, a config de um cliente iria para os coletores de todos.
"""
import json
import sys

if len(sys.argv) < 4:
    print("uso: publicar-fleet-corpo.py <config> <nome> <client_id>", file=sys.stderr)
    sys.exit(2)

arquivo, nome, client_id = sys.argv[1:4]
conteudo = open(arquivo, encoding="utf-8").read()

print(json.dumps({
    "pipeline": {
        "name": nome,
        "contents": conteudo,
        # role="node" porque o singleton tem config e ciclo proprios.
        "matchers": [
            'collector.os="linux"',
            'role="node"',
            f'client_id="{client_id}"',
        ],
        "enabled": True,
    }
}))
