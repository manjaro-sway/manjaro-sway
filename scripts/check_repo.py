#!/usr/bin/env python3
"""Verify that a published architecture tree actually resolves.

A publish that half-succeeded leaves a database naming packages that are not
there, or packages no database names. Both install cleanly for whoever
already has them cached and fail for everyone else, so the invariants a
pacman client depends on are checked here rather than discovered by a user:

  - every entry in the database names a file that exists, at the size the
    database records
  - every published package appears in the database
  - the databases are signed, and so is every package
  - .db and .files agree on their contents
"""

import argparse
import io
import os
import re
import sys
import tarfile

import boto3
from botocore.exceptions import ClientError

DB_NAME = "manjaro-sway"

PKG_SUFFIXES = (".pkg.tar.zst",)

# a database entry records its own filename and size; both must match
FIELD = re.compile(r"%([A-Z0-9]+)%\n([^\n]*)")


def log(message: str) -> None:
    print(message, file=sys.stderr, flush=True)


def s3_client():
    return boto3.client(
        "s3",
        endpoint_url=os.environ["R2_ENDPOINT"],
        aws_access_key_id=os.environ["R2_ACCESS_KEY_ID"],
        aws_secret_access_key=os.environ["R2_SECRET_ACCESS_KEY"],
        region_name="auto",
    )


def fetch(s3, bucket: str, key: str) -> bytes | None:
    try:
        return s3.get_object(Bucket=bucket, Key=key)["Body"].read()
    except ClientError as exc:
        if exc.response["Error"]["Code"] in ("NoSuchKey", "404"):
            return None
        raise


def db_entries(payload: bytes) -> dict[str, dict[str, str]]:
    """Parse a pacman database into {pkgname-pkgver-pkgrel: fields}."""
    entries = {}
    with tarfile.open(fileobj=io.BytesIO(payload), mode="r:gz") as tar:
        for member in tar.getmembers():
            if not member.name.endswith("/desc"):
                continue
            handle = tar.extractfile(member)
            if handle is None:
                continue
            entries[member.name.removesuffix("/desc")] = dict(
                FIELD.findall(handle.read().decode())
            )
    return entries


def objects(s3, bucket: str, prefix: str) -> dict[str, int]:
    """Every object under a prefix, mapped to its size."""
    found = {}
    paginator = s3.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        for obj in page.get("Contents", []):
            found[obj["Key"].removeprefix(prefix)] = obj["Size"]
    return found


def check_arch(s3, bucket: str, arch: str) -> list[str]:
    """Every inconsistency found in one architecture tree."""
    prefix = f"{arch}/"
    problems = []

    present = objects(s3, bucket, prefix)
    if not present:
        # an empty tree is legitimate before the first publish
        return []

    payload = fetch(s3, bucket, f"{prefix}{DB_NAME}.db.tar.gz")
    if payload is None:
        return [f"{arch}: packages are present but there is no database"]
    entries = db_entries(payload)

    for suffix in (".db.tar.gz", ".files.tar.gz"):
        if f"{DB_NAME}{suffix}.sig" not in present:
            problems.append(f"{arch}: {DB_NAME}{suffix} is unsigned")

    listed = set()
    for name, fields in sorted(entries.items()):
        filename = fields.get("FILENAME")
        if not filename:
            problems.append(f"{arch}: {name} has no %FILENAME%")
            continue
        listed.add(filename)
        if filename not in present:
            problems.append(f"{arch}: {name} names a missing file")
            continue
        recorded = fields.get("CSIZE")
        if recorded and int(recorded) != present[filename]:
            problems.append(
                f"{arch}: {filename} is {present[filename]} bytes,"
                f" the database says {recorded}"
            )
        if f"{filename}.sig" not in present:
            problems.append(f"{arch}: {filename} has no signature")

    # a package nobody can install is as broken as a missing one
    for name in sorted(present):
        if name.endswith(PKG_SUFFIXES) and name not in listed:
            problems.append(f"{arch}: {name} is published but absent from the database")

    files_payload = fetch(s3, bucket, f"{prefix}{DB_NAME}.files.tar.gz")
    if files_payload is None:
        problems.append(f"{arch}: no .files database")
    else:
        files_entries = set(db_entries(files_payload))
        for missing in sorted(set(entries) - files_entries):
            problems.append(f"{arch}: {missing} is absent from .files")
        for extra in sorted(files_entries - set(entries)):
            problems.append(f"{arch}: {extra} is in .files but not in .db")

    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--arch", help="check one tree rather than every one")
    args = parser.parse_args()

    bucket = os.environ["R2_BUCKET"]
    s3 = s3_client()

    arches = [args.arch] if args.arch else ["x86_64"]
    problems = []
    for arch in arches:
        problems.extend(check_arch(s3, bucket, arch))

    if problems:
        for problem in problems:
            log(problem)
        return 1

    log(f"{', '.join(arches)}: consistent")
    return 0


if __name__ == "__main__":
    sys.exit(main())
