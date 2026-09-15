#!/usr/bin/env python3
"""Publish built packages into an architecture's repository tree on R2.

The bucket holds one tree per architecture:

    x86_64/manjaro-sway.db.tar.gz + the packages it indexes

Order matters. Packages and their signatures upload first, the database
last, so a client that fetches the database mid-publish never sees an entry
whose package is not there yet.

`arch=any` packages are built once and registered in both databases -
pacman accepts an `any` package from either tree. The workflow hands the
same artifacts to both architecture legs rather than this script writing
two trees in one run, so a failure in one leg cannot leave the other's
database referencing packages it never uploaded.
"""

import argparse
import glob
import hashlib
import os
import subprocess
import tarfile
import sys

import boto3
from boto3.s3.transfer import TransferConfig
from botocore.exceptions import ClientError

DB_NAME = "manjaro-sway"
# repo-add writes .db and .files as symlinks to the .tar.gz; both names are
# published because pacman fetches the short one and tooling reads the long
DB_SUFFIXES = (".db", ".db.tar.gz", ".files", ".files.tar.gz")


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


# Never multipart. boto3 switches to it above 8 MiB by default, and a
# multipart ETag is a digest of digests rather than the object's MD5 - so
# refuse_overwrite has nothing to compare and falls back to a size check
# alone. That silently disabled the guard for exactly the packages where a
# rewrite hurts most: zen-browser-bin (139 MiB) and mise-bin (35 MiB) are
# both over the threshold today. One PUT per object keeps the ETag an MD5
# at every size.
#
# 4 GiB is R2's documented single-PUT ceiling; the largest package here is
# 139 MiB, so nothing approaches it. A package that ever did would fail
# loudly on upload rather than quietly lose the guard.
SINGLE_PUT_LIMIT = 4 * 1024**3
SINGLE_PART = TransferConfig(
    multipart_threshold=SINGLE_PUT_LIMIT, multipart_chunksize=SINGLE_PUT_LIMIT
)


PKG_SUFFIXES = (".pkg.tar.zst",)


def packages_in(directory: str) -> list[str]:
    return sorted(
        path
        for suffix in PKG_SUFFIXES
        for path in glob.glob(os.path.join(directory, f"*{suffix}"))
    )


def pkgname_of(filename: str) -> str:
    """The package name out of a filename.

    A filename is name-version-release-arch.pkg.tar.<ext>, and a name may
    hold hyphens, so strip the three known trailing fields rather than split.
    """
    stem = filename.removesuffix(".sig")
    for suffix in PKG_SUFFIXES:
        stem = stem.removesuffix(suffix)
    return stem.rsplit("-", 3)[0]


def download_databases(s3, bucket: str, prefix: str, pkg_dir: str) -> None:
    """Fetch the existing databases so repo-add extends rather than replaces them.

    Both must come down: repo-add updates whichever files it finds and
    creates the rest from scratch, so publishing with only .db present
    rebuilds .files from this build alone and drops every other package's
    file list.
    """
    for suffix in (".db.tar.gz", ".files.tar.gz"):
        name = f"{DB_NAME}{suffix}"
        local = os.path.join(pkg_dir, name)
        try:
            s3.download_file(bucket, prefix + name, local)
            log(f"downloaded existing {name}")
        except ClientError as exc:
            if exc.response["Error"]["Code"] not in ("NoSuchKey", "404"):
                raise
            log(f"no {name} yet; repo-add will create one")


def referenced_by(db_path: str) -> set[str]:
    """The package filenames the published database points readers at.

    Read before repo-add rewrites it. An object in the bucket that this
    set does not contain has never been handed to a client: nothing links
    it, so nothing has cached it, and replacing it cannot corrupt anything
    somebody holds.
    """
    names: set[str] = set()
    if not os.path.exists(db_path):
        return names
    with tarfile.open(db_path) as archive:
        for member in archive:
            if not member.name.endswith("/desc"):
                continue
            handle = archive.extractfile(member)
            if handle is None:
                continue
            body = handle.read().decode("utf-8", "replace").splitlines()
            if "%FILENAME%" in body:
                names.add(body[body.index("%FILENAME%") + 1].strip())
    return names


def prune_superseded(s3, bucket: str, prefix: str, published: list[str]) -> None:
    """Drop older versions of the packages just published.

    The database only ever references the current version, so an older
    object is unreachable; leaving it would grow the bucket without end.
    """
    keep = set(published)
    names = {pkgname_of(name) for name in published}

    paginator = s3.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        for obj in page.get("Contents", []):
            name = obj["Key"].removeprefix(prefix)
            if not name.endswith(PKG_SUFFIXES + tuple(s + ".sig" for s in PKG_SUFFIXES)):
                continue
            if name in keep or f"{name}.sig" in keep or name.removesuffix(".sig") in keep:
                continue
            if pkgname_of(name) in names:
                s3.delete_object(Bucket=bucket, Key=obj["Key"])
                log(f"pruned superseded {name}")


def refuse_overwrite(s3, bucket: str, key: str, local: str) -> None:
    """Stop before replacing a published package with different bytes.

    The worker serves a .pkg.tar.zst as `immutable, max-age=31536000`, and
    pacman fetches the package and its .sig as two objects against one
    database entry. So replacing the bytes behind a key that is already
    published is not a harmless re-upload: a reader mid-publish gets a
    package from one build and a signature from another, which surfaces as
    "signature is invalid" or "Maximum file size exceeded" and looks like a
    compromised key rather than a race. Both were seen on build-iso (#57).

    Identical bytes are fine - that is a re-run publishing what is already
    there, and uploading them changes nothing a reader can observe.

    This does not make a publish atomic. It refuses the one case that
    silently corrupts what readers hold, and it fails the build that would
    have done it, so a version that did not move is a loud error rather
    than a leaderboard of confusing symptoms elsewhere.
    """
    try:
        head = s3.head_object(Bucket=bucket, Key=key)
    except ClientError as exc:
        if exc.response["Error"]["Code"] in ("NoSuchKey", "404", "NotFound"):
            return
        raise

    def refuse(detail: str) -> None:
        raise SystemExit(
            f"{key} is already published with different content ({detail}).\n"
            "Publishing would replace an object readers cache as immutable, "
            "so a client fetching during the upload can get this package and "
            "another build's signature.\n"
            "Bump pkgrel so the new build gets a name of its own."
        )

    size = os.path.getsize(local)
    if head["ContentLength"] != size:
        refuse(f"{head['ContentLength']} bytes published, {size} built")

    # Same size is not the same bytes. For a single-part upload - which is
    # what upload_file does at these sizes - the ETag is the MD5 of the
    # object, so the comparison is exact. A multipart ETag carries a "-N"
    # suffix and is not an MD5 of the whole object; there is nothing to
    # compare then, and the size check above is all this can say.
    etag = head.get("ETag", "").strip('"')
    if "-" in etag or not etag:
        return

    digest = hashlib.md5(usedforsecurity=False)
    with open(local, "rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    if digest.hexdigest() != etag:
        refuse(f"md5 {etag} published, {digest.hexdigest()} built")


def publish(s3, bucket: str, arch: str, pkg_dir: str, packages: list[str], key: str | None) -> None:
    prefix = f"{arch}/"
    db_file = os.path.join(pkg_dir, f"{DB_NAME}.db.tar.gz")

    download_databases(s3, bucket, prefix, pkg_dir)
    # Read before repo-add rewrites it: these are the filenames the LIVE
    # database points readers at.
    live = referenced_by(db_file)

    # --include-sigs records each package's signature in the database, as
    # every Arch repository does: tooling expects the field, and pacman -Si
    # can then report a signer without fetching the package. --sign is
    # unrelated - it signs the database itself, without which the package
    # list is forgeable.
    repo_add = ["repo-add", "--include-sigs", db_file, *packages]
    if key:
        repo_add[1:1] = ["--sign", "--key", key]
    subprocess.run(repo_add, check=True)

    for package in packages:
        name = os.path.basename(package)
        # Only what the live database actually names. A previous run that
        # uploaded objects and then died before the database left them
        # orphaned - nothing links them, no client has ever been handed
        # one - and refusing to replace those made every retry fail on
        # whatever the last attempt got through, one package per run. The
        # guard exists for objects readers cache as immutable, which is
        # exactly the set the database references.
        if name in live:
            refuse_overwrite(s3, bucket, prefix + name, package)
        s3.upload_file(package, bucket, prefix + name, Config=SINGLE_PART)
        log(f"{arch}: uploaded {name}")
        signature = package + ".sig"
        if os.path.exists(signature):
            s3.upload_file(
                signature, bucket, prefix + os.path.basename(signature), Config=SINGLE_PART
            )

    # the database goes last: until it names them, the objects above are
    # simply unreferenced, and a client mid-publish sees the old repository
    for suffix in DB_SUFFIXES:
        for name in (f"{DB_NAME}{suffix}", f"{DB_NAME}{suffix}.sig"):
            local = os.path.join(pkg_dir, name)
            # repo-add writes .db/.files as symlinks; upload the real bytes
            real = os.path.realpath(local)
            if not os.path.exists(real):
                continue
            s3.upload_file(real, bucket, prefix + name, Config=SINGLE_PART)
            log(f"{arch}: uploaded {name}")

    # After the database, never before it. Pruning first deletes the object
    # the CURRENTLY PUBLISHED database still names, so for the whole length
    # of the upload loop above every client running `pacman -S` on that
    # package gets a 404 - on every single update, deterministically. Once
    # the new database is live nothing references the old version, and the
    # delete is unobservable.
    prune_superseded(s3, bucket, prefix, [os.path.basename(p) for p in packages])


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pkg-dir", required=True, help="directory of built packages")
    parser.add_argument("--arch", required=True, help="architecture tree to publish into")
    args = parser.parse_args()

    packages = packages_in(args.pkg_dir)
    if not packages:
        log("no packages to publish")
        return 1

    bucket = os.environ["R2_BUCKET"]
    key = os.environ.get("GPG_KEYID")
    s3 = s3_client()

    # a database left by an earlier run would be extended rather than
    # rebuilt from what this bucket actually holds
    for stale in glob.glob(os.path.join(args.pkg_dir, f"{DB_NAME}.*")):
        os.remove(stale)

    publish(s3, bucket, args.arch, args.pkg_dir, packages, key)

    log(f"published {len(packages)} package(s) to {args.arch}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
