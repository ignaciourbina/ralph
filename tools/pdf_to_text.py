#!/usr/bin/env python3
"""Extract plain text from a PDF file. Prints to stdout."""

import sys

import pymupdf


def extract_text(pdf_path: str) -> str:
    doc = pymupdf.open(pdf_path)
    pages = []
    for i, page in enumerate(doc):
        text = page.get_text("text")
        if text.strip():
            pages.append(f"--- Page {i + 1} ---\n{text}")
    doc.close()
    return "\n\n".join(pages)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <pdf_path>", file=sys.stderr)
        sys.exit(1)
    print(extract_text(sys.argv[1]))
