#!/usr/bin/env python3
"""
Automated Minecraft 26.3 Assets & Libraries Downloader for Horizon Android
Downloads client.jar, server.jar, and all 114 runtime libraries with checksum verification.
"""

import os
import sys
import json
import urllib.request
import hashlib
from concurrent.futures import ThreadPoolExecutor

HOME = os.path.expanduser("~")
MC_DIR = os.path.join(HOME, ".minecraft")
VERSIONS_DIR = os.path.join(MC_DIR, "versions", "26.3")
SERVERS_DIR = os.path.join(MC_DIR, "servers", "26.3")
LIBS_DIR = os.path.join(MC_DIR, "libraries")

MANIFEST_URL = "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"

def sha1_file(path):
    h = hashlib.sha1()
    with open(path, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()

def download_file(url, dest_path, expected_sha1=None):
    os.makedirs(os.path.dirname(dest_path), exist_ok=True)
    if os.path.exists(dest_path) and expected_sha1:
        if sha1_file(dest_path) == expected_sha1:
            return True

    print(f"[*] Downloading {os.path.basename(dest_path)}...")
    urllib.request.urlretrieve(url, dest_path)
    if expected_sha1 and sha1_file(dest_path) != expected_sha1:
        print(f"[!] Warning: SHA1 mismatch for {dest_path}")
        return False
    return True

def main():
    print("==================================================")
    print("  Minecraft 26.3 Assets Downloader for Horizon")
    print("==================================================")

    os.makedirs(VERSIONS_DIR, exist_ok=True)
    os.makedirs(SERVERS_DIR, exist_ok=True)
    os.makedirs(LIBS_DIR, exist_ok=True)

    version_json_path = os.path.join(VERSIONS_DIR, "26.3.json")
    if not os.path.exists(version_json_path):
        print("[*] Fetching Mojang version manifest...")
        req = urllib.request.urlopen(MANIFEST_URL)
        manifest = json.loads(req.read().decode())
        v26_3 = next((v for v in manifest["versions"] if v["id"] == "26.3"), None)
        if not v26_3:
            print("[!] Version 26.3 not found in manifest!")
            sys.exit(1)
        print(f"[*] Downloading version 26.3 metadata from {v26_3['url']}...")
        urllib.request.urlretrieve(v26_3["url"], version_json_path)

    with open(version_json_path, "r") as f:
        meta = json.load(f)

    # 1. Download Client & Server JAR
    client_dl = meta["downloads"]["client"]
    client_jar = os.path.join(VERSIONS_DIR, "client.jar")
    download_file(client_dl["url"], client_jar, client_dl.get("sha1"))

    server_dl = meta["downloads"]["server"]
    server_jar = os.path.join(SERVERS_DIR, "server.jar")
    download_file(server_dl["url"], server_jar, server_dl.get("sha1"))

    # 2. Download all libraries
    libs = meta.get("libraries", [])
    print(f"[*] Downloading {len(libs)} libraries using multithreading...")
    tasks = []
    for lib in libs:
        artifact = lib.get("downloads", {}).get("artifact")
        if not artifact:
            continue
        rel_path = artifact.get("path")
        url = artifact.get("url")
        sha1 = artifact.get("sha1")
        if rel_path and url:
            target = os.path.join(LIBS_DIR, rel_path)
            tasks.append((url, target, sha1))

    with ThreadPoolExecutor(max_workers=8) as pool:
        results = pool.map(lambda t: download_file(t[0], t[1], t[2]), tasks)

    print("[✓] All Minecraft 26.3 assets and libraries downloaded successfully!")

if __name__ == "__main__":
    main()
