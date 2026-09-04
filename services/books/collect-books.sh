#!/usr/bin/env bash
set -Eeuo pipefail

# ==========================================
# Book collector
# Collects new books from staging sources
# into needs-cleanup for processing
# ==========================================

BASE="/srv/media/books/staging"

# Add new sources here later
SOURCES=(
    "openbooks/books"
    "manual-import"
    "readarr"
)

DEST="needs-cleanup"
LOGDIR="logs"

DEST_DIR="$BASE/$DEST"
LOG_DIR="$BASE/$LOGDIR"
LOG_FILE="$LOG_DIR/collect.log"

mkdir -p "$DEST_DIR"
mkdir -p "$LOG_DIR"

COPIED=0
SKIPPED=0
ERRORS=0

echo "====================================" | tee -a "$LOG_FILE"
echo "Book collection started: $(date)" | tee -a "$LOG_FILE"
echo "====================================" | tee -a "$LOG_FILE"

for SOURCE in "${SOURCES[@]}"; do

    SOURCE_DIR="$BASE/$SOURCE"

    if [[ ! -d "$SOURCE_DIR" ]]; then
        echo "Missing source, skipping: $SOURCE_DIR"
        continue
    fi

    echo
    echo "Scanning: $SOURCE_DIR"

    while IFS= read -r -d '' FILE; do

        FILENAME="$(basename "$FILE")"
        DEST_FILE="$DEST_DIR/$FILENAME"

        if [[ -e "$DEST_FILE" ]]; then
            echo "SKIP (already exists): $FILENAME"
            echo "$(date): SKIP $FILE (already exists)" >> "$LOG_FILE"
            ((SKIPPED+=1))
            continue
        fi

        echo "COPY:"
        echo "  $FILE"
        echo "→ $DEST_FILE"

        if cp "$FILE" "$DEST_FILE"; then
            echo "$(date): COPIED $FILE -> $DEST_FILE" >> "$LOG_FILE"
            ((COPIED+=1))
        else
            echo "ERROR copying: $FILE"
            echo "$(date): ERROR copying $FILE" >> "$LOG_FILE"
            ((ERRORS+=1))
        fi

    done < <(
        find "$SOURCE_DIR" \
            -maxdepth 1 \
            -type f \
            \( \
                -iname "*.epub" -o \
                -iname "*.pdf" -o \
                -iname "*.cbz" -o \
                -iname "*.cbr" -o \
                -iname "*.mobi" -o \
                -iname "*.azw3" \
            \) \
            -print0
    )

done

echo
echo "===================================="
echo "Collection complete"
echo
echo "Copied : $COPIED"
echo "Skipped: $SKIPPED"
echo "Errors : $ERRORS"
echo "===================================="

echo "$(date): Complete - Copied:$COPIED Skipped:$SKIPPED Errors:$ERRORS" >> "$LOG_FILE"
