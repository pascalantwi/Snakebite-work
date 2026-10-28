# Build a LaTeX version of MANUSCRIPT_DRAFT.md for Overleaf: latex/main.tex and latex/snakebite_manuscript_latex.zip
# (main.tex + the PDF figures). Citations become \cite{refN} with the reference numbers of the draft, cross-references
# become hyperlinks, figures use the PDF versions in figures/, and the reference list becomes a numbered
# thebibliography in the same order. Editorial notes (the note under the title and the figures-and-tables list) are left out.
# Compile with pdfLaTeX (Overleaf default). Usage: python3 tools/build_latex.py
import os, re, subprocess, zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
md = open(os.path.join(ROOT, "MANUSCRIPT_DRAFT.md"), encoding="utf-8").read()

def pandoc(text, block=True):
    out = subprocess.run(["pandoc", "-f", "markdown+raw_attribute+raw_tex-auto_identifiers", "-t", "latex", "--wrap=none",
                          "--columns=40"], input=text, capture_output=True, text=True, check=True).stdout
    return out.strip() if block else out.strip().removeprefix("").strip()

def raw(tex):            # raw LaTeX block for pandoc
    return "\n```{=latex}\n" + tex + "\n```\n"

def inline(tex):
    return "`" + tex + "`{=latex}"

def widths(table):
    """pipe table: column widths follow the content (pandoc reads them from the dashes of the separator line)"""
    rows = [[c.strip() for c in ln.strip().strip("|").split("|")] for ln in table.strip().split("\n")]
    body = [r for k, r in enumerate(rows) if k > 1]
    n = len(rows[0]); w = []
    for j in range(n):
        cells = [re.sub(r"[*$`\\{}]", "", r[j]) for r in body if j < len(r)]   # markup does not take space
        head = re.sub(r"[*$`\\{}]", "", rows[0][j])
        longest_word = max((len(x) for c in cells + [head] for x in c.split()), default=3)
        w.append(max(longest_word + 2, min(max((len(c) for c in cells), default=4), 28), 4))
    rows[1] = ["-" * x for x in w]
    return "\n".join("| " + " | ".join(r) + " |" for r in rows) + "\n"

def prep(t):
    """GitHub-flavoured details -> pandoc markdown"""
    # lists directly under a paragraph need a blank line before them
    t = re.sub(r"(?m)^((?![ \t]*[*-] )\S.*)\n(?=[*] )", r"\1\n\n", t)
    # display maths
    t = re.sub(r"```math\n(.*?)\n```", lambda m: "$$" + m.group(1).strip() + "$$", t, flags=re.S)
    # inline maths $`...`$
    t = re.sub(r"\$`(.+?)`\$", lambda m: "$" + m.group(1) + "$", t)
    # citation groups [[n](url),[m](url)]
    t = re.sub(r"\[((?:\[\d+\]\([^)\s]+\))(?:,\s*\[\d+\]\([^)\s]+\))*)\]",
               lambda m: inline(r"\cite{" + ",".join("ref" + n for n in re.findall(r"\[(\d+)\]\(", m.group(1))) + "}"), t)
    # plain numeric citations [12] or [12, 13] (outside maths)
    parts = re.split(r"(\$\$.*?\$\$|\$[^$]+\$)", t, flags=re.S)
    t = "".join(p if i % 2 else re.sub(r"(?<![\w\]\[`])\[(\d+(?:\s*,\s*\d+)*)\](?![(\w])",
                                        lambda m: inline(r"\cite{" + ",".join("ref" + n.strip() for n in m.group(1).split(",")) + "}"), p)
                for i, p in enumerate(parts))
    # cross-references [text](#anchor)
    t = re.sub(r"\[([^\]]+)\]\(#([\w-]+)\)", lambda m: inline(r"\hyperref[" + m.group(2) + "]{" + m.group(1) + "}"), t)
    return t

def body_tex(t):
    return pandoc(prep(t))

# ---------------------------------------------------------------- pieces of the draft
def between(a, b):
    i = md.index(a); j = md.index(b, i)
    return md[i + len(a):j]

title = re.search(r"^\*\*(Is snakebite seasonality climate\?.*?)\*\*$", md, re.M).group(1)
running = re.search(r"^\*\*Running title:\*\* (.*)$", md, re.M).group(1)
authors = re.search(r"^\*\*Authors:\*\* (.*)$", md, re.M).group(1)

main = md[md.index("## Abstract"):md.index("## Figures and tables")]
main = main.replace("\n---\n", "\n")

# figures: anchor + image + caption paragraph
def fig_block(m):
    anchor, path, cap = m.group(1), m.group(2), m.group(3)
    pdf = path.replace(".png", ".pdf")
    cap_tex = pandoc(prep(cap))
    return raw("\\begin{figure}[!htbp]\n\\centering\n\\includegraphics[width=\\linewidth]{" + pdf + "}\n"
               "\\caption*{" + cap_tex + "}\n\\phantomsection\\label{" + anchor + "}\n\\end{figure}")
main = re.sub(r'<a name="([\w-]+)"></a>\n\n!\[[^\]]*\]\(([^)]+)\)\n\n(\*\*(?:Fig|S\d Fig).*?)\n', fig_block, main)

# tables: anchor + bold title + pipe table + footnote paragraph
def tab_block(m):
    anchor, cap, table, foot = m.group(1), m.group(2), m.group(3), m.group(4)
    cap_tex = pandoc(prep(cap)); tab_tex = pandoc(prep(widths(table))); foot_tex = pandoc(prep(foot))
    return raw("\\begingroup\\footnotesize\\hyphenpenalty=10000\n\\phantomsection\\label{" + anchor + "}\n\\noindent " + cap_tex + "\n" + tab_tex +
               "\n\\hyphenpenalty=50\\noindent " + foot_tex + "\\par\\endgroup\n\\medskip")
main = re.sub(r'<a name="([\w-]+)"></a>\n\n(\*\*(?:Table|S\d Table).*?)\n\n((?:\|.*\n)+)\n([^\n]+)\n', tab_block, main)
assert "<a name=\"fig" not in main and "<a name=\"table" not in main, "unconverted figure or table"

# remaining anchors (S1 Text sections) -> labels
main = re.sub(r'<a name="([\w-]+)"></a>', lambda m: raw("\\phantomsection\\label{" + m.group(1) + "}"), main)

# headings: numbered sections 1-5, unnumbered elsewhere
def heading(m):
    level, text = len(m.group(1)), m.group(2).strip()
    num = re.match(r"^(\d+(?:\.\d+)*)\.?\s+(.*)$", text)
    new_level = "#" * (level - 1)
    if num:
        return f"{new_level} {num.group(2)}"
    return f"{new_level} {text} {{-}}"
main = re.sub(r"^(#{2,4}) (.+)$", heading, main, flags=re.M)
body = body_tex(main)

# references
refs = md[md.index("## References"):]
items = re.findall(r"^(\d+)\. (.*)$", refs, re.M)
bib = ["\\begin{thebibliography}{99}"]
for n, text in items:
    t = re.sub(r"(?<![(\[])(https?://\S+?)([.,;]?)(?=\s|$)", lambda m: "<" + m.group(1) + ">" + m.group(2), text)
    bib.append("\\bibitem{ref" + n + "} " + pandoc(t))
bib.append("\\end{thebibliography}")
assert [int(n) for n, _ in items] == list(range(1, len(items) + 1)), "reference numbers not consecutive"

preamble = r"""% Manuscript generated from MANUSCRIPT_DRAFT.md by tools/build_latex.py. Compile with pdfLaTeX (Overleaf default).
\documentclass[11pt,a4paper]{article}
\usepackage[utf8]{inputenc}
\usepackage[T1]{fontenc}
\usepackage{lmodern}
\usepackage{textcomp}
\usepackage{newunicodechar}
\usepackage[margin=2.5cm]{geometry}
\usepackage{amsmath,amssymb}
\usepackage{graphicx}
\usepackage{longtable,booktabs,array,calc}
\usepackage{caption}
\captionsetup{labelformat=empty,justification=justified,singlelinecheck=false,font=small}
\usepackage[numbers,sort&compress]{natbib}
\usepackage{xcolor}
\usepackage[hidelinks]{hyperref}
\usepackage{lineno}
\linenumbers
\setlength{\parskip}{4pt}
\setlength{\parindent}{0pt}
\providecommand{\tightlist}{\setlength{\itemsep}{0pt}\setlength{\parskip}{0pt}}
\newunicodechar{Δ}{\ensuremath{\Delta}}
\newunicodechar{θ}{\ensuremath{\theta}}
\newunicodechar{χ}{\ensuremath{\chi}}
\newunicodechar{ᵃ}{\textsuperscript{a}}
\newunicodechar{−}{\ensuremath{-}}
\newunicodechar{√}{\ensuremath{\surd}}
\newunicodechar{≈}{\ensuremath{\approx}}
\newunicodechar{²}{\textsuperscript{2}}
\newunicodechar{¹}{\textsuperscript{1}}
\renewcommand{\refname}{References}
\begin{document}
"""
front = ("\\begin{flushleft}\n{\\Large\\bfseries " + pandoc(title) + "\\par}\n\\bigskip\n" + pandoc(authors) +
         "\\par\n\\medskip\n\\textbf{Running title:} " + pandoc(running) + "\n\\end{flushleft}\n")
tex = preamble + front + "\n" + body + "\n\n" + "\n".join(bib) + "\n\\end{document}\n"

# sanity checks: every \cite key has a bibitem, every \hyperref target has a label, braces balance
keys = set(re.findall(r"\\bibitem\{(ref\d+)\}", tex))
cited = {k for c in re.findall(r"\\cite\{([^}]*)\}", tex) for k in c.split(",")}
assert cited <= keys, f"citations without bibitem: {sorted(cited - keys)}"
labels = set(re.findall(r"\\label\{([^}]*)\}", tex))
targets = set(re.findall(r"\\hyperref\[([^\]]*)\]", tex))
assert targets <= labels, f"cross-references without label: {sorted(targets - labels)}"
assert tex.count("{") - tex.count("\\{") == tex.count("}") - tex.count("\\}"), "unbalanced braces"
non = sorted({ch for ch in tex if ord(ch) > 127} - set("°±¶·×éíñøń–—ΔθχᵃΓ−√≈²¹"))
assert not non, f"unmapped characters: {non}"

out = os.path.join(ROOT, "latex"); os.makedirs(out, exist_ok=True)
open(os.path.join(out, "main.tex"), "w", encoding="utf-8").write(tex)
figs = sorted(set(re.findall(r"\\includegraphics\[[^\]]*\]\{([^}]+)\}", tex)))
zpath = os.path.join(out, "snakebite_manuscript_latex.zip")
with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
    z.write(os.path.join(out, "main.tex"), "snakebite_manuscript/main.tex")
    for f in figs:
        z.write(os.path.join(ROOT, f), "snakebite_manuscript/" + f)
print(f"main.tex: {len(tex):,} characters; {len(cited)} references cited of {len(keys)}; {len(figs)} figures; "
      f"{len(labels)} labels; zip {os.path.getsize(zpath)/1e6:.2f} MB")
