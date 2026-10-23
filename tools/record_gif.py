# Record the Roblox Studio window to a GIF (for Studio mocks like tools/mock_swords_tiers.luau fly mode).
#   python record_gif.py <out.gif> [seconds=10] [fps=15] [width=720]
# Finds the window whose title contains "Roblox Studio", grabs it with ffmpeg gdigrab (Studio must be
# visible on screen: gdigrab copies what is drawn there), then makes a palette GIF. Read-only for Studio.
import ctypes, ctypes.wintypes as W, os, subprocess, sys, tempfile

out = os.path.abspath(sys.argv[1])
secs = float(sys.argv[2]) if len(sys.argv) > 2 else 10
fps = int(sys.argv[3]) if len(sys.argv) > 3 else 15
width = int(sys.argv[4]) if len(sys.argv) > 4 else 720

user32 = ctypes.windll.user32
titles = []


@ctypes.WINFUNCTYPE(W.BOOL, W.HWND, W.LPARAM)
def each(hwnd, _):
    if user32.IsWindowVisible(hwnd):
        n = user32.GetWindowTextLengthW(hwnd)
        if n:
            buf = ctypes.create_unicode_buffer(n + 1)
            user32.GetWindowTextW(hwnd, buf, n + 1)
            if "Roblox Studio" in buf.value:
                titles.append(buf.value)
    return True


user32.EnumWindows(each, 0)
if not titles:
    sys.exit("no visible Roblox Studio window")
title = titles[0]
print("recording:", title)
tmp = os.path.join(tempfile.gettempdir(), "studio_rec.mp4")
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "gdigrab", "-framerate", "30", "-t", str(secs),
                "-i", f"title={title}", "-c:v", "libx264", "-preset", "veryfast", "-crf", "18", tmp], check=True)
vf = f"fps={fps},scale={width}:-1:flags=lanczos"
pal = os.path.join(tempfile.gettempdir(), "studio_pal.png")
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-vf", vf + ",palettegen=stats_mode=diff", pal], check=True)
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-i", pal, "-lavfi",
                vf + " [x]; [x][1:v] paletteuse=dither=sierra2_4a", "-loop", "0", out], check=True)
print("gif:", out, os.path.getsize(out) // 1024, "KB")
