#!/usr/bin/env python3
"""Extract text from a PDF and format as markdown, preserving structure."""

import re
import sys

import pymupdf


def is_heading(block_text: str, font_sizes: list[float], median_size: float) -> bool:
    """Heuristic: text is a heading if its font size is larger than the median."""
    if not font_sizes:
        return False
    avg_size = sum(font_sizes) / len(font_sizes)
    return avg_size > median_size * 1.15 and len(block_text.strip()) < 200


def extract_markdown(pdf_path: str) -> str:
    doc = pymupdf.open(pdf_path)
    all_font_sizes = []
    pages_data = []

    # First pass: collect font size statistics
    for page in doc:
        blocks = page.get_text("dict", flags=pymupdf.TEXT_PRESERVE_WHITESPACE)["blocks"]
        page_blocks = []
        for block in blocks:
            if block["type"] != 0:  # skip images
                continue
            block_text = ""
            block_sizes = []
            for line in block["lines"]:
                for span in line["spans"]:
                    block_text += span["text"]
                    block_sizes.append(span["size"])
                block_text += "\n"
            if block_text.strip():
                all_font_sizes.extend(block_sizes)
                page_blocks.append((block_text.strip(), block_sizes))
        pages_data.append(page_blocks)

    if not all_font_sizes:
        doc.close()
        return ""

    median_size = sorted(all_font_sizes)[len(all_font_sizes) // 2]

    # Second pass: format as markdown
    output = []
    for i, page_blocks in enumerate(pages_data):
        if not page_blocks:
            continue
        output.append(f"<!-- Page {i + 1} -->")
        for block_text, font_sizes in page_blocks:
            if is_heading(block_text, font_sizes, median_size):
                avg = sum(font_sizes) / len(font_sizes)
                level = "##" if avg > median_size * 1.3 else "###"
                heading = re.sub(r"\s+", " ", block_text.strip())
                output.append(f"\n{level} {heading}\n")
            else:
                # Join lines within a paragraph, preserve paragraph breaks
                cleaned = block_text.strip()
                output.append(cleaned)
        output.append("")

    doc.close()
    return "\n\n".join(output)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <pdf_path>", file=sys.stderr)
        sys.exit(1)
    print(extract_markdown(sys.argv[1]))
