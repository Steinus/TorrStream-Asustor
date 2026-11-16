#!/usr/bin/env python3
"""Build the ASUSTOR APKG using only Python standard library."""
import base64
import gzip
import hashlib
import io
import json
from pathlib import Path
import tarfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "app"
CONFIG = json.loads((APP / "CONTROL/config.json").read_text(encoding="utf-8"))
VERSION = CONFIG["general"]["version"]
ARCH = CONFIG["general"]["architecture"]
OUTPUT = ROOT / "dist" / f"torrstream_{VERSION}_{ARCH}.apk"

def archive_targz(members):
    buf = io.BytesIO()
    with gzip.GzipFile(fileobj=buf, mode="wb", filename="", mtime=0, compresslevel=9) as gz:
        with tarfile.open(fileobj=gz, mode="w", format=tarfile.USTAR_FORMAT) as tf:
            for name, data, mode in sorted(members):
                info = tarfile.TarInfo(name)
                info.size = len(data)
                info.uid = info.gid = info.mtime = 0
                info.uname = info.gname = "root"
                info.mode = mode
                tf.addfile(info, io.BytesIO(data))
    return buf.getvalue()

def members(root):
    return [(p.relative_to(root).as_posix(), p.read_bytes(), 0o755 if p.suffix==".sh" else 0o644)
            for p in root.rglob("*") if p.is_file()]

icon = base64.b64decode((ROOT / "resources/icon.b64").read_text())
assert icon.startswith(b"\x89PNG\r\n\x1a\n")
control = members(APP / "CONTROL") + [("icon.png",icon,0o644)]
data = [(p.relative_to(APP).as_posix(),p.read_bytes(),0o755 if p.suffix==".sh" else 0o644)
        for p in APP.rglob("*") if p.is_file() and "CONTROL" not in p.parts]
OUTPUT.parent.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile(OUTPUT,"w",compression=zipfile.ZIP_DEFLATED,compresslevel=9) as apk:
    for name, blob in [("apkg-version",b"2.0\n"),("control.tar.gz",archive_targz(control)),("data.tar.gz",archive_targz(data))]:
        entry = zipfile.ZipInfo(name,date_time=(2020,1,1,0,0,0))
        entry.create_system = 3
        entry.external_attr = 0o644<<16
        entry.compress_type = zipfile.ZIP_DEFLATED
        apk.writestr(entry,blob)

upstream=json.loads((ROOT/"tracking/upstream.json").read_text())
tag=f"v{VERSION}"
release=f"https://github.com/Steinus/TorrStream-Asustor/releases/tag/{tag}"
latest={
 "version":VERSION,"package":CONFIG["general"]["package"],"name":CONFIG["general"]["name"],
 "adm_min":CONFIG["general"]["firmware"],"architecture":ARCH,
 "upstream_digest":upstream["digest"],"upstream_updated_at":upstream["asset_updated_at"],
 "release_url":release,
 "apk_url":f"https://github.com/Steinus/TorrStream-Asustor/releases/download/{tag}/{OUTPUT.name}",
 "apk_sha256":hashlib.sha256(OUTPUT.read_bytes()).hexdigest()
}
(ROOT/"latest.json").write_text(json.dumps(latest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print(OUTPUT,latest["apk_sha256"])
