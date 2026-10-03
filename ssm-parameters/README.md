# ssm-parameters

SSM parameters that no Terraform module owns — mostly secrets for **TENANT**'s
applications — declared in [ssm-parameters.json](ssm-parameters.json) and reconciled
by [bin/ssm-put-parameters](bin/ssm-put-parameters), one parameter at a time:
`CREATE`, `UPDATE`, `NO CHANGE` or `TYPE DRIFT` (which is refused, never fixed).

```bash
make check               # the manifest's shape; no AWS, no values
make plan  ENV=dev       # what would change; writes nothing
make apply ENV=dev
```

## Adding a parameter

1. Add an entry to `parameters`:
   ```json
   {
     "name": "/__PREFIX__/{environment}/payments/api_key",
     "type": "String",
     "source_env": "PAYMENTS_API_KEY",
     "description": "Read by the payments service as PAYMENTS_API_KEY"
   }
   ```
2. A sensitive value comes from a **GitHub environment secret** (never a variable —
   variables are not masked): add it to the `dev` and `production` environments, and map
   it onto `source_env` in the `env:` block of
   [.github/workflows/ssm-parameters.yml](../.github/workflows/ssm-parameters.yml).
3. Open a pull request: the workflow runs `plan` in dev. On merge it applies in dev, then
   in production behind the environment's reviewers.

## Rules

- **`/platform/<env>/*` belongs to Terraform** (`infrastructure/`); never declare it here.
- **Values never pass through argv**: the script writes with `--cli-input-json` from a
  0600 temp file, and re-masks every `source_env` value in the Actions log.
- **A type cannot change in place.** `put-parameter` refuses it, and so does the script:
  delete the parameter by hand, knowing every reader breaks until it is written again.
