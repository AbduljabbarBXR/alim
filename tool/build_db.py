#!/usr/bin/env python3
"""Builds assets/db/alim.db from the fetched source data.

Sources (all public domain / open licence):
  * Quran Arabic  — fawazahmed0/quran-api, edition ara-quranuthmanihaf
  * Quran English — fawazahmed0/quran-api, edition eng-abdullahyusufal (Yusuf Ali)
  * Surah metadata — fawazahmed0/quran-api info.json
  * Hadith        — fawazahmed0/hadith-api, Sahih al-Bukhari, Sahih Muslim,
                    Forty Hadith of an-Nawawi, Forty Hadith Qudsi (eng + ara)
  * Stories       — authored for Alim (tool/stories.json)

Run:  python3 tool/build_db.py
"""

import json
import os
import re
import sqlite3
import unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.environ.get("ALIM_SRC", "/tmp/opencode")
OUT = os.path.join(ROOT, "assets", "db", "alim.db")

AR_DIACRITICS = re.compile(
    "[\u0610-\u061a\u064b-\u065f\u0670\u06d6-\u06dc\u06df-\u06e8\u06ea-\u06ed\u0640]"
)


def normalize_ar(text: str) -> str:
    text = AR_DIACRITICS.sub("", text)
    text = (
        text.replace("أ", "ا")
        .replace("إ", "ا")
        .replace("آ", "ا")
        .replace("ٱ", "ا")
        .replace("ى", "ي")
        .replace("ئ", "ي")
        .replace("ؤ", "و")
        .replace("ة", "ه")
    )
    return unicodedata.normalize("NFKC", text)


def normalize_en(text: str) -> str:
    return text.lower()


def load(name: str):
    with open(os.path.join(SRC, name), encoding="utf-8") as fh:
        return json.load(fh)


def main() -> None:
    info = load("quran_info.json")
    ar = load("quran_ar.min.json")["quran"]
    en = load("quran_en.min.json")["quran"]
    stories = []
    for part in ("a", "b", "c", "d"):
        path = os.path.join(ROOT, "tool", f"stories_{part}.json")
        with open(path, encoding="utf-8") as fh:
            stories.extend(json.load(fh)["stories"])
    stories.sort(key=lambda s: s["id"])

    if os.path.exists(OUT):
        os.remove(OUT)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    db = sqlite3.connect(OUT)
    c = db.cursor()
    c.executescript(
        """
        CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);

        CREATE TABLE surah (
            number INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            meaning TEXT NOT NULL,
            name_ar TEXT NOT NULL,
            revelation TEXT NOT NULL,
            ayat INTEGER NOT NULL,
            first_ayah INTEGER NOT NULL
        );

        CREATE TABLE ayah (
            number INTEGER PRIMARY KEY,
            surah INTEGER NOT NULL REFERENCES surah(number),
            ayah INTEGER NOT NULL,
            juz INTEGER NOT NULL,
            page INTEGER NOT NULL,
            sajda INTEGER NOT NULL DEFAULT 0,
            text_ar TEXT NOT NULL,
            text_en TEXT NOT NULL,
            ar_search TEXT NOT NULL,
            en_search TEXT NOT NULL
        );
        CREATE INDEX idx_ayah_surah ON ayah(surah, ayah);

        CREATE TABLE hadith_collection (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            arabic_name TEXT NOT NULL,
            blurb TEXT NOT NULL,
            count INTEGER NOT NULL
        );

        CREATE TABLE hadith_book (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            collection TEXT NOT NULL REFERENCES hadith_collection(id),
            number INTEGER NOT NULL,
            title TEXT NOT NULL
        );
        CREATE UNIQUE INDEX idx_hadith_book ON hadith_book(collection, number);

        CREATE TABLE hadith (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            collection TEXT NOT NULL REFERENCES hadith_collection(id),
            book INTEGER NOT NULL,
            number_in_book INTEGER NOT NULL,
            text_en TEXT NOT NULL,
            text_ar TEXT NOT NULL,
            en_search TEXT NOT NULL,
            ar_search TEXT NOT NULL,
            short INTEGER NOT NULL DEFAULT 0
        );
        CREATE INDEX idx_hadith_collection ON hadith(collection, book);

        CREATE TABLE story (
            id INTEGER PRIMARY KEY,
            category TEXT NOT NULL,
            title TEXT NOT NULL,
            minutes INTEGER NOT NULL,
            body TEXT NOT NULL,
            lesson TEXT NOT NULL,
            ayah_ref TEXT,
            ayah_number INTEGER,
            words INTEGER NOT NULL,
            hadith_id INTEGER,
            hadith_ref TEXT
        );

        -- User data. Created here so a fresh install has its tables waiting;
        -- the app also runs this block on open so old installs gain new tables.
        CREATE TABLE IF NOT EXISTS user_kv (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS bookmark (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            kind TEXT NOT NULL,
            ref INTEGER NOT NULL,
            label TEXT NOT NULL,
            created TEXT NOT NULL
        );
        CREATE UNIQUE INDEX IF NOT EXISTS idx_bookmark ON bookmark(kind, ref);
        CREATE TABLE IF NOT EXISTS daily (
            date TEXT PRIMARY KEY,
            verses INTEGER NOT NULL DEFAULT 0,
            hadiths INTEGER NOT NULL DEFAULT 0,
            stories INTEGER NOT NULL DEFAULT 0,
            dhikr INTEGER NOT NULL DEFAULT 0,
            xp INTEGER NOT NULL DEFAULT 0,
            tasks TEXT NOT NULL DEFAULT '{}'
        );
        CREATE TABLE IF NOT EXISTS todo (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            due TEXT,
            done INTEGER NOT NULL DEFAULT 0,
            created TEXT NOT NULL,
            completed_at TEXT
        );
        CREATE TABLE IF NOT EXISTS gratitude (
            date TEXT PRIMARY KEY,
            text TEXT NOT NULL
        );
        """
    )

    # --- Quran -----------------------------------------------------------
    surahs = info["chapters"]
    first = {}
    n = 0
    for s in surahs:
        first[s["chapter"]] = n + 1
        n += len(s["verses"])
    assert n == 6236 and len(ar) == 6236 and len(en) == 6236

    meta_by_ayah = {}
    for s in surahs:
        for v in s["verses"]:
            meta_by_ayah[(s["chapter"], v["verse"])] = v

    for s in surahs:
        c.execute(
            "INSERT INTO surah VALUES (?,?,?,?,?,?,?)",
            (
                s["chapter"],
                s["name"],
                s["englishname"],
                s["arabicname"].replace("سُوْرَةُ ", "").replace("سورة ", ""),
                s["revelation"],
                len(s["verses"]),
                first[s["chapter"]],
            ),
        )

    global_n = 0
    rows = []
    for a, e in zip(ar, en):
        global_n += 1
        assert a["chapter"] == e["chapter"] and a["verse"] == e["verse"]
        m = meta_by_ayah[(a["chapter"], a["verse"])]
        rows.append(
            (
                global_n,
                a["chapter"],
                a["verse"],
                m["juz"],
                m["page"],
                1 if m.get("sajda") else 0,
                a["text"],
                e["text"],
                normalize_ar(a["text"]),
                normalize_en(e["text"]),
            )
        )
    c.executemany("INSERT INTO ayah VALUES (?,?,?,?,?,?,?,?,?,?)", rows)

    # --- Hadith ----------------------------------------------------------
    collections = [
        ("bukhari", "eng-bukhari", "ara-bukhari", "Sahih al-Bukhari",
         "صحيح البخاري", "The most authentic collection after the Qur'an, compiled by Imam al-Bukhari (d. 256 AH)."),
        ("muslim", "eng-muslim", "ara-muslim", "Sahih Muslim",
         "صحيح مسلم", "The second of the two Sahih collections, compiled by Imam Muslim (d. 261 AH)."),
        ("nawawi", "eng-nawawi", "ara-nawawi", "Forty Hadith of an-Nawawi",
         "الأربعون النووية", "Forty essential hadith chosen by Imam an-Nawawi (d. 676 AH); every one is authentic."),
        ("qudsi", "eng-qudsi", "ara-qudsi", "Forty Hadith Qudsi",
         "الأحاديث القدسية", "Forty sacred narrations in which the Prophet ﷺ relays the words of Allah."),
    ]
    hadith_total = 0
    for cid, en_name, ar_name, name, ar_full, blurb in collections:
        e = load(f"hadith_{en_name}.min.json")
        a = load(f"hadith_{ar_name}.min.json")
        assert len(e["hadiths"]) == len(a["hadiths"])
        sections = e["metadata"].get("sections", {})
        for num, title in sections.items():
            c.execute(
                "INSERT INTO hadith_book (collection, number, title) VALUES (?,?,?)",
                (cid, int(num), title or f"Book {num}"),
            )
        rows = []
        blank = 0
        for he, ha in zip(e["hadiths"], a["hadiths"]):
            ref = he.get("reference") or {}
            book = int(ref.get("book", 0) or 0)
            text_en = he["text"].strip()
            text_ar = ha["text"].strip()
            # A handful of dataset rows carry no text in either language.
            # They render as blank cards, so they are dropped here.
            if not text_en or not text_ar:
                blank += 1
                continue
            rows.append(
                (
                    cid,
                    book,
                    int(he.get("hadithnumber", 0) or 0),
                    text_en,
                    text_ar,
                    normalize_en(text_en),
                    normalize_ar(text_ar),
                    1 if len(text_en) <= 650 else 0,
                )
            )
        c.executemany(
            "INSERT INTO hadith (collection, book, number_in_book, text_en, text_ar, en_search, ar_search, short) VALUES (?,?,?,?,?,?,?,?)",
            rows,
        )
        c.execute(
            "INSERT INTO hadith_collection VALUES (?,?,?,?,?)",
            (cid, name, ar_full, blurb, len(rows)),
        )
        hadith_total += len(rows)
        if blank:
            print(f"  {cid}: dropped {blank} blank rows")

    # --- Stories ---------------------------------------------------------
    ayah_lookup = {}
    gn = 0
    for a in ar:
        gn += 1
        ayah_lookup[f"{a['chapter']}:{a['verse']}"] = gn

    names = {cid: display for cid, _en, _ar, display, _full, _blurb in collections}

    # Every story reference is resolved against the bundled corpus, so a
    # reference on screen always points at a real row in this database.
    print("-- hadith references for stories --")
    story_total_words = 0
    for s in stories:
        ref = s["ayah"]
        number = ayah_lookup.get(ref) if ref else None
        words = sum(len(p.split()) for p in s["body"])
        story_total_words += words

        hid = href = None
        phrase = s.get("hadith_search")
        if phrase:
            needle = f"%{phrase.lower()}%"
            total = c.execute(
                "SELECT COUNT(*) FROM hadith WHERE en_search LIKE ?",
                (needle,),
            ).fetchone()[0]
            matches = c.execute(
                "SELECT id, collection, number_in_book, substr(text_en, 1, 78) "
                "FROM hadith WHERE en_search LIKE ? ORDER BY id LIMIT 3",
                (needle,),
            ).fetchall()
            if matches:
                first = matches[0]
                hid = first[0]
                href = f"{names.get(first[1], first[1])} no. {first[2]}"
                print(f"  story {s['id']:>2} OK ({total}) {href}: {first[3]}")
                for alt in matches[1:]:
                    print(
                        f"           alt {names.get(alt[1], alt[1])} "
                        f"no. {alt[2]}: {alt[3]}"
                    )
            else:
                print(f"  story {s['id']:>2} MISS  {phrase!r}")
        else:
            print(f"  story {s['id']:>2} none")

        c.execute(
            "INSERT INTO story VALUES (?,?,?,?,?,?,?,?,?,?,?)",
            (
                s["id"],
                s["category"],
                s["title"],
                s["minutes"],
                "\n\n".join(s["body"]),
                s["lesson"],
                ref,
                number,
                words,
                hid,
                href,
            ),
        )

    c.execute("INSERT INTO meta VALUES ('db_version', '2')")
    c.execute("INSERT INTO meta VALUES ('ayatod', '')")
    c.execute("INSERT INTO meta VALUES ('quran_source', 'Uthmani Hafs text, fawazahmed0/quran-api (public domain)')")
    c.execute("INSERT INTO meta VALUES ('quran_translation', 'Abdullah Yusuf Ali (1934, public domain)')")
    c.execute("INSERT INTO meta VALUES ('hadith_source', 'fawazahmed0/hadith-api (Unlicense)')")
    db.commit()

    # --- Stats -----------------------------------------------------------
    size = os.path.getsize(OUT)
    print(f"built {OUT}  {size/1e6:.1f} MB")
    print(f"  surahs: {len(surahs)}  ayat: 6236")
    print(f"  hadith: {hadith_total} across {len(collections)} collections")
    print(f"  stories: {len(stories)}  ({story_total_words} words)")
    db.close()


if __name__ == "__main__":
    main()
