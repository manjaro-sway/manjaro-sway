#!/usr/bin/env python3
"""Upload a built image and its checksum to the release bucket.

Version-prefixed, so an older image stays fetchable while a newer one
publishes, and `latest/` is repointed only once the versioned copy is
complete - a download that starts mid-upload would otherwise get a truncated
image that still checksums as whatever arrived.
"""

import argparse
import glob
import os
import re
import sys

import boto3
from botocore.config import Config


def log(message: str) -> None:
    print(message, file=sys.stderr, flush=True)


def s3_client():
    # R2 copies an object server-side, and a 1.7 GB image takes minutes -
    # well past botocore's 60s default, which failed the build after a
    # successful upload with "Read timeout on .../latest/manjaro-sway.iso".
    # The copy itself had started; only the client gave up waiting.
    return boto3.client(
        "s3",
        endpoint_url=os.environ["R2_ENDPOINT"],
        aws_access_key_id=os.environ["R2_ACCESS_KEY_ID"],
        aws_secret_access_key=os.environ["R2_SECRET_ACCESS_KEY"],
        region_name="auto",
        config=Config(read_timeout=900, connect_timeout=60, retries={"max_attempts": 3}),
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--iso-dir", required=True)
    parser.add_argument("--version", required=True)
    args = parser.parse_args()

    # (glob, content type, the latest/ alias it repoints)
    ARTEFACTS = (("*.iso", "application/x-iso9660-image", "latest/manjaro-sway.iso"),)

    # SHA256SUMS sits beside the image and must not be uploaded as one:
    # that would repoint latest/ at a text file. It is handled below.
    found = [
        (path, content_type, alias)
        for pattern, content_type, alias in ARTEFACTS
        for path in sorted(glob.glob(os.path.join(args.iso_dir, pattern)))
        if not os.path.basename(path).startswith("SHA256SUMS")
    ]
    if not found:
        log("nothing to upload")
        return 1

    bucket = os.environ["R2_BUCKET"]
    s3 = s3_client()

    for path, content_type, _ in found:
        name = os.path.basename(path)
        key = f"{args.version}/{name}"
        extra = {"ContentType": content_type}
        if name.endswith(".iso"):
            # Stored on the object, not added by the worker: the download
            # link now redirects to the bucket's own hostname, which serves
            # whatever metadata the object carries and knows nothing about
            # our handlers. Without it a browser saves the image under the
            # last path segment or its own guess rather than the name the
            # checksum file refers to.
            extra["ContentDisposition"] = f'attachment; filename="{name}"'
        s3.upload_file(path, bucket, key, ExtraArgs=extra)
        log(f"uploaded {key} ({os.path.getsize(path)} bytes)")

    # Matched by prefix rather than named: the checksum that proves the
    # image has to travel with it, and a silently skipped one is worse
    # than a missing image.
    checksums = sorted(glob.glob(os.path.join(args.iso_dir, "SHA256SUMS*")))
    if not checksums:
        raise SystemExit("no SHA256SUMS beside the artefact")
    for path in checksums:
        name = os.path.basename(path)
        s3.upload_file(
            path,
            bucket,
            f"{args.version}/{name}",
            ExtraArgs={"ContentType": "text/plain"},
        )
        log(f"uploaded {args.version}/{name}")

    # Last, and a pointer rather than a copy of the image. This used to be
    # a server-side copy: 1.7 GB duplicated per release, and worse than
    # wasteful. `latest/` is repointed every release, so a client resuming
    # a download across one asked for a byte range of an object that had
    # been replaced underneath it - serve.js honours If-Range to refuse
    # exactly that, and the refusal is a restarted download either way.
    #
    # The pointer holds the version string and nothing else. The worker
    # reads it and answers 302 to the versioned object, which is immutable,
    # so a resume targets a URL that cannot change under it. It also means
    # this key never needs pruning: it is the same dozen bytes forever.
    for path, _, alias in found:
        name = os.path.basename(path)
        s3.put_object(
            Bucket=bucket,
            Key=alias,
            Body=args.version.encode(),
            ContentType="text/plain",
            # the pointer changes every release and is tiny; a cache that
            # held it would pin the whole site to an old image
            CacheControl="no-cache",
        )
        log(f"{alias} -> {args.version}/{name}")

    prune_old_versions(s3, bucket, keep=5)

    return 0


def prune_old_versions(s3, bucket: str, keep: int) -> None:
    """Delete all but the newest `keep` release prefixes.

    Nothing removed these before, and a weekly build publishes an image a
    week. Versions are YYYYMMDDHHmm, so lexical order is chronological and
    the newest `keep` are simply the tail.

    Whole prefixes, not just the images: a version's checksum and
    signature are worthless once its image is gone, and leaving them
    behind is how a bucket accumulates files nothing references.

    `latest/` is never a candidate - it is not a version prefix, and it
    points at the newest release, which is by definition kept.
    """
    versions = set()
    paginator = s3.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=bucket, Delimiter="/"):
        for prefix in page.get("CommonPrefixes", []):
            name = prefix["Prefix"].rstrip("/")
            # a release prefix and nothing else: latest/, screenshots and
            # anything added later must not be swept up by this
            if re.fullmatch(r"\d{12}", name):
                versions.add(name)

    doomed = sorted(versions)[:-keep] if len(versions) > keep else []
    if not doomed:
        log(f"{len(versions)} release(s) in the bucket; nothing to prune")
        return

    for version in doomed:
        for page in paginator.paginate(Bucket=bucket, Prefix=f"{version}/"):
            for obj in page.get("Contents", []):
                s3.delete_object(Bucket=bucket, Key=obj["Key"])
                log(f"pruned {obj['Key']}")


if __name__ == "__main__":
    sys.exit(main())
