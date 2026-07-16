import export


def test_bundle_is_consumer_oriented_and_deterministic():
    first = export.build_bundle("test")
    second = export.build_bundle("test")
    assert first == second
    assert first["package"]["id"] == "scenelex-core"
    assert first["index"]["sense_ids_by_word"]["messy"] == ["messy-01"]
    # The library grows over time, so assert invariants rather than counts:
    # bundled scenes must always belong to a bundled sense.
    sense_ids = {sense["id"] for sense in first["senses"]}
    assert sense_ids >= {"messy-01", "reluctant-01"}
    assert first["scenes"]
    assert {scene["sense_ref"] for scene in first["scenes"]} <= sense_ids


def test_published_filter_does_not_leak_reviewed_resources():
    bundle = export.build_bundle("test", ("published",))
    assert bundle["senses"] == []
    assert bundle["scenes"] == []
