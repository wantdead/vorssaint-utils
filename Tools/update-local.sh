#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
cd "$(dirname "$0")/.."
install=0
check=0
full_tests=0
for arg in "$@"; do
    case "$arg" in
        --install) install=1 ;;
        --check) check=1 ;;
        --full-tests) full_tests=1 ;;
        --help|-h)
            printf '%s\n' 'Usage: ./Tools/update-local.sh [--check | --install] [--full-tests]' \
                'Fetch upstream main, merge into local/omniwm, test and build the Developer app.' \
                '--check fetches and reports upstream changes without merging or building.' \
                '--full-tests runs every repository test suite; the default validates Dynamic Island.' \
                '--install also installs and launches the Developer app after checks pass.'
            exit 0 ;;
        *) printf 'Unknown option: %s\n' "$arg" >&2; exit 2 ;;
    esac
done
if (( check && (install || full_tests) )); then
    printf '%s\n' '--check cannot be combined with --install or --full-tests.' >&2
    exit 2
fi
if [[ "$(git branch --show-current)" != local/omniwm ]]; then
    printf '%s\n' 'Switch to local/omniwm before updating.' >&2
    exit 1
fi
if [[ -n "$(git status --porcelain)" ]]; then
    printf '%s\n' 'Commit or stash local changes before updating.' >&2
    exit 1
fi
if [[ -n "$(git rev-parse -q --verify MERGE_HEAD 2>/dev/null || true)" ]] \
    || [[ -d "$(git rev-parse --git-path rebase-merge)" ]] \
    || [[ -d "$(git rev-parse --git-path rebase-apply)" ]]; then
    printf '%s\n' 'Finish the active merge or rebase before updating.' >&2
    exit 1
fi
git fetch --quiet origin main
incoming=$(git rev-list --count HEAD..origin/main)
printf 'Upstream commits to merge: %s\n' "$incoming"
if (( check )); then exit 0; fi
if (( incoming )); then
    if ! git merge --no-edit origin/main; then
        # Leave the original branch usable when an upstream edit overlaps the fork.
        if git rev-parse -q --verify MERGE_HEAD >/dev/null; then git merge --abort; fi
        printf '%s\n' 'Upstream merge failed. No build or installation ran; review the conflicting upstream changes.' >&2
        exit 1
    fi
fi
if (( full_tests )); then
    ./build.sh --test
else
    ./build.sh --test-suite=notch
fi
./build.sh --dev
./build/VorssaintDeveloper --selftest
if (( install )); then ./build.sh --dev --install; fi
