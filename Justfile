set shell := ["bash", "-uc"]
set quiet

[no-quiet]
default:
    @just --list

encrypt:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -f ".env" ]; then
        echo "Encrypting .env..."
        sops encrypt --input-type dotenv --output-type dotenv .env > .env.enc
        echo "Done. Encrypted to .env.enc"
    else
        echo "Error: .env not found"
        exit 1
    fi

decrypt:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -f ".env.enc" ]; then
        echo "Decrypting .env.enc..."
        sops decrypt --input-type dotenv --output-type dotenv .env.enc > .env
        echo "Done. Decrypted to .env"
    else
        echo "Error: .env.enc not found"
        exit 1
    fi

edit-env:
    sops --input-type dotenv --output-type dotenv .env.enc

# Push all secrets from .env to GitHub Actions
push-secrets:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -f ".env" ]; then
        echo "Error: .env not found. Run 'just decrypt' first."
        exit 1
    fi
    while IFS='=' read -r key value; do
        [[ -z "$key" || "$key" == \#* ]] && continue
        echo "Setting ${key}..."
        echo -n "${value}" | gh secret set "${key}" --repo pseudobun/tossinger
    done < .env
    echo "All secrets pushed."
