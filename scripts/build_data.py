#!/usr/bin/env python3
"""Build the offline Ohr HaChaim database.

Downloads:
  * Sefaria "Sefaria Vocalized Edition" Hebrew (CC0) for Or HaChaim on
    Genesis, Exodus, Leviticus, Numbers and Deuteronomy.
  * The author's introduction from the Sefaria Hebrew version whose
    versionTitle is exactly "On Your Way" (Public Domain). The duplicate
    version titled "On Your Way " (trailing space, licence unknown) is
    never requested.
  * A Shabbat parasha table from the Hebcal REST API (CC BY 4.0), Israel
    (i=on) and Diaspora (i=off), including combined parshiyot and the
    Simchat Torah reading of Vezot HaBerachah.

No GPL code is used. The script depends only on the Python standard library.

The commentary stored in the database is Hebrew only. English fields are
names of books and parshiyot used by the interface, never a translation.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sqlite3
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from html import unescape
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "OhrHaChaim" / "OhrHaChaim" / "Resources" / "ohr_hachaim.sqlite"
DEFAULT_MANIFEST = ROOT / "data" / "manifest.json"
CACHE_DIR = Path(__file__).resolve().parent / ".cache"

VOCALIZED_VERSION = "Sefaria Vocalized Edition"
VOCALIZED_LICENSE = "CC0"
INTRODUCTION_VERSION = "On Your Way"  # exact; reject "On Your Way "
INTRODUCTION_LICENSE = "Public Domain"

USER_AGENT = "OhrHaChaimDataBuilder/1.0 (offline study app; +https://www.sefaria.org)"

# Jewish chapter/verse boundaries (Koren / Sefaria numbering, not the
# English Bible's shifted verse numbers in a few chapters).
# (book_en, sefaria_shared_title, hebrew_name, english_name,
#  torah_start_chapter, torah_start_verse, torah_end_chapter, torah_end_verse)
PARASHA_DEFS: list[tuple] = [
    ("Genesis", "Bereshit", "בראשית", "Bereshit", 1, 1, 6, 8),
    ("Genesis", "Noach", "נח", "Noach", 6, 9, 11, 32),
    ("Genesis", "Lech Lecha", "לך לך", "Lech Lecha", 12, 1, 17, 27),
    ("Genesis", "Vayera", "וירא", "Vayera", 18, 1, 22, 24),
    ("Genesis", "Chayei Sara", "חיי שרה", "Chayei Sara", 23, 1, 25, 18),
    ("Genesis", "Toldot", "תולדות", "Toldot", 25, 19, 28, 9),
    ("Genesis", "Vayetzei", "ויצא", "Vayetzei", 28, 10, 32, 3),
    ("Genesis", "Vayishlach", "וישלח", "Vayishlach", 32, 4, 36, 43),
    ("Genesis", "Vayeshev", "וישב", "Vayeshev", 37, 1, 40, 23),
    ("Genesis", "Miketz", "מקץ", "Miketz", 41, 1, 44, 17),
    ("Genesis", "Vayigash", "ויגש", "Vayigash", 44, 18, 47, 27),
    ("Genesis", "Vayechi", "ויחי", "Vayechi", 47, 28, 50, 26),
    ("Exodus", "Shemot", "שמות", "Shemot", 1, 1, 6, 1),
    ("Exodus", "Vaera", "וארא", "Vaera", 6, 2, 9, 35),
    ("Exodus", "Bo", "בא", "Bo", 10, 1, 13, 16),
    ("Exodus", "Beshalach", "בשלח", "Beshalach", 13, 17, 17, 16),
    ("Exodus", "Yitro", "יתרו", "Yitro", 18, 1, 20, 23),
    ("Exodus", "Mishpatim", "משפטים", "Mishpatim", 21, 1, 24, 18),
    ("Exodus", "Terumah", "תרומה", "Terumah", 25, 1, 27, 19),
    ("Exodus", "Tetzaveh", "תצוה", "Tetzaveh", 27, 20, 30, 10),
    ("Exodus", "Ki Tisa", "כי תשא", "Ki Tisa", 30, 11, 34, 35),
    ("Exodus", "Vayakhel", "ויקהל", "Vayakhel", 35, 1, 38, 20),
    ("Exodus", "Pekudei", "פקודי", "Pekudei", 38, 21, 40, 38),
    ("Leviticus", "Vayikra", "ויקרא", "Vayikra", 1, 1, 5, 26),
    ("Leviticus", "Tzav", "צו", "Tzav", 6, 1, 8, 36),
    ("Leviticus", "Shmini", "שמיני", "Shmini", 9, 1, 11, 47),
    ("Leviticus", "Tazria", "תזריע", "Tazria", 12, 1, 13, 59),
    ("Leviticus", "Metzora", "מצורע", "Metzora", 14, 1, 15, 33),
    ("Leviticus", "Achrei Mot", "אחרי מות", "Achrei Mot", 16, 1, 18, 30),
    ("Leviticus", "Kedoshim", "קדושים", "Kedoshim", 19, 1, 20, 27),
    ("Leviticus", "Emor", "אמור", "Emor", 21, 1, 24, 23),
    ("Leviticus", "Behar", "בהר", "Behar", 25, 1, 26, 2),
    ("Leviticus", "Bechukotai", "בחוקותי", "Bechukotai", 26, 3, 27, 34),
    ("Numbers", "Bamidbar", "במדבר", "Bamidbar", 1, 1, 4, 20),
    ("Numbers", "Nasso", "נשא", "Nasso", 4, 21, 7, 89),
    ("Numbers", "Beha'alotcha", "בהעלותך", "Beha'alotcha", 8, 1, 12, 16),
    ("Numbers", "Sh'lach", "שלח לך", "Sh'lach", 13, 1, 15, 41),
    ("Numbers", "Korach", "קרח", "Korach", 16, 1, 18, 32),
    ("Numbers", "Chukat", "חקת", "Chukat", 19, 1, 22, 1),
    ("Numbers", "Balak", "בלק", "Balak", 22, 2, 25, 9),
    ("Numbers", "Pinchas", "פינחס", "Pinchas", 25, 10, 30, 1),
    ("Numbers", "Matot", "מטות", "Matot", 30, 2, 32, 42),
    ("Numbers", "Masei", "מסעי", "Masei", 33, 1, 36, 13),
    ("Deuteronomy", "Devarim", "דברים", "Devarim", 1, 1, 3, 22),
    ("Deuteronomy", "Vaetchanan", "ואתחנן", "Vaetchanan", 3, 23, 7, 11),
    ("Deuteronomy", "Eikev", "עקב", "Eikev", 7, 12, 11, 25),
    ("Deuteronomy", "Re'eh", "ראה", "Re'eh", 11, 26, 16, 17),
    ("Deuteronomy", "Shoftim", "שופטים", "Shoftim", 16, 18, 21, 9),
    ("Deuteronomy", "Ki Teitzei", "כי תצא", "Ki Teitzei", 21, 10, 25, 19),
    ("Deuteronomy", "Ki Tavo", "כי תבוא", "Ki Tavo", 26, 1, 29, 8),
    ("Deuteronomy", "Nitzavim", "נצבים", "Nitzavim", 29, 9, 30, 20),
    ("Deuteronomy", "Vayeilech", "וילך", "Vayeilech", 31, 1, 31, 30),
    ("Deuteronomy", "Ha'Azinu", "האזינו", "Ha'Azinu", 32, 1, 32, 52),
    ("Deuteronomy", "V'Zot HaBerachah", "וזאת הברכה", "V'Zot HaBerachah", 33, 1, 34, 12),
]

BOOKS = [
    (1, "Genesis", "בראשית", "Genesis", "Or HaChaim on Genesis"),
    (2, "Exodus", "שמות", "Exodus", "Or HaChaim on Exodus"),
    (3, "Leviticus", "ויקרא", "Leviticus", "Or HaChaim on Leviticus"),
    (4, "Numbers", "במדבר", "Numbers", "Or HaChaim on Numbers"),
    (5, "Deuteronomy", "דברים", "Deuteronomy", "Or HaChaim on Deuteronomy"),
]

# Extra Hebcal spellings that do not letter-match the Sefaria shared title.
EXTRA_ALIASES = {
    "vezothaberakhah": "V'Zot HaBerachah",
    "vezothaberachah": "V'Zot HaBerachah",
    "vzothaberakhah": "V'Zot HaBerachah",
    "vzothaberachah": "V'Zot HaBerachah",
    "vezothabracha": "V'Zot HaBerachah",
    "chayeisarah": "Chayei Sara",
    "metzorah": "Metzora",
    "behaalotecha": "Beha'alotcha",
    "behaaloscha": "Beha'alotcha",
    "shelach": "Sh'lach",
    "shelachlecha": "Sh'lach",
    "shlachlecha": "Sh'lach",
    "kitissa": "Ki Tisa",
    "kiteze": "Ki Teitzei",
    "ekev": "Eikev",
    "reeh": "Re'eh",
    "haazinu": "Ha'Azinu",
    "pekudey": "Pekudei",
    "vayakheil": "Vayakhel",
}

REF_RE = re.compile(
    r"^Or HaChaim on (?P<book>.+?) (?P<start>\d+:\d+:\d+)-(?P<end>\d+(?::\d+){0,2})$"
)
HEBREW_RE = re.compile(r"[\u0590-\u05FF]")
LATIN_RE = re.compile(r"[A-Za-z]")
TAG_RE = re.compile(r"</?([a-zA-Z][a-zA-Z0-9]*)\b[^>]*>")


@dataclass
class ParashaRow:
    id: int
    book_id: int
    shared_title: str
    he_name: str
    en_name: str
    torah_start: tuple[int, int]
    torah_end: tuple[int, int]
    commentary_start: tuple[int, int, int]
    commentary_end: tuple[int, int, int]
    whole_ref: str


def self_test() -> None:
    assert plain_commentary("<b>בְּרֵאשִׁית</b> בָּרָא") == "בראשית ברא"
    assert plain_commentary("אוֹרָה") == "אורה"
    assert parse_range("Or HaChaim on Leviticus 26:3:1-45:2") == ((26, 3, 1), (26, 45, 2))
    assert parse_range("Or HaChaim on Deuteronomy 31:1:1-27:3") == ((31, 1, 1), (31, 27, 3))
    assert parse_range("Or HaChaim on Deuteronomy 32:1:1-52:3") == ((32, 1, 1), (32, 52, 3))
    assert parse_range("Or HaChaim on Genesis 1:1:1-6:7:2") == ((1, 1, 1), (6, 7, 2))
    samples = {
        "Parashat Bereshit": ["Bereshit"],
        "Parashat Lech-Lecha": ["Lech Lecha"],
        "Parashat Beha’alotcha": ["Beha'alotcha"],
        "Parashat Sh’lach": ["Sh'lach"],
        "Parashat Re’eh": ["Re'eh"],
        "Parashat Ha’azinu": ["Ha'Azinu"],
        "Parashat Vayakhel-Pekudei": ["Vayakhel", "Pekudei"],
        "Parashat Achrei Mot-Kedoshim": ["Achrei Mot", "Kedoshim"],
        "Parashat Behar-Bechukotai": ["Behar", "Bechukotai"],
        "Parashat Chukat-Balak": ["Chukat", "Balak"],
        "Parashat Matot-Masei": ["Matot", "Masei"],
        "Parashat Nitzavim-Vayeilech": ["Nitzavim", "Vayeilech"],
        "Parashat Tazria-Metzora": ["Tazria", "Metzora"],
        "Parashat Ki Tisa": ["Ki Tisa"],
        "Parashat Ki Teitzei": ["Ki Teitzei"],
        "Parashat Vezot Haberakhah": ["V'Zot HaBerachah"],
    }
    for title, expected in samples.items():
        got = resolve_hebcal_title(title)
        if got != expected:
            fail(f"title map {title!r} -> {got} expected {expected}")


# Hebrew points and cantillation. Matches HebrewText.stripNikud in the app.
_NIKUD_OR_CANTILLATION = re.compile(r"[\u0591-\u05bd\u05bf\u05c1\u05c2\u05c4\u05c5\u05c7]")
_MARKUP_TAG = re.compile(r"</?b>")


def plain_commentary(markup: str) -> str:
    text = _MARKUP_TAG.sub("", markup)
    text = _NIKUD_OR_CANTILLATION.sub("", text)
    return re.sub(r"\s+", " ", text).strip()


def add_search_index(connection: sqlite3.Connection) -> None:
    """FTS5 over commentary with nikud and cantillation removed, so a plain-letter query matches."""
    connection.execute("DROP TABLE IF EXISTS comments_fts")
    connection.execute(
        """
        CREATE VIRTUAL TABLE comments_fts USING fts5(
            comment_id UNINDEXED,
            plain,
            tokenize = 'unicode61 remove_diacritics 2'
        )
        """
    )
    rows = [
        (comment_id, plain_commentary(f"{dibbur} {body}"))
        for comment_id, dibbur, body in connection.execute("SELECT id, dibbur, body FROM comments")
    ]
    connection.executemany("INSERT INTO comments_fts (comment_id, plain) VALUES (?, ?)", rows)


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def letters_key(title: str) -> str:
    text = title.strip()
    text = re.sub(r"^parashat\s+", "", text, flags=re.IGNORECASE)
    text = re.sub(r"^parshat\s+", "", text, flags=re.IGNORECASE)
    text = (
        text.replace("’", "'")
        .replace("‘", "'")
        .replace("ʼ", "'")
        .replace("`", "'")
    )
    return re.sub(r"[^a-z]", "", text.lower())


def build_alias_map() -> dict[str, str]:
    mapping: dict[str, str] = {}
    for _book, shared, _he, _en, *_rest in PARASHA_DEFS:
        mapping[letters_key(shared)] = shared
    for alias, shared in EXTRA_ALIASES.items():
        mapping[alias] = shared
    return mapping


ALIAS_MAP = build_alias_map()


def resolve_hebcal_title(title: str) -> list[str]:
    """Map a Hebcal English parasha title to one or two Sefaria shared titles."""
    cleaned = re.sub(r"^parashat\s+", "", title.strip(), flags=re.IGNORECASE)
    cleaned = re.sub(r"^parshat\s+", "", cleaned, flags=re.IGNORECASE)
    full = letters_key(cleaned)
    if full in ALIAS_MAP:
        return [ALIAS_MAP[full]]
    parts = re.split(r"\s*[-–—]\s*", cleaned)
    if len(parts) > 1:
        resolved = []
        for part in parts:
            key = letters_key(part)
            if key not in ALIAS_MAP:
                fail(f"unrecognised Hebcal parasha component {part!r} in {title!r}")
            resolved.append(ALIAS_MAP[key])
        return resolved
    fail(f"unrecognised Hebcal parasha title {title!r} (key {full!r})")


def parse_range(whole_ref: str) -> tuple[tuple[int, int, int], tuple[int, int, int]]:
    """Parse a Sefaria alt-struct wholeRef into inclusive comment coordinates.

    A shortened end such as ``26:3:1-45:2`` inherits the missing leading
    sections from the start, which is how Sefaria writes a range that stays
    inside one chapter: 26:3:1 through 26:45:2.
    """
    match = REF_RE.match(whole_ref.strip())
    if not match:
        fail(f"could not parse parasha ref {whole_ref!r}")
    start = tuple(int(part) for part in match.group("start").split(":"))
    end = tuple(int(part) for part in match.group("end").split(":"))
    if len(end) < len(start):
        end = start[: len(start) - len(end)] + end
    if len(start) != 3 or len(end) != 3:
        fail(f"expected chapter:verse:comment in {whole_ref!r}")
    return start, end  # type: ignore[return-value]


def stable_id(book_id: int, chapter: int, verse: int, index: int) -> int:
    if not (0 <= book_id < 10 and 0 <= chapter < 1000 and 0 <= verse < 1000 and 0 <= index < 1000):
        fail(f"coordinate does not fit the stable id: {book_id=} {chapter=} {verse=} {index=}")
    return book_id * 1_000_000_000 + chapter * 1_000_000 + verse * 1_000 + index


def fetch(url: str, retries: int = 4) -> bytes:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    digest = hashlib.sha256(url.encode("utf-8")).hexdigest()[:24]
    cache_path = CACHE_DIR / digest
    meta_path = CACHE_DIR / f"{digest}.url"
    if cache_path.exists() and meta_path.exists() and meta_path.read_text(encoding="utf-8") == url:
        return cache_path.read_bytes()
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
    delay = 1.5
    last_error: Exception | None = None
    for attempt in range(1, retries + 1):
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                body = response.read()
            cache_path.write_bytes(body)
            meta_path.write_text(url, encoding="utf-8")
            time.sleep(0.15)
            return body
        except urllib.error.HTTPError as error:
            last_error = error
            if error.code not in {429, 500, 502, 503, 504} or attempt == retries:
                detail = error.read()[:300]
                fail(f"HTTP {error.code} for {url}: {detail!r}")
        except urllib.error.URLError as error:
            last_error = error
            if attempt == retries:
                fail(f"network error for {url}: {error}")
        time.sleep(delay)
        delay *= 2
    fail(f"failed to fetch {url}: {last_error}")


def fetch_json(url: str) -> dict:
    try:
        data = json.loads(fetch(url).decode("utf-8"))
    except json.JSONDecodeError as error:
        fail(f"invalid JSON from {url}: {error}")
    if not isinstance(data, dict):
        fail(f"expected a JSON object from {url}")
    return data


def version_url(title: str, version_title: str) -> str:
    from urllib.parse import quote

    filename = quote(f"{title} - he - {version_title}.json", safe="")
    return f"https://www.sefaria.org/download/version/{filename}?raw=1"


def index_url(title: str) -> str:
    slug = title.replace(" ", "_")
    return f"https://www.sefaria.org/api/v2/raw/index/{slug}"


def require_hebrew_version(doc: dict, url: str, version_title: str, license_name: str) -> None:
    actual_title = doc.get("versionTitle")
    actual_license = doc.get("license")
    language = doc.get("language")
    if actual_title != version_title:
        fail(
            f"{url} versionTitle is {actual_title!r}, expected exactly {version_title!r}. "
            "Refusing to continue so an unknown-licence duplicate cannot be bundled."
        )
    if actual_license != license_name:
        fail(f"{url} licence is {actual_license!r}, expected {license_name!r}")
    if language != "he":
        fail(f"{url} language is {language!r}, expected Hebrew")
    if version_title != version_title.strip() or version_title.endswith(" "):
        fail("internal error: version title is not an exact trimmed name")


def normalize_markup(raw: str) -> str:
    text = unescape(raw).replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r"<br\s*/?>", "\n", text, flags=re.IGNORECASE)
    tags = {match.group(1).lower() for match in TAG_RE.finditer(text)}
    unexpected = tags - {"b"}
    if unexpected:
        # Keep the words, drop tags we do not render. <b> stays, it marks
        # the dibbur hamatchil and other emphasised phrases in the edition.
        def replace(match: re.Match[str]) -> str:
            return match.group(0) if match.group(1).lower() == "b" else ""

        text = TAG_RE.sub(replace, text)
    text = text.strip()
    return text


def extract_dibbur(markup: str) -> str:
    match = re.match(r"^\s*<b>(.*?)</b>", markup, flags=re.DOTALL)
    if not match:
        return ""
    inner = re.sub(r"<[^>]+>", "", match.group(1))
    return re.sub(r"\s+", " ", inner).strip()


def iter_comments(text_node: object) -> list[tuple[int, int, int, str]]:
    """Return (chapter, verse, comment_index, markup) using 1-based numbers.

    Sefaria's jagged array for this edition is 0-based: index 0 of the
    chapter list is chapter 1, and index 0 of a verse list is comment 1.
    """
    if isinstance(text_node, dict):
        # Schema exports keep the default JaggedArray under the empty key.
        if "" in text_node:
            text_node = text_node[""]
        else:
            fail(f"version text object has no default node: {list(text_node)[:8]}")
    if not isinstance(text_node, list):
        fail(f"version text is {type(text_node).__name__}, expected a chapter list")
    found: list[tuple[int, int, int, str]] = []
    for chapter_index, chapter in enumerate(text_node, start=1):
        if chapter is None:
            continue
        if not isinstance(chapter, list):
            fail(f"chapter {chapter_index} is {type(chapter).__name__}")
        for verse_index, verse in enumerate(chapter, start=1):
            if verse is None or verse == "" or verse == []:
                continue
            if isinstance(verse, str):
                segments = [verse]
            elif isinstance(verse, list):
                segments = verse
            else:
                fail(f"{chapter_index}:{verse_index} is {type(verse).__name__}")
            # Comment numbers follow Sefaria's segment array, including blank
            # slots. A ref such as 40:35:3 is the third slot even when slot 2
            # is an empty string (a common pattern before a parasha colophon).
            for comment_index, segment in enumerate(segments, start=1):
                if segment is None or segment == "":
                    continue
                if not isinstance(segment, str):
                    fail(f"{chapter_index}:{verse_index} segment is {type(segment).__name__}")
                markup = normalize_markup(segment)
                if not markup:
                    continue
                found.append((chapter_index, verse_index, comment_index, markup))
    return found


def introduction_paragraphs(doc: dict) -> list[str]:
    text = doc.get("text")
    if not isinstance(text, dict) or "Introduction" not in text:
        fail('On Your Way export has no "Introduction" node')
    paragraphs = text["Introduction"]
    if not isinstance(paragraphs, list) or not paragraphs:
        fail("On Your Way introduction is empty")
    cleaned: list[str] = []
    for index, paragraph in enumerate(paragraphs, start=1):
        if not isinstance(paragraph, str) or not paragraph.strip():
            fail(f"introduction paragraph {index} is empty or not a string")
        markup = normalize_markup(paragraph)
        # The introduction is stored as Hebrew prose. Drop emphasis tags so a
        # later renderer cannot treat a heading as a commentary dibbur.
        plain = re.sub(r"</?b>", "", markup).strip()
        if LATIN_RE.findall(plain) and len(LATIN_RE.findall(plain)) > len(HEBREW_RE.findall(plain)):
            fail(f"introduction paragraph {index} looks like it is not Hebrew")
        cleaned.append(plain)
    return cleaned


def default_text_node(doc: dict) -> object:
    text = doc.get("text")
    if isinstance(text, dict) and "" in text:
        return text[""]
    return text


def assert_hebrew_corpus(samples: list[str]) -> None:
    hebrew = 0
    latin = 0
    offenders: list[str] = []
    for text in samples:
        plain = re.sub(r"<[^>]+>", "", text)
        h = len(HEBREW_RE.findall(plain))
        lat = len(LATIN_RE.findall(plain))
        hebrew += h
        latin += lat
        if lat > 40 and lat > h:
            offenders.append(plain[:180])
    if offenders:
        fail("refusing Latin-heavy segments (possible translation):\n" + "\n".join(offenders[:5]))
    if hebrew < 1000 or latin * 20 > hebrew:
        fail(f"Hebrew corpus check failed (hebrew letters={hebrew}, latin letters={latin})")


def load_parasha_rows(indexes: dict[str, dict]) -> list[ParashaRow]:
    by_book: dict[str, dict[str, dict]] = {}
    for book_en, _he, _en, title in ((b[1], b[2], b[3], b[4]) for b in BOOKS):
        nodes = indexes[title]["alt_structs"]["Parasha"]["nodes"]
        found: dict[str, dict] = {}
        order: list[str] = []
        for node in nodes:
            shared = node.get("sharedTitle")
            if not shared:
                fail(f"{title} has a parasha node without sharedTitle")
            if shared in found:
                fail(f"duplicate parasha {shared} in {title}")
            found[shared] = node
            order.append(shared)
        expected = [row[1] for row in PARASHA_DEFS if row[0] == book_en]
        if order != expected:
            fail(f"{title} parasha order {order} != expected {expected}")
        by_book[book_en] = found

    book_ids = {book[1]: book[0] for book in BOOKS}
    rows: list[ParashaRow] = []
    for index, (book_en, shared, he_name, en_name, sc, sv, ec, ev) in enumerate(PARASHA_DEFS, start=1):
        node = by_book[book_en][shared]
        start, end = parse_range(node["wholeRef"])
        rows.append(
            ParashaRow(
                id=index,
                book_id=book_ids[book_en],
                shared_title=shared,
                he_name=he_name,
                en_name=en_name,
                torah_start=(sc, sv),
                torah_end=(ec, ev),
                commentary_start=start,
                commentary_end=end,
                whole_ref=node["wholeRef"],
            )
        )
    return rows


def assign_parashot(
    book_id: int, comments: list[tuple[int, int, int, str]], parashot: list[ParashaRow]
) -> tuple[list[int], list[str]]:
    book_parashot = [row for row in parashot if row.book_id == book_id]
    assigned: list[int] = []
    notes: list[str] = []
    for chapter, verse, index, _markup in comments:
        position = (chapter, verse, index)
        matches = [
            row
            for row in book_parashot
            if row.commentary_start <= position <= row.commentary_end
        ]
        if len(matches) > 1:
            names = ", ".join(row.shared_title for row in matches)
            fail(f"comment {book_id} {position} falls in overlapping parashot: {names}")
        if len(matches) == 1:
            assigned.append(matches[0].id)
            continue
        traditional = [
            row
            for row in book_parashot
            if row.torah_start <= (chapter, verse) <= row.torah_end
        ]
        if len(traditional) == 1:
            assigned.append(traditional[0].id)
            notes.append(
                f"book {book_id} {chapter}:{verse}:{index} outside Sefaria commentary "
                f"range, kept in {traditional[0].shared_title} by the Torah boundary"
            )
            continue
        fail(f"comment {book_id} {chapter}:{verse}:{index} is not inside any parasha")
    return assigned, notes


def gap_chapters(row: ParashaRow, chapters_with_any_text: set[int]) -> list[int]:
    """Chapters of this parasha that have no commentary anywhere in the book.

    A chapter split across two parshiyot (for example Exodus 38) is not a gap
    when the other parasha comments on it. Genesis 10 and Leviticus 27 are
    gaps: the vocalized edition has no segments there at all.
    """
    return [
        chapter
        for chapter in range(row.torah_start[0], row.torah_end[0] + 1)
        if chapter not in chapters_with_any_text
    ]


def hebcal_url(year: int, israel: bool) -> str:
    flag = "on" if israel else "off"
    return (
        "https://www.hebcal.com/hebcal?v=1&cfg=json"
        f"&year={year}&month=x&s=on&maj=on&min=off&mod=off&nx=off"
        f"&mf=off&ss=off&c=off&geo=none&M=off&leyning=off&i={flag}"
    )


def is_simchat_torah(item: dict, israel: bool) -> bool:
    title = (item.get("title") or "").strip()
    if title == "Simchat Torah":
        return True
    # In Israel, Shemini Atzeret and Simchat Torah are the same day and Hebcal
    # labels that day "Shmini Atzeret". That is the reading of Vezot HaBerachah.
    if israel and title in {"Shmini Atzeret", "Shemini Atzeret"}:
        return True
    return False


def collect_weekly(years: range, shared_to_id: dict[str, int]) -> list[tuple]:
    rows: list[tuple] = []
    vezot_id = shared_to_id["V'Zot HaBerachah"]
    for year in years:
        for israel in (True, False):
            url = hebcal_url(year, israel)
            print(f"  hebcal {year} {'israel' if israel else 'diaspora'}")
            payload = fetch_json(url)
            items = payload.get("items")
            if not isinstance(items, list):
                fail(f"Hebcal response has no items: {url}")
            by_date: dict[str, dict] = {}
            for item in items:
                if not isinstance(item, dict):
                    continue
                category = item.get("category")
                date = str(item.get("date") or "")[:10]
                if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", date):
                    continue
                slot = by_date.setdefault(date, {"parasha": None, "simchat": False, "hdate": None, "title": None})
                if item.get("hdate"):
                    slot["hdate"] = item.get("hdate")
                if category == "parashat":
                    slot["parasha"] = item.get("title") or ""
                    slot["hdate"] = item.get("hdate") or slot["hdate"]
                elif category == "holiday" and is_simchat_torah(item, israel):
                    slot["simchat"] = True
                    slot["hdate"] = item.get("hdate") or slot["hdate"]
            for date, slot in sorted(by_date.items()):
                if slot["simchat"]:
                    ids = [vezot_id]
                    title = "Simchat Torah"
                    kind = "simchat_torah"
                elif slot["parasha"]:
                    shared = resolve_hebcal_title(slot["parasha"])
                    ids = [shared_to_id[name] for name in shared]
                    title = slot["parasha"]
                    kind = "shabbat"
                else:
                    continue
                rows.append(
                    (
                        date,
                        1 if israel else 0,
                        title,
                        slot["hdate"] or "",
                        ",".join(str(value) for value in ids),
                        kind,
                    )
                )
    return rows


def create_schema(connection: sqlite3.Connection) -> None:
    connection.executescript(
        """
        PRAGMA foreign_keys = ON;

        CREATE TABLE meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );

        CREATE TABLE books (
            id INTEGER PRIMARY KEY,
            en_key TEXT NOT NULL,
            he_name TEXT NOT NULL,
            en_name TEXT NOT NULL,
            sefaria_title TEXT NOT NULL,
            sort_order INTEGER NOT NULL
        );

        CREATE TABLE parashot (
            id INTEGER PRIMARY KEY,
            book_id INTEGER NOT NULL REFERENCES books(id),
            shared_title TEXT NOT NULL,
            he_name TEXT NOT NULL,
            en_name TEXT NOT NULL,
            sort_order INTEGER NOT NULL,
            start_chapter INTEGER NOT NULL,
            start_verse INTEGER NOT NULL,
            start_comment INTEGER NOT NULL,
            end_chapter INTEGER NOT NULL,
            end_verse INTEGER NOT NULL,
            end_comment INTEGER NOT NULL,
            torah_start_chapter INTEGER NOT NULL,
            torah_start_verse INTEGER NOT NULL,
            torah_end_chapter INTEGER NOT NULL,
            torah_end_verse INTEGER NOT NULL,
            whole_ref TEXT NOT NULL
        );

        CREATE TABLE comments (
            id INTEGER PRIMARY KEY,
            book_id INTEGER NOT NULL REFERENCES books(id),
            parasha_id INTEGER REFERENCES parashot(id),
            chapter INTEGER NOT NULL,
            verse INTEGER NOT NULL,
            comment_index INTEGER NOT NULL,
            dibbur TEXT NOT NULL,
            body TEXT NOT NULL,
            source TEXT NOT NULL
        );

        CREATE TABLE gaps (
            parasha_id INTEGER NOT NULL REFERENCES parashot(id),
            chapter INTEGER NOT NULL,
            PRIMARY KEY (parasha_id, chapter)
        );

        CREATE TABLE weekly (
            gregorian_date TEXT NOT NULL,
            israel INTEGER NOT NULL,
            hebcal_title TEXT NOT NULL,
            hdate TEXT NOT NULL,
            parasha_ids TEXT NOT NULL,
            kind TEXT NOT NULL,
            PRIMARY KEY (gregorian_date, israel)
        );

        CREATE INDEX idx_comments_parasha
            ON comments(parasha_id, chapter, verse, comment_index);
        CREATE INDEX idx_comments_book
            ON comments(book_id, chapter, verse, comment_index);
        CREATE INDEX idx_weekly_lookup
            ON weekly(israel, gregorian_date);
        """
    )


def write_database(
    output: Path,
    parashot: list[ParashaRow],
    intro: list[str],
    book_comments: dict[int, list[tuple[int, int, int, str, int]]],
    gaps: list[tuple[int, int]],
    weekly_rows: list[tuple],
    meta: dict[str, str],
) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        output.unlink()
    connection = sqlite3.connect(output)
    try:
        create_schema(connection)
        connection.executemany(
            "INSERT INTO books (id, en_key, he_name, en_name, sefaria_title, sort_order) VALUES (?, ?, ?, ?, ?, ?)",
            [(book_id, en_key, he_name, en_name, title, book_id) for book_id, en_key, he_name, en_name, title in BOOKS],
        )
        connection.executemany(
            """
            INSERT INTO parashot (
                id, book_id, shared_title, he_name, en_name, sort_order,
                start_chapter, start_verse, start_comment,
                end_chapter, end_verse, end_comment,
                torah_start_chapter, torah_start_verse, torah_end_chapter, torah_end_verse,
                whole_ref
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    row.id,
                    row.book_id,
                    row.shared_title,
                    row.he_name,
                    row.en_name,
                    row.id,
                    row.commentary_start[0],
                    row.commentary_start[1],
                    row.commentary_start[2],
                    row.commentary_end[0],
                    row.commentary_end[1],
                    row.commentary_end[2],
                    row.torah_start[0],
                    row.torah_start[1],
                    row.torah_end[0],
                    row.torah_end[1],
                    row.whole_ref,
                )
                for row in parashot
            ],
        )
        comment_rows = []
        for book_id, comments in book_comments.items():
            for chapter, verse, index, markup, parasha_id in comments:
                comment_rows.append(
                    (
                        stable_id(book_id, chapter, verse, index),
                        book_id,
                        parasha_id,
                        chapter,
                        verse,
                        index,
                        extract_dibbur(markup),
                        markup,
                        "sefaria-vocalized",
                    )
                )
        for paragraph_index, paragraph in enumerate(intro, start=1):
            comment_rows.append(
                (
                    stable_id(1, 0, paragraph_index, 1),
                    1,
                    None,
                    0,
                    paragraph_index,
                    1,
                    "",
                    paragraph,
                    "on-your-way-introduction",
                )
            )
        connection.executemany(
            """
            INSERT INTO comments (
                id, book_id, parasha_id, chapter, verse, comment_index, dibbur, body, source
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            comment_rows,
        )
        connection.executemany("INSERT INTO gaps (parasha_id, chapter) VALUES (?, ?)", gaps)
        connection.executemany(
            """
            INSERT INTO weekly (gregorian_date, israel, hebcal_title, hdate, parasha_ids, kind)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            weekly_rows,
        )
        connection.executemany("INSERT INTO meta (key, value) VALUES (?, ?)", list(meta.items()))
        add_search_index(connection)
        connection.commit()
        connection.execute("VACUUM")
    finally:
        connection.close()


def validate_database(path: Path, year_start: int, year_end: int) -> dict:
    if not path.exists():
        fail(f"database not found: {path}")
    connection = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    connection.row_factory = sqlite3.Row
    try:
        meta = {row["key"]: row["value"] for row in connection.execute("SELECT key, value FROM meta")}
        if meta.get("vocalized_license") != VOCALIZED_LICENSE:
            fail("bundled vocalized licence is not CC0")
        if meta.get("vocalized_version") != VOCALIZED_VERSION:
            fail("bundled vocalized version title changed")
        if meta.get("introduction_license") != INTRODUCTION_LICENSE:
            fail("bundled introduction licence is not Public Domain")
        if meta.get("introduction_version") != INTRODUCTION_VERSION:
            fail("introduction version is not exactly 'On Your Way'")
        if meta.get("introduction_version") != meta.get("introduction_version", "").strip():
            fail("introduction version title has leading or trailing whitespace")
        books = connection.execute("SELECT COUNT(*) AS n FROM books").fetchone()["n"]
        parashot = connection.execute("SELECT COUNT(*) AS n FROM parashot").fetchone()["n"]
        if books != 5 or parashot != 54:
            fail(f"expected 5 books and 54 parashot, found {books} and {parashot}")
        intro = connection.execute(
            "SELECT COUNT(*) AS n FROM comments WHERE source = 'on-your-way-introduction'"
        ).fetchone()["n"]
        if intro < 1:
            fail("author introduction is missing")
        vocal = connection.execute(
            "SELECT COUNT(*) AS n FROM comments WHERE source = 'sefaria-vocalized'"
        ).fetchone()["n"]
        if vocal < 1000:
            fail(f"too few commentary segments: {vocal}")
        orphan = connection.execute(
            "SELECT COUNT(*) AS n FROM comments WHERE source = 'sefaria-vocalized' AND parasha_id IS NULL"
        ).fetchone()["n"]
        if orphan:
            fail(f"{orphan} commentary segments are not attached to a parasha")
        gen10 = connection.execute(
            """
            SELECT COUNT(*) AS n FROM comments
            WHERE book_id = 1 AND chapter = 10 AND source = 'sefaria-vocalized'
            """
        ).fetchone()["n"]
        lev27 = connection.execute(
            """
            SELECT COUNT(*) AS n FROM comments
            WHERE book_id = 3 AND chapter = 27 AND source = 'sefaria-vocalized'
            """
        ).fetchone()["n"]
        if gen10 or lev27:
            fail(f"expected no commentary on Genesis 10 ({gen10}) or Leviticus 27 ({lev27})")
        gaps = {
            (row["he_name"], row["chapter"])
            for row in connection.execute(
                """
                SELECT p.he_name AS he_name, g.chapter AS chapter
                FROM gaps g JOIN parashot p ON p.id = g.parasha_id
                """
            )
        }
        if ("נח", 10) not in gaps:
            fail("Genesis 10 is not recorded as a gap inside נח")
        if ("בחוקותי", 27) not in gaps:
            fail("Leviticus 27 is not recorded as a gap inside בחוקותי")
        bodies = [row["body"] for row in connection.execute("SELECT body FROM comments")]
        assert_hebrew_corpus(bodies)
        # No English commentary: the English UI names live in other tables.
        english_body = connection.execute(
            """
            SELECT COUNT(*) AS n FROM comments
            WHERE body LIKE '%Sefaria Community Translation%'
               OR body LIKE '%This verse%'
               OR body LIKE '%translation%'
            """
        ).fetchone()["n"]
        if english_body:
            fail("commentary table contains English translation markers")
        weekly = connection.execute("SELECT COUNT(*) AS n FROM weekly").fetchone()["n"]
        if weekly < 500:
            fail(f"weekly table is too small: {weekly}")
        for israel in (0, 1):
            span = connection.execute(
                "SELECT MIN(gregorian_date) AS a, MAX(gregorian_date) AS b, COUNT(*) AS n FROM weekly WHERE israel = ?",
                (israel,),
            ).fetchone()
            if span["a"][:4] > str(year_start) or span["b"][:4] < str(year_end):
                fail(f"weekly calendar israel={israel} does not cover {year_start}-{year_end}: {span['a']}..{span['b']}")
        combined = connection.execute(
            "SELECT COUNT(*) AS n FROM weekly WHERE parasha_ids LIKE '%,%'"
        ).fetchone()["n"]
        if combined < 10:
            fail("combined parshiyot are missing from the weekly table")
        vezot = connection.execute(
            """
            SELECT COUNT(*) AS n FROM weekly w
            JOIN parashot p ON p.shared_title = 'V''Zot HaBerachah'
            WHERE ',' || w.parasha_ids || ',' LIKE '%,' || p.id || ',%'
            """
        ).fetchone()["n"]
        if vezot < (year_end - year_start):
            fail(f"Vezot HaBerachah is missing from too many years ({vezot})")
        differ = connection.execute(
            """
            SELECT COUNT(*) AS n FROM weekly a
            JOIN weekly b ON a.gregorian_date = b.gregorian_date AND a.israel = 1 AND b.israel = 0
            WHERE a.parasha_ids != b.parasha_ids
            """
        ).fetchone()["n"]
        if differ < 1:
            fail("Israel and Diaspora schedules are identical; the setting would do nothing")
        known_ids = {row["id"] for row in connection.execute("SELECT id FROM parashot")}
        for row in connection.execute("SELECT parasha_ids FROM weekly"):
            for part in row["parasha_ids"].split(","):
                if int(part) not in known_ids:
                    fail(f"weekly table references unknown parasha id {part}")
        opening = connection.execute(
            """
            SELECT body FROM comments
            WHERE book_id = 1 AND chapter = 1 AND verse = 1 AND comment_index = 1
            """
        ).fetchone()
        if opening is None or "אוֹרָה" not in opening["body"]:
            fail("Genesis 1:1 does not start with the expected vocalized opening")
        fts = connection.execute(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'comments_fts'"
        ).fetchone()
        if fts is None:
            fail("comments_fts is missing")
        plain = connection.execute(
            """
            SELECT comment_id, plain FROM comments_fts
            WHERE comments_fts MATCH '"אורה"*'
            LIMIT 5
            """
        ).fetchall()
        if not plain:
            fail("plain-letter search for אורה found nothing")
        if not any("אורה" in row["plain"] and "אוֹרָה" not in row["plain"] for row in plain):
            fail("search index still contains nikud")
        max_index = connection.execute("SELECT MAX(comment_index) AS n FROM comments").fetchone()["n"]
        if max_index >= 1000:
            fail("comment index overflowed the stable id width")
        stats = {
            "books": books,
            "parashot": parashot,
            "vocalized_comments": vocal,
            "introduction_paragraphs": intro,
            "gaps": sorted(f"{name} {chapter}" for name, chapter in gaps),
            "weekly_rows": weekly,
            "combined_weeks": combined,
            "israel_diaspora_differences": differ,
            "max_comment_index": max_index,
            "bytes": path.stat().st_size,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        }
        return stats
    finally:
        connection.close()


def build(output: Path, manifest_path: Path, year_start: int, year_end: int) -> None:
    if year_end < year_start:
        fail("year range is empty")
    print("downloading Sefaria indexes")
    indexes = {}
    for _book_id, _en_key, _he, _en, title in BOOKS:
        indexes[title] = fetch_json(index_url(title))
        if "Parasha" not in indexes[title].get("alt_structs", {}):
            fail(f"{title} index has no alt_structs.Parasha")
    parashot = load_parasha_rows(indexes)
    shared_to_id = {row.shared_title: row.id for row in parashot}

    print("downloading vocalized text (CC0)")
    book_comments: dict[int, list[tuple[int, int, int, str, int]]] = {}
    assignment_notes: list[str] = []
    all_markup: list[str] = []
    for book_id, _en_key, _he, _en, title in BOOKS:
        url = version_url(title, VOCALIZED_VERSION)
        print(f"  {title}")
        doc = fetch_json(url)
        require_hebrew_version(doc, url, VOCALIZED_VERSION, VOCALIZED_LICENSE)
        if title == "Or HaChaim on Genesis":
            intro_node = doc.get("text", {}).get("Introduction") if isinstance(doc.get("text"), dict) else None
            if isinstance(intro_node, list) and any(isinstance(item, str) and item.strip() for item in intro_node):
                fail("vocalized Genesis unexpectedly contains an introduction; review sources before bundling")
        comments = iter_comments(default_text_node(doc))
        if not comments:
            fail(f"no comments parsed from {title}")
        parasha_ids, notes = assign_parashot(book_id, comments, parashot)
        assignment_notes.extend(notes)
        book_comments[book_id] = [
            (chapter, verse, index, markup, parasha_id)
            for (chapter, verse, index, markup), parasha_id in zip(comments, parasha_ids)
        ]
        all_markup.extend(markup for *_rest, markup, _pid in book_comments[book_id])
        positions = {(chapter, verse, index) for chapter, verse, index, _markup in comments}
        for row in parashot:
            if row.book_id != book_id:
                continue
            if row.commentary_start not in positions:
                fail(f"{row.whole_ref} start {row.commentary_start} is not a real comment")
            if row.commentary_end not in positions:
                fail(f"{row.whole_ref} end {row.commentary_end} is not a real comment")

    assert_hebrew_corpus(all_markup)

    print("downloading author's introduction (On Your Way, Public Domain)")
    intro_url = version_url("Or HaChaim on Genesis", INTRODUCTION_VERSION)
    intro_doc = fetch_json(intro_url)
    require_hebrew_version(intro_doc, intro_url, INTRODUCTION_VERSION, INTRODUCTION_LICENSE)
    intro = introduction_paragraphs(intro_doc)

    gaps: list[tuple[int, int]] = []
    for row in parashot:
        chapters_in_book = {
            chapter
            for chapter, _verse, _index, _markup, _parasha_id in book_comments[row.book_id]
        }
        for chapter in gap_chapters(row, chapters_in_book):
            gaps.append((row.id, chapter))

    print(f"downloading Hebcal {year_start}-{year_end}")
    weekly_rows = collect_weekly(range(year_start, year_end + 1), shared_to_id)
    # A Gregorian year query overlaps the next January. Collapse duplicates.
    deduped: dict[tuple[str, int], tuple] = {}
    for row in weekly_rows:
        deduped[(row[0], row[1])] = row
    weekly_rows = [deduped[key] for key in sorted(deduped)]

    generated = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    meta = {
        "vocalized_version": VOCALIZED_VERSION,
        "vocalized_license": VOCALIZED_LICENSE,
        "vocalized_source": "https://www.sefaria.org/",
        "introduction_version": INTRODUCTION_VERSION,
        "introduction_license": INTRODUCTION_LICENSE,
        "introduction_source": "https://www.sefaria.org/",
        "introduction_version_source": str(intro_doc.get("versionSource") or ""),
        "hebcal_license": "CC BY 4.0",
        "hebcal_attribution": "Torah reading schedule from Hebcal.com, CC BY 4.0",
        "hebcal_url": "https://www.hebcal.com/home/195/jewish-calendar-rest-api",
        "year_start": str(year_start),
        "year_end": str(year_end),
        "generated_utc": generated,
        "language": "he",
        "translation_included": "no",
    }
    write_database(output, parashot, intro, book_comments, gaps, weekly_rows, meta)
    stats = validate_database(output, year_start, year_end)
    manifest = {
        "generated_utc": generated,
        "database": str(output.relative_to(ROOT)),
        "sha256": stats["sha256"],
        "bytes": stats["bytes"],
        "licenses": {
            "commentary": {
                "work": "Or HaChaim on Genesis, Exodus, Leviticus, Numbers, Deuteronomy",
                "version": VOCALIZED_VERSION,
                "language": "he",
                "license": VOCALIZED_LICENSE,
                "publisher": "Sefaria",
            },
            "introduction": {
                "work": "Or HaChaim on Genesis, Introduction",
                "version": INTRODUCTION_VERSION,
                "language": "he",
                "license": INTRODUCTION_LICENSE,
                "note": "The version titled 'On Your Way ' with a trailing space was not used; its licence is unknown.",
            },
            "calendar": {
                "provider": "Hebcal.com",
                "license": "CC BY 4.0",
                "url": "https://www.hebcal.com",
                "years": [year_start, year_end],
            },
        },
        "stats": stats,
        "assignment_notes": assignment_notes[:50],
        "assignment_note_count": len(assignment_notes),
    }
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(stats, ensure_ascii=False, indent=2))
    if assignment_notes:
        print(f"{len(assignment_notes)} comments were outside the Sefaria parasha ref and kept via the Torah boundary")
    print(f"wrote {output}")
    print(f"wrote {manifest_path}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Build the offline Ohr HaChaim SQLite database")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--year-start", type=int, default=2024)
    parser.add_argument("--year-end", type=int, default=2038)
    parser.add_argument(
        "--validate-only",
        action="store_true",
        help="Check an existing database without downloading",
    )
    parser.add_argument(
        "--index-only",
        action="store_true",
        help="Rebuild the FTS5 search index on an existing database without downloading",
    )
    args = parser.parse_args()
    self_test()
    if args.index_only:
        connection = sqlite3.connect(args.output)
        try:
            add_search_index(connection)
            connection.commit()
            connection.execute("VACUUM")
        finally:
            connection.close()
        print(f"rebuilt search index in {args.output}")
    if args.validate_only or args.index_only:
        stats = validate_database(args.output, args.year_start, args.year_end)
        print(json.dumps(stats, ensure_ascii=False, indent=2))
        return
    build(args.output, args.manifest, args.year_start, args.year_end)


if __name__ == "__main__":
    main()
