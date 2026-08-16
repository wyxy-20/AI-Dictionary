#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
词库质量校验脚本（R9 词库质量门禁）。

用法：
    python tool/validate_terms.py [path...]

- 不传参数：校验内置词库 assets/data/terms/*.json（26 个字母文件）
- 传参数：校验指定的 JSON 文件（如远程拉取的 terms.json，或
  AI-Terms-Database 仓库的 CI 中作为门禁使用）

校验项：
  1. 每个词条必填字段完整（english_name / chinese_name / category /
     difficulty / short_description / detail_description）
  2. english_name 非空且全局唯一（忽略大小写）
  3. difficulty 必须为 1~3
  4. application / related_terms 必须为字符串数组
  5. 输出统计（词条总数 / 分类数 / 每个字母数量）

退出码：0 = 通过；1 = 存在错误（供 CI 门禁使用）。
"""
import json
import sys
from collections import Counter
from pathlib import Path

REQUIRED_FIELDS = [
    "english_name",
    "chinese_name",
    "category",
    "difficulty",
    "short_description",
    "detail_description",
]
LIST_FIELDS = ["application", "related_terms"]


def validate_terms(terms: list) -> tuple[list[str], Counter]:
    """校验词条列表，返回 (错误列表, 首字母统计)。"""
    errors: list[str] = []
    seen: set[str] = set()
    letter_count: Counter = Counter()

    for idx, term in enumerate(terms):
        pos = f"词条 #{idx + 1}"

        if not isinstance(term, dict):
            errors.append(f"{pos}: 不是 JSON 对象")
            continue

        en = str(term.get("english_name", "")).strip()
        if not en:
            errors.append(f"{pos}: english_name 为空")

        for field in REQUIRED_FIELDS:
            if field not in term or term[field] is None or term[field] == "":
                errors.append(f"{pos} ({en or '?'}): 缺少必填字段 {field}")

        difficulty = term.get("difficulty")
        if difficulty is not None:
            if not isinstance(difficulty, int) or not 1 <= difficulty <= 3:
                errors.append(f"{pos} ({en}): difficulty={difficulty} 不在 1~3 范围")

        for field in LIST_FIELDS:
            value = term.get(field)
            if value is not None:
                if not isinstance(value, list) or not all(
                    isinstance(v, str) for v in value
                ):
                    errors.append(f"{pos} ({en}): {field} 必须是字符串数组")

        key = en.lower()
        if en:
            if key in seen:
                errors.append(f"{pos} ({en}): english_name 重复")
            seen.add(key)
            letter = en[0].upper() if en[0].isalpha() else "#"
            letter_count[letter] += 1

    return errors, letter_count


def load_terms(path: Path) -> list:
    """加载 JSON 文件（支持数组或 {"terms": [...]} 两种格式）。"""
    data = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(data, list):
        return data
    if isinstance(data, dict) and isinstance(data.get("terms"), list):
        return data["terms"]
    raise ValueError(f"{path}: 不是词条数组或 {{'terms': [...]}} 结构")


def main(argv: list[str]) -> int:
    if argv:
        paths = [Path(p) for p in argv]
    else:
        assets = Path(__file__).resolve().parent.parent / "assets" / "data" / "terms"
        paths = sorted(assets.glob("*.json"))

    all_errors: list[str] = []
    letter_count: Counter = Counter()
    total = 0

    for path in paths:
        try:
            terms = load_terms(path)
        except (json.JSONDecodeError, ValueError, OSError) as e:
            all_errors.append(f"{path}: 无法解析 - {e}")
            continue
        errors, letters = validate_terms(terms)
        letter_count += letters
        total += len(terms)
        for err in errors:
            all_errors.append(f"{path}: {err}")
        print(f"{path.name}: {len(terms)} 条")

    print(f"\n总计: {total} 条词条, {len(letter_count)} 个首字母分组")
    print("分布: " + ", ".join(f"{k}={v}" for k, v in sorted(letter_count.items())))

    if all_errors:
        print(f"\n发现 {len(all_errors)} 个问题:")
        for err in all_errors:
            print(f"  ✗ {err}")
        return 1

    print("\n✓ 词库校验通过")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
