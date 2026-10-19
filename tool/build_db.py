#!/usr/bin/env python3
"""Builds assets/db/alim.db from the fetched source data.

Sources (all public domain / open licence):
  * Quran Arabic  — fawazahmed0/quran-api, edition ara-quranuthmanihaf
  * Quran English — Tanzil.net translations (en.sahih, en.pickthall,
                    en.yusufali, en.hilali), verbatim and attributed
  * Surah metadata — fawazahmed0/quran-api info.json
  * Hadith        — fawazahmed0/hadith-api, Sahih al-Bukhari, Sahih Muslim,
                    Forty Hadith of an-Nawawi, Forty Hadith Qudsi (eng + ara)
  * Stories       — authored for Alim (tool/stories_a.json ... stories_d.json)

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


_LONG_DASH = re.compile(r"\s*[\u2014\u2013]\s*")


def tidy_dashes(text: str, comma: str = ", ") -> str:
    """The source translations mark asides with long dashes. The app reads
    better without them, so a comma takes their place."""
    return _LONG_DASH.sub(comma, text).strip()


def load(name: str):
    with open(os.path.join(SRC, name), encoding="utf-8") as fh:
        return json.load(fh)


TRANSLATIONS = [
    ("sahih", "Saheeh International", "Saheeh International", "2011"),
    ("pickthall", "The Meaning of the Glorious Koran", "Marmaduke Pickthall", "1930"),
    ("yusufali", "The Holy Qur'an", "Abdullah Yusuf Ali", "1934"),
    (
        "hilali",
        "Interpretation of the Meanings of the Noble Qur'an",
        "Muhammad Muhsin Khan and Muhammad Taqi-ud-Din al-Hilali",
        "1997",
    ),
]

_TANZIL_LINE = re.compile(r"^(\d+)\|(\d+)\|(.*)$")


def load_tanzil(slug: str):
    """Reads a Tanzil translation file: `surah|ayah|text` per line."""
    out = {}
    with open(
        os.path.join(SRC, f"tanzil_en_{slug}.txt"), encoding="utf-8"
    ) as fh:
        for line in fh:
            m = _TANZIL_LINE.match(line.rstrip("\n"))
            if not m:
                continue
            out[(int(m.group(1)), int(m.group(2)))] = m.group(3)
    assert len(out) == 6236, (slug, len(out))
    return out


def main() -> None:
    info = load("quran_info.json")
    ar = load("quran_ar.min.json")["quran"]
    translations = {slug: load_tanzil(slug) for slug, *_ in TRANSLATIONS}
    ar_keys = {(a["chapter"], a["verse"]) for a in ar}
    for slug, text in translations.items():
        assert set(text.keys()) == ar_keys, slug
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

        CREATE TABLE translation (
            id INTEGER PRIMARY KEY,
            slug TEXT NOT NULL UNIQUE,
            title TEXT NOT NULL,
            translator TEXT NOT NULL,
            year TEXT NOT NULL,
            source TEXT NOT NULL
        );

        CREATE TABLE ayah_translation (
            ayah INTEGER NOT NULL REFERENCES ayah(number),
            translation INTEGER NOT NULL REFERENCES translation(id),
            text TEXT NOT NULL,
            search TEXT NOT NULL
        );
        CREATE UNIQUE INDEX idx_ayah_translation
            ON ayah_translation(ayah, translation);
        CREATE INDEX idx_ayah_translation_text
            ON ayah_translation(translation, ayah);

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
    assert n == 6236 and len(ar) == 6236

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

    for idx, (slug, title, translator, year) in enumerate(TRANSLATIONS, start=1):
        c.execute(
            "INSERT INTO translation VALUES (?,?,?,?,?,?)",
            (idx, slug, title, translator, year, "Tanzil.net"),
        )

    global_n = 0
    rows = []
    trows = []
    for a in ar:
        global_n += 1
        key = (a["chapter"], a["verse"])
        m = meta_by_ayah[key]
        text_en = translations["sahih"][key]
        rows.append(
            (
                global_n,
                a["chapter"],
                a["verse"],
                m["juz"],
                m["page"],
                1 if m.get("sajda") else 0,
                a["text"],
                text_en,
                normalize_ar(a["text"]),
                normalize_en(text_en),
            )
        )
        for idx, (slug, *_rest) in enumerate(TRANSLATIONS, start=1):
            text = translations[slug][key]
            trows.append((global_n, idx, text, normalize_en(text)))
    c.executemany("INSERT INTO ayah VALUES (?,?,?,?,?,?,?,?,?,?)", rows)
    c.executemany(
        "INSERT INTO ayah_translation VALUES (?,?,?,?)", trows
    )

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
            text_en = tidy_dashes(he["text"].strip())
            text_ar = tidy_dashes(ha["text"].strip(), "، ")
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
        # The collections repeat hadiths for chains and cross-references. A
        # reading list should not show the same passage twice: drop chain-only
        # pointer rows, then keep the first row of any repeated translation.
        pointer_prefixes = (
            "this hadith has been narrated",
            "this hadith has been transmitted",
            "a hadith like this",
            "see translation for hadith",
        )
        seen = set()
        kept = []
        chain_only = repeated = 0
        for row in rows:
            low = row[3].lower()
            if low.startswith(pointer_prefixes) and ":" not in row[3]:
                chain_only += 1
                continue
            key = re.sub(r"[^a-z0-9]+", " ", low).strip()
            if key in seen:
                repeated += 1
                continue
            seen.add(key)
            kept.append(row)
        rows = kept
        c.executemany(
            "INSERT INTO hadith (collection, book, number_in_book, text_en, text_ar, en_search, ar_search, short) VALUES (?,?,?,?,?,?,?,?)",
            rows,
        )
        c.execute(
            "INSERT INTO hadith_collection VALUES (?,?,?,?,?)",
            (cid, name, ar_full, blurb, len(rows)),
        )
        hadith_total += len(rows)
        if blank or chain_only or repeated:
            print(
                f"  {cid}: dropped {blank} blank, {chain_only} chain-only, "
                f"{repeated} repeated rows"
            )

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
        title = tidy_dashes(s["title"])
        lesson = tidy_dashes(s["lesson"])
        body = [tidy_dashes(p) for p in s["body"]]
        words = sum(len(p.split()) for p in body)
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
                title,
                s["minutes"],
                "\n\n".join(body),
                lesson,
                ref,
                number,
                words,
                hid,
                href,
            ),
        )

    c.execute("INSERT INTO meta VALUES ('db_version', '4')")
    c.execute("INSERT INTO meta VALUES ('ayatod', '')")
    c.execute("INSERT INTO meta VALUES ('quran_source', 'Uthmani Hafs text, fawazahmed0/quran-api (public domain)')")
    c.execute("INSERT INTO meta VALUES ('quran_translation', 'Saheeh International (default), Pickthall, Yusuf Ali, Hilali and Khan, all via Tanzil.net')")
    c.execute("INSERT INTO meta VALUES ('hadith_source', 'fawazahmed0/hadith-api (Unlicense)')")
    db.commit()

    # --- Stats -----------------------------------------------------------
    size = os.path.getsize(OUT)
    print(f"built {OUT}  {size/1e6:.1f} MB")
    print(f"  surahs: {len(surahs)}  ayat: 6236")
    print(f"  translations: {len(TRANSLATIONS)} x 6236 rows")
    print(f"  hadith: {hadith_total} across {len(collections)} collections")
    print(f"  stories: {len(stories)}  ({story_total_words} words)")
    db.close()


if __name__ == "__main__":
    main()
