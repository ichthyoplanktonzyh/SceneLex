import export


def test_bundle_is_consumer_oriented_and_deterministic():
    first = export.build_bundle("test")
    second = export.build_bundle("test")
    assert first == second
    assert first["package"]["id"] == "scenelex-core"
    assert first["index"]["sense_ids_by_word"]["messy"] == ["messy-01"]
    assert len(first["scenes"]) == 10


def test_published_filter_does_not_leak_reviewed_resources():
    bundle = export.build_bundle("test", ("published",))
    assert bundle["senses"] == []
    assert bundle["scenes"] == []
