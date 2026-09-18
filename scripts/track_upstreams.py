#!/usr/bin/env python3
"""Report, and optionally apply, upstream changes to the vendored PKGBUILDs.

Upstream is not a build input: an AUR PKGBUILD can be force-pushed and a
GitHub one can be rewritten between two builds of the same version, so ours
are copies. That makes them frozen unless something looks, which is what
this does.

Three kinds of upstream, one mechanism:

  - aur.archlinux.org, read through cgit's plain view.
  - github.com, read through the contents API. One file, not a clone: the
    cost is the same as the AUR fetch, so there is no reason to treat these
    differently. (An earlier version skipped them on the assumption that
    checking meant cloning. It does not.)
  - code.manjaro.org, read through the same contents API - it runs Gitea -
    for the files under iso-profiles/shared/. Those are vendored from
    Manjaro's own profile and drift the same way a PKGBUILD does, except
    that nothing here rebuilds from them, so drift is invisible until an
    ISO behaves oddly. gitlab.manjaro.org, where they used to live, is
    gone.

Several vendored copies carry deliberate local edits - `arch=` narrowed to
this repository's single architecture, `nano` added to the live package
list - so an update is never a blind overwrite. A pristine copy of the
upstream text each was made from sits beside it, and that file is the merge
base: with it, an upstream change to a line we never touched applies
cleanly, and one to a line we did touch conflicts loudly. Without it the
"merge" is an overwrite that reverts our edits and reports success.

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

# The iso-profiles half. One manifest naming the upstream repository once,
# rather than a URL per file: the files are a tree, and repeating the
# remote twenty-two times invites the two halves to disagree.
PROFILES = ROOT / "iso-profiles"
PROFILES_MANIFEST = PROFILES / "upstream.yml"
PROFILES_BASES = PROFILES / ".upstream"

AUR_HOST = "https://aur.archlinux.org/"
AUR_PLAIN = "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h={name}"
GITHUB_HOST = "https://github.com/"
GITHUB_API = "https://api.github.com/repos/{repo}/contents/PKGBUILD"
# Gitea's contents API, same shape as GitHub's. code.manjaro.org replaced
# gitlab.manjaro.org, which no longer resolves.
GITEA_API = "{host}/api/v1/repos/{repo}/contents/{path}?ref={ref}"

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
        return "aur", upstream[len(AUR_HOST) :].removesuffix(".git")
    if upstream.startswith(GITHUB_HOST):
        return "github", upstream[len(GITHUB_HOST) :].removesuffix(".git")
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


def fetch_profile_file(remote: dict, path: str) -> bytes:
    """One file out of the upstream iso-profiles tree.

    No content check of the kind fetch() does for a PKGBUILD: these files
    have no shared marker - a sudoers line, an empty localtime placeholder
    and a package list have nothing in common - so there is nothing
    honest to assert. Gitea returns JSON with base64 content or an error
    status, and both are already distinguishable without guessing at the
    body.
    """
    payload = json.loads(
        request(
            GITEA_API.format(
                host=remote["host"].rstrip("/"),
                repo=remote["repo"],
                path=path,
                ref=remote.get("ref", "master"),
            )
        )
    )
    if payload.get("type") != "file":
        raise ValueError(f"{path}: upstream entry is not a file")
    content = payload.get("content")
    if content is None:
        raise ValueError(f"{path}: upstream returned no content")
    return base64.b64decode(content)


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
            [
                "git",
                "merge-file",
                "-L",
                "ours",
                "-L",
                "vendored",
                "-L",
                "upstream",
                "-p",
                str(paths["ours"]),
                str(paths["base"]),
                str(paths["theirs"]),
            ],
            capture_output=True,
        )
        # exit >0 is the number of conflicts; <0 is an error
        return result.stdout, result.returncode == 0


def unified(old: bytes, new: bytes, label: str) -> str:
    import difflib

    return "".join(
        difflib.unified_diff(
            old.decode(errors="replace").splitlines(keepends=True),
            new.decode(errors="replace").splitlines(keepends=True),
            fromfile=f"{label} (upstream, as vendored)",
            tofile=f"{label} (upstream, now)",
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
    diff = unified(base, theirs, f"{name}/PKGBUILD")

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


def check_profile(path: str, remote: dict, apply: bool) -> dict | None:
    """Look at one vendored iso-profiles file. None when nothing moved.

    Same three-way merge as a PKGBUILD, because the reason is the same:
    shared/Packages-Live carries `nano`, which upstream has never had, and
    a two-way overwrite would drop it while reporting success.
    """
    ours_path = PROFILES / path
    if not ours_path.exists():
        log(f"{path}: vendored copy is missing")
        return {"name": path, "state": "failed", "error": "no vendored copy"}

    try:
        theirs = fetch_profile_file(remote, path)
    except (urllib.error.URLError, ValueError, KeyError, TimeoutError) as exc:
        log(f"{path}: could not fetch upstream: {exc}")
        return {"name": path, "state": "failed", "error": str(exc)}

    base_path = PROFILES_BASES / path
    if not base_path.exists():
        log(f"{path}: no merge base at {base_path.relative_to(ROOT)}")
        return {"name": path, "state": "failed", "error": "no merge base"}

    base = base_path.read_bytes()
    if sha256(base) == sha256(theirs):
        return None

    log(f"{path}: upstream changed")
    ours = ours_path.read_bytes()
    merged, clean = merge(base, ours, theirs)
    diff = unified(base, theirs, path)

    if clean and apply:
        ours_path.write_bytes(merged)
        base_path.write_bytes(theirs)

    return {
        "name": path,
        "state": "changed" if clean else "conflicted",
        "kind": "iso-profiles",
        "upstream": f"{remote['host'].rstrip('/')}/{remote['repo']} {path}",
        "diff": diff,
    }


def slug(name: str) -> str:
    """A filename for a report about `name`.

    A package name is already one. An iso-profiles name is a path, and
    `shared/Packages-Live.md` would mean a directory that does not exist -
    which is exactly how this failed the first time it ran against a
    profile file.
    """
    return name.replace("/", "__")


def paths_for(result: dict) -> tuple[str, str]:
    """(vendored copy, merge base) as repository-relative paths."""
    if result.get("kind") == "iso-profiles":
        return f"iso-profiles/{result['name']}", f"iso-profiles/.upstream/{result['name']}"
    return (
        f"packages/{result['name']}/PKGBUILD",
        f"packages/.upstream/{result['name']}.PKGBUILD",
    )


def body_for(result: dict) -> str:
    ours, base = paths_for(result)
    if result["state"] == "changed":
        verdict = (
            "Merged cleanly onto our copy: upstream touched no line we edit.\n"
            "Check the result still builds before merging."
        )
    else:
        verdict = (
            "**Conflicts.** Upstream changed a line we deliberately edit, so\n"
            "nothing was written - `" + ours + "` is\n"
            "untouched. Reconcile by hand, then update\n"
            "`" + base + "` to the new\n"
            "upstream text so the next merge has the right base."
        )
    return (
        f"`{result['upstream']}` moved under our vendored copy.\n\n"
        f"{verdict}\n\n"
        f"```diff\n{result['diff']}```\n"
    )


def seed_profile_bases(profiles: dict) -> int:
    """Write a merge base for every tracked iso-profiles file.

    Run once, when a file starts being tracked. Seeding is only safe while
    the vendored copy and upstream agree, or while the difference is a
    local edit someone has decided to keep: the base records what upstream
    said, and a wrong base makes the next merge either drop our edit or
    conflict on a line nobody touched. It refuses to overwrite a base that
    already exists, because doing so would silently discard the history of
    the copy it describes.
    """
    remote = profiles.get("remote")
    if not remote:
        log("no remote in the iso-profiles manifest")
        return 2

    failed = []
    for path in sorted(profiles.get("files", [])):
        base_path = PROFILES_BASES / path
        if base_path.exists():
            log(f"{path}: base exists; leaving it alone")
            continue
        try:
            theirs = fetch_profile_file(remote, path)
        except (urllib.error.URLError, ValueError, KeyError, TimeoutError) as exc:
            log(f"{path}: could not fetch upstream: {exc}")
            failed.append(path)
            continue
        base_path.parent.mkdir(parents=True, exist_ok=True)
        base_path.write_bytes(theirs)
        ours = (PROFILES / path).read_bytes() if (PROFILES / path).exists() else b""
        note = "identical" if ours == theirs else "LOCAL EDIT preserved"
        log(f"{path}: seeded ({note})")

    print(json.dumps({"seeded": True, "failed": failed}))
    return 2 if failed else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="write the merged PKGBUILD and base")
    parser.add_argument(
        "--report-dir",
        type=Path,
        help="write one markdown body per changed package here",
    )
    parser.add_argument("--only", help="check a single package directory")
    parser.add_argument(
        "--seed-profile-bases",
        action="store_true",
        help="write iso-profiles merge bases from upstream and exit",
    )
    args = parser.parse_args()

    profiles = {}
    if PROFILES_MANIFEST.exists():
        profiles = yaml.safe_load(PROFILES_MANIFEST.read_text()) or {}

    if args.seed_profile_bases:
        return seed_profile_bases(profiles)

    packages = yaml.safe_load(MANIFEST.read_text())["packages"]

    results = []
    for name in sorted(packages):
        if args.only and name != args.only:
            continue
        result = check(name, packages[name] or {}, args.apply)
        if result:
            results.append(result)

    remote = profiles.get("remote")
    for path in sorted(profiles.get("files", [])):
        if args.only and path != args.only:
            continue
        result = check_profile(path, remote, args.apply)
        if result:
            results.append(result)

    if args.report_dir:
        args.report_dir.mkdir(parents=True, exist_ok=True)
        for result in results:
            if result["state"] in ("changed", "conflicted"):
                # an iso-profiles name is a path, so it cannot be a filename
                # as-is; the workflow reads the item back out of the report
                (args.report_dir / f"{slug(result['name'])}.md").write_text(body_for(result))

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
