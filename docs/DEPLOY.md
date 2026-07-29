# Deploying updates to the Pi

Three ways to get updated code onto the Pi. Pick whichever suits you — they end
up at the same place (`/home/muksri/blacktown-bin-day` on the Pi). After any of them,
restart the app so the new code loads:

```bash
sudo systemctl restart binday      # if you used the systemd autostart
# or, if you launch start.sh manually: Ctrl+C then ./start.sh
```

Assumptions below: Pi hostname `binday`, user `muksri`, repo cloned at
`/home/muksri/blacktown-bin-day`. Adjust to match your setup.

---

## Method 1 — GitHub → existing repo `muksri1/bindayapp`

The v2 files live in this folder (`blacktown-bin-day/`). Your GitHub repo is
**https://github.com/muksri1/bindayapp** and already has your v1 history. The
clean way to update it and keep that history is to drop the v2 files into a fresh
clone and commit. Run on your PC (Windows Command Prompt), one folder above this
project — adjust the parent path if different:

```cmd
cd C:\dev\Claude-CoWork\BinDay-App
git clone https://github.com/muksri1/bindayapp.git
robocopy blacktown-bin-day bindayapp /E /XD .git
cd bindayapp
git add -A
git commit -F ..\blacktown-bin-day\docs\commit-msg-v2.txt
git push origin HEAD
```

- `robocopy … /XD .git` copies every v2 file over the clone **except** the `.git`
  folder, so the repo's history stays intact.
- `git push origin HEAD` pushes to whatever the repo's default branch is (`main`
  or `master`) without you needing to know which.
- The commit message is stored in `docs/commit-msg-v2.txt` so you don't have to
  retype it.

### Or: review it as a branch + Pull Request first
```cmd
cd C:\dev\Claude-CoWork\BinDay-App\bindayapp
git checkout -b v2
git add -A
git commit -F ..\blacktown-bin-day\docs\commit-msg-v2.txt
git push -u origin v2
```
Then on GitHub click **Compare & pull request**, paste the notes from
`CHANGELOG.md`, review the diff, and **Merge**. Tag the release if you like:
```cmd
git tag -a v2.0.0 -m "v2.0.0"
git push origin v2.0.0
```

### Then update the Pi
Your Pi folder is a file copy, not a git checkout, so pull won't work there. Use
Method 3 (`pscp`) to copy the files across — or, one time, replace the Pi folder
with a clone so future updates are a simple `git pull`:
```bash
cd ~ && rm -rf blacktown-bin-day \
  && git clone https://github.com/muksri1/bindayapp.git blacktown-bin-day \
  && chmod +x blacktown-bin-day/start.sh
# then restart the kiosk (Method 3 / DEPLOYMENT-NOTES.md)
```

> Quick alternative (⚠️ discards v1 history): from this `blacktown-bin-day/`
> folder you can force the repo to match v2 exactly —
> `git remote add origin https://github.com/muksri1/bindayapp.git` then
> `git push -u origin main --force`. Only do this if you don't care about the v1
> commits on GitHub.

---

## Method 2 — Local push with VS Code (recommended for learning)

This edits/copies files on the Pi directly from VS Code over SSH — no GitHub
round-trip. Two options; **Remote-SSH** is the better one to learn.

### 2a. Remote-SSH (edit files live on the Pi)
1. In VS Code, install the **Remote - SSH** extension (by Microsoft).
2. Press `F1` → **Remote-SSH: Connect to Host…** → **Add New SSH Host** →
   enter `ssh muksri@binday.local` (or `ssh muksri@<pi-ip>`).
3. Pick the host, enter the Pi password when prompted. A new VS Code window opens
   *running on the Pi*.
4. **File → Open Folder →** `/home/muksri/blacktown-bin-day`.
5. Edit files (or drag the updated `src/index.html`, `start.sh`, etc. from your
   PC into the explorer to overwrite). Saving writes straight to the Pi.
6. Open the built-in terminal (`` Ctrl+` ``) — it's a shell *on the Pi*:
   ```bash
   sudo systemctl restart binday
   ```

> First connection is slow (VS Code installs a small server on the Pi). The
> Zero 2W has limited RAM — close other apps if it feels sluggish.

### 2b. SSH FS / SFTP (copy files without opening a remote window)
Install the **SFTP** extension (Natizyskunk) or **SSH FS**, add a config pointing
at `binday.local` / user `muksri` / your target folder, then right-click files →
**Upload**. Good for a quick single-file push.

---

## Method 3 — PuTTY / SCP (what you already know)

You're comfortable with PuTTY, so this is the fastest for you.

### 3a. Pull from GitHub over a PuTTY session
Open PuTTY → connect to `binday.local` (or the Pi's IP), log in as `pi`, then:

```bash
cd /home/muksri/blacktown-bin-day
git pull
sudo systemctl restart binday
```

### 3b. Copy files straight from your PC with `pscp` (no GitHub)
`pscp` ships with PuTTY. From a Windows Command Prompt on your PC, in the folder
that contains the updated files.

First make sure the destination folder exists on the Pi (copying multiple items
with `-r` fails with *"remote filespec … not a directory"* if it doesn't):

```cmd
plink muksri@binday.local "mkdir -p /home/muksri/blacktown-bin-day"
```

Then copy:

```cmd
pscp -r src proxy.py start.sh binday.service docs README.md CHANGELOG.md muksri@binday.local:/home/muksri/blacktown-bin-day/
```

It'll prompt for the Pi password, then copy everything over. Restart the app:

```cmd
plink muksri@binday.local "sudo systemctl restart binday"
```

(Or just restart from an interactive PuTTY session.)

> `pscp`/`plink` are in the PuTTY install folder. If Windows can't find them, add
> that folder (e.g. `C:\Program Files\PuTTY`) to your PATH, or run them from there.

---

## Verifying the update took

After restarting, on the Pi:

```bash
systemctl status binday            # should be active (running)
```

On the display, confirm the v2 behaviour: the countdown shows days to the *next*
Tuesday (not a stuck "0 days"), and on a Monday after 5 PM the put-out bins pulse.
You can fake a time to test without waiting by setting the Pi clock temporarily:

```bash
sudo timedatectl set-ntp false
sudo date -s "2026-08-03 18:05:00"     # a Monday evening — bins should pulse
# ...check the screen...
sudo timedatectl set-ntp true          # restore real time
```
