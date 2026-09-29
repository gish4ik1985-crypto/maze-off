#!/usr/bin/env python3
"""Генератор .html-близнецов из .md (план: аудит v5.5, пункт 4).

Раньше GAMEDESIGN/ARCHITECTURE/CLAUDE/README.html правились руками и
расходились с .md. Теперь .html — производная: правишь только .md и
запускаешь `python tools/md2html.py`.
Без зависимостей: свой небольшой конвертер под тот Markdown, что реально
используется в проекте (заголовки, абзацы, списки с вложенностью и
продолжениями, таблицы, ``` -блоки, цитаты, ---, `code`, **b**, *i*, ссылки).

  python tools/md2html.py           # записать все .html
  python tools/md2html.py --check   # только проверить: html свежий? (код 1 если нет)
"""
import html
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FILES = ["CLAUDE", "ARCHITECTURE", "GAMEDESIGN", "README"]

CSS = """:root { color-scheme: dark; }
body {
  background: #0b0d14;
  color: #d7e0f0;
  font-family: -apple-system, Segoe UI, Roboto, sans-serif;
  line-height: 1.55;
  max-width: 900px;
  margin: 0 auto;
  padding: 32px 24px 80px;
}
h1 { color: #7ef9e8; border-bottom: 2px solid #1c2740; padding-bottom: 10px; }
h2 { color: #7ef9e8; margin-top: 2.2em; border-bottom: 1px solid #1c2740; padding-bottom: 6px; }
h3 { color: #ffd76a; margin-top: 1.6em; }
h4 { color: #b6a6ff; }
a { color: #6fc3ff; }
code { background: #131a2a; padding: 2px 5px; border-radius: 4px; color: #ffd76a; font-size: 0.9em; }
pre { background: #10141f; border: 1px solid #1c2740; border-radius: 8px; padding: 14px; overflow-x: auto; }
pre code { background: none; padding: 0; color: #d7e0f0; }
table { border-collapse: collapse; width: 100%; margin: 1em 0; }
th, td { border: 1px solid #1c2740; padding: 8px 10px; text-align: left; }
th { background: #131a2a; color: #7ef9e8; }
hr { border: none; border-top: 1px solid #1c2740; margin: 2.2em 0; }
blockquote { border-left: 3px solid #1c2740; margin: 1em 0; padding: 0 1em; color: #a9b6cf; }
ul, ol { padding-left: 1.4em; }
li { margin: 0.3em 0; }
strong { color: #ffd76a; }
p { margin: 0.8em 0; }"""

LIST_RE = re.compile(r"^(\s*)([-*]|\d+\.)\s+(.*)$")
TABLE_SEP = re.compile(r"^\s*\|[\s:|-]+\|\s*$")


def inline(text):
    codes = []

    def stash(m):
        codes.append("<code>%s</code>" % html.escape(m.group(1), quote=False))
        return "\x00%d\x00" % (len(codes) - 1)

    text = re.sub(r"`([^`]+)`", stash, text)
    text = html.escape(text, quote=False)
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"(?<![*\w])\*([^*\s][^*]*?)\*(?![*\w])", r"<em>\1</em>", text)
    text = re.sub(
        r"\[([^\]]+)\]\(([^)\s]+)\)",
        lambda m: '<a href="%s">%s</a>' % (re.sub(r"\.md(#|$)", r".html\1", m.group(2)), m.group(1)),
        text)
    return re.sub(r"\x00(\d+)\x00", lambda m: codes[int(m.group(1))], text)


def indent_of(s):
    return len(s) - len(s.lstrip(" "))


def render_list(lines):
    base = indent_of(lines[0])
    ordered = lines[0].lstrip()[0].isdigit()
    items, cur = [], None
    for ln in lines:
        if not ln.strip():
            continue
        m = LIST_RE.match(ln)
        if m and indent_of(ln) == base:
            cur = {"text": [m.group(3)], "sub": []}
            items.append(cur)
        elif cur is not None:
            if LIST_RE.match(ln) or cur["sub"]:
                cur["sub"].append(ln)
            else:
                cur["text"].append(ln.strip())
    out = []
    for it in items:
        body = inline(" ".join(it["text"]))
        if it["sub"]:
            body += render_list(it["sub"])
        out.append("<li>%s</li>" % body)
    tag = "ol" if ordered else "ul"
    return "<%s>%s</%s>" % (tag, "".join(out), tag)


def is_block_start(ln, nxt):
    s = ln.strip()
    return (s.startswith("```") or s.startswith("#") or s == "---" or s.startswith(">")
            or (s.startswith("|") and nxt is not None and TABLE_SEP.match(nxt) is not None)
            or (LIST_RE.match(ln) is not None and indent_of(ln) == 0))


def split_row(ln):
    ln = ln.strip()
    if ln.startswith("|"):
        ln = ln[1:]
    if ln.endswith("|"):
        ln = ln[:-1]
    return [c.strip().replace("\\|", "|") for c in re.split(r"(?<!\\)\|", ln)]


def convert(md):
    lines = md.replace("\r\n", "\n").split("\n")
    out, i, n = [], 0, len(lines)
    while i < n:
        ln = lines[i]
        s = ln.strip()
        nxt = lines[i + 1] if i + 1 < n else None
        if not s:
            i += 1
        elif s.startswith("```"):
            i += 1
            buf = []
            while i < n and not lines[i].strip().startswith("```"):
                buf.append(lines[i])
                i += 1
            i += 1
            out.append("<pre><code>%s</code></pre>" % html.escape("\n".join(buf), quote=False))
        elif re.match(r"^#{1,6}\s", s):
            lvl = len(s) - len(s.lstrip("#"))
            out.append("<h%d>%s</h%d>" % (lvl, inline(s[lvl:].strip()), lvl))
            i += 1
        elif s == "---":
            out.append("<hr>")
            i += 1
        elif s.startswith("|") and nxt is not None and TABLE_SEP.match(nxt):
            head = split_row(ln)
            i += 2
            rows = []
            while i < n and lines[i].strip().startswith("|"):
                rows.append(split_row(lines[i]))
                i += 1
            t = "<table><thead><tr>%s</tr></thead><tbody>" % "".join("<th>%s</th>" % inline(c) for c in head)
            for r in rows:
                t += "<tr>%s</tr>" % "".join("<td>%s</td>" % inline(c) for c in r)
            out.append(t + "</tbody></table>")
        elif s.startswith(">"):
            buf = []
            while i < n and lines[i].strip().startswith(">"):
                buf.append(lines[i].strip()[1:].strip())
                i += 1
            out.append("<blockquote>%s</blockquote>" % convert("\n".join(buf)))
        elif LIST_RE.match(ln):
            buf = [ln]
            i += 1
            while i < n:
                l2 = lines[i]
                if not l2.strip():
                    j = i
                    while j < n and not lines[j].strip():
                        j += 1
                    if j < n and (indent_of(lines[j]) >= 2
                                  or (LIST_RE.match(lines[j]) and indent_of(lines[j]) == indent_of(ln))):
                        i = j
                        continue
                    break
                if indent_of(l2) == 0 and not LIST_RE.match(l2):
                    break
                buf.append(l2)
                i += 1
            out.append(render_list(buf))
        else:
            buf = [s]
            i += 1
            while i < n and lines[i].strip() and not is_block_start(lines[i], lines[i + 1] if i + 1 < n else None):
                buf.append(lines[i].strip())
                i += 1
            out.append("<p>%s</p>" % inline(" ".join(buf)))
    return "\n".join(out)


def page(name, md):
    m = re.search(r"^#\s+(.+)$", md, re.M)
    title = re.sub(r"[`*]", "", m.group(1)) if m else name
    lang = "ru"
    old = os.path.join(ROOT, name + ".html")
    if os.path.exists(old):
        txt = open(old, encoding="utf-8").read(4000)
        t = re.search(r"<title>(.*?)</title>", txt, re.S)
        if t:
            title = html.unescape(t.group(1))
        lg = re.search(r'<html lang="(\w+)"', txt)
        if lg:
            lang = lg.group(1)
    return ('<!doctype html>\n<html lang="%s">\n<head>\n<meta charset="utf-8">\n<title>%s</title>\n'
            '<style>\n%s\n</style>\n</head>\n<body>\n%s\n</body>\n</html>\n'
            % (lang, html.escape(title, quote=False), CSS, convert(md)))


def main():
    check = "--check" in sys.argv
    stale = []
    for name in FILES:
        src = os.path.join(ROOT, name + ".md")
        if not os.path.exists(src):
            continue
        new = page(name, open(src, encoding="utf-8").read())
        dst = os.path.join(ROOT, name + ".html")
        old = open(dst, encoding="utf-8").read() if os.path.exists(dst) else ""
        if old.replace("\r\n", "\n") != new:
            stale.append(name)
            if not check:
                with open(dst, "w", encoding="utf-8", newline="\n") as f:
                    f.write(new)
    if check:
        print("html устарел: " + ", ".join(stale) if stale else "html свежий")
        sys.exit(1 if stale else 0)
    print("обновлено: " + (", ".join(stale) if stale else "ничего"))


if __name__ == "__main__":
    main()
