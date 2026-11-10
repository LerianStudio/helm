# Fleet Management — gestão remota de configuração

O Fleet Management vem **ligado** por padrão (`fleetManagement.enabled: true`), com `url` e `username` preenchidos. O cliente fornece só o token, pelo Secret abaixo.

O cliente executa **um** comando antes do install, com os valores que entregamos
— um Secret, duas chaves:

```bash
# ⚠️ NÃO use `--from-literal` com token: DEMONSTRADO por execução — a credencial
# fica visível em `ps -eo args` enquanto o comando roda, e no histórico do shell
# depois. Qualquer usuário no host consegue ler.
#
# `read -rs` não ecoa e não vai para o histórico; `--from-file` lê de stdin.
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

read -rs TELEMETRY_TOKEN; echo
read -rs FLEET_TOKEN; echo

kubectl -n monitoring create secret generic alloy-lerian \
  --from-file=telemetry-token=<(printf '%s' "$TELEMETRY_TOKEN") \
  --from-file=fleet-token=<(printf '%s' "$FLEET_TOKEN")

unset TELEMETRY_TOKEN FLEET_TOKEN
```

Exige `bash` ou `zsh` — a substituição de processo `<(...)` não existe em `sh`. Para
uma chave só, `printf '%s' "$TOKEN" | kubectl ... --from-file=chave=/dev/stdin`
funciona em qualquer shell.

É o único passo manual. Todo o resto o chart resolve.

O chart valida quatro coisas ao habilitar, e cada uma recusa o render com mensagem
que nomeia a correção:

| Faltando | Por que é bloqueante |
|---|---|
| `url` vazia | o host varia por stack e região; construir à mão é erro documentado |
| `username` vazio | é o id numérico da stack, visível na interface |
| `ALLOY_FLEET_POD_NAME` ausente | o `remotecfg` lê a variável; sem ela o agente não inicia |
| `ALLOY_FLEET_TOKEN` com `optional: true` | **medido:** o render passava e o agente subia SEM o token — autentica, falha, e nunca recebe configuração, visível só no log do pod |

O último foi encontrado em revisão: declarar a variável não basta, ela precisa ser
obrigatória.

Há uma quinta guarda, sobre a **outra** credencial: se o perfil autentica no destino,
`ALLOY_DESTINATION_CREDENTIAL` com `optional: true` também recusa o render. O motivo é
o mesmo modo de falha, com consequência pior — o pod subiria com o header vazio, o
ponto de entrada responderia `401`, que é falha **permanente**: o dado é descartado na
hora, sem reenvio, e nada reinicia nem alerta.

### Sobre o `username`

**Não é identidade — é o ID numérico da stack, igual para todos os clientes.** Não
serve para diferenciar origem. A credencial que varia é o **token**.

## Não exige o operator

`remotecfg` é bloco de configuração do runtime do agente, não recurso de um
operator. O chart standalone é caminho suportado, e assim o `bind`/`escalate` que
o operator pediria no RBAC **fica fora do cluster**.

Ver `COMPONENTES-EXCLUIDOS.md` para o detalhe do privilégio que evitamos.

## Transporte

**Pull, HTTPS 443 de saída.** O agente pergunta ao serviço se há configuração
nova, no intervalo configurado. **Nada disca para dentro do cluster do cliente** —
é o que torna isso aceitável em rede de terceiro, sem VPN nem link privado.

Versão mínima do agente: v1.7.2. Usamos 1.21.3.

## Onde vive a sanitização com o Fleet ligado

Com `fleetManagement.enabled: true` (o padrão), a configuração local do papel `node` tem só os blocos `logging` e `remotecfg`. A cadeia de coleta desse papel, com as regras de sanitização e o exportador, vem da configuração publicada no Fleet. O papel `singleton` não recebe pipeline do Fleet: a cadeia dele, com as mesmas regras de sanitização, fica na configuração local.

A configuração publicada é o render deste chart. `sanitizacao/publicar-fleet.sh` a publica, e `sanitizacao/verificar-fleet.sh` compara o publicado com o template. Quem tem acesso à console do Fleet pode publicar por fora desse caminho. O verificador compara a configuração inteira com o render só quando `CLIENT_ID` está definido; sem `CLIENT_ID`, ele confere apenas as regras de PII das pipelines que as têm.

## Identidade do collector

O identificador é composto da marca de procedência mais o nome do pod, injetado
da metadata do objeto:

```
<origem>-<nome-do-pod>
```

**Por que não o padrão.** Se `id` é omitido, o agente gera um UUID e o persiste no
seu diretório de armazenamento. Em pod efêmero sem volume, isso é perdido a cada
reinício — produzindo identidade nova toda vez e churn no registro da frota.

`constants.hostname` também não serve: num DaemonSet resolveria para o nó, não
para o pod.

## ⚠️ Atributos: use os remotos para segmentação com significado de segurança

Existem três categorias:

| Categoria | Quem define | Pode ser falsificado |
|---|---|---|
| Reservados (`collector.os`, `collector.version`, `collector.ID`) | O serviço injeta | **Não** — a documentação afirma que não podem ser sobrescritos |
| Locais | O agente declara | **Sim** — auto-declarados, sem validação de conteúdo documentada |
| Remotos | Definidos na interface | Não, e **têm precedência** sobre os locais |

**Consequência para modelo multi-cliente:** se a segmentação de pipeline depender
de atributo **local**, um agente mal configurado poderia declarar o atributo de
outro cliente e receber configuração alheia. Para qualquer matching com
significado de segurança, use atributos **remotos**.

## O que fica obrigatoriamente local

Configuração remota é **módulo**, não configuração de topo. Estes blocos
permanecem locais:

- `logging`, `tracing`
- `remotecfg` (o próprio bloco)
- parâmetros do servidor HTTP


## Rotação do token

**Decisão: manter variável de ambiente.** É o caminho que a documentação de
onboarding mostra, e mais legível na configuração.

**Custo aceito:** variável de ambiente **não recarrega**. Trocar o token exige
reiniciar os pods — em cluster de cliente, isso é janela negociada.

A alternativa existe e fica registrada: com `password_file` e o Secret montado
como volume, o agente relê o arquivo a cada requisição, permitindo rotação sem
reinício. Se a frequência de rotação passar a doer, é a mudança a fazer.

## Verificação executada

Validado contra o binário v1.18.1, não apenas renderizado:

| Cenário | Resultado |
|---|---|
| Desligado | zero blocos `remotecfg`; config idêntica à anterior |
| Ligado, token falso | `unauthenticated: invalid token` — **o bloco foi parseado e executado** |
| Ligado, endpoint inexistente | falha de DNS, não de parse — confirma que a sintaxe é válida |
| `enabled: true` sem `url` | render falha com mensagem explicando |
| `enabled: true` sem `username` | render falha com mensagem explicando |

O erro de autenticação é a prova positiva: o agente chegou a tentar autenticar,
o que só ocorre se o bloco for sintaticamente válido.
