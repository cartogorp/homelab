import time
import os
import shutil
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
from faster_whisper import WhisperModel

UPLOAD_DIR = "/srv/storage/whisper/uploads"
OUTPUT_DIR = "/srv/storage/whisper/transcripts"
PROCESSED_DIR = "/srv/storage/whisper/processed"

os.makedirs(UPLOAD_DIR, exist_ok=True)
os.makedirs(OUTPUT_DIR, exist_ok=True)
os.makedirs(PROCESSED_DIR, exist_ok=True)

model = WhisperModel("base.en", device="cpu")

def wait_for_file(path, checks=3, delay=1):
    last_size = -1
    stable = 0

    for _ in range(30):
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

    return False


class Handler(FileSystemEventHandler):
    def on_created(self, event):
        if event.is_directory:
            return

        filepath = event.src_path
        filename = os.path.basename(filepath)

        print(f"Detected: {filename}")

        if not wait_for_file(filepath):
            print("File not stable, skipping")
            return

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

        shutil.move(filepath, processed_path)

        print(f"Moved: {processed_path}")


observer = Observer()
observer.schedule(Handler(), UPLOAD_DIR, recursive=False)
observer.start()

print("Watching uploads folder...")

try:
    while True:
        time.sleep(5)
except KeyboardInterrupt:
    observer.stop()

observer.join()
