#!/usr/bin/env python3
"""md2html.py — markdown-mode 的外部转换器 (stdin → stdout)。

供 markdown-mode 的 markdown-command 调用:
  markdown-command = '("python3" "/Users/dok4ever/.emacs.d/md2html.py")'
markdown-mode 把 buffer 内容通过 stdin 传入, 本脚本输出完整 HTML,
被 markdown-standalone 识别为 standalone (含 DOCTYPE) 后直接交给 eww 渲染。

支持: 标题/表格/代码块/列表/引用/粗体/行内代码/分隔线。
"""
import sys
import re
import html as h

def inline(s):
    s = h.escape(s)
    s = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', s)
    s = re.sub(r'`([^`]+)`', r'<code>\1</code>', s)
    return s

def render(md):
    lines = md.split('\n')
    out, code_buf, table_buf = [], [], []
    in_code = False

    def flush_table():
        if not table_buf:
            return
        rows = [[c.strip() for c in r.strip().strip('|').split('|')]
                for r in table_buf]
        rows = [r for r in rows if not all(re.fullmatch(r':?-{2,}:?', c) for c in r)]
        if rows:
            out.append('<table>')
            for i, r in enumerate(rows):
                tag = 'th' if i == 0 else 'td'
                out.append('<tr>' + ''.join(f'<{tag}>{inline(c)}</{tag}>' for c in r) + '</tr>')
            out.append('</table>')
        table_buf.clear()

    def flush_code():
        if code_buf:
            out.append(f'<pre><code>{h.escape(chr(10).join(code_buf))}</code></pre>')
            code_buf.clear()

    for ln in lines:
        if ln.strip().startswith('```'):
            if in_code:
                flush_code(); in_code = False
            else:
                flush_table(); in_code = True
            continue
        if in_code:
            code_buf.append(ln); continue
        s = ln.rstrip()
        if not s.strip():
            flush_table(); out.append(''); continue
        if re.match(r'^\s*\|.*\|\s*$', s):
            table_buf.append(s); continue
        if table_buf:
            flush_table()
        if re.fullmatch(r'-{3,}', s.strip()):
            out.append('<hr>'); continue
        m = re.match(r'^(#{1,6})\s+(.*)$', s)
        if m:
            out.append(f'<h{len(m.group(1))}>{inline(m.group(2))}</h{len(m.group(1))}>')
            continue
        m = re.match(r'^(\s*)[-*]\s+(.*)$', s)
        if m:
            out.append(f'<li>{inline(m.group(2))}</li>'); continue
        m = re.match(r'^>\s?(.*)$', s)
        if m:
            out.append(f'<blockquote>{inline(m.group(1))}</blockquote>'); continue
        out.append(f'<p>{inline(s)}</p>')

    flush_table(); flush_code()
    return '\n'.join(out)

CSS = """
body { font-family: -apple-system, "PingFang SC", "SF Pro Text", sans-serif; max-width: 780px; margin: 40px auto; padding: 0 24px; color: #1f2328; line-height: 1.7; }
h1 { font-size: 26px; border-bottom: 2px solid #d0d7de; padding-bottom: 8px; }
h2 { font-size: 20px; margin-top: 32px; border-bottom: 1px solid #d8dee4; padding-bottom: 6px; }
h3 { font-size: 16px; margin-top: 24px; }
table { border-collapse: collapse; width: 100%; margin: 12px 0; font-size: 14px; }
th, td { border: 1px solid #d0d7de; padding: 6px 12px; text-align: left; }
th { background: #f6f8fa; }
pre { background: #f6f8fa; border: 1px solid #d0d7de; border-radius: 6px; padding: 12px; overflow-x: auto; font-size: 13px; }
code { background: #f6f8fa; border-radius: 4px; padding: 1px 4px; font-family: "SF Mono", Menlo, monospace; font-size: 13px; }
pre code { background: none; padding: 0; }
blockquote { border-left: 4px solid #d0d7de; margin: 12px 0; padding: 4px 16px; color: #57606a; }
li { margin: 4px 0; }
hr { border: none; border-top: 1px solid #d8dee4; margin: 28px 0; }
"""

def main():
    md = sys.stdin.read()
    body = render(md)
    title_m = re.search(r'^#\s+(.+)$', md, re.M)
    title = title_m.group(1).strip() if title_m else 'Markdown Preview'
    print(f"""<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{h.escape(title)}</title>
<style>{CSS}</style></head>
<body>
{body}
</body></html>""")

if __name__ == '__main__':
    main()
