"""SPEC-007 凍結：語料判型、合成列、覆蓋、樣本、commit 資訊（唯一 import spec006 處）。"""

from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))
import spec006_reference as corpus_ref  # noqa: E402

from spec007_extract import (  # noqa: E402
    CORPUS_FB,
    CORPUS_GPDM,
    COVERS_ALL,
    DOMAIN_BUNDLE_TYPE,
    DOMAIN_FIELD,
    FIXTURE_DIR,
    REASON_DUPLICATED,
    REASON_INVALID_SHAPE,
    REASON_MISSING,
    REASON_PATTERN,
    REASON_SELF,
    REFERENCE_VERSION,
    SCHEMA_RELATIVE,
    SYNTHETIC_CORPUS,
    TICKET_TYPE,
    compile_id_patterns,
    compile_main_graph_patterns,
    edge_field_names,
    load_edge_types,
)
from spec007_graph import (  # noqa: E402
    GraphResult,
    build_graph,
    compute_expected,
    expected_files,
    row_corpus,
    write_json,
)


# ---------------------------------------------------------------------------
# freeze：語料 -> manifest
# ---------------------------------------------------------------------------


def json_safe(value: Any, stats: Counter) -> Any:
    """YAML 的 date／datetime 轉 ISO 字串（Dart yaml 套件不解析時間戳，讀入即為字串）。"""
    if isinstance(value, (datetime.datetime, datetime.date)):
        stats["dates_to_iso_string"] += 1
        return value.isoformat()
    if isinstance(value, dict):
        if not all(isinstance(k, str) for k in value):
            raise ValueError(f"non-string key cannot be frozen: {list(value)}")
        return {k: json_safe(v, stats) for k, v in value.items()}
    if isinstance(value, list):
        return [json_safe(v, stats) for v in value]
    if value is None or isinstance(value, (str, int, float, bool)):
        return value
    raise ValueError(f"unserializable YAML value type: {type(value).__name__}")


def _judge_node(
    absolute: Path, type_table: corpus_ref.SchemaTypeTable
) -> tuple[str | None, dict[str, Any] | None]:
    """SPEC-006 FR-03 節點判型（與 corpus_ref.classify_file 的 node 分支同義，只解析一次 YAML）。"""
    text = corpus_ref.read_file(absolute).text
    if text is None:
        return None, None
    classified = corpus_ref.classify_text(text)
    if classified.result != corpus_ref.RESULT_USABLE:
        return None, None
    node_id = classified.data.get("id")
    if not isinstance(node_id, str):
        return None, None
    matched = type_table.match_id(node_id)
    return (matched.node_type, classified.data) if matched.kind == "hit" else (None, None)


def collect_real_rows(
    root: Path,
    corpus: str,
    type_table: corpus_ref.SchemaTypeTable,
    field_names: list[str],
    stats: Counter,
) -> tuple[list[dict[str, Any]], dict[str, dict[str, Any]]]:
    """回傳 (manifest 列, path -> 完整 frontmatter)；只收 Corpus 判為節點的檔案。"""
    rows, frontmatters = [], {}
    for absolute in sorted(corpus_ref.scan_markdown_files(root)):
        node_type, data = _judge_node(absolute, type_table)
        if node_type is None:
            continue
        relative_path = absolute.relative_to(root).as_posix()
        full = json_safe(data, stats)
        rows.append(
            {
                "corpus": corpus,
                "path": relative_path,
                "id": full["id"],
                "node_type": node_type,
                "status": full.get("status"),
                "title": full.get("title"),
                "edge_fields": {
                    k: full[k]
                    for k in field_names + ([DOMAIN_FIELD] if node_type == DOMAIN_BUNDLE_TYPE else [])
                    if k in full
                },
                "synthetic": False,
                "covers": [],
            }
        )
        frontmatters[relative_path] = full
    return rows, frontmatters


def snapshot_signature(root: Path) -> list[tuple[str, int]]:
    """語料 docs/ 下全部 .md 的 (相對路徑, mtime_ns)；用來偵測凍結期間語料被改動。"""
    files = corpus_ref.scan_markdown_files(root)
    return sorted((f.relative_to(root).as_posix(), f.stat().st_mtime_ns) for f in files)


def _syn(id_: str, path: str, node_type: str, covers: list[str], **fields: Any) -> dict[str, Any]:
    return {
        "corpus": SYNTHETIC_CORPUS,
        "synthetic_host": CORPUS_GPDM,
        "path": path,
        "id": id_,
        "node_type": node_type,
        "status": fields.pop("status", "pending"),
        "title": fields.pop("title", f"synthetic {id_}"),
        "edge_fields": fields,
        "synthetic": True,
        "covers": covers,
    }


def synthetic_rows() -> list[dict[str, Any]]:
    """語料缺席類別的合成列（ID 空間 9.9.9／PROP-901，不與真實語料重疊）。"""
    base = "docs/work-logs/v9/v9.9/v9.9.9/tickets/"
    t = TICKET_TYPE
    return [
        _syn("9.9.9-W9-001", base + "9.9.9-W9-001.md", t, ["duplicate_id"]),
        _syn("9.9.9-W9-001", base + "9.9.9-W9-001-copy.md", t, ["duplicate_id"]),
        _syn("9.9.9-W9-002", base + "9.9.9-W9-002.md", t, ["target_duplicated"],
             relatedTo=["9.9.9-W9-001"]),
        _syn("9.9.9-W9-003", base + "9.9.9-W9-003.md", t, ["self_reference"],
             relatedTo=["9.9.9-W9-003"]),
        _syn("9.9.9-W9-004", base + "9.9.9-W9-004.md", t, ["invalid_shape"],
             blockedBy=["9.9.9-W9-002", 42], discovered_during=True,
             source_ticket={"a": "b"}, relatedTo=[["x"]]),
        _syn("9.9.9-W9-005", base + "9.9.9-W9-005.md", t, ["null_in_list"],
             blockedBy=["9.9.9-W9-002", None]),
        _syn("9.9.9-W9-006", base + "9.9.9-W9-006.md", t, ["non_string_status_title"],
             status=3, title=["a"]),
        _syn("PROP-901", "docs/proposals/PROP-901-synthetic.md", "PROP",
             ["outputs_non_list_subkey"],
             outputs={"design_refs": ["9.9.9-W9-002"], "notes": "x"}),
    ]


def derive_real_covers(rows: list[dict[str, Any]], result: GraphResult) -> dict[str, set[str]]:
    """由建圖結果推導真實列各自負責的 D5 類別（path 對類別集合）。"""
    by_id = {r["id"]: r["path"] for r in rows if not r["synthetic"]}
    tags: dict[str, set[str]] = defaultdict(set)

    def tag(node_id: str, cover: str) -> None:
        if node_id in by_id:
            tags[by_id[node_id]].add(cover)

    provenance_targets: dict[str, set[str]] = defaultdict(set)
    for (edge_type, start, end), declared in result.edges.items():
        if edge_type in result.undirected:
            if len(declared) == 1:
                tag(next(iter(declared)), "related_one_side")
            else:
                tag(start, "related_both_sides")
                tag(end, "related_both_sides")
        elif edge_type == "spawn" and declared == {end}:
            tag(start, "spawn_reverse_only")
        if edge_type == "provenance":
            provenance_targets[start].add(end)
    for start, ends in provenance_targets.items():
        if len(ends) >= 2:
            tag(start, "provenance_multi_source")
    for defect in result.multi_sources:
        if defect["edge_type"] == "spawn":
            tag(defect["from"], "spawn_multi_source")
    for defect in result.ref_defects:
        if defect["reason"] == REASON_MISSING:
            tag(defect["source_id"], "dangling")
        if defect["reason"] == REASON_PATTERN:
            tag(defect["source_id"], "malformed_pattern")
        if defect["reason"] == REASON_SELF:  # 真實語料已有（closed_by 自指），不再以合成列補
            tag(defect["source_id"], "self_reference")
    return tags


def coverage_gaps(rows: list[dict[str, Any]]) -> list[str]:
    """IT1-A5 守衛的參照版：回傳 manifest 未覆蓋的 §2.2.1 類別。"""
    present = {c for row in rows for c in row["covers"]}
    return [c for c in COVERS_ALL if c not in present]


def _null_items(row: dict[str, Any]) -> int:
    count = 0
    for value in row["edge_fields"].values():
        for v in list(value.values()) if isinstance(value, dict) else [value]:
            if isinstance(v, list):
                count += sum(1 for item in v if item is None)
    return count


def _has_non_string(value: Any) -> bool:
    return value is not None and not isinstance(value, str)


def real_evidence_for_synthetic_only(
    rows: list[dict[str, Any]], result: GraphResult
) -> dict[str, int]:
    """合成只補語料缺席類別：回傳這些類別在真實列的實際出現數（必須為 0）。"""
    real_rows = [r for r in rows if not r["synthetic"]]
    return {
        "duplicate_id": len(result.duplicates),
        "invalid_shape": result.reasons[REASON_INVALID_SHAPE],
        "target_duplicated": result.reasons[REASON_DUPLICATED],
        "null_in_list": sum(_null_items(r) for r in real_rows),
        "non_string_status_title": sum(
            1 for r in real_rows if _has_non_string(r["status"]) or _has_non_string(r["title"])
        ),
    }


def pick_ticket_samples(
    rows: list[dict[str, Any]], frontmatters: dict[tuple[str, str], dict[str, Any]]
) -> dict[str, Any]:
    """IT-3：每個語料、每種字串 status 值至少一張（取路徑字典序第一張）。"""
    samples, status_values, missing = [], {}, {}
    for corpus in (CORPUS_GPDM, CORPUS_FB):
        tickets = sorted(
            (
                r for r in rows
                if not r["synthetic"] and r["corpus"] == corpus and r["node_type"] == TICKET_TYPE
            ),
            key=lambda r: r["path"],
        )
        picked: dict[str, dict[str, Any]] = {}
        status_counts: Counter = Counter()
        for row in tickets:
            if isinstance(row["status"], str):
                status_counts[row["status"]] += 1
                picked.setdefault(row["status"], row)
        status_values[corpus] = dict(sorted(status_counts.items()))
        missing[corpus] = sum(1 for r in tickets if not isinstance(r["status"], str))
        for status in sorted(picked):
            row = picked[status]
            samples.append(
                {
                    "corpus": corpus,
                    "path": row["path"],
                    "id": row["id"],
                    "frontmatter": frontmatters[(corpus, row["path"])],
                }
            )
    return {
        "header": {
            "note": "IT-3 samples; every sample is an existing manifest row (same corpus and path)",
            "status_values": status_values,
            "tickets_without_string_status": missing,
        },
        "samples": samples,
    }


def check_samples_against_manifest(
    samples: dict[str, Any], manifest: dict[str, Any], field_names: list[str]
) -> None:
    """凍結時斷言：樣本的 id／status／title／使用中邊型欄位原值等於 manifest 同 path 的列。"""
    index = {(r["corpus"], r["path"]): r for r in manifest["rows"]}
    for sample in samples["samples"]:
        row = index[(sample["corpus"], sample["path"])]
        fm = sample["frontmatter"]
        got = {k: fm[k] for k in field_names if k in fm}
        same = (
            fm["id"] == row["id"]
            and fm.get("status") == row["status"]
            and fm.get("title") == row["title"]
            and got == row["edge_fields"]
        )
        if not same:
            raise AssertionError(f"sample differs from manifest row: {sample['path']}")


def corpus_commit_info(root: Path) -> dict[str, Any]:
    """讀 HEAD commit。語料為他人 repo 時不呼叫 git，直接讀 .git（唯讀）。"""
    git_dir = root / ".git"
    if git_dir.is_dir():
        head = (git_dir / "HEAD").read_text().strip()
        if head.startswith("ref: "):
            ref = head[5:]
            ref_file = git_dir / ref
            if ref_file.exists():
                return {"commit": ref_file.read_text().strip()}
            for line in (git_dir / "packed-refs").read_text().splitlines():
                if line.endswith(" " + ref):
                    return {"commit": line.split()[0]}
        return {"commit": head}
    out = subprocess.run(
        ["git", "-C", str(root), "rev-parse", "HEAD"], capture_output=True, text=True, check=True
    )
    status = subprocess.run(
        ["git", "-C", str(root), "status", "--porcelain", "--", "docs"],
        capture_output=True, text=True, check=True,
    )
    return {"commit": out.stdout.strip(), "dirty_docs_entries": len(status.stdout.splitlines())}

def _finish_manifest(
    rows: list[dict[str, Any]],
    roots: dict[str, Path],
    repo: Path,
    table: dict[str, Any],
    stats: Counter,
    snapshots: dict[str, dict[str, Any]],
) -> dict[str, Any]:
    """凍結時附上 covers 標記與 header；synthetic 只補缺席類別，違反即中止。"""
    edge_types = load_edge_types(table)
    patterns = compile_id_patterns(table)
    main_patterns = compile_main_graph_patterns(table)
    rows.sort(key=lambda r: (row_corpus(r), r["path"]))
    real_rows = [r for r in rows if not r["synthetic"]]
    for corpus in roots:  # 兩語料 ID 空間可能重疊，逐語料各建一輪
        corpus_rows = [r for r in rows if row_corpus(r) == corpus]
        corpus_real = [r for r in corpus_rows if not r["synthetic"]]
        real_ids = {r["id"] for r in corpus_real}
        clash = [r["id"] for r in corpus_rows if r["synthetic"] and r["id"] in real_ids]
        if clash:
            raise AssertionError(f"synthetic id overlaps real rows: {clash}")
        real_result = build_graph(corpus_real, edge_types, patterns, main_patterns)
        evidence = real_evidence_for_synthetic_only(corpus_rows, real_result)
        if any(evidence.values()):
            raise AssertionError(f"{corpus}: category exists in corpus, must not be synthetic: {evidence}")
        tags = derive_real_covers(corpus_real, real_result)
        for row in corpus_real:
            row["covers"] = sorted(tags.get(row["path"], set()))
    gaps = coverage_gaps(rows)
    if gaps:
        raise AssertionError(f"manifest misses categories: {gaps}")
    cover_rows = {c: {"real": 0, "synthetic": 0} for c in COVERS_ALL}
    for row in rows:
        for c in row["covers"]:
            cover_rows[c]["synthetic" if row["synthetic"] else "real"] += 1
    header = {
        "frozen_date": datetime.date.today().isoformat(),
        "reference_version": REFERENCE_VERSION,
        "framework_version": (repo / ".claude/VERSION").read_text().strip(),
        "schema_generated_at_framework_version": table["schema_generated_at_framework_version"],
        "id_pattern_dialect": table.get("id_pattern_dialect"),
        "corpus_commits": {c: corpus_commit_info(root) for c, root in roots.items()},
        "corpus_snapshots": snapshots,
        "row_counts_real": dict(sorted(Counter(r["corpus"] for r in real_rows).items())),
        "row_counts_with_synthetic": dict(sorted(Counter(row_corpus(r) for r in rows).items())),
        "covers_rows": cover_rows,
        "yaml_dates_converted_to_iso_string": stats["dates_to_iso_string"],
    }
    return {"header": header, "rows": rows}

def _cmd_freeze(args: argparse.Namespace) -> None:
    repo = Path(args.gpdm_root).resolve()
    roots = {CORPUS_GPDM: repo, CORPUS_FB: Path(args.fb_root).expanduser().resolve()}
    out_dir = Path(args.out_dir) if args.out_dir else repo / FIXTURE_DIR
    table = json.loads((repo / SCHEMA_RELATIVE).read_text(encoding="utf-8"))
    type_table = corpus_ref.SchemaTypeTable(table["node_types"])
    field_names = edge_field_names(load_edge_types(table))

    stats: Counter = Counter()
    rows, frontmatters, snapshots = [], {}, {}
    for corpus, root in roots.items():
        before = snapshot_signature(root)
        corpus_rows, corpus_fm = collect_real_rows(root, corpus, type_table, field_names, stats)
        if snapshot_signature(root) != before:
            raise RuntimeError(f"{corpus} changed while freezing; rerun when the corpus is quiet")
        snapshots[corpus] = {
            "docs_md_files": len(before),
            "signature_sha256": hashlib.sha256(json.dumps(before).encode()).hexdigest(),
        }
        rows += corpus_rows
        frontmatters.update({(corpus, p): fm for p, fm in corpus_fm.items()})
    rows += synthetic_rows()

    manifest = _finish_manifest(rows, roots, repo, table, stats, snapshots)
    out_dir.mkdir(parents=True, exist_ok=True)
    write_json(out_dir / "type_table.json", table)
    write_json(out_dir / "graph_manifest.json", manifest)
    computed = compute_expected(manifest, table)
    for name, data in expected_files(manifest, computed).items():
        write_json(out_dir / name, data)
    samples = pick_ticket_samples(manifest["rows"], frontmatters)
    check_samples_against_manifest(samples, manifest, field_names)
    write_json(out_dir / "ticket_detail_samples.json", samples)
    print(json.dumps(manifest["header"], ensure_ascii=False, indent=1))
    print(json.dumps(samples["header"], ensure_ascii=False, indent=1))
    real_only = {c: v["real_only"] for c, v in computed["counts"].items()}
    print(json.dumps(real_only, ensure_ascii=False, indent=1))
