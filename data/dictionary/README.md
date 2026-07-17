# 词典事实缓存

`wiktionary/` 下的 `.jsonl` 文件是 [kaikki.org](https://kaikki.org) 对
Wiktionary 的机器解析数据的逐词缓存，由 `tools/dictionary.py` 按需抓取。

- **许可**：Wiktionary 内容采用 CC-BY-SA 3.0/4.0；本目录是其派生缓存，
  保留同一许可与署名（Wiktionary contributors, via kaikki.org / wiktextract）。
- **角色**：这些数据是起草与审核的**事实锚点**（音标、词性、义项划分参照），
  不是 SceneLex 的内容来源。正式义项的 `definition`、语义骨架与场景规格
  必须自行撰写，不得照抄词典释义原文。
- 缓存可随时删除重建（`python3 tools/dictionary.py <word> --refresh`）。
