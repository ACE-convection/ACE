# Large basis data: local-only policy and GitHub LFS cleanup

## Policy and data access

The 101-ACE KHN26 and 88-ACE slab basis payloads must remain outside ordinary
Git and Git LFS. This includes full MAT files, shared NetCDF files embedding
PMB/PMDv/PMD operators, compressed copies and byte-split parts. The rule applies
regardless of release version. Local runtime and source data are retained.

Historical small 4-, 7-, 8- and 11-ACE basis lineage remains preserved,
including its existing Git/LFS representation. Source, converters, small
provenance records and hashes remain versioned.

Large data will be provided separately on request. Maintainer contact details
will be published later; no contact address has been assigned in this record.
Existing local files must be verified against their provenance/manifest before
use. `tools/input/materialize_v02187_inputs.py` reconstructs the 88-ACE inputs
from separately supplied local parts; it does not download them from Git LFS.

## Current Git status of the large payloads

The audit examined reachable Git blobs and LFS pointers through all ordinary
refs and registered worktree HEADs. Neither the known 101-/88-ACE full-payload
identities nor their known byte parts were reachable. No additional history
rewrite is needed for these payloads in the currently published branches/tags.
The earlier release reconstruction had already removed the new operator data.

The remaining large local LFS cache entries are the eleven 88-ACE byte-part
objects. Each is compared with the original distribution manifest and a retained
local part before deletion. Full local 88-ACE MAT/NetCDF files and the 101-ACE
shared input are also hash-verified. See [cleanup evidence](large_basis_cleanup.json)
for exact object identities, sizes, preservation checks and execution status.
This report does not claim that local cache removal deletes server objects.

`.gitignore` excludes these full files and parts. `.gitattributes` explicitly
disables the inherited LFS filter for their known paths and keeps provenance
JSON as ordinary text. Never bypass these rules with `git add -f` or restore
old large payload pointers from backup history. Git LFS remains enabled for
allowed historical small data; it is not uninstalled globally.

## Remove the old objects from GitHub through the website

Deleting a file in GitHub's repository browser, or force-pushing cleaned refs,
does not purge its LFS payload or free its LFS storage quota. GitHub's documented
options are to delete and recreate the repository, or contact GitHub Support
when the repository must be retained. Because ACE retains releases and allowed
small historical LFS objects, use the Support route.

1. Sign in to the GitHub account that owns/administers `ACE-convection/ACE`.
2. Open [GitHub Support](https://support.github.com/contact), select the relevant
   account/organization and repository, and describe the request as removal of
   orphaned Git LFS objects. The exact form labels depend on the account and plan.
3. Copy the request below and attach the small
   [OID inventory](large_basis_cleanup.json). Ask Support to verify whether each
   listed object exists for this repository and purge only the targeted large
   objects. The identities are known locally; server existence is not assumed.
4. Ask Support to preserve the repository, releases and all other LFS objects,
   especially the small historical bases. Ask them to confirm completion and
   any storage-accounting delay; check the account/organization's usage afterward.

Do not delete the repository or remove a billing data pack as a substitute for
this targeted request. Deleting/recreating a repository is a separate destructive
operation and has not been authorized or performed. No support ticket is sent
by this workflow; the repository owner must submit the request through the site.

Suggested request (English):

```text
Repository: https://github.com/ACE-convection/ACE

Please help verify and purge orphaned Git LFS objects associated with the large
101-ACE KHN26 and 88-ACE basis/operator inputs for this repository. These payloads
are now supplied outside Git/Git LFS. We have audited the current published
branches/tags: the known full payloads and byte parts are not referenced there.

The attached large_basis_cleanup.json lists exact SHA-256 OIDs and expected
sizes. Eleven 88-ACE part objects were present in the local LFS cache; additional
full-file hashes identify 101-/88-ACE inputs that may never have been uploaded.
Please check server existence and repository association before purging.

Please preserve this repository, its releases, and all other LFS objects,
including the historical small 4-/7-/8-/11-ACE bases and sounding inputs.
Do not delete/recreate the repository or purge all of its LFS storage.

Please confirm which listed objects were purged and when the released storage
will be reflected in the account's usage.
```

Official reference, checked 2026-10-15:
[Removing files from Git Large File Storage](https://docs.github.com/en/repositories/working-with-files/managing-large-files/removing-files-from-git-large-file-storage).

## What this cleanup does not change

Model source, numerical algorithms, small historical data and local full-size
runtime files are retained. Recovery bundles can contain old Git pointer blobs;
they are local-only backups and must never be mirrored or pushed wholesale.
GitHub can retain unreferenced server objects after refs are rewritten. Only a
confirmed server-side purge establishes deletion of those payloads there.
