# Merge bases

The pristine upstream text each vendored `shared/` file was copied from, as
fetched, before any of our edits. The tree mirrors `shared/` exactly, so a
base sits at the same path one level down.

They exist so `scripts/track_upstreams.py` can do a real three-way merge.
Without a base, "merging" an upstream change into our copy is just an
overwrite: `shared/Packages-Live` carries `nano`, which upstream has never
had, and a two-way merge would drop it while reporting success.

Nothing builds from these files - the ISO builds from `shared/` itself.
`track_upstreams.py --apply` refreshes a base only when it has merged that
file's change into `shared/`, so base and vendored copy always describe the
same upstream revision.

Seeded once with `--seed-profile-bases`, which refuses to overwrite a base
that already exists: rewriting one would silently discard the history of
the copy it describes, and the next merge would either drop a local edit or
conflict on a line nobody touched.
