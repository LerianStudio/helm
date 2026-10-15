# Helm Upgrade from v9.2.7 to v9.2.8

## Topics

- **[Fixes](#fixes)**
  - [1. RabbitMQ bootstrap password rotation and security hardening](#1-rabbitmq-bootstrap-password-rotation-and-security-hardening)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. RabbitMQ bootstrap password rotation and security hardening

The RabbitMQ bootstrap job has been updated to support password rotation and prevent password exposure in RabbitMQ definitions files.

#### What changed

The `bootstrap-rabbitmq.yaml` template now implements a more secure and idempotent method for managing RabbitMQ users. The bootstrap job now:

1. **Strips user definitions from the ConfigMap**: The `transaction` and `consumer` users are no longer included in the `load_definitions.json` file to prevent their passwords from being overwritten with default values
2. **Uses PUT instead of POST**: User passwords are now updated via `PUT /api/users/{username}` before applying definitions, ensuring password rotation converges on every run
3. **Validates passwords**: Adds a check to reject passwords containing control characters that could break JSON escaping
4. **Improves hook ordering**: The ConfigMap now uses Helm and ArgoCD hooks to ensure it's created before the Job runs during upgrades

**Before (v9.2.7):**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: midaz-bootstrap-rabbitmq-definitions
  namespace: {{ .Release.Namespace }}
data:
  load_definitions.json: |
{{ .Files.Get "files/rabbitmq/load_definitions.json" | indent 4 }}
```

```bash
echo "Checking if RabbitMQ users already exist..."

# Check if key users exist (transaction, consumer)
TRANSACTION_EXISTS=$(curl -sSk -u "$RABBITMQ_ADMIN_USER:$RABBITMQ_ADMIN_PASS" \
  "$BASE_URL/api/users/transaction" 2>/dev/null || echo "not_found")
CONSUMER_EXISTS=$(curl -sSk -u "$RABBITMQ_ADMIN_USER:$RABBITMQ_ADMIN_PASS" \
  "$BASE_URL/api/users/consumer" 2>/dev/null || echo "not_found")

if echo "$TRANSACTION_EXISTS" | grep -q '"name":"transaction"' && \
   echo "$CONSUMER_EXISTS" | grep -q '"name":"consumer"'; then
  echo "RabbitMQ definitions already applied (users transaction and consumer exist). Skipping."
  exit 0
fi

echo "Applying RabbitMQ definitions from file..."
# ... POST definitions ...

echo "Updating RabbitMQ user: transaction..."
# ... PUT transaction user ...

echo "Updating RabbitMQ user: consumer..."
# ... PUT consumer user ...
```

**After (v9.2.8):**

```yaml
{{- $defs := .Files.Get "files/rabbitmq/load_definitions.json" | fromJson }}
{{- $perms := list }}
{{- range $defs.permissions }}{{ if has .user (list "transaction" "consumer") }}{{ $perms = append $perms . }}{{ end }}{{ end }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: midaz-bootstrap-rabbitmq-definitions
  namespace: {{ .Release.Namespace }}
  annotations:
    argocd.argoproj.io/hook: Sync
    helm.sh/hook: post-install,pre-upgrade
    helm.sh/hook-weight: "-1"
    helm.sh/hook-delete-policy: before-hook-creation
data:
  load_definitions.json: {{ set (omit $defs "users") "permissions" $perms | toJson | quote }}
```

```bash
case "$RABBITMQ_TRANSACTION_PASS$RABBITMQ_CONSUMER_PASS" in *[[:cntrl:]]*)
  echo "A RabbitMQ app password (transaction or consumer) contains a control character; choose one without."
  exit 1;;
esac

# Every run PUTs both users, then POSTs the definitions (their permissions need the users),
# so a rotated password converges. The password is JSON-escaped.
put_user() {
  echo "Updating RabbitMQ user: $1..."
  PASS=$(printf '%s' "$2" | sed 's/[\\"]/\\&/g')
  HTTP_CODE=$(curl -sSk -o /tmp/response.txt -w "%{http_code}" \
    -u "$RABBITMQ_ADMIN_USER:$RABBITMQ_ADMIN_PASS" \
    -H "content-type: application/json" \
    -X PUT \
    --data "{\"password\":\"$PASS\",\"tags\":\"administrator\"}" \
    "$BASE_URL/api/users/$1")
  if [ "$HTTP_CODE" -lt 200 ] || [ "$HTTP_CODE" -ge 300 ]; then
    echo "Error updating $1 user (HTTP $HTTP_CODE):"
    cat /tmp/response.txt
    exit 1
  fi
  echo "Done."
}
put_user transaction "$RABBITMQ_TRANSACTION_PASS"
put_user consumer "$RABBITMQ_CONSUMER_PASS"

echo "Applying RabbitMQ definitions from file..."
# ... POST definitions ...
```

#### Why it matters

This change addresses several operational and security concerns:

1. **Password rotation support**: Previously, changing the `transaction` or `consumer` passwords in your Helm values would not take effect if the users already existed. The bootstrap job would skip execution, leaving the old passwords in place. Now, the job runs on every upgrade and updates passwords via `PUT`, ensuring password rotation converges.

2. **Security**: User definitions in the `load_definitions.json` file previously contained default passwords. If the definitions were posted after users were created with secret passwords, the default passwords would overwrite the live ones. The new implementation removes users from the definitions file entirely.

3. **Idempotency**: The job now runs unconditionally and is safe to execute multiple times. It no longer skips execution based on user existence checks.

4. **JSON escaping**: Passwords are now properly escaped for JSON, preventing injection issues with special characters (except control characters, which are explicitly rejected).

#### Impact

- **Scope**: The bootstrap job only renders when `global.externalRabbitmqDefinitions.enabled: true` (an external broker). Installs that use the bundled RabbitMQ subchart are not affected by this release.
- **Behavior change**: The bootstrap job no longer skips when the `transaction` and `consumer` users already exist. On every `helm upgrade` it sets both users' passwords on the broker to the values in `global.externalRabbitmqDefinitions.appCredentials` (or the Secret named in `appCredentials.useExistingSecret.name`, keys `RABBITMQ_DEFAULT_PASS` and `RABBITMQ_CONSUMER_PASS`).
- **Password rotation**: Operators can now rotate RabbitMQ passwords by updating Helm values and running `helm upgrade`
- **Validation**: The job will fail early if passwords contain control characters (newlines, tabs, etc.)
- **Connections**: The ledger authenticates with `ledger.secrets.RABBITMQ_DEFAULT_PASS` and `ledger.secrets.RABBITMQ_CONSUMER_PASS` (or `ledger.existingSecretName`), which are separate values from `appCredentials`. If the two differ, the broker is switched to the `appCredentials` passwords and the ledger fails to authenticate the next time it connects.
- **ArgoCD compatibility**: The ConfigMap now uses sync hooks to ensure proper ordering in ArgoCD-managed deployments

> **Warning:** If you have previously rotated RabbitMQ passwords outside of Helm (e.g., via the RabbitMQ management UI or API), or if `appCredentials` still holds placeholder or outdated values because v9.2.7 skipped existing users, those values will overwrite the live passwords during this upgrade.

> **Warning:** If your RabbitMQ passwords contain control characters (ASCII 0-31 or 127), the bootstrap job will fail with a validation error. Update your passwords to use only printable characters before upgrading.

#### Action required

**If you use an external broker (`global.externalRabbitmqDefinitions.enabled: true`)**, before upgrading make sure the bootstrap credentials match the passwords the ledger uses and the broker holds today:

| Bootstrap value | Must equal |
|-----------------|------------|
| `global.externalRabbitmqDefinitions.appCredentials.transactionPassword` | `ledger.secrets.RABBITMQ_DEFAULT_PASS` |
| `global.externalRabbitmqDefinitions.appCredentials.consumerPassword` | `ledger.secrets.RABBITMQ_CONSUMER_PASS` |

If you use Secrets instead, `appCredentials.useExistingSecret.name` must point to a Secret whose `RABBITMQ_DEFAULT_PASS` and `RABBITMQ_CONSUMER_PASS` keys hold the same passwords as the ledger's.

**If you use the bundled RabbitMQ:** No action required.

**To rotate RabbitMQ passwords during upgrade:**

1. Update both the bootstrap credentials and the ledger's passwords to the same new values:

```yaml
global:
  externalRabbitmqDefinitions:
    enabled: true
    appCredentials:
      transactionPassword: "new-secure-password-1"
      consumerPassword: "new-secure-password-2"
ledger:
  secrets:
    RABBITMQ_DEFAULT_PASS: "new-secure-password-1"
    RABBITMQ_CONSUMER_PASS: "new-secure-password-2"
```

2. Run the upgrade:

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.8 -n midaz
```

3. The bootstrap job will update the passwords automatically. Monitor the job logs:

```bash
kubectl logs -n midaz -l job-name=midaz-bootstrap-rabbitmq --tail=100 -f
```

4. Restart the ledger so its pods pick up the new passwords (v9.2.8 does not restart pods when their Secret changes):

```bash
kubectl -n midaz rollout restart deployment/midaz-ledger
```

**If the bootstrap job fails after upgrade:**

1. Check the job logs for validation errors:

```bash
kubectl logs -n midaz -l job-name=midaz-bootstrap-rabbitmq --tail=50
```

2. If you see "A RabbitMQ app password contains a control character", update your passwords to remove control characters and re-run the upgrade.

3. If you see HTTP errors during user updates, verify the credentials in `global.externalRabbitmqDefinitions.rabbitmqAdminLogin` (`username`/`password`, or `useExistingSecret.name` with keys `RABBITMQ_ADMIN_USER`/`RABBITMQ_ADMIN_PASS`) and that this user has the `administrator` tag.

> **Note:** This change does not modify the structure of your `values.yaml` configuration.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.8 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.8 -n midaz
```
