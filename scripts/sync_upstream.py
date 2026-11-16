#!/usr/bin/env python3
"""Sync official TorrStream archive SHA-256, increment APKG revision only on changes."""
import json
import os
import re
from pathlib import Path
from urllib.request import Request, urlopen

ROOT=Path(__file__).resolve().parents[1]
API="https://api.github.com/repos/cash94/cash94.github.io/releases/tags/%23vidaa"
TRACK=ROOT/"tracking/upstream.json"
CONFIG=ROOT/"app/CONTROL/config.json"
fixture=os.getenv("UPSTREAM_RELEASE_FIXTURE")
if fixture:
    release=json.loads(Path(fixture).read_text())
else:
    headers={"Accept":"application/vnd.github+json","User-Agent":"Steinus-TorrStream-Asustor","X-GitHub-Api-Version":"2022-11-28"}
    token=os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    if token:
        headers["Authorization"]="Bearer "+token
    req=Request(API,headers=headers)
    with urlopen(req,timeout=35) as resp: release=json.load(resp)
assets=[a for a in release.get("assets",[]) if a.get("name")=="TorrStream-linux.zip"]
if len(assets)!=1: raise SystemExit("Expected exactly one official Linux asset")
asset=assets[0]
digest=asset.get("digest","")
if not re.fullmatch(r"sha256:[0-9a-f]{64}",digest):
    raise SystemExit("Missing official SHA-256 digest; refusing update")
old=json.loads(TRACK.read_text())
if old.get("digest")==digest:
    print("No upstream update:",digest)
    raise SystemExit(0)
config=json.loads(CONFIG.read_text())
version=config["general"]["version"]
match=re.fullmatch(r"(\d+\.\d+\.\d+\.r)(\d+)",version)
if not match: raise SystemExit("Unsupported version "+version)
new=f"{match.group(1)}{int(match.group(2))+1:02d}"
config["general"]["version"]=new
CONFIG.write_text(json.dumps(config,ensure_ascii=False,indent=2)+"\n")
(ROOT/"app/VERSION").write_text(new+"\n")
TRACK.write_text(json.dumps({"asset":"TorrStream-linux.zip","digest":digest,"asset_updated_at":asset.get("updated_at",""),"source":"https://github.com/cash94/cash94.github.io/releases/tag/%23vidaa"},indent=2)+"\n")
changelog=ROOT/"app/CONTROL/changelog.txt"
changelog.write_text(f"{new}\n- Synced upstream cash94 TorrStream (SHA-256: {digest[7:]}).\n- Settings preserved.\n\n"+changelog.read_text())
print(f"Upstream updated: {version} -> {new}")
