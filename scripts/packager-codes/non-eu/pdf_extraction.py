import pdfplumber
from pdfplumber.page import Page


def get_bbox(pdf_obj):
    return pdf_obj["x0"], pdf_obj["top"], pdf_obj["x1"], pdf_obj["bottom"]


def extract_page(page: Page):
    if len(page.curves) < 2:
        raise ValueError(
            "PDF page contains less than 2 curves, formatting may have changed"
        )

    # Find table bounding box
    min_x0 = min(c["x0"] for c in page.curves)
    max_x1 = max(c["x1"] for c in page.curves)
    min_top = min(c["top"] for c in page.curves)
    max_bottom = max(c["bottom"] for c in page.curves)
    table_bbox = (min_x0, min_top, max_x1, max_bottom)
    table_page = page.crop(table_bbox)

    # Get table lines
    vertical_lines_x = sorted(set(p[0] for p in table_page.curves[0]["points"]))
    vertical_lines_x = [table_page.curves[1]["x0"]] + vertical_lines_x + [
        table_page.curves[1]["x1"]]
    horizontal_lines_y = sorted(c["points"][0][1] for c in table_page.curves[1:])
    horizontal_lines_y = [table_page.curves[0]["top"]] + horizontal_lines_y + [
        table_page.curves[-1]["bottom"]]

    return table_page.extract_table(
        {
            "horizontal_strategy": "explicit",
            "explicit_vertical_lines": vertical_lines_x,
            "vertical_strategy": "explicit",
            "explicit_horizontal_lines": horizontal_lines_y,
        }
    )


table_header = [
    "Approval number",
    "Name",
    "City",
    "Regions",
    "Activities",
    "Remark",
    "Date of request",
]


def extract_doc(pdf):
    doc_table = [table_header]
    for page in pdf.pages:
        table = extract_page(page)
        if table[0] != table_header:
            raise ValueError("invalid table header")
        doc_table.extend(table[1:])
    return doc_table


def main():
    import sys
    with pdfplumber.open(sys.argv[1]) as pdf:
        table = extract_doc(pdf)
        print("\n".join(["\t".join(l) for l in table]))


if __name__ == "__main__":
    main()
