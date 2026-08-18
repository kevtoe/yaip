#!/usr/bin/env python3
"""Stage a pinned, verified Whisper Tiny bundle for a Yaip release."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import tempfile
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path


ARGMAX_REPO = "argmaxinc/whisperkit-coreml"
ARGMAX_REVISION = "97a5bf9bbc74c7d9c12c755d04dea59e672e3808"
OPENAI_REPO = "openai/whisper-tiny"
OPENAI_REVISION = "169d4a4341b33bc18d8881c4b69c2e104e1cc0af"


@dataclass(frozen=True)
class Asset:
    group: str
    repo: str
    revision: str
    remote_path: str
    destination: str
    sha256: str
    bytes: int


MODEL_FILES = [
    ("AudioEncoder.mlmodelc/analytics/coremldata.bin", "0b25820e5b2ab0b0686b4bea147fb217d1d1bface45170ff4ffde01fa6864ae2", 243),
    ("AudioEncoder.mlmodelc/coremldata.bin", "142c33ade402fe41952059f175eb855093dfe09b5d2b84624a31e3a9952ed47d", 347),
    ("AudioEncoder.mlmodelc/metadata.json", "5dde769b4120fb9839440f0968d6da48c7d9027a70f1d73f44cb3257b1093791", 1859),
    ("AudioEncoder.mlmodelc/model.mil", "69048dfa0f9e43591d57e2cad7dbc871159fe884b2d17ae8399921540ecb5809", 307978),
    ("AudioEncoder.mlmodelc/model.mlmodel", "030d64a3ddd296d6f709691a66a870aab7ee9f19e5fe07e8086245fb85302802", 54965),
    ("AudioEncoder.mlmodelc/weights/weight.bin", "bcd0879f6d1c61832765c7ec05d883d0dcbf1504057b13095fd315484196fc5e", 16422784),
    ("MelSpectrogram.mlmodelc/analytics/coremldata.bin", "7f77e6457285248f99cd7aa3fd4cc2efbb17733e63e7023ac53abe1f95785d07", 243),
    ("MelSpectrogram.mlmodelc/coremldata.bin", "dabdc5aa69f6ef4d97dc9499f5c30514e00e96b53b750b33a5a6471363c71662", 328),
    ("MelSpectrogram.mlmodelc/metadata.json", "f2b08d80d9cdd39fc0ccdbb5fac86a5f8dd9bcaa839706c3568be6fe8abd82d4", 1848),
    ("MelSpectrogram.mlmodelc/model.mil", "b8063d8e57c113472ac7c2d248e44383568a018978a753c1884ac406b997a374", 10176),
    ("MelSpectrogram.mlmodelc/weights/weight.bin", "5b65b76f4e1dab57239e3946f6ab1314a7d1fdfa114485683dd04476ca62adb6", 354080),
    ("TextDecoder.mlmodelc/analytics/coremldata.bin", "bfbe102ae5fb9368974a077f780441dd222fdfb0c7778c1df227ef6a73cbaada", 243),
    ("TextDecoder.mlmodelc/coremldata.bin", "292f96416a33f9a80aaa62ead3dd5206aee6c5e6b3ac6cc02c059d38cbf04c6a", 633),
    ("TextDecoder.mlmodelc/metadata.json", "01e8288ac875d02cd7155a715727f2732141bc3ea7519bcb43be0f407c7e9c28", 4752),
    ("TextDecoder.mlmodelc/model.mil", "04224ea00c5d1b3e6a00c33b7b4dafd43434a68ccf3e3fdb42cb221911b945ae", 141140),
    ("TextDecoder.mlmodelc/model.mlmodel", "1afdfc3a8f3e8d6afc46e1ecc5fb216eadccbf82d9c568e7dbd3955143a1cd0e", 113134),
    ("TextDecoder.mlmodelc/weights/weight.bin", "d0313e1a4ffa88538c141cc3c73e6eb0e3dc54db9d574b21c7c034de688e4951", 59216434),
    ("config.json", "9b59f5e09030bd142035cb2e1456c9edfaf6de11194b79d9d05f27a86571a74c", 1464),
    ("generation_config.json", "45738853cc16804f73edfa036a56409cc7403ab99424876fc1abe0a9ccf5c6f2", 2746),
]

TOKENIZER_FILES = [
    ("config.json", "ffdccec4f3211f4c63310f2b7098f309fe70f3952cedc5e4d11e43f5b2379b98", 1983),
    ("tokenizer.json", "27fc476bfe7f17299480be2273fc0608e4d5a99aba2ab5dec5374b4482d1a566", 2480466),
    ("tokenizer_config.json", "2a4c4281cf9f51ac6ccc406fdc711a087afe6530f671fa7b80953edc498275ce", 282683),
]


ASSETS = [
    Asset(
        "Model", ARGMAX_REPO, ARGMAX_REVISION,
        f"openai_whisper-tiny/{relative}", f"Model/{relative}", digest, size,
    )
    for relative, digest, size in MODEL_FILES
] + [
    Asset(
        "Tokenizer", OPENAI_REPO, OPENAI_REVISION,
        relative, f"Tokenizer/{relative}", digest, size,
    )
    for relative, digest, size in TOKENIZER_FILES
]


def digest(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def valid(path: Path, asset: Asset) -> bool:
    return path.is_file() and path.stat().st_size == asset.bytes and digest(path) == asset.sha256


def local_source(asset: Asset) -> Path | None:
    home = Path.home()
    if asset.group == "Model":
        root = Path(os.environ.get(
            "YAIP_WHISPER_MODEL_SOURCE",
            home / "Documents/huggingface/models/argmaxinc/whisperkit-coreml/openai_whisper-tiny",
        ))
        relative = asset.remote_path.removeprefix("openai_whisper-tiny/")
    else:
        root = Path(os.environ.get(
            "YAIP_WHISPER_TOKENIZER_SOURCE",
            home / "Documents/huggingface/models/openai/whisper-tiny",
        ))
        relative = asset.remote_path
    candidate = root / relative
    return candidate if valid(candidate, asset) else None


def download(asset: Asset, destination: Path) -> None:
    encoded = "/".join(urllib.parse.quote(part) for part in asset.remote_path.split("/"))
    url = f"https://huggingface.co/{asset.repo}/resolve/{asset.revision}/{encoded}?download=true"
    request = urllib.request.Request(url, headers={"User-Agent": "YaipRelease/1"})
    with urllib.request.urlopen(request, timeout=120) as response, destination.open("wb") as output:
        shutil.copyfileobj(response, output)
    if not valid(destination, asset):
        destination.unlink(missing_ok=True)
        raise RuntimeError(f"Integrity check failed for {asset.remote_path}")


def stage(output: Path) -> None:
    cache = Path.home() / "Library/Caches/YaipRelease/WhisperTiny"
    cache.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="yaip-model-") as temporary:
        staged = Path(temporary) / "WhisperTiny"
        for asset in ASSETS:
            destination = staged / asset.destination
            destination.parent.mkdir(parents=True, exist_ok=True)

            source = local_source(asset)
            if source is None:
                cached = cache / asset.destination
                if not valid(cached, asset):
                    cached.parent.mkdir(parents=True, exist_ok=True)
                    print(f"Downloading {asset.remote_path}")
                    download(asset, cached)
                source = cached
            shutil.copy2(source, destination)

        manifest = {
            "name": "OpenAI Whisper Tiny (WhisperKit Core ML)",
            "model": {"repository": ARGMAX_REPO, "revision": ARGMAX_REVISION},
            "tokenizer": {"repository": OPENAI_REPO, "revision": OPENAI_REVISION},
            "totalBytes": sum(asset.bytes for asset in ASSETS),
            "files": [
                {"path": asset.destination, "bytes": asset.bytes, "sha256": asset.sha256}
                for asset in ASSETS
            ],
        }
        (staged / "MODEL_MANIFEST.json").write_text(json.dumps(manifest, indent=2) + "\n")

        if output.exists():
            shutil.rmtree(output)
        output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(staged, output)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    arguments = parser.parse_args()
    stage(arguments.output)
    print(f"Staged {len(ASSETS)} verified files at {arguments.output}")


if __name__ == "__main__":
    main()
