#!/usr/bin/env python3
"""Builds BibleAlarm/Resources/Bibles/verse_sets.json: the curated list of morning verses.

The app never shows a random verse from the whole Bible (that would include genealogies and
laws); it draws from these hand-picked references. Every reference is checked against all
three bundled versions, and anything missing or too long for the wake-up screen is dropped.

Usage: python3 Tools/verse_sets.py BibleAlarm/Resources/Bibles
"""
import json
import os
import sys

SETS = {
"peace": """JHN 14:27, JHN 16:33, PHP 4:6, PHP 4:7, ISA 26:3, PSA 4:8, PSA 29:11, COL 3:15, 2TH 3:16, ROM 5:1,
 ROM 15:13, NUM 6:24, NUM 6:25, NUM 6:26, PSA 119:165, ISA 32:17, MAT 5:9, ROM 12:18, ISA 54:10, PSA 34:14,
 JAS 3:18, ROM 8:6, PRO 16:7, ISA 55:12, PSA 85:8, EPH 2:14, 1PE 5:7, MAT 11:28, MAT 11:29, MAT 11:30, PSA 46:10,
 ISA 9:6, LUK 2:14, 1CO 14:33, GAL 5:22, PSA 37:11, HEB 12:14, 2CO 13:11""",
"strength": """PHP 4:13, ISA 40:31, ISA 40:29, ISA 41:10, PSA 46:1, PSA 18:2, PSA 28:7, NEH 8:10, 2CO 12:9, 2CO 12:10,
 EPH 6:10, DEU 31:6, JOS 1:9, PSA 27:1, PSA 73:26, HAB 3:19, EXO 15:2, PSA 118:14, ISA 12:2, 2TI 1:7, 1CO 16:13,
 PSA 138:3, PSA 31:24, ISA 41:13, PSA 121:1, PSA 121:2, DEU 33:27, PSA 55:22, 2SA 22:33, PSA 18:32, 1CH 16:11,
 PSA 105:4, EPH 3:16, COL 1:11, 2TH 3:3, 1PE 5:10, PSA 46:5, ZEP 3:17, PSA 59:16, PSA 68:35, ISA 26:4, PSA 84:5""",
"hope": """JER 29:11, ROM 15:13, ROM 8:28, ROM 8:18, ROM 5:5, ROM 12:12, HEB 11:1, HEB 10:23, HEB 6:19, LAM 3:22,
 LAM 3:23, LAM 3:24, LAM 3:25, PSA 42:11, PSA 71:5, PSA 130:5, PSA 33:22, PSA 39:7, PRO 23:18, ISA 43:19, 1PE 1:3,
 ROM 8:24, ROM 8:25, PSA 31:24, PSA 62:5, TIT 2:13, PSA 147:11, MIC 7:7, ROM 5:3, ROM 5:4, 2CO 4:16, 2CO 4:17,
 2CO 4:18, REV 21:4, REV 21:5, PSA 30:5, JOB 19:25, PSA 119:114, ISA 40:8, PHP 1:6, 1CO 2:9, PSA 16:11, JHN 11:25""",
"love": """JHN 3:16, 1JN 4:8, 1JN 4:16, 1JN 4:18, 1JN 4:19, 1JN 4:10, 1JN 4:7, 1JN 3:1, 1JN 3:18, ROM 5:8, ROM 8:38,
 ROM 8:39, 1CO 13:4, 1CO 13:5, 1CO 13:6, 1CO 13:7, 1CO 13:8, 1CO 13:13, 1CO 16:14, JHN 13:34, JHN 13:35, JHN 15:12,
 JHN 15:13, JHN 15:9, EPH 4:2, EPH 5:2, EPH 3:17, EPH 3:18, EPH 3:19, COL 3:14, 1PE 4:8, PRO 10:12, PRO 17:17,
 MAT 22:37, MAT 22:39, MRK 12:30, DEU 6:5, DEU 7:9, PSA 136:1, PSA 86:15, PSA 103:8, PSA 36:7, JER 31:3, ZEP 3:17,
 ROM 12:9, ROM 12:10, ROM 13:10, GAL 2:20, GAL 5:13, LUK 6:35, MAT 5:44, SNG 8:7, PSA 63:3, EPH 2:4, EPH 2:5""",
"faith": """HEB 11:1, HEB 11:6, 2CO 5:7, MRK 11:24, MRK 9:23, MAT 17:20, MAT 21:22, ROM 10:17, ROM 1:17, EPH 2:8,
 EPH 2:9, GAL 2:20, JAS 1:3, JAS 1:6, JAS 2:17, 1JN 5:4, PRO 3:5, PRO 3:6, PSA 37:5, PSA 56:3, PSA 56:4, ISA 26:4,
 JHN 20:29, JHN 14:1, JHN 11:40, LUK 1:37, MAT 19:26, MRK 10:27, HAB 2:4, 1CO 16:13, 2TI 4:7, 1PE 1:8, 1PE 1:7,
 ROM 4:20, ROM 4:21, HEB 12:2, PSA 9:10, PSA 112:7, PSA 125:1, JER 17:7, PSA 28:7, NAM 1:7, PSA 20:7, PSA 62:8,
 PSA 118:8, JHN 6:35, ROM 10:9, GAL 3:26""",
"joy": """PSA 118:24, NEH 8:10, PHP 4:4, 1TH 5:16, PSA 16:11, PSA 30:5, PSA 100:1, PSA 100:2, PSA 126:3, PSA 126:5,
 JHN 15:11, JHN 16:22, JHN 16:24, ROM 14:17, ROM 15:13, GAL 5:22, JAS 1:2, HAB 3:18, ISA 61:10, ISA 12:3, ISA 55:12,
 PSA 5:11, PSA 32:11, PSA 47:1, PSA 51:12, PSA 94:19, PSA 97:11, PRO 17:22, PRO 15:13, ZEP 3:17, LUK 2:10, 1PE 1:8,
 PSA 4:7, PSA 28:7, PSA 33:21, PSA 90:14, PSA 92:4, PSA 95:1, ECC 3:12, 3JN 1:4, PSA 19:8, PSA 40:16, PSA 68:3""",
"wisdom": """PRO 1:7, PRO 2:6, PRO 3:5, PRO 3:6, PRO 3:7, PRO 3:9, PRO 3:13, PRO 3:27, PRO 4:7, PRO 4:23, PRO 4:18,
 PRO 9:10, PRO 10:9, PRO 10:12, PRO 11:2, PRO 11:25, PRO 12:25, PRO 13:20, PRO 14:26, PRO 14:29, PRO 15:1, PRO 15:3,
 PRO 15:13, PRO 15:22, PRO 15:33, PRO 16:3, PRO 16:9, PRO 16:18, PRO 16:24, PRO 16:32, PRO 17:17, PRO 17:22,
 PRO 18:10, PRO 18:21, PRO 18:24, PRO 19:11, PRO 19:17, PRO 19:20, PRO 19:21, PRO 20:7, PRO 21:2, PRO 21:21,
 PRO 22:1, PRO 22:6, PRO 22:9, PRO 23:18, PRO 24:16, PRO 25:11, PRO 27:1, PRO 27:17, PRO 28:13, PRO 29:25, PRO 30:5,
 PRO 31:25, PRO 31:30, JAS 1:5, JAS 1:19, JAS 3:17, ECC 3:1, ECC 3:11, ECC 12:13, PSA 111:10, PSA 90:12, COL 3:16,
 COL 4:6, JOB 28:28, PSA 119:11, MIC 6:8, EPH 5:15, EPH 5:16""",
"psalms": """PSA 1:1, PSA 1:2, PSA 1:3, PSA 3:3, PSA 5:3, PSA 8:1, PSA 9:1, PSA 9:9, PSA 16:8, PSA 18:1, PSA 18:30,
 PSA 19:1, PSA 19:14, PSA 23:1, PSA 23:2, PSA 23:3, PSA 23:4, PSA 23:5, PSA 23:6, PSA 24:1, PSA 25:4, PSA 25:5,
 PSA 27:4, PSA 27:14, PSA 32:8, PSA 33:4, PSA 34:1, PSA 34:4, PSA 34:8, PSA 34:18, PSA 37:4, PSA 37:7, PSA 37:23,
 PSA 37:24, PSA 40:1, PSA 40:2, PSA 40:3, PSA 42:1, PSA 42:2, PSA 46:10, PSA 51:10, PSA 55:22, PSA 57:1, PSA 61:2,
 PSA 62:1, PSA 62:2, PSA 63:1, PSA 65:11, PSA 66:1, PSA 67:1, PSA 73:28, PSA 84:10, PSA 84:11, PSA 86:5, PSA 90:2,
 PSA 91:1, PSA 91:2, PSA 91:4, PSA 91:11, PSA 95:6, PSA 96:1, PSA 100:3, PSA 100:4, PSA 100:5, PSA 103:1, PSA 103:2,
 PSA 103:3, PSA 103:4, PSA 103:5, PSA 103:11, PSA 103:12, PSA 103:13, PSA 107:1, PSA 107:9, PSA 113:3, PSA 116:1,
 PSA 116:2, PSA 118:1, PSA 118:6, PSA 119:9, PSA 119:18, PSA 119:105, PSA 119:130, PSA 121:3, PSA 121:5, PSA 121:7,
 PSA 121:8, PSA 127:1, PSA 133:1, PSA 136:26, PSA 138:8, PSA 139:1, PSA 139:9, PSA 139:10, PSA 139:14, PSA 139:23,
 PSA 139:24, PSA 143:8, PSA 143:10, PSA 145:3, PSA 145:8, PSA 145:9, PSA 145:18, PSA 147:3, PSA 150:6""",
"comfort": """PSA 34:18, PSA 147:3, MAT 5:4, MAT 11:28, 2CO 1:3, 2CO 1:4, ISA 41:10, ISA 43:2, ISA 43:1, ISA 49:15,
 ISA 49:16, ISA 66:13, PSA 23:4, PSA 46:1, PSA 55:22, PSA 94:19, PSA 119:50, PSA 119:76, JHN 14:1, JHN 14:27,
 JHN 14:18, REV 21:4, ROM 8:28, ROM 8:38, DEU 31:8, JOS 1:5, HEB 13:5, HEB 13:6, 1PE 5:7, PSA 9:9, PSA 27:10,
 PSA 30:5, PSA 73:26, NAM 1:7, ISA 40:1, ISA 40:11, ISA 51:12, LAM 3:22, MAT 28:20, PSA 56:8, ISA 53:4, ISA 53:5,
 PSA 68:5, 2TH 2:16, 2TH 2:17, PSA 71:21, PSA 86:17""",
"guidance": """PRO 3:5, PRO 3:6, PSA 32:8, PSA 119:105, ISA 30:21, ISA 58:11, PSA 25:9, PSA 37:23, PSA 48:14, PSA 73:24,
 PRO 16:9, PRO 16:3, JAS 1:5, JHN 16:13, JHN 8:12, JHN 14:6, JHN 10:27, PSA 143:8, PSA 143:10, PSA 5:8, PSA 25:4,
 PSA 31:3, PSA 139:10, ISA 42:16, ISA 48:17, JER 33:3, PRO 4:11, PRO 11:14, PRO 20:24, ROM 12:2, GAL 5:16, GAL 5:25,
 PSA 16:7, PSA 23:3, PSA 27:11, PSA 119:133, EXO 13:21, DEU 31:8, MAT 6:33, MAT 7:7, MAT 7:8, PRO 2:6, PSA 37:5,
 ISA 55:8, ISA 55:9, JER 10:23, PRO 19:21, MIC 6:8, COL 3:17, 1CO 10:31""",
"grace": """EPH 2:8, EPH 2:9, EPH 2:10, 2CO 12:9, ROM 3:23, ROM 3:24, ROM 6:23, ROM 5:8, ROM 8:1, ROM 10:9, ROM 10:13,
 JHN 1:12, JHN 1:14, JHN 1:16, JHN 3:16, JHN 3:17, JHN 5:24, JHN 10:10, JHN 10:28, JHN 14:6, ACT 4:12, ACT 16:31,
 TIT 2:11, TIT 3:5, HEB 4:16, 1JN 1:9, 1JN 5:11, 1JN 5:12, 2CO 5:17, 2CO 5:21, 2CO 9:8, GAL 2:20, ISA 1:18, ISA 53:5,
 ISA 53:6, PSA 103:12, MIC 7:18, MIC 7:19, 1PE 2:24, 1PE 5:10, 1TI 1:15, 1TI 2:5, 2TI 1:9, JAS 4:6, HEB 7:25,
 REV 3:20, MAT 1:21, LUK 19:10, JHN 6:37, JHN 8:36, ROM 5:20, ROM 11:6, EPH 1:7, COL 1:13, COL 1:14, 2PE 3:9,
 2PE 3:18, HEB 9:28, 1CO 15:57, ROM 1:16""",
"prayer": """PHP 4:6, 1TH 5:17, MAT 6:6, MAT 6:9, MAT 6:10, MAT 6:11, MAT 6:12, MAT 6:13, MAT 7:7, MAT 21:22, MRK 11:24,
 JER 33:3, JER 29:12, JER 29:13, JAS 5:16, JAS 1:5, 1JN 5:14, 1JN 5:15, PSA 5:3, PSA 17:6, PSA 18:6, PSA 34:17,
 PSA 55:17, PSA 66:19, PSA 66:20, PSA 102:17, PSA 116:1, PSA 141:2, PSA 145:18, ROM 8:26, ROM 12:12, COL 4:2,
 EPH 6:18, HEB 4:16, LUK 11:9, LUK 18:1, JHN 14:13, JHN 14:14, JHN 15:7, JHN 16:24, 2CH 7:14, ISA 65:24, PSA 4:1,
 PSA 86:6, PSA 86:7, PRO 15:29, MAT 18:20, MAT 26:41, 1PE 3:12, 1TI 2:1, PSA 61:1, PSA 65:2, LAM 3:25, PSA 62:8,
 PSA 19:14""",
"gratitude": """1TH 5:18, PSA 107:1, PSA 118:1, PSA 100:4, PSA 136:1, PSA 9:1, PSA 28:7, PSA 30:12, PSA 69:30, PSA 92:1,
 PSA 95:2, PSA 103:2, PSA 106:1, PSA 118:28, PSA 118:29, PSA 136:26, PSA 138:1, COL 3:15, COL 3:17, COL 2:7,
 COL 4:2, EPH 5:20, PHP 4:6, 1CH 16:34, 1CH 16:8, 1CH 29:13, 2CO 9:15, 2CO 9:11, 1CO 15:57, HEB 12:28, HEB 13:15,
 JAS 1:17, 1TI 4:4, PSA 7:17, PSA 50:23, PSA 75:1, PSA 105:1, PSA 111:1, PSA 116:17, ISA 12:4, DAN 2:23, JON 2:9,
 PSA 34:1, PSA 63:3, PSA 145:1, PSA 145:2, REV 4:11, REV 7:12, 2CO 2:14, 2CO 4:15, ROM 11:36, PSA 139:14""",
"courage": """JOS 1:9, DEU 31:6, DEU 31:8, ISA 41:10, ISA 41:13, PSA 27:1, PSA 27:14, PSA 31:24, PSA 56:3, PSA 56:11,
 PSA 118:6, 2TI 1:7, 1CO 16:13, JHN 16:33, ROM 8:31, ROM 8:37, HEB 13:6, PSA 23:4, PSA 34:4, PSA 46:2, PSA 91:5,
 PSA 112:7, PRO 28:1, PRO 29:25, ISA 35:4, ISA 43:1, ISA 43:5, ISA 54:17, MAT 10:31, MAT 14:27, MRK 5:36, LUK 12:32,
 JHN 14:27, ACT 18:9, 1PE 3:14, 1JN 4:4, 1JN 4:18, EPH 6:10, EPH 6:11, PHP 1:28, 1CH 28:20, 2CH 20:15, 2CH 32:7,
 EXO 14:13, EXO 14:14, NUM 14:9, DEU 3:22, DEU 20:4, ISA 12:2, ZEC 4:6, HAG 2:4, PSA 3:6, PSA 16:8, PSA 138:3,
 DAN 10:19, 2KI 6:16, JER 1:8, REV 1:17""",
"morning": """PSA 5:3, PSA 143:8, LAM 3:22, LAM 3:23, PSA 118:24, PSA 90:14, PSA 59:16, MRK 1:35, PSA 57:8, PSA 108:2,
 PSA 92:1, PSA 92:2, ISA 50:4, PSA 30:5, PSA 46:5, PSA 88:13, PSA 119:147, PRO 8:17, ISA 33:2, PSA 65:8, PSA 113:3,
 MAT 6:33, MAT 6:34, ROM 13:11, ROM 13:12, EPH 5:14, ISA 60:1, PSA 3:5, PSA 63:1, PSA 19:14, 2CO 4:16, COL 3:23,
 PSA 37:5, PSA 90:17, PRO 16:3, ZEP 3:5, GEN 1:3, PSA 130:6, HOS 6:3, MAL 4:2, LUK 1:78, 2PE 1:19, REV 22:16,
 ISA 26:9, PSA 17:15, PSA 139:18, NUM 6:24, GAL 6:9, 1CO 15:58, PHP 3:13, PHP 3:14, HEB 12:1, MAT 5:14, MAT 5:16,
 JOS 24:15, PSA 127:2, ISA 40:28, COL 3:2, ROM 12:1, ROM 12:11, 1TH 5:5, 1TH 5:8, EPH 4:1, PSA 96:2, DEU 6:6, DEU 6:7""",
}

# Longest verse (in characters) that still reads comfortably in large type on the wake-up screen.
MAX_LEN = {"kjv": 260, "web": 260, "cuv": 95}
MIN_LEN = {"kjv": 20, "web": 20, "cuv": 6}


def main(folder):
    bibles = {}
    for v in MAX_LEN:
        data = json.load(open(os.path.join(folder, v + ".json"), encoding="utf-8"))
        bibles[v] = {b["id"]: b["chapters"] for b in data["books"]}
    out, dropped, seen = [], [], set()
    for set_id, text in SETS.items():
        refs = []
        for ref in [r.strip() for r in text.replace("\n", " ").split(",") if r.strip()]:
            book, cv = ref.split(" ")
            chapter, verse = [int(x) for x in cv.split(":")]
            ok = True
            for v, books in bibles.items():
                try:
                    t = books[book][chapter - 1][verse - 1]
                except (KeyError, IndexError):
                    t = ""
                if not (MIN_LEN[v] <= len(t) <= MAX_LEN[v]):
                    ok = False
                    dropped.append((set_id, ref, v, len(t)))
            if ok and ref not in refs:
                refs.append(ref)
                seen.add(ref)
        out.append({"id": set_id, "refs": refs})
    with open(os.path.join(folder, "verse_sets.json"), "w", encoding="utf-8") as f:
        json.dump({"sets": out}, f, ensure_ascii=False, indent=1)
    print("unique verses:", len(seen), {s["id"]: len(s["refs"]) for s in out})
    print("dropped:", sorted(set(dropped)))


if __name__ == "__main__":
    main(sys.argv[1])
