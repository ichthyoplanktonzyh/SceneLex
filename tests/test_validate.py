import pytest

import validate


def test_current_repository_is_valid():
    result = validate.validate_repository()
    assert result.errors == []


def test_beat_sequence_must_be_contiguous(tmp_path):
    assert validate._beats_are_contiguous([1, 2, 3])
    assert not validate._beats_are_contiguous([1, 3])
    assert not validate._beats_are_contiguous([2, 3])
    assert not validate._beats_are_contiguous([1, 1])


def test_frequency_band_invariant():
    errors = []
    validate._validate_frequency(
        {"frequency": {"band": "high", "rank": 3200}}, "sense", errors
    )
    assert errors == ["sense: frequency.band 'high' 与 rank 3200 不一致"]


def _scene(sense, stype, surface):
    doc = {"sense_ref": sense, "scene_type": stype}
    if surface is not None:
        doc["surface"] = surface
    return doc


def test_identical_surfaces_in_same_type_warn(tmp_path):
    result = validate.ValidationResult()
    home = {"domain": "household", "participant_type": "child",
            "setting": "indoor-home"}
    result.scenes = {
        tmp_path / "a-01-proto-01.yaml": _scene("a-01", "prototype", home),
        tmp_path / "a-01-proto-02.yaml": _scene("a-01", "prototype", dict(home)),
    }
    validate._check_surface_diversity(result, tmp_path)
    assert any("surface 完全相同" in w for w in result.warnings)


def test_diverse_surfaces_do_not_warn(tmp_path):
    result = validate.ValidationResult()
    result.scenes = {
        tmp_path / "a-01-proto-01.yaml": _scene(
            "a-01", "prototype",
            {"domain": "household", "participant_type": "child",
             "setting": "indoor-home"}),
        tmp_path / "a-01-proto-02.yaml": _scene(
            "a-01", "prototype",
            {"domain": "sports", "participant_type": "adult",
             "setting": "outdoor-stadium"}),
    }
    validate._check_surface_diversity(result, tmp_path)
    assert result.warnings == []


def test_missing_surface_only_warns_for_multi_scene_types(tmp_path):
    result = validate.ValidationResult()
    result.scenes = {
        tmp_path / "a-01-proto-01.yaml": _scene("a-01", "prototype", None),
        tmp_path / "a-01-contrast-01.yaml": _scene("a-01", "contrast", None),
    }
    validate._check_surface_diversity(result, tmp_path)
    assert result.warnings == []
    result.scenes[tmp_path / "a-01-proto-02.yaml"] = _scene(
        "a-01", "prototype", None
    )
    validate._check_surface_diversity(result, tmp_path)
    assert sum("缺少 surface" in w for w in result.warnings) == 2


def test_queue_prioritizes_dangling_refs_and_excludes_covered():
    import candidates as queue_tool
    items = queue_tool.build_queue(30)
    assert items, "队列不应为空"
    reasons = [item["reason"] for item in items]
    if "frequency" in reasons:
        assert reasons.index("frequency") > reasons.count("dangling_reference") - 1
    covered = queue_tool.covered_words()
    assert not covered & {item["word"] for item in items}


def test_dictionary_pos_crosscheck_warns_on_mismatch(tmp_path, monkeypatch):
    import dictionary
    monkeypatch.setattr(
        dictionary, "cached_facts",
        lambda w: {"pos_senses": {"adv": ["gloss"]}} if w == "nearly" else None,
    )
    result = validate.ValidationResult()
    result.senses = {
        tmp_path / "nearly-01.yaml": {"word": "nearly", "pos": "noun"},
        tmp_path / "other-01.yaml": {"word": "other", "pos": "noun"},
    }
    validate._check_dictionary_facts(result, tmp_path)
    assert len(result.warnings) == 1 and "pos 'noun'" in result.warnings[0]

    result2 = validate.ValidationResult()
    result2.senses = {
        tmp_path / "nearly-01.yaml": {"word": "nearly", "pos": "adverb"},
    }
    validate._check_dictionary_facts(result2, tmp_path)
    assert result2.warnings == []


# ------------------------------------------- 场景 → 词义语义修订状态

import revisions


def _sense(sense_id="a-01", schema_version="1.1", semantic_revision=1, **extra):
    doc = {"id": sense_id, "schema_version": schema_version, **extra}
    if semantic_revision is not None:
        doc["semantic_revision"] = semantic_revision
    return doc


def _bound_scene(scene_id="a-01-proto-01", sense_ref="a-01",
                 schema_version="1.1", sense_revision=1):
    doc = {"id": scene_id, "sense_ref": sense_ref,
           "schema_version": schema_version, "scene_type": "prototype"}
    if sense_revision is not None:
        doc["sense_revision"] = sense_revision
    return doc


def _checked(tmp_path, scene, sense):
    result = validate.ValidationResult()
    if sense is not None:
        result.senses = {tmp_path / f"{sense['id']}.yaml": sense}
    result.scenes = {tmp_path / f"{scene['id']}.yaml": scene}
    validate._check_scene_revisions(result, tmp_path)
    return result


def test_matching_revision_is_current(tmp_path):
    result = _checked(tmp_path, _bound_scene(sense_revision=2),
                      _sense(semantic_revision=2))
    assert [c.status for c in result.scene_revisions.values()] == [revisions.CURRENT]
    assert result.errors == [] and result.warnings == []


def test_behind_revision_warns_but_does_not_fail_validate(tmp_path):
    result = _checked(tmp_path, _bound_scene(sense_revision=1),
                      _sense(semantic_revision=2))
    check = next(iter(result.scene_revisions.values()))
    assert check.status == revisions.NEEDS_REVIEW
    assert (check.scene_revision, check.current_revision) == (1, 2)
    assert result.errors == []
    assert len(result.warnings) == 1
    assert "重新审核" in result.warnings[0]


def test_revision_ahead_of_wordsense_is_an_error(tmp_path):
    result = _checked(tmp_path, _bound_scene(sense_revision=3),
                      _sense(semantic_revision=2))
    assert next(iter(result.scene_revisions.values())).status == revisions.INVALID
    assert len(result.errors) == 1


def test_legacy_scene_without_binding_is_not_an_error(tmp_path):
    result = _checked(
        tmp_path,
        _bound_scene(schema_version="1.0", sense_revision=None),
        _sense(schema_version="1.0", semantic_revision=None),
    )
    assert next(iter(result.scene_revisions.values())).status == revisions.LEGACY
    assert result.errors == [] and result.warnings == []


def test_scene_11_without_sense_revision_is_invalid(tmp_path):
    result = _checked(tmp_path, _bound_scene(sense_revision=None), _sense())
    assert next(iter(result.scene_revisions.values())).status == revisions.INVALID
    assert result.errors


def test_scene_11_referencing_legacy_sense_is_invalid(tmp_path):
    result = _checked(
        tmp_path,
        _bound_scene(),
        _sense(schema_version="1.0", semantic_revision=None),
    )
    assert next(iter(result.scene_revisions.values())).status == revisions.INVALID
    assert result.errors


def test_sense_11_without_semantic_revision_is_invalid(tmp_path):
    result = _checked(tmp_path, _bound_scene(), _sense(semantic_revision=None))
    assert next(iter(result.scene_revisions.values())).status == revisions.INVALID
    assert result.errors


def test_unknown_sense_ref_is_missing(tmp_path):
    result = _checked(tmp_path, _bound_scene(sense_ref="ghost-01"), None)
    assert next(iter(result.scene_revisions.values())).status == revisions.MISSING
    assert result.errors


def test_non_integer_revision_is_invalid(tmp_path):
    result = _checked(tmp_path, _bound_scene(sense_revision=True), _sense())
    assert next(iter(result.scene_revisions.values())).status == revisions.INVALID


def test_plain_version_bump_does_not_affect_scene_status(tmp_path):
    """措辞/状态/普通 version 变化不是语义变化, 场景仍然 CURRENT。"""
    sense = _sense(semantic_revision=1, version=7, status="published",
                   sense_label="润色过的标签")
    result = _checked(tmp_path, _bound_scene(sense_revision=1), sense)
    assert next(iter(result.scene_revisions.values())).status == revisions.CURRENT
    assert result.errors == [] and result.warnings == []


def _revision_exit_code(tmp_path, scenes_and_senses, sense_filter=""):
    result = validate.ValidationResult()
    result.senses = {tmp_path / f"s{i}.yaml": sense
                     for i, (_, sense) in enumerate(scenes_and_senses)
                     if sense is not None}
    result.scenes = {tmp_path / f"{scene['id']}.yaml": scene
                     for scene, _ in scenes_and_senses}
    validate._check_scene_revisions(result, tmp_path)
    return validate.print_scene_revisions(result, tmp_path, sense_filter)


def test_scene_revisions_cli_exit_codes(tmp_path, capsys):
    current = (_bound_scene(sense_revision=2), _sense(semantic_revision=2))
    behind = (_bound_scene(sense_revision=1), _sense(semantic_revision=2))
    legacy = (_bound_scene(schema_version="1.0", sense_revision=None),
              _sense(schema_version="1.0", semantic_revision=None))
    ahead = (_bound_scene(sense_revision=9), _sense(semantic_revision=2))
    missing = (_bound_scene(sense_ref="ghost-01"), None)

    assert _revision_exit_code(tmp_path, [current]) == 0
    assert _revision_exit_code(tmp_path, [behind]) == 0
    assert _revision_exit_code(tmp_path, [legacy]) == 0
    assert _revision_exit_code(tmp_path, [ahead]) == 1
    assert _revision_exit_code(tmp_path, [missing]) == 1


def test_scene_revisions_cli_reports_both_revisions(tmp_path, capsys):
    _revision_exit_code(
        tmp_path, [(_bound_scene(sense_revision=1), _sense(semantic_revision=4))]
    )
    out = capsys.readouterr().out
    assert "NEEDS_REVIEW a-01-proto-01" in out
    assert "scene revision: 1" in out
    assert "current WordSense revision: 4" in out
    assert "needs_review: 1" in out


def test_scene_revisions_cli_filters_by_sense(tmp_path, capsys):
    scenes = [
        (_bound_scene(sense_revision=1), _sense(semantic_revision=2)),
        (_bound_scene(scene_id="b-01-proto-01", sense_ref="b-01",
                      sense_revision=1),
         _sense(sense_id="b-01", semantic_revision=5)),
    ]
    _revision_exit_code(tmp_path, scenes, sense_filter="b-01")
    out = capsys.readouterr().out
    assert "b-01-proto-01" in out and "a-01-proto-01" not in out
    assert "needs_review: 1" in out


# --------------------------------- revision-only 路径不替发布门发言

def _revision_repo(tmp_path, scene, sense):
    """一个只放了 senses/ 与 scenes/ 的最小数据目录。"""
    import yaml
    (tmp_path / "senses").mkdir()
    (tmp_path / "scenes" / sense["id"]).mkdir(parents=True)
    (tmp_path / "senses" / f"{sense['id']}.yaml").write_text(
        yaml.safe_dump(sense, allow_unicode=True), encoding="utf-8")
    (tmp_path / "scenes" / sense["id"] / f"{scene['id']}.yaml").write_text(
        yaml.safe_dump(scene, allow_unicode=True), encoding="utf-8")
    return tmp_path


def _forbid_full_gate_checks(monkeypatch):
    """任何与语义修订无关的发布门检查被调用都算失败。"""
    def _forbidden(name):
        def _boom(*args, **kwargs):
            raise AssertionError(f"revision-only 路径不得运行 {name}")
        return _boom

    for name in ("_check_dictionary_facts", "_check_inventory_identity",
                 "_check_word_entries", "_check_surface_diversity",
                 "validate_repository", "load_schema"):
        monkeypatch.setattr(validate, name, _forbidden(name))


def test_revision_only_path_skips_unrelated_gate_checks(tmp_path, monkeypatch):
    _revision_repo(tmp_path, _bound_scene(sense_revision=1),
                   _sense(semantic_revision=2))
    _forbid_full_gate_checks(monkeypatch)
    result = validate.validate_scene_revisions(tmp_path)
    assert [c.status for c in result.scene_revisions.values()] == [
        revisions.NEEDS_REVIEW
    ]


def test_revision_only_path_neither_runs_nor_hides_unrelated_errors(
    tmp_path, monkeypatch
):
    """一个与修订无关的普通校验错误 (这里: 场景 id 与文件名不一致) 既不被运行,
    也不被这份只谈修订的报告吞掉。"""
    scene = _bound_scene(sense_revision=2)
    sense = _sense(semantic_revision=2)
    _revision_repo(tmp_path, scene, sense)
    # 完整发布门会因为这个改名报错; revision-only 不该关心它。
    (tmp_path / "scenes" / sense["id"] / f"{scene['id']}.yaml").rename(
        tmp_path / "scenes" / sense["id"] / "renamed.yaml"
    )
    assert any("文件名与 id" in message
               for message in validate.validate_repository(tmp_path).errors)

    _forbid_full_gate_checks(monkeypatch)
    result = validate.validate_scene_revisions(tmp_path)
    assert result.errors == []
    assert [c.status for c in result.scene_revisions.values()] == [
        revisions.CURRENT
    ]


def _run_cli(tmp_path, monkeypatch, capsys, *args):
    """跑一次 validate.py 的 CLI, 返回 (退出码, stdout)。"""
    _forbid_full_gate_checks(monkeypatch)
    monkeypatch.setattr(
        validate.sys, "argv",
        ["validate.py", "--data-root", str(tmp_path), "--scene-revisions", *args],
    )
    with pytest.raises(SystemExit) as exit_info:
        validate.main()
    return exit_info.value.code, capsys.readouterr().out


@pytest.mark.parametrize("scene_revision,sense_revision,schema_version,expected", [
    (2, 2, "1.1", 0),        # CURRENT
    (1, 2, "1.1", 0),        # NEEDS_REVIEW
    (None, 1, "1.0", 0),     # LEGACY
    (9, 2, "1.1", 1),        # INVALID
])
def test_scene_revisions_cli_exit_code_by_status(
    tmp_path, monkeypatch, capsys, scene_revision, sense_revision,
    schema_version, expected
):
    _revision_repo(
        tmp_path,
        _bound_scene(schema_version=schema_version, sense_revision=scene_revision),
        _sense(schema_version=schema_version,
               semantic_revision=sense_revision if schema_version == "1.1" else None),
    )
    code, _ = _run_cli(tmp_path, monkeypatch, capsys)
    assert code == expected


def test_scene_revisions_cli_fails_on_missing_sense(tmp_path, monkeypatch, capsys):
    _revision_repo(tmp_path, _bound_scene(sense_ref="ghost-01"), _sense())
    code, out = _run_cli(tmp_path, monkeypatch, capsys)
    assert code == 1 and "MISSING" in out


def test_scene_revisions_cli_sense_filter_still_works(
    tmp_path, monkeypatch, capsys
):
    import yaml
    _revision_repo(tmp_path, _bound_scene(sense_revision=1),
                   _sense(semantic_revision=2))
    (tmp_path / "senses" / "b-01.yaml").write_text(
        yaml.safe_dump(_sense(sense_id="b-01", semantic_revision=5)),
        encoding="utf-8")
    (tmp_path / "scenes" / "b-01").mkdir()
    (tmp_path / "scenes" / "b-01" / "b-01-proto-01.yaml").write_text(
        yaml.safe_dump(_bound_scene(scene_id="b-01-proto-01", sense_ref="b-01",
                                    sense_revision=1)),
        encoding="utf-8")

    code, out = _run_cli(tmp_path, monkeypatch, capsys, "b-01")
    assert code == 0
    assert "b-01-proto-01" in out and "a-01-proto-01" not in out
    assert "needs_review: 1" in out
