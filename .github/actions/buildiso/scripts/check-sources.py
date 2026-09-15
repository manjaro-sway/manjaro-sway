#!/usr/bin/env python3
"""Check that every source the action fetches is reachable and shaped right.

Three consecutive releases were broken by one-line faults in the fetch
steps - a stale URL, a clone landing in a differently-named directory, a
raw file that was really an HTML page. Each cost a full ISO build, about
twenty-five minutes per edition, to discover.

None of them needed a build to catch. This parses the fetch steps out of
action.yml and checks, in seconds:

- every clone resolves, and lands in the directory the next line enters
- every fetched file exists and looks like what the step does with it
- no source has drifted back to an unreachable host
- nothing the runner executes has CRLF line endings
- every mirror pacman falls back through still serves the repositories

It reads action.yml rather than repeating its URLs, so a source added
without a corresponding check is still covered.
"""

import argparse
import io
import re
import subprocess
import tarfile
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path

import yaml

# a clone, optionally with an explicit target directory
CLONE = re.compile(r"git clone[^\n]*?(https://\S+?\.git)[ \t]*([\w.-]*)")
# the pushd/cd that a clone is expected to be followed by
ENTER = re.compile(r"^\s*(?:pushd|cd)\s+([\w.-]+)", re.MULTILINE)
# a file fetched for its content rather than cloned. The url may sit behind
# any number of flags, and a wrapped command carries it on a continuation
# line, so match the whole command and pick the url out of it rather than
# requiring the two to be adjacent.
FETCH = re.compile(r"^[^#\n]*\b(?:curl|wget)\b(?:[^\n]*\\\n)*[^\n]*", re.MULTILINE)
URL = re.compile(r"https://\S+")

# what a fetched file must contain to be the thing the step thinks it is
EXPECTED = {
    "lsb-release": "DISTRIB_ID",
    "pacman-mirrors.conf": "/etc/pacman-mirrors.conf",
}


def log(msg: str) -> None:
    print(msg, file=sys.stderr, flush=True)


def steps(action: Path) -> str:
    """Every run block in the action, concatenated."""
    doc = yaml.safe_load(action.read_text())
    return "\n".join(s.get("run", "") for s in doc["runs"]["steps"])


def check_clones(body: str, workdir: str) -> list[str]:
    """Each clone must resolve and land where the following line looks."""
    problems = []
    for match in CLONE.finditer(body):
        url, target = match.group(1), match.group(2)
        landed = target or url.rsplit("/", 1)[1].removesuffix(".git")

        after = ENTER.search(body[match.end() : match.end() + 300])
        expected = after.group(1) if after else None
        if expected and expected != landed:
            problems.append(
                f"{url} lands in {landed}/ but the next line enters {expected}/"
            )

        done = subprocess.run(
            ["git", "ls-remote", "--exit-code", url, "HEAD"],
            capture_output=True,
            timeout=120,
            check=False,
        )
        if done.returncode != 0:
            problems.append(f"{url} is not reachable")
            continue
        log(f"  clone {url.rsplit('/', 1)[1]:44} -> {landed}/")
    return problems


def fetch(url: str, attempts: int = 3, binary: bool = False) -> str | bytes | None:
    """Fetch a url, tolerating the transient failures mirrors actually serve.

    archlinux.org answers a run of requests with an intermittent 502, so a
    single attempt reports a source as gone when it is merely flaking. Only
    a url that fails every attempt is treated as a real problem.
    """
    for attempt in range(attempts):
        try:
            with urllib.request.urlopen(url, timeout=60) as resp:
                payload = resp.read()
                return payload if binary else payload.decode("utf-8", "replace")
        except (urllib.error.URLError, OSError) as e:
            log(f"  retry {url} ({e})" if attempt + 1 < attempts else f"  gave up on {url} ({e})")
            if attempt + 1 < attempts:
                time.sleep(2 * (attempt + 1))
    return None


def check_fetches(body: str) -> list[str]:
    """Each fetched file must exist and contain what the step relies on."""
    problems = []
    seen = set()
    for command in FETCH.finditer(body):
        found = URL.search(command.group(0))
        if not found:
            # a curl or wget whose url is interpolated or on the next line
            continue
        url = found.group(0).rstrip("\\").rstrip()
        if "${" in url or "$(" in url or url in seen:
            # interpolated at build time; nothing static to check
            continue
        seen.add(url)
        payload = fetch(url)
        if payload is None:
            problems.append(f"{url} is not fetchable")
            continue

        name = url.rsplit("/", 1)[1]
        needle = EXPECTED.get(name)
        if needle and needle not in payload:
            # this is how a /-/tree/ url served html for a config file
            problems.append(f"{url} does not look like {name}: no {needle!r}")
            continue
        log(f"  fetch {name:44} -> {len(payload)} bytes")
    return problems


# the mirrors the keyring resolver falls back through, as declared there
REPO = re.compile(r'^\s+"(?:\$\{BUILD_MIRROR:-)?(https://[^"$]+?)(?:\})?(?:/\$\{BRANCH[^"]*)?"', re.MULTILINE)


def check_keyring_repos(script: Path, branch: str = "stable") -> list[str]:
    """Every mirror the keyring resolver falls back through must serve it.

    The keyring used to come from archlinux.org's packages page, which is
    an HTML redirector and answered 502 for one request in three. It now
    comes from a repository database on a real mirror, so that database is
    what has to be checked - and a fallback nobody exercises is no
    fallback at all.
    """
    problems = []
    for match in REPO.finditer(script.read_text()):
        base = match.group(1).rstrip("/")
        db = f"{base}/{branch}/core/x86_64/core.db" if "manjaro" in base else f"{base}/core.db"

        payload = fetch(db, binary=True)
        if payload is None:
            problems.append(f"{db} is not fetchable")
            continue
        try:
            with tarfile.open(fileobj=io.BytesIO(payload), mode="r:gz") as db_tar:
                names = db_tar.getnames()
        except (tarfile.TarError, OSError) as e:
            problems.append(f"{db} is not a readable package database: {e}")
            continue
        if not any(n.startswith("archlinux-keyring-") for n in names):
            problems.append(f"{db} carries no archlinux-keyring")
            continue
        log(f"  keyring {base.split('/')[2]:42} -> core.db, {len(names)} entries")
    return problems


def check_build_mirrors(action: Path, branch: str = "stable") -> list[str]:
    """Every mirror pacman falls back through must serve the repositories.

    A mirror that has stopped syncing, or moved, is worse than no fallback
    at all: the failover finds it, the download fails anyway, and the
    build is no better off for the wait.
    """
    problems = []
    doc = yaml.safe_load(action.read_text())
    inputs = doc["inputs"]
    mirrors = [inputs["build-mirror"]["default"], *inputs["fallback-mirrors"]["default"].split()]

    for mirror in mirrors:
        db = f"{mirror.rstrip('/')}/{branch}/core/x86_64/core.db"
        payload = fetch(db, binary=True)
        if payload is None:
            problems.append(f"{db} is not fetchable")
            continue
        try:
            with tarfile.open(fileobj=io.BytesIO(payload), mode="r:gz") as db_tar:
                entries = len(db_tar.getnames())
        except (tarfile.TarError, OSError) as e:
            problems.append(f"{db} is not a readable package database: {e}")
            continue
        log(f"  mirror {mirror.split('/')[2]:43} -> core.db, {entries} entries")
    return problems


def check_line_endings(action: Path) -> list[str]:
    """No CRLF anywhere the runner executes.

    Bash refuses a script with CRLF line endings, and the message names
    the shell rather than the endings - cryptic, and a quarter of an hour
    into a build. .gitattributes keeps them out of the repository; this
    catches a file that arrived some other way.
    """
    problems = []
    for path in [action, *sorted(action.parent.glob("scripts/*.sh"))]:
        if b"\r\n" in path.read_bytes():
            problems.append(f"{path} has CRLF line endings; bash will not run it")
            continue
        log(f"  endings {path.name:42} -> lf")
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--action", default="action.yml", type=Path)
    args = parser.parse_args()

    body = steps(args.action)
    with tempfile.TemporaryDirectory() as workdir:
        problems = (
            check_clones(body, workdir)
            + check_fetches(body)
            + check_line_endings(args.action)
            + check_keyring_repos(args.action.parent / "scripts/install-archlinux-keyring.sh")
            + check_build_mirrors(args.action)
        )

    if problems:
        log("")
        for problem in problems:
            log(f"  {problem}")
        log(f"\n{len(problems)} problem(s)")
        return 1

    log("\nevery source resolves and is shaped as the steps expect")
    return 0


if __name__ == "__main__":
    sys.exit(main())
