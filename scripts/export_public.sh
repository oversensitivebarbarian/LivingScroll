#!/usr/bin/env bash
# Copies this repo's git-tracked files into a separate directory, excluding
# internal/ALL-CAPS directories and non-code planning artifacts that back this
# project's own AI-assisted development workflow but aren't needed to build,
# test, or contribute to the app. This repo itself is NEVER rewritten or
# force-pushed by this script — it only ever reads from the working tree and
# writes to <dest-dir>.
#
# Usage:
#   scripts/export_public.sh <dest-dir> [--init-git --author "Name <email>"]
#
#   <dest-dir>   Destination directory (created if absent; must be empty or
#                not exist). Anything already there is left untouched other
#                than the files this script writes.
#   --init-git   After copying, run `git init` + a single commit in <dest-dir>
#                (a FRESH history — nothing from this repo's own git log is
#                carried over; that's deliberate, see EXCLUDES below).
#   --author     Optional override: "Name <email>" used as the commit author,
#                set as LOCAL config in <dest-dir> only — your global git
#                identity is NEVER read or inherited, so a real name/email you
#                don't want tied to a pseudonymous public account can't leak
#                in by accident. Defaults to DEFAULT_AUTHOR_NAME / the decoded
#                DEFAULT_AUTHOR_EMAIL_B64 below (the "Oversensitive Barbarian"
#                pseudonym) when omitted.
#
# The default email is stored base64-encoded, decoded only at the moment it
# is written to git config, so the literal address never sits in this
# script's source as plaintext — this script itself ends up in the public
# export, and a plaintext `user@domain.tld` is exactly the pattern spam
# harvesters scrape public GitHub repos for. Not encryption (trivially
# reversible), just enough to defeat naive regex scraping.
#
# What is excluded and why:
#   - SPECS/ NAVIGATIONS/ LAYOUTS/ TASKS/ RESOURCES/  — internal ALL-CAPS
#     planning/reference directories (design specs, navigation specs, layout
#     specs, task notes, third-party reference material). RESOURCES/ also
#     contains copyrighted third-party PDFs and a broken/untracked gitlink —
#     excluding the whole directory (rather than filtering its contents) is
#     what keeps that out of the public copy without needing to rewrite this
#     repo's own git history.
#   - CLAUDE.md, claude.session, .claude/  — instructions/state for this
#     project's AI coding assistant, not app documentation.
#   - .idea/, *.iml  — IDE project files.
#   - .gitea/        — internal CI, superseded by .github/workflows.
#   - docs/BUILD_MACHINE.md, docs/scene_map_widget.md — internal notes (an
#     obsolete self-hosted build-machine writeup and a disabled-feature note);
#     the rest of docs/ (CI_SETUP.md) stays public.
#   - The .gitignore's own `/RESOURCES/npc-generator-live/` entry (+ its
#     explanatory comment) — dead weight in the public copy since RESOURCES/
#     itself is never copied there; stripped by post-processing below rather
#     than excluded wholesale (every other line in .gitignore is copied as-is).
#
# Everything else that's git-tracked — including README.md, LICENSE,
# CONTRIBUTING.md, and docs/CI_SETUP.md — is copied as-is.
set -euo pipefail

DEFAULT_AUTHOR_NAME='Oversensitive Barbarian'
DEFAULT_AUTHOR_EMAIL_B64='b3ZlcnNlbnNpdGl2ZWJhcmJhcmlhbkBnbWFpbC5jb20='

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <dest-dir> [--init-git --author \"Name <email>\"]" >&2
  exit 1
fi

dest=$1
shift
init_git=false
author=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --init-git) init_git=true; shift ;;
    --author) author=${2:-}; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$author" ]]; then
  author="$DEFAULT_AUTHOR_NAME <$(echo "$DEFAULT_AUTHOR_EMAIL_B64" | base64 -d)>"
fi
if [[ ! "$author" =~ ^(.+)\ \<(.+)\>$ ]]; then
  echo "error: --author must look like \"Name <email>\", got: $author" >&2
  exit 1
fi

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

mkdir -p "$dest"
dest=$(cd "$dest" && pwd)

exclude_prefixes=(
  "SPECS/"
  "NAVIGATIONS/"
  "LAYOUTS/"
  "TASKS/"
  "RESOURCES/"
  ".claude/"
  ".gitea/"
  ".idea/"
)
exclude_exact=(
  "CLAUDE.md"
  "claude.session"
  "docs/BUILD_MACHINE.md"
  "docs/scene_map_widget.md"
)

is_excluded() {
  local path=$1
  for p in "${exclude_prefixes[@]}"; do
    [[ "$path" == "$p"* ]] && return 0
  done
  for e in "${exclude_exact[@]}"; do
    [[ "$path" == "$e" ]] && return 0
  done
  [[ "$path" == *.iml ]] && return 0
  return 1
}

count=0
skipped=0
while IFS= read -r -d '' path; do
  if is_excluded "$path"; then
    skipped=$((skipped + 1))
    continue
  fi
  target="$dest/$path"
  mkdir -p "$(dirname "$target")"
  cp "$path" "$target"
  count=$((count + 1))
done < <(git ls-files -z)

echo "Exported $count file(s) to $dest (excluded $skipped internal file(s))."

# Strip the RESOURCES/-only .gitignore entry (and its explanatory comment):
# dead in the public copy since RESOURCES/ itself was never copied. Buffers
# blank/comment lines and only drops them if they turn out to precede the
# dead entry; any other blank/comment run is flushed through unchanged.
gitignore="$dest/.gitignore"
if [[ -f "$gitignore" ]]; then
  awk '
    /^#/ || /^[[:space:]]*$/ { buf[n++] = $0; next }
    $0 == "/RESOURCES/npc-generator-live/" { n = 0; next }
    { for (i = 0; i < n; i++) print buf[i]; n = 0; print }
    END { for (i = 0; i < n; i++) print buf[i] }
  ' "$gitignore" > "$gitignore.tmp"
  mv "$gitignore.tmp" "$gitignore"
fi

if $init_git; then
  author_name=${BASH_REMATCH[1]}
  author_email=${BASH_REMATCH[2]}
  (
    cd "$dest"
    git init -q
    git config user.name "$author_name"
    git config user.email "$author_email"
    git add -A
    git commit -q -m "Public export $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  )
  echo "Initialized a fresh git history in $dest (author: $author_name <$author_email>)."
fi
