# Sphinx configuration of the HORNET manuals (make docs).
#
# The chapters are GitHub Markdown, read by MyST. Three things differ between
# GitHub and the PDF, and are rewritten here when the LaTeX builder reads a page:
#   - figures: GitHub shows figures/<name>.svg, the PDF uses figures/<name>.pdf
#   - links to repository files (../rtl/..., ../Makefile) become GitHub URLs
#   - <!-- pdf: landscape --> ... <!-- pdf: end landscape --> puts a wide figure
#     on a landscape page (an HTML comment, invisible on GitHub)
# Tables get their column widths from their content, and short tables and code
# blocks are kept on one page (LatexLayout below).
import datetime
import re

from docutils import nodes
from sphinx import addnodes
from sphinx.transforms.post_transforms import SphinxPostTransform
from sphinx.util import logging

project = "HORNET RV32IMF"
author = "Istanbul Technical University, GSTL"
release = "2.0"
version = "2.0"
copyright = f"{datetime.date.today().year}, {author}"

extensions = ["myst_parser"]
source_suffix = {".md": "markdown"}
root_doc = "index"
exclude_patterns = ["README.md", "_build", "_templates", "figures/*.drawio"]
# _templates/longtable.tex.jinja: no "continued" rows in tables that break
templates_path = ["_templates"]
myst_heading_anchors = 3
myst_enable_extensions = ["colon_fence"]
# toc.secnum: manual.md numbers the Part I chapters a second time (for its own PDF)
suppress_warnings = ["myst.header", "myst.xref_missing", "toc.secnum"]

REPO = "https://github.com/GSTL-ITU/HORNET-RV32IMF/blob/main/"

html_theme = "sphinx_rtd_theme"
html_title = "HORNET RV32IMF manual"

latex_engine = "xelatex"
# two manuals from the same chapters: Part I (manual.md) and Parts I and II (index.md)
_AUTHOR = "Istanbul Technical University\\\\GSTL Laboratory"
latex_documents = [
    ("manual", "hornet-manual.tex", "HORNET RV32IMF\\\\Processor and SoC Manual", _AUTHOR, "manual"),
    (root_doc, "hornet-student-manual.tex", "HORNET RV32IMF\\\\Student's Manual", _AUTHOR, "manual"),
]
latex_toplevel_sectioning = "chapter"
latex_show_urls = "no"
latex_elements = {
    "papersize": "a4paper",
    "pointsize": "10pt",
    "extraclassoptions": "openany,oneside",
    "fontpkg": r"""
\setmainfont{FreeSerif}
\setsansfont{FreeSans}
\setmonofont{lmmono10-regular.otf}[BoldFont=lmmonolt10-bold.otf, ItalicFont=lmmono10-italic.otf, Scale=0.95]
""",
    "preamble": r"""
\usepackage{pdflscape}
\usepackage{newunicodechar}
\newunicodechar{→}{\ensuremath{\rightarrow}}
\newunicodechar{←}{\ensuremath{\leftarrow}}
\newunicodechar{↔}{\ensuremath{\leftrightarrow}}
\newunicodechar{≥}{\ensuremath{\geq}}
\newunicodechar{≤}{\ensuremath{\leq}}
\newunicodechar{×}{\ensuremath{\times}}
\newunicodechar{±}{\ensuremath{\pm}}
\newunicodechar{≈}{\ensuremath{\approx}}
\newunicodechar{✓}{\checkmark}
\newfontfamily\hornetboxfont{FreeMono}[Scale=0.83125]% as wide as the code font (0.525 em x 0.95)
\newunicodechar{─}{{\hornetboxfont ─}}
\newunicodechar{│}{{\hornetboxfont │}}
\newunicodechar{└}{{\hornetboxfont └}}
\newunicodechar{├}{{\hornetboxfont ├}}
\setcounter{tocdepth}{1}
\setlength{\headheight}{24pt}
\usepackage{needspace}
% table column of #1 x \linewidth (LatexTableColumns): ragged right, no hyphenation
% (hyphenation off through the minimum word length: the penalties would also
% stop inline code from breaking after / . , ;)
\newcolumntype{\HornetCol}[1]{>{\raggedright\arraybackslash\lefthyphenmin=62 \righthyphenmin=62 }%
    p{\dimexpr #1\linewidth-2\tabcolsep\relax}}
""",
    "figure_align": "H",
    # Sphinx names the contents after the first toctree caption ("Part I: ...")
    "tableofcontents": r"\renewcommand{\contentsname}{Contents}\sphinxtableofcontents",
    "sphinxsetup": "TitleColor={rgb}{0.10,0.20,0.40}, InnerLinkColor={rgb}{0.10,0.25,0.55}, OuterLinkColor={rgb}{0.10,0.25,0.55}",
}

_LINK = re.compile(r"\]\((\.\./)+([^)#\s]+)(#[^)\s]*)?\)")
_LANDSCAPE = re.compile(r"<!-- pdf: landscape -->.*?<!-- pdf: end landscape -->", re.S)
_IMAGE = re.compile(r"!\[([^\]]*)\]\(([^)\s]+)\)")


def _latex_source(app, docname, source):
    if app.builder.name != "latex":
        return
    text = source[0]
    text = re.sub(r"(figures/[\w-]+)\.svg", r"\1.pdf", text)
    # repository files outside docs/ -> GitHub
    text = _LINK.sub(lambda m: f"]({REPO}{m.group(2)}{m.group(3) or ''})", text)
    # a figure on a landscape page shares it with the section heading above it
    text = _LANDSCAPE.sub(lambda m: _IMAGE.sub(r"\n```{image} \2\n:alt: \1\n:width: 88%\n```\n", m.group(0)), text)
    text = text.replace("<!-- pdf: landscape -->", "\n```{raw} latex\n\\begin{landscape}\n```\n")
    text = text.replace("<!-- pdf: end landscape -->", "\n```{raw} latex\n\\end{landscape}\n```\n")
    text = text.replace("<!-- pdf: newpage -->", "\n```{raw} latex\n\\clearpage\n```\n")
    source[0] = text


# Tables and code blocks in the PDF. Left alone, Sphinx sizes table columns
# with tabulary and justifies the cells: code is pushed out of narrow columns,
# short headers are hyphenated and justified cells get wide gaps. Instead every
# table gets a column spec computed from its content, the way browsers lay out
# tables: each column is at least as wide as its longest unbreakable word, and
# the rest of the line goes to the columns with more text. Widths are in pt,
# from the glyph widths of FreeSerif (cells) and FreeSans (headers) at 10 pt.
# A tall table may break across pages; a shorter table or code block moves to
# the next page as a whole when it does not fit.
LINE_WIDTH = 451.0           # \linewidth: A4 with 1 in margins
CELL_PAD = 12.0              # 2 \tabcolsep
MONO_WIDTH = 5.0             # Latin Modern Mono at 0.95
SHORT_CELL = 50.0            # a cell narrower than this is never wrapped
LINE_HEIGHT = 12.0
LONG_TABLE = 400.0           # a taller table may break across pages
KEEP_CODE_LINES = 40         # a shorter code block is not split across pages
KEEP_HEADING_LINES = 7       # a heading needs this many lines below it on its page

_logger = logging.getLogger(__name__)


def _glyphs(letters, widths):
    return dict(zip(letters, (w / 100 for w in widths)))


_LETTERS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 .,;:-/()"
_SERIF = _glyphs(_LETTERS, [
    444, 500, 444, 500, 444, 333, 500, 500, 278, 278, 500, 278, 778, 500, 500, 500, 500, 333, 389, 278,
    500, 500, 722, 500, 500, 444, 722, 667, 667, 722, 611, 556, 722, 722, 333, 389, 722, 611, 889, 722,
    722, 556, 722, 667, 556, 611, 722, 722, 944, 722, 722, 611] + [500] * 10 + [250, 250, 250, 278, 333, 278, 333, 333])
_SANS = _glyphs(_LETTERS, [
    556, 556, 500, 556, 556, 278, 556, 556, 222, 222, 500, 222, 833, 556, 556, 556, 556, 333, 500, 278,
    556, 500, 722, 500, 500, 500, 667, 667, 722, 722, 667, 611, 778, 722, 278, 500, 667, 556, 833, 722,
    778, 667, 778, 722, 667, 611, 722, 667, 944, 667, 667, 611] + [556] * 10 + [278, 278, 278, 278, 333, 278, 333, 333])


def _char_width(c, mono, head):
    if mono:
        return MONO_WIDTH
    return (_SANS if head else _SERIF).get(c.replace(" ", " "), 7.5)


def _block_widths(block, head):
    """(longest unbreakable piece, whole text on one line) of a paragraph."""
    chars = []
    for text in block.findall(nodes.Text):
        mono = isinstance(text.parent, nodes.literal)
        chars += [(c, mono) for c in text.astext().replace("\n", " ")]
    longest = whole = piece = 0.0
    for c, mono in chars:
        w = _char_width(c, mono, head)
        whole += w
        if c == " ":
            piece = 0.0
            continue
        piece += w
        longest = max(longest, piece)
        if mono and c in "/,;":      # inline code breaks after these
            piece = 0.0
    return longest, whole


def _cell_widths(entry, head):
    narrow = wide = 0.0
    for block in entry.findall(nodes.paragraph):
        n, w = _block_widths(block, head)
        narrow, wide = max(narrow, n), max(wide, w)
    for block in entry.findall(nodes.literal_block):
        w = MONO_WIDTH * max(len(line) for line in block.astext().splitlines() or [""])
        narrow, wide = max(narrow, w), max(wide, w)
    if wide < SHORT_CELL:
        narrow = wide
    return narrow * 1.02 + 1, wide * 1.02 + 1


# "232 320" and "2.8 k" stay on one line (a non-breaking space in LaTeX)
_KEEP_TOGETHER = re.compile(r"(?<=\d) (?=\d{3}\b|(?:k|M|G|KB|MB|GB|MHz|ns|min|h|s|bit)\b)")


class LatexLayout(SphinxPostTransform):
    default_priority = 400
    builders = ("latex",)

    def run(self, **kwargs):
        for text in list(self.document.findall(nodes.Text)):
            if not isinstance(text.parent, (nodes.literal, nodes.literal_block)) and _KEEP_TOGETHER.search(text):
                text.parent.replace(text, nodes.Text(_KEEP_TOGETHER.sub("\u00a0", text.astext())))
        # no section heading at the bottom of a page (chapters start a page anyway)
        for section in list(self.document.findall(nodes.section)):
            if isinstance(section.parent, nodes.section):
                section.parent.insert(section.parent.index(section), _needspace(KEEP_HEADING_LINES))
        for table in list(self.document.findall(nodes.table)):
            self._columns(table)
        for code in list(self.document.findall(nodes.literal_block)):
            lines = code.astext().count("\n") + 1
            if lines <= KEEP_CODE_LINES and not any(isinstance(a, nodes.table) for a in _ancestors(code)):
                _keep(code, lines + 2)

    def _columns(self, table):
        rows = list(table.findall(nodes.row))
        ncols = len(list(table.findall(nodes.colspec)))
        narrow, wide = [0.0] * ncols, [0.0] * ncols
        cells = []
        for row in rows:
            head = isinstance(row.parent, nodes.thead)
            cells.append([])
            for i, entry in enumerate(row.findall(nodes.entry)):
                # an empty cell would be an empty paragraph: a blank line in the PDF
                for par in list(entry.findall(nodes.paragraph)):
                    if not par.astext().strip():
                        par.parent.remove(par)
                if i < ncols and not entry.get("morecols"):
                    n, w = _cell_widths(entry, head)
                    narrow[i], wide[i] = max(narrow[i], n), max(wide[i], w)
                    cells[-1].append((i, w))
        avail = LINE_WIDTH - CELL_PAD * ncols
        if sum(wide) <= avail:
            widths = [w + (avail - sum(wide)) * w / sum(wide) for w in wide]
        elif sum(narrow) >= avail:
            _logger.warning("table too wide for the page", location=table)
            widths = [n * avail / sum(narrow) for n in narrow]
        else:
            k = (avail - sum(narrow)) / (sum(wide) - sum(narrow))
            widths = [n + (w - n) * k for n, w in zip(narrow, wide)]
        spec = "".join(r"\HornetCol{%.3f}" % ((w + CELL_PAD) / LINE_WIDTH - 0.0005) for w in widths)
        table.parent.insert(table.parent.index(table), addnodes.tabular_col_spec(spec=spec))
        # a tall table may break across pages, but not before its header and first four rows
        heights = [LINE_HEIGHT * max([-(-w // widths[i]) for i, w in row] or [1]) + 3 for row in cells]
        if sum(heights) > LONG_TABLE:
            table["classes"].append("longtable")
            _keep(table, int(sum(heights[:5]) / LINE_HEIGHT) + 1)
        else:
            _keep(table, int(sum(heights) / LINE_HEIGHT) + 1)


def _ancestors(node):
    while node.parent is not None:
        node = node.parent
        yield node


def _keep(node, lines):
    """Start a new page before node unless this many lines of text still fit.
    A short paragraph that introduces it, and the heading right above that
    paragraph, move to the new page with it."""
    target = node
    intro = _previous(node)
    if isinstance(intro, nodes.paragraph) and len(intro.astext()) < 400:
        lines += len(intro.astext()) // 90 + 2
        target = intro
        intro = _previous(intro)
    if isinstance(intro, nodes.title):
        target = intro.parent
        lines += 3
    target.parent.insert(target.parent.index(target), _needspace(lines))


def _needspace(lines):
    return nodes.raw("", r"\needspace{%d\baselineskip}" % lines, format="latex")


def _previous(node):
    """The sibling before node, skipping nodes that print nothing."""
    i = node.parent.index(node)
    while i > 0 and isinstance(node.parent[i - 1], (addnodes.tabular_col_spec, nodes.raw, nodes.target)):
        i -= 1
    return node.parent[i - 1] if i > 0 else None


def setup(app):
    app.connect("source-read", _latex_source)
    app.add_post_transform(LatexLayout)
