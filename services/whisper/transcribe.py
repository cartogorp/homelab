import os
import shutil
import time

from faster_whisper import WhisperModel


UPLOAD_DIR = "/srv/storage/whisper/uploads"
OUTPUT_DIR = "/srv/storage/whisper/transcripts"
PROCESSED_DIR = "/srv/storage/whisper/processed"

SCAN_INTERVAL = 5
STABLE_CHECKS = 3


os.makedirs(UPLOAD_DIR, exist_ok=True)
os.makedirs(OUTPUT_DIR, exist_ok=True)
os.makedirs(PROCESSED_DIR, exist_ok=True)


print("Loading Whisper model...")
model = WhisperModel("base.en", device="cpu")
print("Whisper model loaded.")


def get_audio_files():
    """Return audio files currently waiting in the uploads directory."""
    try:
        entries = os.listdir(UPLOAD_DIR)
    except FileNotFoundError:
        return []

    audio_extensions = {".m4a", ".mp3", ".wav", ".mp4", ".webm", ".ogg", ".flac"}

    return sorted(
        os.path.join(UPLOAD_DIR, filename)
        for filename in entries
        if os.path.isfile(os.path.join(UPLOAD_DIR, filename))
        and os.path.splitext(filename)[1].lower() in audio_extensions
    )


def wait_for_file(path, checks=STABLE_CHECKS, delay=1):
    """
    Wait until a file's size remains unchanged for `checks` consecutive checks.

    Returns True if the file becomes stable, False if it disappears.
    """
    last_size = None
    stable = 0

    while True:
        try:
            size = os.path.getsize(path)
        except FileNotFoundError:
            return False

        if size == last_size:
            stable += 1
        else:
            stable = 0

        if stable >= checks:
            return True

        last_size = size
        time.sleep(delay)


def transcribe_file(filepath):
    filename = os.path.basename(filepath)

    print(f"Processing: {filename}")

    segments, info = model.transcribe(
        filepath,
        beam_size=5,
        vad_filter=True,
        word_timestamps=True,
    )

    lines = []

    for seg in segments:
        start_min = int(seg.start // 60)
        start_sec = int(seg.start % 60)

        lines.append(
            f"[{start_min:02d}:{start_sec:02d}] {seg.text.strip()}"
        )

    text = "\n".join(lines)

    base_name = os.path.splitext(filename)[0]
    out_path = os.path.join(OUTPUT_DIR, base_name + ".txt")

    with open(out_path, "w") as f:
        f.write(text)

    print(f"Saved: {out_path}")

    processed_path = os.path.join(PROCESSED_DIR, filename)

    # Avoid overwriting an existing processed file.
    if os.path.exists(processed_path):
        timestamp = int(time.time())
        name, ext = os.path.splitext(filename)
        processed_path = os.path.join(
            PROCESSED_DIR,
            f"{name}_{timestamp}{ext}",
        )

    shutil.move(filepath, processed_path)

    print(f"Moved: {processed_path}")


print("Watching uploads folder...")

try:
    while True:
        for filepath in get_audio_files():
            filename = os.path.basename(filepath)

            print(f"Detected: {filename}")

            if not wait_for_file(filepath):
                print(f"File disappeared while waiting: {filename}")
                continue

            try:
                transcribe_file(filepath)
            except Exception as exc:
                print(f"ERROR processing {filename}: {exc}", flush=True)

        time.sleep(SCAN_INTERVAL)

except KeyboardInterrupt:
    print("Stopping Whisper service...")
