# TorrStream for ASUSTOR (ADM 5.1)

Unofficial **TorrStream** package for ASUSTOR NAS based on the upstream [cash94 TorrStream / VIDAA Linux build](https://github.com/cash94/cash94.github.io/releases/tag/%23vidaa).

**Tested by owner:** previous `VIDAA TorrStream` APKG `1.0.0.r02` works on AS5304T. **New revision `1.0.0.r04` has not yet been tested on a real NAS.** Target: **ADM 5.1.4.RM62**, x86-64 (AS53 series). The package keeps minimum firmware `5.1.0` so older supported ADM 5.1 versions are not unnecessarily blocked.

## Install or upgrade

Download the [latest APK](https://github.com/Steinus/TorrStream-Asustor/releases/latest) and install through **ADM → App Central → Management → Manual Install**. **Do not uninstall the old package first.** The internal ID remains `vidaa-torrstream`, even though the visible name changes to **TorrStream**. This makes it an in-place upgrade and preserves `/volume1/Docker/Vidaa`.

Open `http://NAS_IP:8098` or click **TorrStream** on the ADM desktop. On first launch the package downloads upstream `TorrStream-linux-amd64`, plus the [Jellyfin FFmpeg](https://github.com/jellyfin/jellyfin-ffmpeg) portable tools.

| Setting | Value |
|---|---|
| App Central package ID (unchanged) | `vidaa-torrstream` |
| Display name | **TorrStream** |
| ADM | **5.1.x** including 5.1.4.RM62 |
| NAS CPU | x86-64 |
| Web port | **8098** |
| Persistent data | `/volume1/Docker/Vidaa` |
| Config | `/volume1/Docker/Vidaa/config.env` |
| Log | `/volume1/Docker/Vidaa/logs/vidaa.log` |

## How updates work

1. GitHub Actions in **this repository** checks the official `#vidaa` release each day (03:17 UTC).
2. When `TorrStream-linux.zip` changes its official SHA-256 digest, it increments the APKG revision (`r03`, `r04`, ...), rebuilds the installer, updates [`latest.json`](latest.json), and publishes the APK to **Releases**. It also runs when manually dispatched from the **Actions** tab.
3. The installed package checks [`latest.json`](latest.json) every six hours and writes **one new log entry** (tag `TorrStream`, via `logger`) when a newer package revision is available. It also creates `/volume1/Docker/Vidaa/update_available.txt` with the GitHub download link.
4. Open **Releases** and install the newer APK via **App Central → Manual Install**, keeping the original settings.

**Important ADM limitation:** a manually installed third-party APK does **not** automatically appear in App Central's official **Updates** catalog just because a GitHub Release exists. This project does **not** modify ADM's internal update database. The checker uses the NAS system log and a status file; a native update badge in **App Central → Updates** requires official ASUSTOR App Central publication. The package does **not** silently install updates.

Check for updates immediately via SSH:

```sh
/usr/local/AppCentral/vidaa-torrstream/bin/check-update.sh
cat /volume1/Docker/Vidaa/update_available.txt
```

The second command displays a file only if an update has been detected. The system-log entry depends on whether ADM exposes standard syslog messages in its log viewer.

## Administration and backup

```sh
# Current status
/usr/local/AppCentral/vidaa-torrstream/CONTROL/start-stop.sh status

# Log
tail -n 100 /volume1/Docker/Vidaa/logs/vidaa.log

# Manually refresh upstream TorrStream binary (stop the app first)
/usr/local/AppCentral/vidaa-torrstream/bin/download.sh app

# Manually refresh FFmpeg (stop the app first)
/usr/local/AppCentral/vidaa-torrstream/bin/download.sh ffmpeg
```

Stop and start TorrStream from App Central. To change the HTTP port, edit `PORT=8098` in `config.env`; note that the desktop shortcut remains on 8098 until the APK metadata is rebuilt. Backup `/volume1/Docker/Vidaa` before major changes. The uninstall hook does not delete this folder.

## Building locally

Requires Python 3.9+ (stdlib only):

```sh
python3 scripts/build.py
```

The resulting `dist/torrstream_<version>_x86-64.apk` is an APKG v2.0 ZIP with `apkg-version`, `control.tar.gz`, and `data.tar.gz`. Sources are in [`app/`](app/) and the icon is stored as base64 in [`resources/icon.b64`](resources/icon.b64). The binary TorrStream and FFmpeg are not included; the NAS downloads them on first launch.

To compare the current official upstream release and bump the APKG only when the digest changed:

```sh
python3 scripts/sync_upstream.py
python3 scripts/build.py
```

The workflow uses `GITHUB_TOKEN` with `contents: write`; GitHub Actions must be enabled and allowed to create releases for automatic publication to work. Changes to upstream binaries remain under their authors' licenses.

## Credits

- Upstream TorrStream / VIDAA: **cash94** — [source and releases](https://github.com/cash94/cash94.github.io)
- FFmpeg: **Jellyfin FFmpeg** — [releases](https://github.com/jellyfin/jellyfin-ffmpeg)
- ASUSTOR wrapper package and GitHub automation: **Steinus**

Do not expose port 8098 to the public internet without suitable access controls.

## Name shown in ADM

The application display name is **TorrStream** in r03 and later. Its internal package ID remains `vidaa-torrstream` to enable in-place upgrades without losing `/volume1/Docker/Vidaa`. If ADM still shows the old name, check the installed package version in App Central, then reload ADM or sign out and back in. Do not uninstall the working package just to change its label.
