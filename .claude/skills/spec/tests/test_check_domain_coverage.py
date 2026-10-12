"""check_domain_coverage 測試：FR token 展開（逗號/範圍）+ 覆蓋差集判定。"""

import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent.parent / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

import check_domain_coverage as cdc  # noqa: E402


# --- extract_fr_ids：token 展開 ---

def test_extract_single_fr():
    assert cdc.extract_fr_ids("FR-04 覆蓋") == {4}


def test_extract_comma_list():
    assert cdc.extract_fr_ids("FR-01,02,03 群") == {1, 2, 3}


def test_extract_range_tilde():
    assert cdc.extract_fr_ids("FR-13~17 各畫面") == {13, 14, 15, 16, 17}


def test_extract_range_hyphen():
    assert cdc.extract_fr_ids("FR-19-21 cross-cutting") == {19, 20, 21}


def test_extract_mixed_tokens():
    ids = cdc.extract_fr_ids("| FR-04,07,12 | Networth |\n| FR-19,20,21,25 | presentation |")
    assert ids == {4, 7, 12, 19, 20, 21, 25}


# --- extract_spec_frs：從 ### FR-XX: 標題 ---

def test_extract_spec_frs_from_headers():
    spec = "# spec\n### FR-01: A\nbody\n### FR-25: B\nbody\n"
    assert cdc.extract_spec_frs(spec) == {1, 25}


def test_extract_spec_frs_handles_h4_headers():
    """真實 SPEC-001 用 #### FR-XX:（H4）——不可只認 H3（Round 2-C 假通過回歸）。"""
    spec = "## FR\n#### FR-01: A\nbody\n#### FR-26: B\nbody\n"
    assert cdc.extract_spec_frs(spec) == {1, 26}


# --- check_domain_coverage：差集 ---

def test_all_covered_returns_empty():
    spec = "### FR-01: A\n### FR-02: B\n"
    domain_map = "§7\n| FR-01,02 | Ledger |\n"
    assert cdc.check_domain_coverage(spec, domain_map) == []


def test_uncovered_fr_reported():
    """domain map 停在 FR-24，spec 有 FR-25/26 → 回報未覆蓋（已實證缺口）。"""
    spec = "### FR-24: 驗證\n### FR-25: 設定\n### FR-26: 提醒\n"
    domain_map = "覆蓋表\n| FR-24 | Ledger |\n"
    assert cdc.check_domain_coverage(spec, domain_map) == [25, 26]


def test_range_coverage_matches_individual_spec_frs():
    spec = "### FR-13: A\n### FR-15: B\n### FR-17: C\n"
    domain_map = "| FR-13~17 | presentation |\n"
    assert cdc.check_domain_coverage(spec, domain_map) == []


# --- locate_domain_map ---

def test_locate_prefers_same_dir(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)  # 隔離 cwd，避免 fallback 命中真實 docs/domain-map.md
    spec = tmp_path / "SPEC-001.md"
    spec.write_text("### FR-01: A\n", encoding="utf-8")
    dmap = tmp_path / "domain-map.md"
    dmap.write_text("| FR-01 | Ledger |\n", encoding="utf-8")
    assert cdc.locate_domain_map(spec, None) == dmap


def test_locate_missing_returns_none(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)  # 隔離 cwd，確保無 docs/domain-map.md fallback
    spec = tmp_path / "SPEC-001.md"
    spec.write_text("### FR-01: A\n", encoding="utf-8")
    assert cdc.locate_domain_map(spec, None) is None


# --- extract_event_signaled_frs：事件流訊號詞掃描 ---

def test_extract_event_signaled_frs_hits_signal_word():
    spec = "### FR-01: 掃描完成的系統層通知\n驗收：發送通知。\n"
    assert cdc.extract_event_signaled_frs(spec) == {1}


def test_extract_event_signaled_frs_no_signal_word():
    spec = "### FR-01: 一般敘述\n驗收：文字對齊正確。\n"
    assert cdc.extract_event_signaled_frs(spec) == set()


def test_extract_event_signaled_frs_english_word_case_insensitive():
    spec = "### FR-02: 背景任務\n改以 Isolate 執行。\n"
    assert cdc.extract_event_signaled_frs(spec) == {2}


def test_extract_event_signaled_frs_multiple_frs_only_some_signaled():
    spec = (
        "### FR-01: 一般敘述\n無訊號。\n"
        "### FR-02: 排程任務\n背景排程處理。\n"
    )
    assert cdc.extract_event_signaled_frs(spec) == {2}


# --- extract_channel_section：以標題文字定位，不依編號 ---

def test_extract_channel_section_locates_by_title_regardless_of_numbering():
    """章節編號可能與既有內容衝突（如本專案既有「## 2.5」），須以標題文字定位。"""
    domain_map = (
        "## 2.5 三個易混淆詞的定義\n其他內容\n"
        "## 9. 通道與協調圖\n通道內容\n"
        "## 10. 下一節\n下一節內容\n"
    )
    section = cdc.extract_channel_section(domain_map)
    assert section is not None
    assert "通道內容" in section
    assert "下一節內容" not in section
    assert "其他內容" not in section


def test_extract_channel_section_missing_returns_none():
    assert cdc.extract_channel_section("## 3. Bundle 界定表\n無此節\n") is None


# --- extract_arrival_level_table：通道節內的到達類別與級別子表 ---

def test_extract_arrival_level_table_locates_subsection():
    channel_section = (
        "## 2.5. 通道與協調圖\n"
        "### 2.5.1 通道清單\n通道清單內容\n"
        "### 2.5.3 到達類別與級別實例\n"
        "| 通道 | 事件/請求 | 到達類別 | 級別 | 引用來源 |\n"
        "|---|---|---|---|---|\n"
        "| toast | 掃描完成通知 | 推送型 | 不可棄 | FR-01 |\n"
    )
    table = cdc.extract_arrival_level_table(channel_section)
    assert table is not None
    assert "FR-01" in table
    assert "通道清單內容" not in table


def test_extract_arrival_level_table_missing_subsection_returns_none():
    channel_section = "## 2.5. 通道與協調圖\n### 2.5.1 通道清單\n僅有通道清單\n"
    assert cdc.extract_arrival_level_table(channel_section) is None


def test_extract_arrival_level_table_none_input_returns_none():
    assert cdc.extract_arrival_level_table(None) is None


# --- check_event_flow_labeling：整合行為 ---

def test_check_event_flow_labeling_no_signal_returns_empty():
    spec = "### FR-01: 一般敘述\n無訊號。\n"
    domain_map = "## 3. Bundle 界定表\n無通道節\n"
    assert cdc.check_event_flow_labeling(spec, domain_map) == []


def test_check_event_flow_labeling_missing_channel_section_reports_all_signaled():
    spec = "### FR-01: 掃描完成通知\n發送通知。\n"
    domain_map = "## 3. Bundle 界定表\n無通道節\n"
    assert cdc.check_event_flow_labeling(spec, domain_map) == [1]


def test_check_event_flow_labeling_labeled_fr_not_reported():
    spec = "### FR-01: 掃描完成通知\n發送通知。\n"
    domain_map = (
        "## 2.5. 通道與協調圖\n"
        "### 2.5.3 到達類別與級別實例\n"
        "| 通道 | 事件/請求 | 到達類別 | 級別 | 引用來源 |\n"
        "|---|---|---|---|---|\n"
        "| toast | 掃描完成通知 | 推送型 | 不可棄 | FR-01 |\n"
    )
    assert cdc.check_event_flow_labeling(spec, domain_map) == []


def test_check_event_flow_labeling_partial_labeling_reports_unlabeled_only():
    spec = (
        "### FR-01: 掃描完成通知\n發送通知。\n"
        "### FR-02: 暫態提示\n事件觸發提示。\n"
    )
    domain_map = (
        "## 2.5. 通道與協調圖\n"
        "### 2.5.3 到達類別與級別實例\n"
        "| 通道 | 事件/請求 | 到達類別 | 級別 | 引用來源 |\n"
        "|---|---|---|---|---|\n"
        "| toast | 掃描完成通知 | 推送型 | 不可棄 | FR-01 |\n"
    )
    assert cdc.check_event_flow_labeling(spec, domain_map) == [2]


# --- CLI：--check-event-flow-labeling ---

def test_main_with_event_flow_flag_reports_missing_labeling(tmp_path, monkeypatch, capsys):
    monkeypatch.chdir(tmp_path)
    spec = tmp_path / "SPEC-001.md"
    spec.write_text("### FR-01: 掃描完成通知\n發送通知。\n", encoding="utf-8")
    domain_map = tmp_path / "domain-map.md"
    domain_map.write_text("| FR-01 | Ledger |\n", encoding="utf-8")
    rc = cdc.main([str(spec), "--check-event-flow-labeling"])
    assert rc == 1
    out = capsys.readouterr().out
    assert "事件流標定檢核發現" in out
    assert "FR-01" in out


def test_main_without_event_flow_flag_skips_check(tmp_path, monkeypatch, capsys):
    """未帶 flag 時不執行事件流標定檢核，維持既有行為。"""
    monkeypatch.chdir(tmp_path)
    spec = tmp_path / "SPEC-001.md"
    spec.write_text("### FR-01: 掃描完成通知\n發送通知。\n", encoding="utf-8")
    domain_map = tmp_path / "domain-map.md"
    domain_map.write_text("| FR-01 | Ledger |\n", encoding="utf-8")
    rc = cdc.main([str(spec)])
    assert rc == 0
    assert "事件流標定" not in capsys.readouterr().out


# --- FR 比對鍵 = (spec 識別, FR 編號) ---

SPEC_A = "---\nid: SPEC-101\n---\n### FR-01: a\n### FR-02: b\n### FR-03: c\n"
SPEC_B = SPEC_A.replace("SPEC-101", "SPEC-202")
MAP_UNDER_B = "## 8. 覆蓋\n### SPEC-202 小節\n| FR-01~03 | Ledger |\n"


def test_e2_same_number_fr_under_other_spec_is_uncovered(capsys):
    """E2 正向對照：map 只在 SPEC-202 下覆蓋 FR-01~03，SPEC-101 三條全未覆蓋。"""
    assert cdc.check_domain_coverage(SPEC_A, MAP_UNDER_B) == [1, 2, 3]


def test_e2_same_map_fully_covers_owning_spec():
    assert cdc.check_domain_coverage(SPEC_B, MAP_UNDER_B) == []


def test_same_line_attribution_nearest_spec():
    dm = "## 覆蓋\n| SPEC-101 FR-01、SPEC-202 FR-02 | X |\n"
    assert cdc.check_domain_coverage(SPEC_A, dm) == [2, 3]
    assert cdc.check_domain_coverage(SPEC_B, dm) == [1, 3]


def test_same_line_multiple_frs_share_preceding_spec():
    dm = "## 覆蓋\n| SPEC-101 FR-01、FR-03 | X |\n"
    assert cdc.check_domain_coverage(SPEC_A, dm) == [2]


def test_unattributed_tokens_ignored_when_map_has_attributed():
    dm = "## 3. 其他\n提到 FR-01 FR-02 FR-03\n## SPEC-101 覆蓋\n| FR-02 | X |\n"
    assert cdc.check_domain_coverage(SPEC_A, dm) == [1, 3]


def test_compat_mode_when_map_has_no_attribution(capsys):
    """E1 對照：無歸屬 map 走相容（不分 spec），stderr 說明；有歸屬 map 結果不同。"""
    dm = "## 覆蓋\n| FR-01~03 | X |\n"
    assert cdc.check_domain_coverage(SPEC_A, dm) == []
    assert "相容" in capsys.readouterr().err
    assert cdc.check_domain_coverage(SPEC_A, MAP_UNDER_B) != []


def test_compat_mode_warns_when_spec_id_missing(capsys):
    spec = "### FR-01: a\n"
    assert cdc.check_domain_coverage(spec, MAP_UNDER_B) == []
    assert "WARNING" in capsys.readouterr().err


def test_spec_id_from_filename_when_no_frontmatter_id(tmp_path):
    p = tmp_path / "SPEC-202-name.md"
    p.write_text("### FR-01: a\n", encoding="utf-8")
    assert cdc.extract_spec_id("### FR-01: a\n", p) == "SPEC-202"


def test_spec_id_not_read_from_body_after_frontmatter():
    """frontmatter 無 id 時，不得把收尾 --- 之後正文的 id: 行當成 spec 識別。"""
    spec = "---\ntitle: x\n---\nid: SPEC-999\n### FR-01: a\n"
    assert cdc.extract_spec_id(spec) is None


def test_spec_id_outside_spec_nnn_form_falls_back_to_compat(capsys):
    """id 不是 SPEC-NNN 形式時 map 的歸屬鍵對不上，須走相容模式並警告，不得全數報未覆蓋。"""
    spec = "---\nid: SPEC-UI-001\n---\n### FR-01: a\n"
    assert cdc.check_domain_coverage(spec, MAP_UNDER_B) == []
    assert "WARNING" in capsys.readouterr().err


# --- 多 domain 解析鏈（0.5.0-W1-086.1）---

def _write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def _multi_domain_fixture(tmp_path, source_specs="[SPEC-101]"):
    """SPEC 在 docs/spec/ui/（無 map）；兩個 domain map 分攤 FR，系統層補 FR-03。"""
    _write(tmp_path / "docs/spec/ui/SPEC-101-x.md", SPEC_A)
    _write(tmp_path / "docs/spec/a/domain-map.md",
           f"---\nsource_specs: {source_specs}\n---\n## SPEC-101\n| FR-01 | A |\n")
    _write(tmp_path / "docs/spec/b/domain-map.md",
           f"---\nsource_specs: {source_specs}\n---\n## SPEC-101\n| FR-02 | B |\n")
    _write(tmp_path / "docs/system-layer.md", "## SPEC-101 覆蓋\n| FR-03 | sys |\n")
    return tmp_path / "docs/spec/ui/SPEC-101-x.md"


def test_multi_map_union_resolves_without_flag(tmp_path, monkeypatch, capsys):
    monkeypatch.chdir(tmp_path)
    spec = _multi_domain_fixture(tmp_path)
    found = cdc.locate_domain_maps(Path("docs/spec/ui/SPEC-101-x.md"), None)
    assert [p.as_posix() for p in found] == [
        "docs/spec/a/domain-map.md", "docs/spec/b/domain-map.md", "docs/system-layer.md"]
    assert cdc.main([str(spec)]) == 0  # 聯集覆蓋 FR-01/02/03


def test_multi_map_e1_without_source_specs_differs(tmp_path, monkeypatch, capsys):
    """E1 對照：同 fixture 無 source_specs 列入 -> 解析不到，rc=1 且訊息為「未列入」。"""
    monkeypatch.chdir(tmp_path)
    spec = _multi_domain_fixture(tmp_path, source_specs="[]")
    assert cdc.locate_domain_maps(Path("docs/spec/ui/SPEC-101-x.md"), None) == []
    assert cdc.main([str(spec)]) == 1
    out = capsys.readouterr().out
    assert "無一份" in out and "source_specs" in out


def test_ui_dir_without_any_map_reports_no_map(tmp_path, monkeypatch, capsys):
    monkeypatch.chdir(tmp_path)
    spec = tmp_path / "docs/spec/ui/SPEC-101-x.md"
    _write(spec, SPEC_A)
    assert cdc.main([str(spec)]) == 1
    out = capsys.readouterr().out
    assert "找不到任何 domain map" in out and "無一份" not in out


def test_single_domain_root_map_unchanged(tmp_path, monkeypatch, capsys):
    monkeypatch.chdir(tmp_path)
    spec = tmp_path / "docs/spec/SPEC-101-x.md"
    _write(spec, SPEC_A)
    _write(tmp_path / "docs/domain-map.md", "## 覆蓋\n| FR-01~03 | X |\n")
    found = cdc.locate_domain_maps(Path("docs/spec/SPEC-101-x.md"), None)
    assert [p.as_posix() for p in found] == ["docs/domain-map.md"]
    assert cdc.main([str(spec)]) == 0


# --- 多 map 聯集在集合層（0.5.0-W1-086.3）---

def _map(specs, body):
    return f"---\nsource_specs: [{specs}]\n---\n{body}"


def test_union_event_flow_label_only_in_later_file(tmp_path, monkeypatch, capsys):
    """紅輸入：通道章節標題在每份 map 皆有，標定表只在排最後的系統層。"""
    monkeypatch.chdir(tmp_path)
    spec = tmp_path / "docs/spec/ui/SPEC-101-x.md"
    _write(spec, "---\nid: SPEC-101\n---\n### FR-01: 掃描通知\n### FR-02: b\n### FR-03: c\n")
    _write(tmp_path / "docs/spec/a/domain-map.md",
           _map("SPEC-101", "## SPEC-101\n| FR-01~03 | A |\n## 通道與協調圖\n無表\n"))
    _write(tmp_path / "docs/system-layer.md",
           "## 通道與協調圖\n### 到達類別與級別實例\n| FR-01 | 級別 |\n")
    assert cdc.main([str(spec), "--check-event-flow-labeling"]) == 0, capsys.readouterr().out


def test_union_heading_stack_resets_at_file_boundary(tmp_path, monkeypatch, capsys):
    """紅輸入：前一份以 SPEC-202 標題結尾，後一份無標題的 FR 不得繼承它。"""
    monkeypatch.chdir(tmp_path)
    spec = tmp_path / "docs/spec/ui/SPEC-101-x.md"
    _write(spec, SPEC_A)
    _write(tmp_path / "docs/spec/a/domain-map.md",
           _map("SPEC-101, SPEC-202", "## SPEC-101\n| FR-01 | A |\n## SPEC-202\n| FR-09 | A |\n"))
    _write(tmp_path / "docs/spec/b/domain-map.md", _map("SPEC-101", "| FR-02~03 | B |\n"))
    assert cdc.main([str(spec)]) == 0, capsys.readouterr().out


def test_union_untitled_map_falls_back_to_its_source_specs(tmp_path, monkeypatch, capsys):
    monkeypatch.chdir(tmp_path)
    spec = tmp_path / "docs/spec/ui/SPEC-101-x.md"
    _write(spec, SPEC_A)
    _write(tmp_path / "docs/spec/a/domain-map.md", _map("SPEC-101", "| FR-02~03 | A |\n"))
    _write(tmp_path / "docs/spec/b/domain-map.md", _map("SPEC-101", "## SPEC-101\n| FR-01 | B |\n"))
    assert cdc.main([str(spec)]) == 0, capsys.readouterr().out


def test_union_untitled_multi_source_specs_counts_to_inspected_spec(tmp_path, monkeypatch, capsys):
    """整份無歸屬的 map 其 FR 計給受檢 SPEC，與 source_specs 值數無關（0.5.0-W1-086.5）。"""
    monkeypatch.chdir(tmp_path)
    spec = tmp_path / "docs/spec/ui/SPEC-101-x.md"
    _write(spec, SPEC_A)
    _write(tmp_path / "docs/spec/a/domain-map.md", _map("SPEC-101", "## SPEC-101\n| FR-01 | A |\n"))
    _write(tmp_path / "docs/spec/b/domain-map.md", _map("SPEC-101, SPEC-202", "| FR-02~03 | B |\n"))
    assert cdc.main([str(spec)]) == 0, capsys.readouterr().out


# --- 0.5.0-W1-086.5：審查的四種由綠轉紅輸入 + 一例反向假綠 ---

def _in_domain_dir(tmp_path, monkeypatch, map_text, system=None, extra_map=None):
    """SPEC-101 在 docs/spec/a/（domain 目錄內），同目錄 map 為未帶 SPEC 標題的 map_text。"""
    monkeypatch.chdir(tmp_path)
    _write(tmp_path / "docs/spec/a/SPEC-101-x.md", SPEC_A)
    _write(tmp_path / "docs/spec/a/domain-map.md", map_text)
    if extra_map:
        _write(tmp_path / "docs/spec/b/domain-map.md", extra_map)
    if system:
        _write(tmp_path / "docs/system-layer.md", system)
    return str(tmp_path / "docs/spec/a/SPEC-101-x.md")


def test_green_to_red_1_multi_source_specs_with_other_spec_in_system(tmp_path, monkeypatch, capsys):
    spec = _in_domain_dir(tmp_path, monkeypatch, _map("SPEC-101, SPEC-202", "| FR-01~03 | A |\n"),
                          system="## SPEC-202\n| FR-09 | s |\n")
    assert cdc.main([spec]) == 0, capsys.readouterr().out


def test_green_to_red_2_no_source_specs_system_mentions_other_spec(tmp_path, monkeypatch, capsys):
    spec = _in_domain_dir(tmp_path, monkeypatch, _map("", "| FR-01~03 | A |\n"),
                          system="SPEC-202 的 FR-09 見此\n")
    assert cdc.main([spec]) == 0, capsys.readouterr().out


def test_green_to_red_3_source_specs_lists_other_spec(tmp_path, monkeypatch, capsys):
    spec = _in_domain_dir(tmp_path, monkeypatch, _map("SPEC-202", "| FR-01~03 | A |\n"),
                          system="## SPEC-202\n| FR-09 | s |\n")
    assert cdc.main([spec]) == 0, capsys.readouterr().out


def test_green_to_red_4_multi_source_specs_and_other_map_titled(tmp_path, monkeypatch, capsys):
    spec = _in_domain_dir(tmp_path, monkeypatch, _map("SPEC-101, SPEC-202", "| FR-02~03 | A |\n"),
                          extra_map=_map("SPEC-101", "## SPEC-101\n| FR-01 | B |\n"))
    assert cdc.main([spec]) == 0, capsys.readouterr().out


def test_reverse_false_green_verdict_independent_of_neighbours(tmp_path, monkeypatch, capsys):
    """首個 SPEC 標題前的散文 FR 不計入；判定不因旁邊有無系統層而改變。"""
    body = "前言提到 FR-01\n## SPEC-101\n| FR-02~03 | A |\n"
    spec = _in_domain_dir(tmp_path, monkeypatch, _map("SPEC-101", body))
    alone = cdc.main([spec])
    _write(tmp_path / "docs/system-layer.md", "## SPEC-202\n| FR-09 | s |\n")
    with_system = cdc.main([spec])
    assert alone == with_system == 1


def test_union_spec_inside_domain_dir_includes_other_listed_and_system(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    _write(tmp_path / "docs/spec/a/SPEC-101-x.md", SPEC_A)
    _write(tmp_path / "docs/spec/a/domain-map.md", _map("SPEC-101", "## SPEC-101\n| FR-01 | A |\n"))
    _write(tmp_path / "docs/spec/b/domain-map.md", _map("SPEC-101", "## SPEC-101\n| FR-02 | B |\n"))
    _write(tmp_path / "docs/system-layer.md", "## SPEC-101\n| FR-03 | sys |\n")
    found = cdc.locate_domain_maps(Path("docs/spec/a/SPEC-101-x.md"), None)
    assert [p.as_posix() for p in found] == [
        "docs/spec/a/domain-map.md", "docs/spec/b/domain-map.md", "docs/system-layer.md"]
    assert cdc.main([str(tmp_path / "docs/spec/a/SPEC-101-x.md")]) == 0


def test_union_filter_loads_only_listing_maps(tmp_path, monkeypatch):
    """過濾對照：未列入本 SPEC 的 map 不載入。"""
    monkeypatch.chdir(tmp_path)
    _write(tmp_path / "docs/spec/ui/SPEC-101-x.md", SPEC_A)
    _write(tmp_path / "docs/spec/a/domain-map.md", _map("SPEC-101", "## SPEC-101\n| FR-01 | A |\n"))
    _write(tmp_path / "docs/spec/c/domain-map.md", _map("SPEC-999", "## SPEC-999\n| FR-02 | C |\n"))
    found = cdc.locate_domain_maps(Path("docs/spec/ui/SPEC-101-x.md"), None)
    assert [p.as_posix() for p in found] == ["docs/spec/a/domain-map.md"]


# --- 0.5.0-W1-157：FR 標題全形冒號 + 空集合兩種性質分流 ---

def test_extract_spec_frs_fullwidth_colon():
    assert cdc.extract_spec_frs("### FR-01：A\n#### FR-02: B\n") == {1, 2}


def _fm(value=None):
    if value is None:
        return "---\nid: SPEC-900\n---\n"
    return f"---\nid: SPEC-900\nhas_functional_requirements: {value}\n---\n"


def _run_nomap(tmp_path, spec_text, capsys, *extra):
    spec = tmp_path / "SPEC-900-x.md"
    spec.write_text(spec_text, encoding="utf-8")
    rc = cdc.main([str(spec), *extra])
    return rc, capsys.readouterr().out


def _write_map(tmp_path, source_specs="SPEC-001"):
    (tmp_path / "domain-map.md").write_text(
        f"---\nsource_specs: [{source_specs}]\n---\n# 通道與協調圖\n## 到達類別與級別實例\nFR-01\n",
        encoding="utf-8")


def test_declared_false_no_fr_rc0_without_any_map(tmp_path, capsys):
    rc, out = _run_nomap(tmp_path, _fm("false") + "# s\n元件契約表\n", capsys)
    assert rc == 0
    assert "宣告無 FR" in out and "未執行覆蓋比對" in out
    assert "通過" not in out


def test_declared_false_skips_event_flow_check_even_with_map(tmp_path, capsys):
    # 同目錄有 map 時，若仍跑事件流檢核會印「事件流標定檢核通過」
    _write_map(tmp_path)
    rc, out = _run_nomap(tmp_path, _fm("false") + "# s\n元件契約表\n", capsys,
                         "--check-event-flow-labeling")
    assert rc == 0
    assert "通過" not in out and "事件流" not in out


def test_declared_false_with_map_not_listing_spec_rc0(tmp_path, capsys):
    _write_map(tmp_path, "SPEC-001")  # 未列入 SPEC-900
    rc, out = _run_nomap(tmp_path, _fm("false") + "# s\n", capsys)
    assert rc == 0 and "宣告無 FR" in out


def test_declaration_outside_frontmatter_not_honored(tmp_path, capsys):
    body = "# s\nhas_functional_requirements: false\n"
    fenced = "# s\n```yaml\nhas_functional_requirements: false\n```\n"
    for text in (_fm() + body, _fm() + fenced, body, fenced):
        rc, _ = _run_nomap(tmp_path, text, capsys)
        assert rc != 0


def test_declared_false_but_fr_heading_contradicts(tmp_path, capsys):
    rc, out = _run_nomap(tmp_path, _fm("false") + "# s\n### FR-01: A\n", capsys)
    assert rc != 0 and "矛盾" in out


def test_declared_false_loose_headings_contradict(tmp_path, capsys):
    for h in ("fr-01", "FR01", "FR 01", "FR\uff0d01", "FR\u201301"):
        rc, _ = _run_nomap(tmp_path, _fm("false") + f"# s\n## {h} x\n", capsys)
        assert rc != 0, h


def test_declared_false_nfr_heading_not_contradiction(tmp_path, capsys):
    rc, _ = _run_nomap(tmp_path, _fm("false") + "# s\n## NFR-01 x\n", capsys)
    assert rc == 0


def test_undeclared_zero_fr_fails_regardless_of_wording(tmp_path, capsys):
    for body in ("# s\n元件契約表\n", "# s\n**FR-01** 需求\n"):
        for fm in (_fm(), _fm("true")):
            rc, out = _run_nomap(tmp_path, fm + body, capsys)
            assert rc != 0
            assert "### FR-NN" in out and "has_functional_requirements: false" in out


def test_non_boolean_declaration_errors(tmp_path, capsys):
    # 本文含 FR 標題：若被當作 true 會走比對，不會出現「須為布林」訊息
    for v in ('"false"', "null", "", "no"):
        rc, out = _run_nomap(tmp_path, _fm(v) + "# s\n### FR-01: A\n", capsys)
        assert rc != 0, v
        assert "須為布林" in out, v


def test_declared_false_letter_continuation_headings_not_contradiction(tmp_path, capsys):
    for h in ("Framework", "FRAME"):
        rc, _ = _run_nomap(tmp_path, _fm("false") + f"# s\n## {h} x\n", capsys)
        assert rc == 0, h


# --- 0.5.0-W1-086.5 追修：系統層不適用整份無歸屬規則 + stderr 訊號 ---

SYSTEM_PROSE = "涉及 FR-02 與 FR-03\n"


def test_system_layer_unattributed_not_counted_in_domain_dir(tmp_path, monkeypatch, capsys):
    spec = _in_domain_dir(tmp_path, monkeypatch, _map("SPEC-101", "## SPEC-101\n| FR-01 | A |\n"),
                          system=SYSTEM_PROSE)
    assert cdc.main([spec]) == 1, capsys.readouterr().out


def test_system_layer_unattributed_not_counted_outside_domain_dir(tmp_path, monkeypatch, capsys):
    monkeypatch.chdir(tmp_path)
    spec = tmp_path / "docs/spec/ui/SPEC-101-x.md"
    _write(spec, SPEC_A)
    _write(tmp_path / "docs/spec/a/domain-map.md", _map("SPEC-101", "## SPEC-101\n| FR-01 | A |\n"))
    _write(tmp_path / "docs/system-layer.md", SYSTEM_PROSE)
    assert cdc.main([str(spec)]) == 1, capsys.readouterr().out


def test_default_attribution_signal_on_stderr(tmp_path, monkeypatch, capsys):
    spec = _in_domain_dir(tmp_path, monkeypatch, _map("SPEC-101", "| FR-01~03 | A |\n"))
    assert cdc.main([spec]) == 0
    err = capsys.readouterr().err
    assert "domain-map.md" in err and "無任何 SPEC 歸屬" in err


def test_no_signal_when_explicitly_attributed(tmp_path, monkeypatch, capsys):
    spec = _in_domain_dir(tmp_path, monkeypatch, _map("SPEC-101", "## SPEC-101\n| FR-01~03 | A |\n"))
    assert cdc.main([spec]) == 0
    assert "無任何 SPEC 歸屬" not in capsys.readouterr().err
