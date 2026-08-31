#!/usr/bin/env bash
# Usage:
#   update-secure-rebuild-config.sh \
#     <source_tag> \
#     <release_tag> \
#     <release_number> \
#     <editions_json>

set -euo pipefail

if [ "$#" -ne 4 ]; then
  echo "Usage: $0 <source_tag> <release_tag> <release_number> <editions_json>" >&2
  exit 2
fi

SOURCE_TAG="$1"
RELEASE_TAG="$2"
RELEASE_NUMBER="$3"
EDITIONS_JSON="$4"

CONFIG="${CONFIG:-.github/secure-rebuild.json}"

if ! [[ "${RELEASE_NUMBER}" =~ ^[1-9][0-9]*$ ]]; then
  echo "Error: release_number must be a positive integer" >&2
  exit 2
fi

if ! [[ "${RELEASE_TAG}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: release_tag must have format X.Y.Z.N" >&2
  exit 2
fi

if [ ! -f "${CONFIG}" ]; then
  echo "Error: config not found: ${CONFIG}" >&2
  exit 1
fi

# Expected format:
# {
#   "-ee": { "latest": true },
#   "-de": { "latest": true }
# }
if ! jq -e '
  type == "object"
  and all(
    .[];
    type == "object"
    and has("latest")
    and (.latest | type == "boolean")
  )
' >/dev/null 2>&1 <<< "${EDITIONS_JSON}"; then
  echo 'Error: editions_json must look like {"-ee":{"latest":true}}' >&2
  exit 2
fi

if ! jq -e '
  type == "object"
  and (.releases | type == "object")
' "${CONFIG}" >/dev/null 2>&1; then
  echo "Error: ${CONFIG} must contain a releases object" >&2
  exit 1
fi

# For release_tag 9.6.1.1:
# MINOR   = 9.6.1
# SHORTER = 9.6
# MAJOR   = 9
MINOR="${RELEASE_TAG%.*}"
SHORTER="${MINOR%.*}"
MAJOR="${RELEASE_TAG%%.*}"
MAJOR_KEY="v${MAJOR}"

TMP_FILE="$(mktemp "${CONFIG}.tmp.XXXXXX")"

cleanup() {
  rm -f "${TMP_FILE}"
}

trap cleanup EXIT

jq \
  --arg key "${MAJOR_KEY}" \
  --arg src "${SOURCE_TAG}" \
  --arg rel "${RELEASE_TAG}" \
  --arg s1 "${MINOR}" \
  --arg s2 "${SHORTER}" \
  --argjson release_number "${RELEASE_NUMBER}" \
  --argjson eds "${EDITIONS_JSON}" \
'
  # Strips latest only for editions present in the new $eds.
  # Uses exact key comparison via index() so that empty key ""
  # does not match "-ee" or "-de".
  def strip_latest_for_editions($eds):
    ($eds | keys) as $edition_keys
    |
    map(
      .editions |= with_entries(
        .key as $edition_key
        |
        if ($edition_keys | index($edition_key)) != null
        then .value.latest = false
        else .
        end
      )
    );

  # Removes a short tag by exact match.
  def remove_exact_short_tag($tag):
    map(
      .short_tags |= map(
        select(. != $tag)
      )
    );

  # For subsequent rebuild releases, removes short tags
  # from the previous record of the same patch version.
  # Example: when adding 9.6.1.2, removes "9.6.1" and "9.6" from 9.6.1.1.
  def remove_patch_short_tags($s1; $s2):
    map(
      if (.short_tags | index($s1)) != null
      then
        .short_tags |= map(
          select(. != $s1 and . != $s2)
        )
      else
        .
      end
    );

  def new_record($src; $rel; $s1; $s2; $eds):
    {
      source_tag: $src,
      release_tag: $rel,
      short_tags: [$s1, $s2],
      editions: $eds
    };

  # Remember whether the major branch existed before changes.
  (.releases | has($key)) as $major_existed
  |

  # Idempotency guard: remove any existing record with the same release_tag
  # to avoid duplicates on re-run.
  .releases |= with_entries(
    .value |= map(
      select(.release_tag != $rel)
    )
  )
  |

  if $major_existed then

    # Major branch already exists (e.g. v9).
    .releases[$key] = (
      .releases[$key]

      # First release of a new minor (release_number == 1):
      # remove the short minor tag (e.g. "9.6") from the previous record.
      # Subsequent rebuild release:
      # remove both "9.6.1" and "9.6" from the previous record
      # of the same patch version.
      |
      if $release_number == 1
      then remove_exact_short_tag($s2)
      else remove_patch_short_tags($s1; $s2)
      end

      # Strip latest only for editions included in the new release.
      |
      strip_latest_for_editions($eds)
    )
    |

    # Prepend the new release record.
    .releases[$key] = [
      new_record($src; $rel; $s1; $s2; $eds)
    ] + .releases[$key]

  else

    # A new major branch is being created (e.g. first v10).
    # Strip latest for the corresponding editions across all existing major branches.
    .releases |= with_entries(
      .value |= strip_latest_for_editions($eds)
    )
    |

    .releases[$key] = [
      new_record($src; $rel; $s1; $s2; $eds)
    ]
    |

    # Keep only the two most recent major branches.
    .releases = (
      .releases
      | to_entries
      | sort_by(
          .key
          | ltrimstr("v")
          | tonumber
        )
      | reverse
      | .[0:2]
      | from_entries
    )

  end
' "${CONFIG}" > "${TMP_FILE}"

# Validate that the result is valid JSON.
jq -e . "${TMP_FILE}" >/dev/null

mv "${TMP_FILE}" "${CONFIG}"
trap - EXIT

echo "Updated ${CONFIG}:"
cat "${CONFIG}"

