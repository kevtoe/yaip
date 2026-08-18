# Contributing to Yaip

Thanks for helping make local Mac dictation better.

## Before opening a change

- Keep Yaip focused on fast dictation, local transcription and recoverable
  history.
- Keep interface copy short and plain.
- Do not add analytics, accounts, remote transcription or hidden network calls.
- Never commit credentials, signing material, personal paths, model caches,
  dictation data or release artefacts.

## Development

You need an Apple Silicon Mac, macOS 14 or later, Xcode and XcodeGen.

```bash
brew install xcodegen
./Scripts/audit-public.sh
./Scripts/build.sh test
./Scripts/build.sh build
```

Run builds through `Scripts/build.sh` so project generation and architecture
settings stay consistent.

## Pull requests

Explain the user problem, keep the change narrow and include tests where the
behaviour can regress. For interface changes, include a screenshot with
fictional content only.
