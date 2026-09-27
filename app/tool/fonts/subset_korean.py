#!/usr/bin/env python3
# Copyright 2026 Suruch Chakrapeesirisuk
# SPDX-License-Identifier: Apache-2.0
"""ตัด NotoSansKR ตัวเต็มให้เหลือชุดที่แอปฝังไว้ใน assets/fonts/

ชุดที่เก็บ (DECISIONS #74):
- พยางค์ฮันกึล 2,350 ตัวของ KS X 1001 — ชุดที่ใช้กันจริงเกือบทั้งหมด พนักงานพิมพ์ชื่อลูกค้า
  ชื่อโปร หมายเหตุ เป็นภาษาเกาหลีได้โดยไม่ขึ้นกล่อง
- จาโม (U+1100–11FF) และจาโมแบบ compatibility (U+3130–318F) — ตัวที่โผล่ระหว่างพิมพ์ผ่าน IME
- ASCII, เครื่องหมายวรรคตอน CJK (U+3000–303F)
- ทุกตัวที่ subset เดิมมี (จึงไม่มีอะไรหายจากคำแปลที่ผ่านเทสต์อยู่แล้ว)

พยางค์นอก KS X 1001 (หายากมาก) ปล่อยให้ฟอนต์สำรองของแพลตฟอร์มวาด

ใช้:
    npm pack @expo-google-fonts/noto-sans-kr@0.4.3   # ไฟล์ .ttf ตัวเต็มจาก Google Fonts (OFL)
    tar xzf expo-google-fonts-noto-sans-kr-0.4.3.tgz
    python3 app/tool/fonts/subset_korean.py package
"""
import sys
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont

WEIGHTS = {400: '400Regular', 500: '500Medium', 700: '700Bold', 800: '800ExtraBold'}
ASSETS = Path(__file__).resolve().parents[2] / 'assets' / 'fonts'


def codepoints(previous: set[int]) -> set[int]:
    ksx = {
        c
        for c in range(0xAC00, 0xD7A4)
        if len(chr(c).encode('euc-kr', errors='ignore')) == 2
    }
    assert len(ksx) == 2350, len(ksx)
    return (
        previous
        | ksx
        | set(range(0x1100, 0x1200))
        | set(range(0x3130, 0x3190))
        | set(range(0x20, 0x7F))
        | set(range(0x3000, 0x3040))
    )


def main(package: Path) -> None:
    for weight, folder in WEIGHTS.items():
        target = ASSETS / f'NotoSansKR-{weight}.ttf'
        previous = set(TTFont(target).getBestCmap()) if target.exists() else set()
        options = subset.Options()
        options.layout_features = ['*']
        options.name_IDs = ['*']
        options.notdef_outline = True
        font = TTFont(package / folder / f'NotoSansKR_{folder}.ttf')
        subsetter = subset.Subsetter(options)
        subsetter.populate(unicodes=sorted(codepoints(previous)))
        subsetter.subset(font)
        font.save(target)
        print(f'{target.relative_to(ASSETS.parents[1])}  {target.stat().st_size // 1024} KB')


if __name__ == '__main__':
    main(Path(sys.argv[1] if len(sys.argv) > 1 else 'package'))
