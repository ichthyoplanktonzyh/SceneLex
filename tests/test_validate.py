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
