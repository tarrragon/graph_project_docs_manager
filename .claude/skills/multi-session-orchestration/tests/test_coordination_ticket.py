"""coordination_ticket.py 測試：以 tmp_path 建假 repo。"""
import json
import subprocess
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent.parent / "scripts"
sys.path.insert(0, str(SCRIPTS))
import coordination_ticket as ct  # noqa: E402

TODOLIST = """versions:
  - version: "0.5.0"
    status: "completed"
    worklog: "docs/work-logs/v0/v0.5/v0.5.0/"
  - version: "0.6.0"
    status: "active"
    worklog: "docs/work-logs/v0/v0.6/v0.6.0/"
"""
COORD = "status: in_progress\ncoordination: true\n"


def make_repo(tmp_path, tickets, todolist=TODOLIST, override=None):
    if todolist is not None:
        (tmp_path / "docs").mkdir()
        (tmp_path / "docs/todolist.yaml").write_text(todolist, encoding="utf-8")
    for ticket_id, fm in tickets.items():
        version = ticket_id.split("-")[0]
        minor = ".".join(version.split(".")[:2])
        d = tmp_path / f"docs/work-logs/v0/v{minor}/v{version}/tickets"
        d.mkdir(parents=True, exist_ok=True)
        (d / f"{ticket_id}.md").write_text(f"---\nid: {ticket_id}\n{fm}---\n# body\n", encoding="utf-8")
    if override:
        cfg = tmp_path / ".claude/project-integration"
        cfg.mkdir(parents=True)
        (cfg / "multi-session.json").write_text(json.dumps({"coordinationTicket": override}))
    return tmp_path


def test_one_ticket_ok(tmp_path):
    make_repo(tmp_path, {"0.6.0-W1-099": COORD, "0.6.0-W1-100": "status: in_progress\n"})
    r = ct.resolve_coordination_ticket(tmp_path)
    assert (r["kind"], r["ticket"], r["source"]) == ("ok", "0.6.0-W1-099", "auto")


def test_none(tmp_path):
    make_repo(tmp_path, {"0.6.0-W1-100": "status: in_progress\n"})
    assert ct.resolve_coordination_ticket(tmp_path)["kind"] == "none"


def test_multiple(tmp_path):
    make_repo(tmp_path, {"0.6.0-W1-099": COORD, "0.6.0-W1-101": COORD})
    r = ct.resolve_coordination_ticket(tmp_path)
    assert r["kind"] == "multiple"
    assert [c["ticket"] for c in r["candidates"]] == ["0.6.0-W1-099", "0.6.0-W1-101"]


def test_override_open_wins(tmp_path):
    make_repo(tmp_path, {"0.6.0-W1-099": COORD, "0.6.0-W1-050": "status: pending\n"},
              override="0.6.0-W1-050")
    r = ct.resolve_coordination_ticket(tmp_path)
    assert (r["kind"], r["ticket"], r["source"]) == ("ok", "0.6.0-W1-050", "override")


def test_override_closed_falls_back_with_warning(tmp_path):
    make_repo(tmp_path, {"0.6.0-W1-099": COORD, "0.5.0-W1-349": "status: completed\n"},
              override="0.5.0-W1-349")
    r = ct.resolve_coordination_ticket(tmp_path)
    assert (r["kind"], r["ticket"], r["source"]) == ("ok", "0.6.0-W1-099", "auto")
    assert any("0.5.0-W1-349" in w and "已結案" in w for w in r["warnings"])


def test_call_override_beats_config(tmp_path):
    make_repo(tmp_path, {"0.6.0-W1-099": COORD, "0.6.0-W1-050": "status: pending\n"},
              override="0.5.0-W1-349")
    r = ct.resolve_coordination_ticket(tmp_path, override="0.6.0-W1-050")
    assert r["ticket"] == "0.6.0-W1-050" and r["source"] == "override"


def test_todolist_missing_is_error(tmp_path, capsys):
    make_repo(tmp_path, {"0.6.0-W1-099": COORD}, todolist=None)
    r = ct.resolve_coordination_ticket(tmp_path)
    assert r["kind"] == "error" and r["reason"]
    assert "todolist" in capsys.readouterr().err


def test_cli_json_fields(tmp_path):
    make_repo(tmp_path, {"0.6.0-W1-099": COORD})
    out = subprocess.run([sys.executable, str(SCRIPTS / "coordination_ticket.py"), "--json",
                          "--project-dir", str(tmp_path)], capture_output=True, text=True)
    data = json.loads(out.stdout)
    assert out.returncode == 0
    assert {"kind", "ticket", "path", "source", "warnings", "candidates"} <= set(data)
