#!/bin/bash
# Set up Python venv and install dependencies for ralph-lit-rev
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RALPH_DIR="$(dirname "$SCRIPT_DIR")"
VENV_DIR="$RALPH_DIR/.venv"

if [ -d "$VENV_DIR" ]; then
  echo "Venv already exists at $VENV_DIR"
  echo "To recreate, remove it first: rm -rf $VENV_DIR"
  exit 0
fi

echo "Creating Python venv at $VENV_DIR..."
python3 -m venv "$VENV_DIR"

echo "Installing dependencies..."
"$VENV_DIR/bin/pip" install --quiet --upgrade pip
"$VENV_DIR/bin/pip" install --quiet -r "$SCRIPT_DIR/requirements.txt"

echo "Setup complete."
echo "PDF tools available at:"
echo "  $VENV_DIR/bin/python $SCRIPT_DIR/pdf_to_text.py <file.pdf>"
echo "  $VENV_DIR/bin/python $SCRIPT_DIR/pdf_to_markdown.py <file.pdf>"
