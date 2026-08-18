# Yaip distribution

## Support

- macOS 14 or later
- Apple Silicon only
- Drag-to-Applications DMG

Yaip needs Microphone, Accessibility and Input Monitoring permission for global
dictation. macOS asks the user for these permissions after installation.

## Local QA candidate

Requirements: Xcode, XcodeGen, `create-dmg` and Python 3.

```bash
./Scripts/build.sh test
./Scripts/build.sh integration
./Scripts/build.sh release
```

Candidate files include `UNNOTARIZED` in their name and must not be published.

## Public release

The signing team is supplied at runtime and is never stored in this repository.

```bash
YAIP_DEVELOPMENT_TEAM=<team> ./Scripts/build.sh public-release
```

The release pipeline:

1. Audits the public source.
2. Builds an arm64 release with hardened runtime.
3. Adds and verifies the pinned Whisper Tiny model.
4. Signs and notarises the exact model-bearing app.
5. Runs a bundled-model transcription smoke test.
6. Verifies code signing, Gatekeeper and the disk image.
7. Emits the DMG, SHA-256 checksum and JSON metadata in `dist/`.

Never publish an artefact whose name contains `UNNOTARIZED`.

## Model provenance

- WhisperKit model: `argmaxinc/whisperkit-coreml`, revision
  `97a5bf9bbc74c7d9c12c755d04dea59e672e3808`, variant
  `openai_whisper-tiny`
- Tokenizer and model card: `openai/whisper-tiny`, revision
  `169d4a4341b33bc18d8881c4b69c2e104e1cc0af`

Every bundled file is pinned by size and SHA-256. The app includes the relevant
licences and notices.

## Release checks

```bash
./Scripts/audit-public.sh
./Scripts/build.sh test
./Scripts/build.sh verify-public-boundary
```

Before publishing, also test installation, first-run permissions, dictation and
text insertion on a clean Apple Silicon Mac. Automatic updates are not yet
implemented, so releases are distributed as versioned DMGs with checksums.
