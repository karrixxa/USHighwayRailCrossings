"""Turn the report's Markdown source into a Word document.

Handles the small subset of Markdown the report uses: # and ## headings,
paragraphs, bullet and numbered lists, pipe tables, **bold** and *italic*.
Two special lines insert images:
    [Figure N: caption. File: path/to/figure.png]
    [Equation. File: path/to/equation.png]

Usage (from the repository root, after 09_make_figures.R and 10_make_equation.py):
    python scripts/11_build_report_docx.py
    python scripts/11_build_report_docx.py report/report.md report/STAT425_final_report.docx

Input:  report/report.md (default) and the images it names
Output: report/STAT425_final_report.docx (default)
"""
import re
import sys
from pathlib import Path

from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.shared import Inches, Pt

DEFAULT_SOURCE = Path("report/report.md")
DEFAULT_OUTPUT = Path("report/STAT425_final_report.docx")
INLINE_STYLE = re.compile(r"(\*\*[^*]+\*\*|\*[^*]+\*)")
FIGURE_WIDTH, EQUATION_WIDTH = Inches(6), Inches(4.2)


def add_styled_text(paragraph, text):
    """Append `text` to a Word paragraph, turning **bold** and *italic* into runs."""
    for part in INLINE_STYLE.split(text):
        if not part:
            continue
        if part.startswith("**") and part.endswith("**"):
            paragraph.add_run(part[2:-2]).bold = True
        elif part.startswith("*") and part.endswith("*"):
            paragraph.add_run(part[1:-1]).italic = True
        else:
            paragraph.add_run(part)


def add_table(doc, markdown_rows):
    """Add a Markdown pipe table to `doc`, bolding the header row.

    Args:
        doc: python-docx Document.
        markdown_rows: the table's lines, e.g. ["| a | b |", "| --- | --- |", "| 1 | 2 |"].
    """
    rows = []
    for line in markdown_rows:
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if not all(re.fullmatch(r"-+", cell) for cell in cells):   # skip the --- separator
            rows.append(cells)
    table = doc.add_table(rows=len(rows), cols=len(rows[0]))
    table.style = "Table Grid"
    for r, cells in enumerate(rows):
        for c, text in enumerate(cells):
            cell = table.cell(r, c)
            cell.text = ""
            add_styled_text(cell.paragraphs[0], text)
            if r == 0:
                for run in cell.paragraphs[0].runs:
                    run.bold = True
    doc.add_paragraph()


def add_image(doc, path, width, caption=None):
    """Add a centred image, with an italic caption underneath if given."""
    doc.add_picture(str(path), width=width)
    doc.paragraphs[-1].alignment = WD_ALIGN_PARAGRAPH.CENTER
    if caption:
        doc.add_paragraph().add_run(caption.rstrip(".") + ".").italic = True


def build_docx(source, output):
    """Convert the Markdown file `source` into the Word file `output`."""
    doc = Document()
    doc.styles["Normal"].font.name = "Calibri"
    doc.styles["Normal"].font.size = Pt(11)

    lines = source.read_text(encoding="utf-8").splitlines()
    i = 0
    while i < len(lines):
        line = lines[i].rstrip()
        if line.startswith("|"):
            start = i
            while i < len(lines) and lines[i].startswith("|"):
                i += 1
            add_table(doc, lines[start:i])
            continue

        if not line:
            pass
        elif line.startswith("# "):
            doc.add_heading(line[2:], level=0)
        elif line.startswith("## "):
            doc.add_heading(line[3:], level=1)
        elif line.startswith("- "):
            add_styled_text(doc.add_paragraph(style="List Bullet"), line[2:])
        elif re.match(r"^\d+\. ", line):
            add_styled_text(doc.add_paragraph(style="List Number"), re.sub(r"^\d+\. ", "", line))
        elif line.startswith("[Equation") and "File:" in line:
            add_image(doc, Path(line.strip("[]").split("File:")[1].strip()), EQUATION_WIDTH)
        elif line.startswith("[Figure") and "File:" in line:
            caption, path = line.strip("[]").split("File:")
            add_image(doc, Path(path.strip()), FIGURE_WIDTH, caption.strip())
        else:
            add_styled_text(doc.add_paragraph(), line)
        i += 1

    doc.save(output)
    print(f"Wrote {output}")


if __name__ == "__main__":
    source = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_SOURCE
    output = Path(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_OUTPUT
    build_docx(source, output)
