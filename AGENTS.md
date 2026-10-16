# AGENTS.md

## Purpose

This file defines the canonical development instructions for the ACE repository.

ACE is a scientific atmospheric model with MATLAB and Fortran implementations. Some developers may not be familiar with Git, so AI assistants are expected to actively help maintain a safe, understandable, and reproducible development workflow.

These instructions apply to repository organization, code modification, scientific development, and AI-assisted development.

---

## 1. Git-assisted development

Some ACE developers may not be familiar with Git. AI assistants must therefore actively help maintain a safe and understandable Git workflow.

Before starting a new development task, the AI should, when repository access is available:

- check the current Git branch;
- check the working-tree status;
- report relevant uncommitted changes;
- identify whether the current work belongs on the existing branch;
- suggest creating a new branch when the work represents a new feature, experiment, refactor, migration, or substantial bug fix.

New development should normally use a dedicated branch rather than modifying `main` directly.

Suggested branch naming patterns include:

- `feature/...`
- `fix/...`
- `refactor/...`
- `test/...`
- `docs/...`
- `migration/...`

Examples:

- `feature/p3-interface`
- `fix/pressure-solver`
- `refactor/matlab-layout`
- `migration/matlab-v024`

The AI must NOT automatically create commits merely because a task is complete.

After completing a logical unit of work, the AI should:

- summarize what changed;
- suggest whether the current state is suitable for a commit;
- propose a concise commit message when useful;
- ask the developer whether they want to commit.

The developer decides whether and when to commit.

---

## 2. Potentially destructive Git operations

Potentially destructive or history-rewriting Git operations must never be performed without explicit developer approval.

This includes, but is not limited to:

- `git reset --hard`
- `git clean -fd`
- `git push --force`
- `git push --force-with-lease`
- destructive `git restore`
- destructive `git checkout -- <file>`
- deleting branches
- rebasing shared history
- rewriting commits
- removing untracked files that may contain work

Before recommending or performing such an operation, the AI must explain:

1. what the command will change;
2. what work may be lost or rewritten;
3. whether the operation affects only local history or also shared remote history;
4. whether a safer alternative exists.

When uncertain, preserve existing work.

---

## 3. Do not use filenames as version control

Do not create new active source files solely to represent development versions using suffixes such as:

- `_v24`
- `_new`
- `_latest`
- `_final`
- `_final2`
- `_backup`

Active source files should use stable names.

Development history should be managed using:

- Git commits;
- branches;
- tags;
- documented releases.

Historical snapshots may legitimately contain version numbers in filenames. Do not rename, delete, or consolidate historical snapshot files until their lineage has been explicitly reviewed.

---

## 4. Separate repository cleanup from scientific changes

Whenever possible, keep the following types of changes separate:

- formatting;
- comments and documentation;
- file movement;
- file renaming;
- directory restructuring;
- refactoring;
- bug fixes affecting model behavior;
- numerical algorithm changes;
- physical parameterization changes;
- changes in constants or configuration.

Repository cleanup and scientific changes should not be mixed into one large modification.

A preferred development sequence is:

1. inspect;
2. document;
3. make structural or organizational changes;
4. verify that behavior is preserved;
5. make scientific changes separately;
6. test again.

This separation improves reviewability, debugging, reproducibility, and Git history.

---

## 5. Scientific-code caution

ACE is scientific numerical software. AI assistants must not assume that apparently small code differences are scientifically insignificant.

When reviewing or modifying code, explicitly consider changes involving:

- governing equations;
- numerical discretization;
- advection;
- diffusion;
- pressure solvers;
- time integration;
- physical constants;
- parameterizations;
- numerical precision;
- array ordering;
- grid definitions;
- boundary conditions;
- initialization;
- diagnostics;
- I/O behavior;
- compiler-dependent behavior.

A textual diff alone is not sufficient evidence that two implementations are scientifically equivalent.

If the scientific significance of a difference is uncertain, report the difference and ask for developer review rather than silently resolving it.

Do not redesign, modernize, optimize, or simplify scientific algorithms unless explicitly requested.

---

## 6. MATLAB and Fortran implementations

The MATLAB and Fortran implementations are related but must not be assumed to be completely identical.

The general development roles are:

- MATLAB: primary reference implementation for dynamics development and testing.
- Fortran: high-performance implementation that may include additional physical parameterizations and production-oriented functionality.

Shared model components should eventually be validated across both implementations.

Examples of components that may require cross-implementation consistency include:

- dynamics;
- grid definitions;
- pressure solvers;
- time integration;
- thermodynamic calculations;
- shared numerical operators.

Some physics may exist only in the Fortran implementation. This is acceptable and should be documented rather than artificially duplicated.

Do not force one-to-one correspondence between MATLAB and Fortran files when the model architecture does not justify it.

---

## 7. Historical code and repository migration

The ACE repository may contain or receive historical MATLAB and Fortran snapshots.

Historical code should be treated as evidence of model development history.

Before deleting, merging, renaming, or consolidating historical code:

1. identify the apparent version;
2. compare it with adjacent versions;
3. document relevant differences;
4. distinguish scientific changes from structural changes;
5. identify uncertainties;
6. obtain developer confirmation before destructive cleanup.

Do not assume that version numbers imply a strictly linear history.

During migration or repository archaeology, preservation and traceability take priority over cosmetic cleanup.

---

## 8. Large changes require review

Before performing any large-scale change, the AI must first summarize the proposed work and obtain developer confirmation.

This includes:

- large refactors;
- directory restructuring;
- mass renaming;
- moving many files;
- deleting duplicated code;
- changing public interfaces;
- replacing numerical methods;
- changing model configuration conventions;
- broad formatting changes across the repository.

The preferred workflow is:

1. inspect the relevant code;
2. summarize findings;
3. propose a small, reviewable change;
4. explain expected impact;
5. obtain confirmation;
6. implement the change;
7. run available checks;
8. summarize the resulting diff.

Avoid large autonomous rewrites.

---

## 9. Commit guidance

The AI may recommend commits but must not assume permission to commit.

A commit should normally represent one logical operation.

Good examples:

- `matlab: import historical v0.24 snapshot`
- `fortran: port pressure solver changes`
- `tests: add dry-bubble regression case`
- `docs: document MATLAB-Fortran component mapping`
- `refactor: reorganize thermodynamic utilities`

Avoid vague commit messages such as:

- `update`
- `fix`
- `new version`
- `latest code`
- `changes`

When multiple unrelated changes exist, recommend separating them before committing.

---

## 10. Language

Communication with developers must use only:

- English;
- Traditional Chinese / 正體中文 / 繁體中文;
- or a mixture of English and Traditional Chinese.

Do not use other languages unless the developer explicitly requests them.

Technical terms may remain in English when that is clearer or conventional.

---

## 11. End-of-conversation development summary

At the end of every development-related conversation, provide a concise summary with the following structure.

### Current work summary

Provide exactly three important points covering the current development work. These may include:

1. work completed or analyzed;
2. current technical state, findings, or unresolved issues;
3. decisions, constraints, or important implementation details established during the conversation.

### Next direction

Provide one recommended next development direction.

### Git status

When repository access or reliable Git-state information is available, also report:

- current branch;
- relevant modified files;
- whether the current work has been committed.

If Git status is unavailable, do not invent it.

---

## 12. General AI behavior for ACE development

AI assistants should:

- prefer small, reviewable steps;
- preserve traceability;
- explain assumptions;
- distinguish confirmed facts from hypotheses;
- avoid silently changing scientific intent;
- help developers use Git safely;
- suggest tests appropriate to the change;
- keep documentation synchronized with important architectural decisions.

When uncertain whether a change is organizational or scientific, treat it as potentially scientific until reviewed.

The goal is not merely to make the code cleaner. The goal is to make ACE development reproducible, understandable, scientifically trustworthy, and maintainable by multiple developers.

---

## 13. Basis data policy from v0.21 onward

The developer requires basis data for v0.21 and later to remain local-only.
Do not add, commit, upload or push basis payloads, including through Git LFS,
archives or byte-split parts. This includes shared NetCDF files containing
complete PMB/PMDv/PMD operators and their parts. Do not bypass ignore rules
with `git add -f` for these payloads.

Version only source code, conversion/materialization tools, documentation,
small provenance records and hashes needed to identify externally supplied
local data. Preserve local basis files. Removing an already tracked basis
from the current index does not remove earlier commits or server LFS objects.
Rewriting existing/shared history, replacing published tags, force-pushing,
or deleting server objects requires explicit separate developer authorization.
Historical pre-v0.21 basis lineage must remain preserved unless separately
authorized for cleanup.

### Large-basis clarification (developer decision)

The local-only rule also covers the 101-ACE KHN26 basis and shared NetCDF,
regardless of their v0.20 release lineage, as well as the 88-ACE basis and
shared NetCDF. Never track or upload these full payloads or byte-split parts
in ordinary Git or Git LFS. Preserve local runtime files and author data.
The developer explicitly retains historical small 4-, 7-, 8- and 11-ACE
basis lineage. Keep source, materializers, small provenance and hashes
versioned. Large payloads will be supplied separately on request; contact
information will be published later. Do not invent contact information.
