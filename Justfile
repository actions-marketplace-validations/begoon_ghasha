tag tag:
    #!/usr/bin/env bash
    set -euo pipefail
    tag="{{ tag }}"
    if [[ "$tag" != v* ]]; then
        echo "error: tag must start with 'v' (got: $tag)" >&2
        exit 1
    fi
    git tag -a "$tag" -m "$tag"

release version:
    #!/usr/bin/env bash
    set -euo pipefail
    version="{{ version }}"
    if [[ ! "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "error: version must be vX.Y.Z (got: $version)" >&2
        exit 1
    fi
    major="${version%%.*}"
    git tag -a "$version" -m "$version"
    git tag -fa "$major" -m "$major"
    echo
    echo "created/moved tags:"
    git show-ref --tags "$version" "$major"
    echo
    echo "to publish, run:"
    echo "  git push origin $version"
    echo "  git push --force origin $major"
