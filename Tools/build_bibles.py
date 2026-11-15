#!/usr/bin/env python3
"""Converts public-domain Bible XML files into the compact JSON the app bundles.

Source: https://github.com/seven1m/open-bibles (all three files are listed there as Public Domain)
  eng-kjv.osis.xml   King James Version
  eng-web.usfx.xml   World English Bible
  chi-cuv.usfx.xml   Chinese Union Version, Traditional (和合本)

Usage: python3 Tools/build_bibles.py <folder with the three xml files> BibleAlarm/Resources/Bibles

Output format (one file per version):
  {"id": "kjv", "books": [{"id": "GEN", "chapters": [["verse 1", "verse 2", ...], ...]}, ...]}
A verse that does not exist in a version is an empty string.
"""
import html
import json
import os
import re
import sys

BOOKS = ["GEN", "EXO", "LEV", "NUM", "DEU", "JOS", "JDG", "RUT", "1SA", "2SA", "1KI", "2KI", "1CH", "2CH",
         "EZR", "NEH", "EST", "JOB", "PSA", "PRO", "ECC", "SNG", "ISA", "JER", "LAM", "EZK", "DAN", "HOS",
         "JOL", "AMO", "OBA", "JON", "MIC", "NAM", "HAB", "ZEP", "HAG", "ZEC", "MAL", "MAT", "MRK", "LUK",
         "JHN", "ACT", "ROM", "1CO", "2CO", "GAL", "EPH", "PHP", "COL", "1TH", "2TH", "1TI", "2TI", "TIT",
         "PHM", "HEB", "JAS", "1PE", "2PE", "1JN", "2JN", "3JN", "JUD", "REV"]

OSIS = ["Gen", "Exod", "Lev", "Num", "Deut", "Josh", "Judg", "Ruth", "1Sam", "2Sam", "1Kgs", "2Kgs", "1Chr",
        "2Chr", "Ezra", "Neh", "Esth", "Job", "Ps", "Prov", "Eccl", "Song", "Isa", "Jer", "Lam", "Ezek", "Dan",
        "Hos", "Joel", "Amos", "Obad", "Jonah", "Mic", "Nah", "Hab", "Zeph", "Hag", "Zech", "Mal", "Matt",
        "Mark", "Luke", "John", "Acts", "Rom", "1Cor", "2Cor", "Gal", "Eph", "Phil", "Col", "1Thess", "2Thess",
        "1Tim", "2Tim", "Titus", "Phlm", "Heb", "Jas", "1Pet", "2Pet", "1John", "2John", "3John", "Jude", "Rev"]
OSIS_TO_ID = dict(zip(OSIS, BOOKS))


def clean(text, chinese=False):
    text = re.sub(r"<[^>]*>", "", text)
    text = html.unescape(text)
    text = text.replace("¶", "")  # pilcrow paragraph marks in some KJV files
    if chinese:
        text = re.sub(r"\s+", "", text)
    else:
        text = re.sub(r"\s+", " ", text).strip()
        text = re.sub(r"\s+([,.;:!?])", r"\1", text)
    return text


def put(store, book, chapter, verse, text):
    if not text:
        return
    chapters = store.setdefault(book, {})
    verses = chapters.setdefault(chapter, {})
    verses[verse] = (verses[verse] + " " + text) if verse in verses else text


def parse_usfx(path, chinese=False):
    data = open(path, encoding="utf-8").read()
    store = {}
    for m in re.finditer(r'<book id="([A-Z0-9]+)"[^>]*>(.*?)</book>', data, re.S):
        book, body = m.group(1), m.group(2)
        if book not in BOOKS:
            continue
        # Drop notes, cross references, headings, Psalm titles and other non-verse content.
        for tag in ("f", "x", "ef", "ex", "s", "d", "h", "toc", "id", "ide", "rem", "r", "mt", "ms", "sp"):
            body = re.sub(r"<%s(\s[^>]*)?>.*?</%s>" % (tag, tag), "", body, flags=re.S)
        body = re.sub(r'<p sfm="(mt\d*|ms\d*|is\d*|ip|r|mr|sr|s\d*|d)"[^>]*>.*?</p>', "", body, flags=re.S)
        parts = re.split(r'(<c id="\d+"\s*/>|<v id="[^"]+"[^>]*/>|<ve\s*/>)', body)
        chapter, verse = 0, None
        for part in parts:
            c = re.match(r'<c id="(\d+)"', part)
            v = re.match(r'<v id="([^"]+)"', part)
            if c:
                chapter, verse = int(c.group(1)), None
            elif v:
                verse = int(re.match(r"\d+", v.group(1)).group(0))
            elif part.startswith("<ve"):
                verse = None
            elif verse is not None and chapter:
                text = clean(part, chinese)
                if chinese and book == "PSA" and verse == 1:
                    # Psalm titles are printed in brackets at the start of verse 1; they are not verse text.
                    text = re.sub(r"^（[^）]*）", "", text)
                put(store, book, chapter, verse, text)
    return store


def parse_osis(path):
    data = open(path, encoding="utf-8").read()
    data = re.sub(r"<title[^>]*>.*?</title>", "", data, flags=re.S)
    data = re.sub(r"<note[^>]*>.*?</note>", "", data, flags=re.S)
    store = {}
    pattern = re.compile(r'<verse osisID="([^"]+)" sID="([^"]+)"[^>]*/>(.*?)<verse eID="\2"\s*/>', re.S)
    for m in pattern.finditer(data):
        ref = m.group(1).split(" ")[0].split(".")
        if len(ref) != 3 or ref[0] not in OSIS_TO_ID:
            continue
        put(store, OSIS_TO_ID[ref[0]], int(ref[1]), int(ref[2]), clean(m.group(3)))
    return store


def export(store, version_id, out_dir):
    books = []
    count = 0
    for book in BOOKS:
        chapters = store.get(book)
        if not chapters:
            raise SystemExit("%s: missing book %s" % (version_id, book))
        out = []
        for c in range(1, max(chapters) + 1):
            verses = chapters.get(c, {})
            row = [verses.get(v, "") for v in range(1, (max(verses) if verses else 0) + 1)]
            count += sum(1 for t in row if t)
            out.append(row)
        books.append({"id": book, "chapters": out})
    path = os.path.join(out_dir, version_id + ".json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump({"id": version_id, "books": books}, f, ensure_ascii=False, separators=(",", ":"))
    print("%s: %d verses, %.1f MB" % (version_id, count, os.path.getsize(path) / 1e6))


if __name__ == "__main__":
    src, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)
    export(parse_osis(os.path.join(src, "eng-kjv.osis.xml")), "kjv", out_dir)
    export(parse_usfx(os.path.join(src, "eng-web.usfx.xml")), "web", out_dir)
    export(parse_usfx(os.path.join(src, "chi-cuv.usfx.xml"), chinese=True), "cuv", out_dir)
