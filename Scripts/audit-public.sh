#!/bin/bash
# Fast checks for files and strings that should never enter the public project.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if find . -type f \
    \( -name '.env' -o -name '*.pem' -o -name '*.p12' -o -name '*.mobileprovision' \
       -o -name '*.key' -o -name '*.cer' -o -name '*.pyc' \) -print | grep -q .; then
    echo "Credential or signing material found in the project." >&2
    exit 9
fi

if find . -type d -name '__pycache__' -print | grep -q .; then
    echo "Generated Python cache found in the project." >&2
    exit 9
fi

if rg -n --hidden --glob '!.git/**' --glob '!Scripts/*.sh' \
    '(/Users/[^/]+/|DEVELOPMENT_TEAM:[[:space:]]*[A-Z0-9]+|BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|gh[opsu]_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{20,})' .; then
    echo "A local path, team identifier or credential-like value was found." >&2
    exit 9
fi

if rg -n --hidden --glob '!.git/**' --glob '!Scripts/audit-public.sh' \
    '(YAIP_INTERNAL|OpenAICompatible|CloudProfile|KeychainStore|WAVEncoder|API[ _-]?key|managed[ _-]?network|corporate[ _-]?device)' .; then
    echo "Private build or remote transcription content was found." >&2
    exit 9
fi

if rg -n --hidden --glob '!.git/**' --glob '!Scripts/audit-public.sh' \
    '(dictation-history\.json|Application Support/Yaip|Library/Developer/Xcode/DerivedData)' \
    README.md docs .github 2>/dev/null; then
    echo "Private runtime or development paths were found in public presentation files." >&2
    exit 9
fi

echo "Public source audit passed."
