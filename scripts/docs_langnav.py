#!/usr/bin/env python3
"""docs/ 의 지원 · 개인정보 페이지에 언어 전환 링크와 hreflang 을 넣는다 (다시 돌려도 같은 결과).

docs/index.html · privacy.html 은 한국어(기본), docs/<언어>/ 는 그 언어.
en-GB 는 docs/en/ 을 같이 쓴다. 페이지 안의 표시
  <!--HREFLANG--> … <!--/HREFLANG-->  (head)
  <!--LANGNAV--> … <!--/LANGNAV-->    (본문 맨 위)
사이를 매번 새로 채운다.
"""
import pathlib, re

DOCS = pathlib.Path(__file__).resolve().parent.parent / "docs"
BASE = "https://m1zz.github.io/ThinkFlow/"
# 폴더(없으면 루트) · hreflang 들 · 그 언어로 쓴 이름
LANGS = [
    ("", ["ko"], "한국어"), ("en", ["en", "en-GB"], "English"), ("ja", ["ja"], "日本語"),
    ("zh-Hans", ["zh-Hans"], "简体中文"), ("zh-Hant", ["zh-Hant"], "繁體中文"),
    ("es", ["es"], "Español"), ("de", ["de"], "Deutsch"), ("fr", ["fr"], "Français"),
    ("it", ["it"], "Italiano"), ("pt-BR", ["pt-BR"], "Português (Brasil)"), ("ru", ["ru"], "Русский"),
    ("th", ["th"], "ไทย"), ("vi", ["vi"], "Tiếng Việt"), ("cs", ["cs"], "Čeština"),
    ("da", ["da"], "Dansk"), ("el", ["el"], "Ελληνικά"), ("fi", ["fi"], "Suomi"),
    ("id", ["id"], "Bahasa Indonesia"), ("nb", ["nb"], "Norsk bokmål"), ("nl", ["nl"], "Nederlands"),
    ("pl", ["pl"], "Polski"), ("sv", ["sv"], "Svenska"), ("tr", ["tr"], "Türkçe"),
]
NAV_CSS = ('<style>.langnav{display:flex;flex-wrap:wrap;gap:6px 12px;justify-content:center;font-size:13px;'
           'margin:-24px 0 32px;color:var(--secondary)}.langnav a{color:var(--secondary)}'
           '.langnav a[aria-current]{color:var(--accent);font-weight:600}</style>')


def url(folder, page):
    path = (folder + "/" if folder else "") + ("" if page == "index.html" else page)
    return BASE + path


def rel(cur, folder, page):
    up = "../" if cur else ""
    return up + (folder + "/" if folder else "") + page


def fill(text, tag, body):
    pat = re.compile(rf"<!--{tag}-->.*?(<!--/{tag}-->|$)", re.S | re.M)
    block = f"<!--{tag}-->\n{body}\n<!--/{tag}-->"
    if f"<!--/{tag}-->" in text:
        return re.sub(rf"<!--{tag}-->.*?<!--/{tag}-->", lambda _: block, text, flags=re.S)
    if f"<!--{tag}-->" in text:
        return text.replace(f"<!--{tag}-->", block, 1)
    anchor = "</head>" if tag == "HREFLANG" else '<div class="container">'
    i = text.index(anchor)
    if tag == "HREFLANG":
        return text[:i] + block + "\n" + text[i:]
    return text[:i + len(anchor)] + "\n  " + block + text[i + len(anchor):]


for cur, _, _ in LANGS:
    for page in ("index.html", "privacy.html"):
        f = DOCS / cur / page if cur else DOCS / page
        text = f.read_text(encoding="utf-8")
        links = []
        for folder, codes, _ in LANGS:
            for c in codes:
                links.append(f'<link rel="alternate" hreflang="{c}" href="{url(folder, page)}">')
        links.append(f'<link rel="alternate" hreflang="x-default" href="{url("en", page)}">')
        links.append(NAV_CSS)
        nav = []
        for folder, codes, name in LANGS:
            cur_attr = ' aria-current="page"' if folder == cur else ""
            nav.append(f'<a href="{rel(cur, folder, page)}" hreflang="{codes[0]}" lang="{codes[0]}"{cur_attr}>{name}</a>')
        text = fill(text, "HREFLANG", "\n".join(links))
        text = fill(text, "LANGNAV", '<nav class="langnav" aria-label="Language">' + "".join(nav) + "</nav>")
        f.write_text(text, encoding="utf-8")
        print("updated", f.relative_to(DOCS))
