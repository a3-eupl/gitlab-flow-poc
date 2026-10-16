#!/bin/bash

PROTECTED_DIR=.layer/@a3/opt/arch-it3ct/protected

mkdir -p ${PROTECTED_DIR}
cp -r src/. ${PROTECTED_DIR}

# A shallow clone only has the tip commit, so `git log -- <file>` can't find
# each file's real last-touching commit and falls back to the tip for every
# file. Fill in the missing history before computing per-file blame dates.
if [ "$(git rev-parse --is-shallow-repository 2>/dev/null)" = "true" ]; then
    git fetch --unshallow --quiet || echo "warning: could not unshallow git history, updated/author dates may be inaccurate" >&2
fi

while IFS= read -r -d '' file; do
    opt_file="${PROTECTED_DIR}/${file#src/}"
    [ -f "$opt_file" ] || continue

    # Auto-generated content (e.g. src/scope/pdr/README.md and
    # src/scope/pdr-agisapp/README.md, rewritten by the pdr:report /
    # pdr:report:agisapp CI jobs every run but not committed back) already
    # carries its own generation timestamp in the report body, and git only
    # knows the commit that first added the file - not a meaningful "last
    # updated" for this content. Skip the tag for these pages entirely.
    case "$file" in
        src/scope/pdr/*|src/scope/pdr-agisapp/*) continue ;;
    esac

    updated=$(TZ=Europe/Bratislava git log -1 --date=format-local:'%H:%M %d-%m-%Y' --format='%ad' -- "$file")
    author=$(git log -1 --format='%an' -- "$file")
    [ -z "$updated" ] && continue

    # Detect front-matter (and CRLF vs LF) from the record itself, rather than
    # via `grep`, whose "^---$" match against CRLF-terminated lines differs
    # between grep implementations (BSD vs GNU/busybox) across dev/CI hosts.
    awk -v u="$updated" -v a="$author" '
        NR==1 {
            crlf = (substr($0, length($0), 1) == "\r") ? "\r" : ""
            first = $0
            sub(/\r$/, "", first)
            if (first == "---") {
                print $0
                print " updated: " u crlf
                if (a != "") print " author: " a crlf
            } else {
                print "---" crlf
                print " updated: " u crlf
                if (a != "") print " author: " a crlf
                print "---" crlf
                print $0
            }
            next
        }
        { print }
    ' "$opt_file" > "$opt_file.tmp" && mv "$opt_file.tmp" "$opt_file"
done < <(find src/scope -name '*.md' -print0)

echo ${CI_JOB_NAME}
