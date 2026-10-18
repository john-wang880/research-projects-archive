"""Copy public Sentaurus templates to a fresh directory and relocate project paths.

This command never supplies material data or launches a simulator. All material
cards, optical tables, grids, and saved states must be supplied or rebuilt locally.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import sys


REPOSITORY = Path(__file__).resolve().parents[1]
TEMPLATES = REPOSITORY / "templates"
PROJECTS = {
    "__FIGURE3_PROJECT__": "figure3",
    "__FIGURE3_VARIANT_PROJECT__": "figure3_finite_lifetime",
    "__FIGURE4_BASELINE_PROJECT__": "figure4_baseline",
    "__FIGURE4_CALIBRATED_PROJECT__": "figure4_calibrated",
}
TOKEN = re.compile(r"__FIGURE[A-Z0-9_]*__")
EXCLUDED_SUFFIXES = {".par", ".tdr", ".sav", ".plt", ".out", ".log", ".sta", ".err", ".pdf"}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def checked_path(path: Path) -> str:
    value = path.resolve().as_posix()
    if any(character in value for character in ('"', "\n", "\r")):
        raise ValueError("Output paths must not contain quotes or line breaks")
    return value


def prepare(destination: Path) -> dict:
    if not TEMPLATES.is_dir():
        raise FileNotFoundError(f"Template directory is missing: {TEMPLATES}")
    destination = destination.expanduser().resolve()
    if destination.exists():
        raise FileExistsError(f"Output directory already exists; choose a fresh path: {destination}")
    if destination == TEMPLATES or destination.is_relative_to(TEMPLATES):
        raise ValueError("Output directory must be outside the template directory")
    mapping = {token: checked_path(destination / name) for token, name in PROJECTS.items()}
    entries = sorted(TEMPLATES.rglob("*"))
    if any(path.is_symlink() for path in entries):
        raise ValueError("Symbolic links are not supported in public templates")
    files = [path for path in entries if path.is_file()]
    if not files:
        raise ValueError("No template files were found")
    contents = {}
    for path in files:
        if path.is_symlink():
            raise ValueError(f"Symbolic links are not supported in public templates: {path}")
        if path.suffix.lower() in EXCLUDED_SUFFIXES or path.name.lower().startswith("sic_uv_nk"):
            raise ValueError(f"An excluded material or runtime file was found in templates: {path}")
        text = path.read_text(encoding="utf-8-sig")
        unknown = set(TOKEN.findall(text)) - set(mapping)
        if unknown:
            raise ValueError(f"Unknown project placeholders in {path}: {sorted(unknown)}")
        contents[path.relative_to(TEMPLATES)] = text
    source_hashes = {path.relative_to(TEMPLATES).as_posix(): digest(path) for path in files}
    shutil.copytree(TEMPLATES, destination)
    replacements = {}
    for relative, text in contents.items():
        count = 0
        for token, local_path in mapping.items():
            count += text.count(token)
            text = text.replace(token, local_path)
        if TOKEN.search(text):
            raise ValueError(f"A project placeholder remains in {relative}")
        if count:
            (destination / relative).write_text(text, encoding="utf-8")
            replacements[relative.as_posix()] = count
    current_hashes = {path.relative_to(TEMPLATES).as_posix(): digest(path) for path in files}
    if current_hashes != source_hashes:
        raise RuntimeError("Source templates changed during preparation; inspect the prepared directory")
    prepared_files = sorted(path for path in destination.rglob("*") if path.is_file())
    manifest = {
        "mode": "prepare_only",
        "simulator_launched": False,
        "material_files_provided": False,
        "project_paths": mapping,
        "source_template_sha256": source_hashes,
        "prepared_file_sha256": {path.relative_to(destination).as_posix(): digest(path) for path in prepared_files},
        "placeholder_replacements": replacements,
        "note": "Provide legal material cards and optical tables, then rebuild meshes and dark states before simulation.",
    }
    (destination / "preparation_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-root", required=True, type=Path, help="Fresh local directory receiving the template projects")
    parser.add_argument("--prepare-only", action="store_true", help="Explicit alias for the default behavior; no simulator is ever started")
    args = parser.parse_args()
    try:
        manifest = prepare(args.output_root)
    except (OSError, ValueError, RuntimeError) as error:
        print(f"Preparation failed: {error}", file=sys.stderr)
        return 1
    print("Prepared local source projects:")
    for token, path in manifest["project_paths"].items():
        print(f"  {token}: {path}")
    print("No material files were supplied and no simulator was launched.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
