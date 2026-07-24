"""Repository-wide source integrity checks."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


def test_all_python_sources_compile() -> None:
    """Catch syntax damage in CLI modules that other tests do not import."""
    source_roots = (ROOT / "tools", ROOT / "tests", ROOT / "examples")

    for source_root in source_roots:
        for path in source_root.rglob("*.py"):
            source = path.read_text(encoding="utf-8")
            compile(source, str(path), "exec")


def test_source_files_have_no_merge_conflict_markers() -> None:
    """Reject unresolved merge markers in executable and contract sources."""
    source_roots = (
        ROOT / "tools",
        ROOT / "tests",
        ROOT / "examples",
        ROOT / "schema",
        ROOT / "prompts",
    )
    text_suffixes = {".py", ".json", ".yaml", ".yml", ".md", ".html", ".js", ".css"}
    marker_prefixes = ("<" * 7, "=" * 7, ">" * 7)

    for source_root in source_roots:
        for path in source_root.rglob("*"):
            if not path.is_file() or path.suffix not in text_suffixes:
                continue
            for line_number, line in enumerate(
                path.read_text(encoding="utf-8").splitlines(),
                start=1,
            ):
                assert not line.startswith(marker_prefixes), (
                    f"unresolved merge conflict marker at {path}:{line_number}"
                )
