#!/usr/bin/env python3
"""Выносит функции из main.gd в отдельный скрипт-«строитель» (механически).

    python tools/extract_fn.py main.gd hud_builder.gd HudBuilder _build_hud [...]

Каждая функция становится `static func имя(g, параметры)`, где `g` — главный узел
(main.gd); любое обращение к членам main (var/const/func и унаследованные методы
Node2D) получает префикс `g.`; в main.gd остаётся тонкая обёртка с той же
сигнатурой, которая зовёт `Const.имя(self, ...)`. Код вынесенной функции не
меняется ни на символ, кроме префиксов. Строки и комментарии не трогаются.

Проверять результат нужно дампом дерева узлов до/после и смоук-тестом: скрипт
предупреждает о подозрительных местах (ключи словарей вида `{name=...}`, локальные
переменные, затеняющие члены main).
"""
import re
import sys
import os

KEYWORDS = set("""if elif else for while match var const func return await in not and or is as
pass break continue static class extends true false null self signal enum when assert preload
void int float bool String Array Dictionary Vector2 Vector3 Color""".split())


def read(p):
    return open(p, encoding="utf-8").read()


def main_members(src):
    names = set()
    for line in src.split("\n"):
        m = re.match(r"^(?:@onready\s+)?(?:static\s+)?(?:var|const|func|signal)\s+(\w+)", line)
        if m:
            names.add(m.group(1))
        m = re.match(r"^enum\s+(\w+)", line)
        if m:
            names.add(m.group(1))
    return names


def split_segments(text):
    """[(is_code, chunk)] — строки и комментарии отделены от кода."""
    segs = []
    i, n = 0, len(text)
    buf = []

    def flush(code=True):
        if buf:
            segs.append((code, "".join(buf)))
            buf.clear()

    while i < n:
        c = text[i]
        if c == "#":
            flush()
            j = text.find("\n", i)
            j = n if j < 0 else j
            segs.append((False, text[i:j]))
            i = j
        elif c in "\"'":
            flush()
            q = c
            if text.startswith(q * 3, i):
                j = text.find(q * 3, i + 3)
                j = n if j < 0 else j + 3
            else:
                j = i + 1
                while j < n and text[j] != q:
                    if text[j] == "\\":
                        j += 1
                    j += 1
                j += 1
            segs.append((False, text[i:j]))
            i = j
        else:
            buf.append(c)
            i += 1
    flush()
    return segs


def function_span(lines, name):
    start = None
    for k, line in enumerate(lines):
        if re.match(r"^(?:static\s+)?func\s+%s\s*\(" % re.escape(name), line):
            start = k
            break
    if start is None:
        raise SystemExit("нет функции " + name)
    end = len(lines)
    for k in range(start + 1, len(lines)):
        if lines[k] and not lines[k][0].isspace():
            end = k
            break
    # комментарии/пустые строки перед следующей функцией относятся к ней
    while end > start + 1 and (lines[end - 1].strip() == "" or lines[end - 1].lstrip().startswith("#") and not lines[end - 1][0].isspace()):
        end -= 1
    return start, end


def locals_of(code):
    out = set()
    for m in re.finditer(r"\b(?:var|const)\s+(\w+)", code):
        out.add(m.group(1))
    for m in re.finditer(r"\bfor\s+(\w+)\s+in\b", code):
        out.add(m.group(1))
    for m in re.finditer(r"\bfunc\s*\w*\s*\(([^)]*)\)", code):
        for part in m.group(1).split(","):
            nm = part.strip().split(":")[0].split("=")[0].strip()
            if nm:
                out.add(nm)
    return out


def transform(body, prefix_names, warn):
    loc = locals_of("".join(c for ok, c in split_segments(body) if ok))
    shadow = loc & prefix_names
    for s in sorted(shadow):
        warn("локальная переменная «%s» затеняет член main — не префиксуется" % s)
    names = prefix_names - loc
    pat = re.compile(r"(?<![\w.$%@&^])([A-Za-z_]\w*)")
    out = []
    for ok, chunk in split_segments(body):
        if not ok:
            out.append(chunk)
            continue

        def sub(m):
            nm = m.group(1)
            if nm == "self":
                return "g"
            if nm in KEYWORDS or nm not in names:
                return nm
            after = chunk[m.end():m.end() + 6].lstrip()
            before = chunk[max(0, m.start() - 2):m.start()].strip()
            if after.startswith("=") and not after.startswith("==") and before in ("{", ","):
                warn("похоже на ключ словаря «%s=» — проверь вручную" % nm)
                return nm
            return "g." + nm
        out.append(pat.sub(sub, chunk))
    res = "".join(out)
    # `g` без типа (Variant): вывод типа через := в вынесенном коде невозможен, а
    # локальные const с обращением к g. — не константные выражения. Поведение то же.
    res = res.replace(":=", "=")
    res = re.sub(r"\bconst\s+(\w+)((?:\s*:\s*\w+)?\s*=[^\n]*\bg\.)", r"var \1\2", res)
    return res


def main():
    src_path, dst_path, const_name = sys.argv[1], sys.argv[2], sys.argv[3]
    fn_names = sys.argv[4:]
    src = read(src_path)
    api = set(open(os.environ["NODE2D_API"], encoding="utf-8").read().split()) if os.environ.get("NODE2D_API") else set()
    members = main_members(src)
    prefix_names = (members | api) - KEYWORDS
    lines = src.split("\n")
    pieces = []
    wrappers = {}
    for fn in fn_names:
        a, b = function_span(lines, fn)
        head = lines[a]
        body = "\n".join(lines[a + 1:b])
        m = re.match(r"^func\s+(\w+)\s*\((.*?)\)\s*(->\s*[\w\.\[\]]+)?\s*:\s*$", head)
        if not m:
            raise SystemExit("не разобрана сигнатура: " + head)
        params, ret = m.group(2), (m.group(3) or "")
        warns = []
        new_body = transform(body, prefix_names, warns.append)
        for w in warns:
            print("[%s] %s" % (fn, w))
        sig = "static func %s(g%s)%s:" % (fn, (", " + params) if params.strip() else "", (" " + ret) if ret else "")
        pieces.append(sig + "\n" + new_body)
        pnames = [p.strip().split(":")[0].split("=")[0].strip() for p in params.split(",") if p.strip()]
        call = "%s.%s(%s)" % (const_name, fn, ", ".join(["self"] + pnames))
        is_void = (not ret) or "void" in ret
        if re.search(r"\bawait\b", "".join(c for ok, c in split_segments(body) if ok)):
            call = "await " + call   # корутина: обёртка тоже должна ждать
        wrappers[fn] = (a, b, head + "\n\t" + (call if is_void else "return " + call) + "\n")
    # в main.gd — справа налево, чтобы индексы не плыли
    for fn, (a, b, w) in sorted(wrappers.items(), key=lambda kv: -kv[1][0]):
        lines[a:b] = w.rstrip("\n").split("\n") + [""]
    text = "\n".join(lines)
    const_line = 'const %s = preload("res://%s")' % (const_name, os.path.basename(dst_path))
    if const_line not in text:
        # после первой строки const TILE
        i = text.index("\nconst TILE")
        text = text[:i] + "\n" + const_line + text[i:]
    header = ("extends RefCounted\n\n# Вынесено из main.gd механически (tools/extract_fn.py, v6.8): код функций\n"
              "# тот же, что был в main.gd; `g` — главный узел, все его члены с префиксом `g.`.\n"
              "# Состояние остаётся в main.gd (переменные `_hud_layer`, `_vitals`, …).\n\n")
    if os.path.exists(dst_path):   # дописываем в уже созданный строитель
        old = read(dst_path).rstrip("\n")
        open(dst_path, "w", encoding="utf-8", newline="\n").write(old + "\n\n" + "\n\n".join(pieces) + "\n")
    else:
        open(dst_path, "w", encoding="utf-8", newline="\n").write(header + "\n\n".join(pieces) + "\n")
    open(src_path, "w", encoding="utf-8", newline="\n").write(text)
    print("вынесено: %s -> %s" % (", ".join(fn_names), dst_path))


if __name__ == "__main__":
    main()
