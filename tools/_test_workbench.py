"""Quick test for workbench API endpoints."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from workbench import app
from fastapi.testclient import TestClient

client = TestClient(app)

# Test /api/dict
r = client.get("/api/dict")
assert r.status_code == 200
data = r.json()
print(f"/api/dict: {data['total']} words")
for w in data["words"][:3]:
    print(f"  {w['word']}: {w['sense_count']} senses, {w['scene_count']} scenes")

# Test /api/dict/{word}
r = client.get("/api/dict/dirty")
assert r.status_code == 200
data = r.json()
print(f"/api/dict/dirty: {data['word']}, {len(data['senses'])} senses")
for s in data["senses"]:
    print(f"  {s['id']}: {len(s['scenes'])} scenes")

# Test /api/dict/notfound
r = client.get("/api/dict/zzzznotfound")
assert r.status_code == 404
print("404 for unknown word: OK")

# Test /dictionary page
r = client.get("/dictionary")
assert r.status_code == 200
print("/dictionary page: OK")

# Test /words/{word} page
r = client.get("/words/dirty")
assert r.status_code == 200
print("/words/dirty page: OK")

# Test /api/dict/almost (word with multiple scenes of same type)
r = client.get("/api/dict/almost")
assert r.status_code == 200
data = r.json()
proto_count = data["senses"][0]["scene_types"].get("prototype", 0)
print(f"/api/dict/almost: {data['word']}, prototype scenes: {proto_count}")
assert proto_count == 2

print("\nAll tests passed")
