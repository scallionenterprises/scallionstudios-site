#!/usr/bin/env bash
# Create *_small.jpg previews (max dimension 750px) for product images.
# Skips thumbnail.jpg and existing *_small.jpg files. Originals are kept.
#
# Usage:
#   ./scripts/make-small-images.sh assets/img/202607-side-table-dog-bed
#   ./scripts/make-small-images.sh assets/img/202607-side-table-dog-bed --print-markdown

set -euo pipefail

MAX_DIM=750

usage() {
  echo "Usage: $0 <assets-img-dir> [--print-markdown]" >&2
  exit 1
}

[[ $# -ge 1 ]] || usage

DIR="${1%/}"
PRINT_MD=false
[[ "${2:-}" == "--print-markdown" ]] && PRINT_MD=true

if [[ ! -d "$DIR" ]]; then
  echo "Error: not a directory: $DIR" >&2
  exit 1
fi

resize_image() {
  local src="$1"
  local dest="$2"

  if command -v magick >/dev/null 2>&1; then
    magick "$src" -resize "${MAX_DIM}x${MAX_DIM}>" -quality 85 "$dest"
  elif command -v convert >/dev/null 2>&1; then
    convert "$src" -resize "${MAX_DIM}x${MAX_DIM}>" -quality 85 "$dest"
  elif command -v sips >/dev/null 2>&1; then
    # sips -Z sets the longest side; copy first so the original is untouched
    cp "$src" "$dest"
    sips -Z "$MAX_DIM" "$dest" >/dev/null
  else
    echo "Error: need magick, convert, or sips to resize images" >&2
    exit 1
  fi
}

created=0
skipped=0

shopt -s nullglob
for src in "$DIR"/*.{jpg,jpeg,JPG,JPEG,png,PNG,webp,WEBP}; do
  base="$(basename "$src")"
  name="${base%.*}"
  ext="${base##*.}"
  ext_lower="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"

  # Skip thumbnails and already-generated smalls
  if [[ "$base" == "thumbnail.jpg" || "$base" == "thumbnail.jpeg" ]]; then
    skipped=$((skipped + 1))
    continue
  fi
  if [[ "$name" == *_small ]]; then
    skipped=$((skipped + 1))
    continue
  fi

  # Always emit JPEG smalls as *_small.jpg
  dest="$DIR/${name}_small.jpg"

  if [[ -f "$dest" && "$dest" -nt "$src" ]]; then
    echo "up to date: $dest"
    skipped=$((skipped + 1))
  else
    echo "creating: $dest"
    resize_image "$src" "$dest"
    created=$((created + 1))
  fi

  if $PRINT_MD; then
    echo "{% include product-image.html file=\"${name}.${ext_lower}\" %}"
  fi
done

echo "Done. created=$created skipped=$skipped"
echo
echo "Markdown usage (inside a product page):"
echo "  {% include product-image.html file=\"front.jpg\" %}"
echo
echo "Or wrap several in <div class=\"product-images\"> ... </div>"
