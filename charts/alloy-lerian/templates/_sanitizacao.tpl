{{/*
==============================================================================
REGULATED-DATA SANITISATION
==============================================================================
Not part of the values surface. There is no configuration that disables a rule,
weakens one, or produces unsanitised output. The absence of those knobs is the
guarantee, not a limitation.

Every rule here was verified by running the pinned agent against a known input
and comparing the output exactly. Three mechanics were established empirically
and are load-bearing:

  1. backreference notation is $1. The form $$1 emits the LITERAL text "$1"
     with no error, producing output that looks masked and is not
  2. replace_pattern is an EDITOR: its own statement, never nested in set()
  3. no lookahead or lookbehind — the engine rejects both at load

Identifiers stay in CLEAR by decision (2026-10-10): CPF, CNPJ, matricula,
contract numbers, UUIDs and resource ids. Masked: names, e-mail, phone, postal
address, bank account and branch, Pix keys, credentials.
*/}}
{{- define "alloy-lerian.config.sanitizacao" -}}
{{- $nome := .nome | default "sanitizacao" -}}
{{- $saida := .saida | default "otelcol.processor.batch.agrupamento.input" -}}
otelcol.processor.transform {{ $nome | quote }} {
  // "ignore" keeps a malformed rule from halting the pipeline. This is also
  // why correctness is asserted in CI rather than trusted at runtime: a wrong
  // rule produces no error, only output that appears masked.
  error_mode = "ignore"

  log_statements {
    context = "log"
    statements = [
      // --- PHONE ---
      // E.164 with country and area code: preserves both, masks the subscriber
      // number. Region is useful in diagnosis; the number is not.
      `replace_pattern(body, "(\\+[0-9]{2}[0-9]{2})[0-9]{8,9}", "$1********")`,

      // National form with separators.
      `replace_pattern(body, "(\\([0-9]{2}\\) )[0-9]{4,5}-[0-9]{4}", "$1*****-****")`,

      // --- BANK ACCOUNT AND BRANCH ---
      // ⚠️ Estas duas SO funcionam por NOME DE CAMPO — o inverso das de telefone, e
      // a razao esta no dado real. MEDIDO em Cappta-Prd:
      //
      //   account:388408                  6 digitos
      //   account:12880000007785418277   20 digitos
      //   branch:4364                     4 digitos
      //   branch:1                        1 DIGITO
      //
      // Nao existe forma que distinga `branch:1` de `gateway:6`, `method:03` ou
      // `count:7`. Uma regra por forma mascararia metade do log de plataforma.
      //
      // O nome do campo e o unico sinal disponivel, e aqui ele basta: conta e
      // agencia sempre aparecem nomeadas no log do ledger,
      // nunca soltas em texto livre. MEDIDO: 0 falso positivo em 8 entradas
      // legitimas (`bank_code:`, `ispb:`, `port=`, `count=`, `http_latency_ms:`,
      // `k8s_pod_name:`, epoch, SHA).
      //
      // ⚠️ Cobertura menor por consequencia: conta em texto livre NAO e mascarada.
      // Aceito — a alternativa corrompe diagnostico em volume.
      //
      // ⚠️ OS SUFIXOS SAO ENUMERADOS, e nao `[A-Za-z]*`, de proposito.
      //
      // A primeira versao aceitava so `account=`, `account_number=`, `branch=` e
      // `agency=` exatos. MEDIDO contra o log do Banqi: nao mascarava nada la, porque
      // os campos sao camelCase com sufixo — `accountNumberDestination`, `agencyNumber`
      // — e nem `accountNumber=` sozinho casava.
      //
      // Alargar para `account[A-Za-z]*[=:]` resolveria a cobertura e abriria dois
      // falsos positivos MEDIDOS:
      //
      //   accountingPeriod=202608  -> accountingPeriod=********
      //   branchless=0             -> branchless=****
      //
      // Enumerar `_?number` e a lista de papeis (origin|destination|source|target|
      // from|to) cobre as formas reais e recusa as duas acima. Verificado: 15 formas
      // que devem mascarar, 14 entradas legitimas que nao devem — 0 falha nas duas
      // direcoes.
      //
      // ⚠️ Um campo com sufixo FORA da lista volta a passar em claro. E o preco de
      // nao ter falso positivo, e a razao de a lista estar visivel aqui em vez de
      // escondida num `*`: acrescentar um sufixo novo e uma linha, e o caso de teste
      // correspondente prova que funcionou.
      `replace_pattern(body, "(?i)((?:conta |account(?:_?number)?(?:origin|destination|source|target|from|to)?[=:]))([0-9]{4,})", "$1********")`,
      `replace_pattern(body, "(?i)((?:ag[eê]ncia |(?:agency|branch)(?:_?number)?(?:origin|destination|source|target|from|to)?[=:]))([0-9]+)", "$1****")`,

      // --- PERSON NAME ---
      // Anchored on capitalisation: name terms start uppercase and the
      // surrounding log text is lowercase, which delimits the value without a
      // lookbehind. This is a PREMISE about how applications log, not a
      // guarantee — an application logging names in a different case would not
      // match.
      //
      // ONE rule, and it masks EVERY term after the first. There were two before
      // (3+ terms, then exactly 2) and both leaked, which is worse than not
      // masking because the output looks protected:
      //
      //   Ana Silva              -> "Ana ********** Silva"   full name readable
      //   Ana Beatriz Costa Lima -> "Ana ********** Lima"    surname preserved
      //
      // The surname is the most identifying term, so preserving it defeats the
      // rule. The given name is kept for legibility in diagnosis; everything
      // after it goes. Verified: 1 term is left alone, 2/3/4 terms are fully
      // masked, and a following `key=value` field is not consumed.
      //
      // ⚠️ PARTICULA MINUSCULA (`da`, `de`, `dos`, `e`) faz parte do termo seguinte,
      // nao encerra o nome. Sem isto a regra PARAVA na particula e o sobrenome
      // vazava — e em nome brasileiro a particula e o caso comum, nao a excecao.
      //
      // MEDIDO em bancada (2026-10-07, agente real, cadeia servida pelo Fleet), as
      // duas formas lado a lado na MESMA execucao:
      //
      //   {"customerName":"Joao Carlos Silva"} -> {"customerName":"Joao **********"}
      //   {"customerName":"Joao da Silva"}     -> {"customerName":"Joao da Silva"}
      //
      // A segunda saiu INTACTA. A porta de entrega nao pegava porque o caso
      // canonico usa tres termos capitalizados — ha agora um caso para a particula.
      //
      // A particula e aceita apenas ENTRE termos: ela nao pode iniciar nem encerrar
      // a captura, entao `cliente da empresa` continua sem casar e a ancora de
      // capitalizacao segue valendo.
      `replace_pattern(body, "((?:customer|sender|recipient|receiver|client|holder)(?:Name|_name)\\W{1,4})(\\p{Lu}[\\p{L}]*)(?: (?:(?i:d[aeio]s?|e|y|del|la) )?\\p{Lu}[\\p{L}]*)+", "$1$2 **********")`,

      // --- EMAIL ADDRESS ---
      // Preserves two characters of the local part and the WHOLE domain. The
      // domain identifies the provider or corporate client, not the person,
      // and is genuinely useful in diagnosis.
      `replace_pattern(body, "([A-Za-z0-9]{1,2})[A-Za-z0-9._%+-]*(@[A-Za-z0-9.-]+\\.[A-Za-z]{2,})", "$1****$2")`,

      // --- PIX KEY ---
      // By key label: a key can be a CPF, CNPJ or UUID, which stay in clear unlabelled.
      // \x22 is the JSON double quote; a literal one would hide the rule from the
      // extractor that diffs this file against regras.alloy and Fleet.
      `replace_pattern(body, "(?i)((?:chave_?pix|pix_?key)\\x22?[=:] ?\\x22?)[^\\s\\x22,;}]+", "$1**********")`,

      // --- POSTAL ADDRESS ---
      // Masked ENTIRELY. Unlike an email domain or a phone area code, any
      // fragment of an address sharply narrows the search space for a person.
      // The only class with no preserved part, and that is deliberate.
      `replace_pattern(body, "((?:address|street|logradouro|endereco)[=:] ?)[\\p{Lu}0-9][^=]*?( [a-z_]+[=:]|$)", "$1**********$2")`,

      // --- AUTHENTICATION CREDENTIAL ---
      // Different in kind from every rule above: those protect data that
      // IDENTIFIES someone, this protects a value that GRANTS ACCESS. A leaked
      // credential is not a privacy incident, it is an authenticated session in
      // someone else's hands — and it stays exploitable until it expires.
      //
      // The SCHEME NAME is preserved and nothing else. "Bearer" versus "Basic"
      // is what makes an authentication failure diagnosable; no fragment of the
      // credential itself has diagnostic value, and preserving a JWT prefix
      // would disclose the signing algorithm. Second class with no preserved
      // part, for a different reason than postal address.
      //
      // Scheme names are case-sensitive and key forms need `=`/`:`, so prose such
      // as "invalid token signature" or "basic validation failed" stays readable.
      `replace_pattern(body, "((?:Bearer|Basic|Digest) |(?i:token|apikey|api_key)[=:] ?)[A-Za-z0-9._~+/=-]{8,}", "$1**********")`,

      // Assignment form, where the scheme is not what precedes the value:
      // password=, secret=, client_secret=, access_token=. The KEY is preserved
      // because knowing WHICH credential appeared is what makes a leak
      // actionable — you cannot rotate what you cannot name.
      `replace_pattern(body, "(?i)((?:password|passwd|senha|secret|client_secret|access_token|refresh_token|private_key)[=:] ?)[^\\s,;}]+", "$1**********")`,
    ]
  }

  output {
    logs = [{{ $saida }}]
  }
}
{{- end -}}
