#!/usr/bin/env python3
"""Report, and optionally apply, upstream changes to the vendored PKGBUILDs.

Upstream is not a build input: an AUR PKGBUILD can be force-pushed and a
GitHub one can be rewritten between two builds of the same version, so ours
are copies. That makes them frozen unless something looks, which is what
this does.

Two kinds of upstream, one mechanism:

  - aur.archlinux.org, read through cgit's plain view.
  - github.com, read through the contents API. One file, not a clone: the
    cost is the same as the AUR fetch, so there is no reason to treat these
    differently. (An earlier version skipped them on the assumption that
    checking meant cloning. It does not.)

Several vendored PKGBUILDs carry deliberate local edits - `arch=` narrowed
to this repository's single architecture - so an update is never a blind
overwrite. `packages/.upstream/<name>.PKGBUILD` holds the pristine
upstream text each copy was made from, and that file is the merge base:
with it, an upstream change to a line we never touched applies cleanly, and
one to a line we did touch conflicts loudly. Without it the "merge" is an
overwrite that reverts our edits and reports success.

Output is per package, so the caller can open one pull request per update
rather than one containing everything: an unrelated conflict should not
hold up a clean one.

Exit status: 0 when nothing moved, 1 when something did, 2 when a fetch
failed.
"""

import argparse
import base64
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
PACKAGES = ROOT / "packages"
MANIFEST = PACKAGES / "upstreams.yml"
BASES = PACKAGES / ".upstream"

AUR_HOST = "https://aur.archlinux.org/"
AUR_PLAIN = "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h={name}"
GITHUB_HOST = "https://github.com/"
GITHUB_API = "https://api.github.com/repos/{repo}/contents/PKGBUILD"

USER_AGENT = "manjaro-sway-track-upstreams"


def log(message: str) -> None:
    print(message, file=sys.stderr, flush=True)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def request(url: str, accept: str | None = None) -> bytes:
    headers = {"User-Agent": USER_AGENT}
    if accept:
        headers["Accept"] = accept
    # GitHub's unauthenticated limit is 60/hour from one address, which a
    # shared runner can exhaust; the workflow token raises it to 1000
    token = os.environ.get("GITHUB_TOKEN")
    if token and url.startswith("https://api.github.com/"):
        headers["Authorization"] = f"Bearer {token}"
    with urllib.request.urlopen(
        urllib.request.Request(url, headers=headers), timeout=30
    ) as response:
        return response.read()


def source_of(upstream: str) -> tuple[str, str] | None:
    """(kind, identifier) for an upstream URL, or None if we cannot read it."""
    if upstream.startswith(AUR_HOST) and "/cgit/" not in upstream:
        return "aur", upstream[len(AUR_HOST):].removesuffix(".git")
    if upstream.startswith(GITHUB_HOST):
        return "github", upstream[len(GITHUB_HOST):].removesuffix(".git")
    return None


def fetch(kind: str, identifier: str) -> bytes:
    if kind == "aur":
        body = request(AUR_PLAIN.format(name=identifier))
    else:
        payload = json.loads(
            request(
                GITHUB_API.format(repo=identifier),
                accept="application/vnd.github+json",
            )
        )
        body = base64.b64decode(payload["content"])

    # cgit answers 200 with an HTML error page for an unknown package, and a
    # repository can hold a PKGBUILD-shaped file that is not one, so a
    # plausible-looking response still has to be checked
    if b"pkgname" not in body:
        raise ValueError(f"{identifier}: upstream did not return a PKGBUILD")
    return body


def merge(base: bytes, ours: bytes, theirs: bytes) -> tuple[bytes, bool]:
    """Replay our local edits onto the new upstream text.

    `git merge-file` does the three-way merge, so a change upstream makes
    to a line we never touched applies cleanly, and one to a line we did
    touch conflicts loudly instead of silently reverting our edit.
    """
    with tempfile.TemporaryDirectory() as tmp:
        paths = {}
        for label, data in (("base", base), ("ours", ours), ("theirs", theirs)):
            paths[label] = Path(tmp, label)
            paths[label].write_bytes(data)

        result = subprocess.run(
            ["git", "merge-file", "-L", "ours", "-L", "vendored", "-L", "upstream",
             "-p", str(paths["ours"]), str(paths["base"]), str(paths["theirs"])],
            capture_output=True,
        )
        # exit >0 is the number of conflicts; <0 is an error
        return result.stdout, result.returncode == 0


def unified(old: bytes, new: bytes, name: str) -> str:
    import difflib

    return "".join(
        difflib.unified_diff(
            old.decode(errors="replace").splitlines(keepends=True),
            new.decode(errors="replace").splitlines(keepends=True),
            fromfile=f"{name}/PKGBUILD (upstream, as vendored)",
            tofile=f"{name}/PKGBUILD (upstream, now)",
        )
    )


def check(name: str, entry: dict, apply: bool) -> dict | None:
    """Look at one package. None when nothing moved."""
    upstream = entry.get("upstream")
    if not upstream:
        return None
    source = source_of(upstream)
    if not source:
        log(f"{name}: no reader for {upstream}; skipping")
        return {"name": name, "state": "unreadable"}
    kind, identifier = source

    pkgbuild = PACKAGES / name / "PKGBUILD"
    ours = pkgbuild.read_bytes()

    try:
        theirs = fetch(kind, identifier)
    except (urllib.error.URLError, ValueError, KeyError, TimeoutError) as exc:
        log(f"{name}: could not fetch upstream: {exc}")
        return {"name": name, "state": "failed", "error": str(exc)}

    base_path = BASES / f"{name}.PKGBUILD"
    if not base_path.exists():
        # without a base there is no three-way merge, and a two-way one
        # silently reverts our local edits
        log(f"{name}: no merge base at {base_path.relative_to(ROOT)}")
        return {"name": name, "state": "failed", "error": "no merge base"}

    base = base_path.read_bytes()
    if sha256(base) == sha256(theirs):
        return None

    log(f"{name}: upstream changed")
    merged, clean = merge(base, ours, theirs)
    diff = unified(base, theirs, name)

    if clean and apply:
        pkgbuild.write_bytes(merged)
        # base and vendored copy must always describe the same upstream
        # revision, or the next merge has the wrong base
        base_path.write_bytes(theirs)

    return {
        "name": name,
        "state": "changed" if clean else "conflicted",
        "kind": kind,
        "upstream": upstream,
        "diff": diff,
    }


def body_for(result: dict) -> str:
    if result["state"] == "changed":
        verdict = (
            "Merged cleanly onto our copy: upstream touched no line we edit.\n"
            "Check the result still builds before merging."
        )
    else:
        verdict = (
            "**Conflicts.** Upstream changed a line we deliberately edit, so\n"
            "nothing was written - `packages/" + result["name"] + "/PKGBUILD` is\n"
            "untouched. Reconcile by hand, then update\n"
            "`packages/.upstream/" + result["name"] + ".PKGBUILD` to the new\n"
            "upstream text so the next merge has the right base."
        )
    return (
        f"`{result['upstream']}` moved under our vendored copy.\n\n"
        f"{verdict}\n\n"
        f"```diff\n{result['diff']}```\n"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--apply", action="store_true", help="write the merged PKGBUILD and base"
    )
    parser.add_argument(
        "--report-dir",
        type=Path,
        help="write one markdown body per changed package here",
    )
    parser.add_argument("--only", help="check a single package directory")
    args = parser.parse_args()

    packages = yaml.safe_load(MANIFEST.read_text())["packages"]

    results = []
    for name in sorted(packages):
        if args.only and name != args.only:
            continue
        result = check(name, packages[name] or {}, args.apply)
        if result:
            results.append(result)

    if args.report_dir:
        args.report_dir.mkdir(parents=True, exist_ok=True)
        for result in results:
            if result["state"] in ("changed", "conflicted"):
                (args.report_dir / f"{result['name']}.md").write_text(body_for(result))

    summary = {
        "changed": [r["name"] for r in results if r["state"] == "changed"],
        "conflicted": [r["name"] for r in results if r["state"] == "conflicted"],
        "failed": [r["name"] for r in results if r["state"] in ("failed", "unreadable")],
    }
    print(json.dumps(summary))

    if summary["failed"]:
        return 2
    return 1 if summary["changed"] or summary["conflicted"] else 0


if __name__ == "__main__":
    sys.exit(main())
