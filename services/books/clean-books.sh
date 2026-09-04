#!/usr/bin/env bash
set -Eeuo pipefail

# ==========================================
# Book cleaner
# Cleans filenames using EPUB metadata
# Format:
#   Title - Author.epub
#
# Source:
#   needs-cleanup
#
# Output:
#   import-ready
#   processed-originals
# ==========================================

BASE="/srv/media/books/staging"

SOURCE="needs-cleanup"
READY="import-ready"
ARCHIVE="processed-originals"
LOGDIR="logs"

SOURCE_DIR="$BASE/$SOURCE"
READY_DIR="$BASE/$READY"
ARCHIVE_DIR="$BASE/$ARCHIVE"
LOG_DIR="$BASE/$LOGDIR"
LOG_FILE="$LOG_DIR/cleanup.log"

mkdir -p "$READY_DIR"
mkdir -p "$ARCHIVE_DIR"
mkdir -p "$LOG_DIR"

PROCESSED=0
SKIPPED=0
FAILED=0

echo "====================================" | tee -a "$LOG_FILE"
echo "Book cleanup started: $(date)" | tee -a "$LOG_FILE"
echo "====================================" | tee -a "$LOG_FILE"


while IFS= read -r -d '' FILE; do

    FILENAME="$(basename "$FILE")"

    echo
    echo "===================================="
    echo "File:"
    echo "  $FILENAME"
    echo

    # Extract metadata
    TITLE=$(ebook-meta "$FILE" | awk -F': ' '/Title[[:space:]]*:/{print $2; exit}')
    AUTHOR=$(ebook-meta "$FILE" | awk -F': ' '/Author\(s\)[[:space:]]*:/{print $2; exit}' | sed 's/\[.*\]//')

    if [[ -z "$TITLE" || -z "$AUTHOR" ]]; then
        echo "Could not read metadata."
        echo "$(date): FAILED metadata $FILE" >> "$LOG_FILE"
        FAILED=$((FAILED + 1))
        continue
    fi

    # Remove subtitle after colon
    TITLE="${TITLE%%:*}"

    # Clean whitespace
    TITLE="$(echo "$TITLE" | sed 's/[[:space:]]*$//' | sed 's/^[[:space:]]*//')"
    AUTHOR="$(echo "$AUTHOR" | sed 's/[[:space:]]*$//' | sed 's/^[[:space:]]*//')"

    # Remove duplicated author from title when metadata includes it
    # Example:
    #   Title : Follett, Ken - The Pillars of the Earth
    #   Author: Follett, Ken
    # becomes:
    #   Title : The Pillars of the Earth

    if [[ "$TITLE" == "$AUTHOR - "* ]]; then
	TITLE="${TITLE#"$AUTHOR - "}"
    elif [[ "$TITLE" == *" - $AUTHOR" ]]; then
	TITLE="${TITLE%" - $AUTHOR"}"
    fi

    NEW_NAME="${TITLE} - ${AUTHOR}.epub"

    echo "Metadata:"
    echo "  Title : $TITLE"
    echo "  Author: $AUTHOR"
    echo
    echo "New filename:"
    echo "  $NEW_NAME"
    echo

    printf "Import? [y/N] "
    read -r ANSWER </dev/tty || ANSWER="n"

    if [[ "$ANSWER" =~ ^[Yy]$ ]]; then

        DEST="$READY_DIR/$NEW_NAME"

        echo
        echo "Copying:"
        echo "  $DEST"

        if cp "$FILE" "$DEST" && [[ -f "$DEST" ]]; then

            mv "$FILE" "$ARCHIVE_DIR/"

            echo "Imported successfully."
            echo "$(date): IMPORTED $NEW_NAME" >> "$LOG_FILE"

            PROCESSED=$((PROCESSED + 1))

        else

            echo "Copy failed. Original left untouched."
            echo "$(date): FAILED copy $FILE" >> "$LOG_FILE"

            FAILED=$((FAILED + 1))

        fi

    else

        echo "Skipped."
        SKIPPED=$((SKIPPED + 1))

    fi

done < <(
    find "$SOURCE_DIR" \
        -maxdepth 1 \
        -type f \
        \( \
            -iname "*.epub" -o \
            -iname "*.pdf" -o \
            -iname "*.cbz" -o \
            -iname "*.mobi" -o \
            -iname "*.azw3" \
        \) \
        -print0
)


echo
echo "===================================="
echo "Cleanup complete"
echo
echo "Processed: $PROCESSED"
echo "Skipped  : $SKIPPED"
echo "Failed   : $FAILED"
echo "===================================="

echo "$(date): Complete - Processed:$PROCESSED Skipped:$SKIPPED Failed:$FAILED" >> "$LOG_FILE"
