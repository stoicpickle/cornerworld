#!/bin/sh

set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
resources="$repo_root/Sources/TrailApp/Resources"
ledger="$repo_root/docs/ASSET_PROVENANCE.md"
missing=0

if [ ! -d "$resources" ]; then
    echo "Missing resource directory: $resources" >&2
    exit 1
fi

if [ ! -f "$ledger" ]; then
    echo "Missing provenance ledger: $ledger" >&2
    exit 1
fi

for asset in "$resources"/*; do
    [ -f "$asset" ] || continue
    relative_path=${asset#"$repo_root/"}
    if ! awk -v expected_path="$relative_path" '
        BEGIN {
            in_record = 0
            found = 0
        }

        /^### / && in_record { exit }

        $0 == "- **Path:** `" expected_path "`" {
            in_record = 1
            found = 1
            next
        }

        in_record && /^- \*\*Provider\/mode:\*\* .+/ { provider = 1 }
        in_record && /^- \*\*Generated:\*\* .+/ { generated = 1 }
        in_record && /^- \*\*Terms reviewed:\*\* .+/ { terms = 1 }
        in_record && /^- \*\*Seed:\*\* .+/ { seed = 1 }
        in_record && /^- \*\*Reference:\*\* .+/ { reference = 1 }
        in_record && /^- \*\*Creative brief:\*\* .+/ { brief = 1 }
        in_record && /^- \*\*Human-authored treatment:\*\* .+/ { treatment = 1 }

        END {
            if (!(found && provider && generated && terms && seed && reference && brief && treatment)) {
                exit 1
            }
        }
    ' "$ledger"; then
        echo "Missing or incomplete asset provenance: $relative_path" >&2
        missing=1
    fi
done

if [ "$missing" -ne 0 ]; then
    echo "Add each shipped resource to docs/ASSET_PROVENANCE.md." >&2
    exit 1
fi

echo "All shipped resources have provenance records."
