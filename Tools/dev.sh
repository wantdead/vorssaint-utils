#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint
set -euo pipefail
cd "$(dirname "$0")/.."
started=$SECONDS
for arg in "$@"; do
    case "$arg" in
        --test-suite=*) ./build.sh "$arg" ;;
        --help|-h)
            print 'Usage: ./Tools/dev.sh [--test-suite=NAME]'
            print 'Build, install, self-test and relaunch the Developer app.'
            exit 0 ;;
        *) print -u2 "Unknown option: $arg"; exit 2 ;;
    esac
done
./build.sh --dev --install
app='/Applications/Vorssaint (Developer).app'
"$app/Contents/MacOS/VorssaintDeveloper" --selftest
open -a "$app"
print "✓ Developer app running ($((SECONDS - started))s)"
