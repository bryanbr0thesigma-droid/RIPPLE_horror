# Downloads each narration line read by Microsoft Sam (the SAPI 4 voice from Windows 95 to XP)
# from tetyys.com's SAPI4 service, which runs the original voice. Writes voice/<id>.wav and skips
# lines already downloaded, so the service is only asked once per line.
#   python3 fetch_voice.py [voice_dir]
import os, sys, time, urllib.parse, urllib.request
from narration import LINES

OUT = sys.argv[1] if len(sys.argv) > 1 else "voice"
URL = "https://www.tetyys.com/SAPI4/SAPI4?"
os.makedirs(OUT, exist_ok=True)
for key, text in LINES.items():
    path = f"{OUT}/{key}.wav"
    if os.path.exists(path):
        continue
    q = urllib.parse.urlencode({"text": text, "voice": "Sam", "pitch": 100, "speed": 150})
    for attempt in range(4):
        try:
            data = urllib.request.urlopen(URL + q, timeout=60).read()
            break
        except Exception as e:
            print("retry", key, e)
            time.sleep(2 ** attempt * 2)
    else:
        sys.exit(f"could not fetch {key}")
    assert data[:4] == b"RIFF", f"{key}: not a WAV"
    open(path, "wb").write(data)
    print(key, len(data))
    time.sleep(0.5)
