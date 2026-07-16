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
