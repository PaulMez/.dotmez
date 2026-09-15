#!/usr/bin/env bash
# Compare and sync alias definitions between this repo's .zshrc and a target .zshrc.
#
# Aliases live inline in configs/.zshrc (the repo is the source of truth). This
# script reads `alias name=...` lines out of both files and reports four buckets:
#
#   missing  - in the repo, not on the target        -> added by --apply
#   changed  - in both, but the definition differs   -> updated by --apply
#   extra    - on the target, not in the repo        -> reported only, never touched
#   in sync  - identical on both sides
#
# Comparison is file-based on purpose. Comparing against the live `alias`
# builtin would drown the "extra" bucket in oh-my-zsh plugin aliases (see
# macos/macosaliasall.txt for what that looks like).
#
# Default mode is --check: it reports drift and writes nothing. Pass --apply to
# make changes; the target is backed up first.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_ZSHRC="$SCRIPT_DIR/configs/.zshrc"
DESTS=()
MODE="check"

usage() {
  cat >&2 <<'EOF'
Usage: install_aliases.sh [--check | --apply] [--source FILE] [--dest FILE]...

  --check          Compare only, write nothing (default).
                   Exits 0 when in sync, 1 when the target is missing or has
                   outdated aliases, so it is usable as a CI/pre-commit gate.
  --apply          Add missing aliases and update changed ones on the target.
                   Backs up the target to <file>.bak.<timestamp> first.
  --source FILE    Repo-side .zshrc to read aliases from.
                   (default: configs/.zshrc next to this script)
  --dest FILE      Target .zshrc to compare/update. Repeatable.
                   (default: $HOME/.zshrc)

Examples:
  ./install_aliases.sh                                   # check ~/.zshrc
  ./install_aliases.sh --apply                           # sync ~/.zshrc
  ./install_aliases.sh --dest ubuntuDesktop/.zshrc \
                       --dest macos/.zshrc               # check repo variants
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) MODE="check"; shift ;;
    --apply) MODE="apply"; shift ;;
    --source)
      [[ $# -ge 2 ]] || usage
      SOURCE_ZSHRC="$2"; shift 2 ;;
    --dest)
      [[ $# -ge 2 ]] || usage
      DESTS+=("$2"); shift 2 ;;
    -h|--help) usage ;;
    *) echo "Error: unknown argument '$1'" >&2; usage ;;
  esac
done

if [[ ${#DESTS[@]} -eq 0 ]]; then
  DESTS=("$HOME/.zshrc")
fi

if [[ ! -f "$SOURCE_ZSHRC" ]]; then
  echo "Error: source .zshrc not found at $SOURCE_ZSHRC" >&2
  exit 1
fi

# Extract "name<TAB>full alias line" for every uncommented alias definition.
# Kept POSIX-awk clean (no gawk-only match() capture groups) so it runs on
# macOS /usr/bin/awk as well as gawk/mawk.
extract_aliases() {
  awk '
    /^alias[[:space:]]+[A-Za-z0-9_.-]+=/ {
      name = $0
      sub(/^alias[[:space:]]+/, "", name)
      sub(/=.*/, "", name)
      print name "\t" $0
    }
  ' "$1"
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

src_aliases="$tmpdir/source"
extract_aliases "$SOURCE_ZSHRC" > "$src_aliases"
src_count=$(wc -l < "$src_aliases" | tr -d ' ')

echo "Source: $SOURCE_ZSHRC ($src_count alias(es))"

drift=0

for DEST_ZSHRC in "${DESTS[@]}"; do
  echo
  echo "Target: $DEST_ZSHRC"

  if [[ ! -f "$DEST_ZSHRC" ]]; then
    echo "  target does not exist - all $src_count alias(es) would be added"
    drift=1
    if [[ "$MODE" == "apply" ]]; then
      cut -f2- "$src_aliases" > "$DEST_ZSHRC"
      echo "  created with $src_count alias(es)"
      drift=0
    fi
    continue
  fi

  report="$tmpdir/report"
  : > "$report"

  # Classify every alias, and (in apply mode) emit the rewritten file.
  # New aliases are inserted after the last existing alias line so they land in
  # the alias block rather than at the end of the file, which may sit after a
  # guard or a `return`.
  awk -v src_file="$src_aliases" -v report="$report" -v mode="$MODE" '
    BEGIN {
      FS = "\t"
      while ((getline line < src_file) > 0) {
        tab = index(line, "\t")
        name = substr(line, 1, tab - 1)
        src[name] = substr(line, tab + 1)
        order[++n] = name
      }
      close(src_file)
    }
    {
      lines[++total] = $0
      if ($0 ~ /^alias[[:space:]]+[A-Za-z0-9_.-]+=/) {
        name = $0
        sub(/^alias[[:space:]]+/, "", name)
        sub(/=.*/, "", name)
        seen[name] = 1
        last_alias_line = total
        if (name in src) {
          if ($0 == src[name]) {
            synced++
          } else {
            print "changed\t" name "\t" $0 "\t" src[name] > report
            changed++
            if (mode == "apply") lines[total] = src[name]
          }
        } else {
          print "extra\t" name "\t" $0 > report
          extra++
        }
      }
    }
    END {
      for (i = 1; i <= n; i++) {
        name = order[i]
        if (!(name in seen)) {
          print "missing\t" name "\t" src[name] > report
          missing[++m] = name
        }
      }
      printf("counts\t%d\t%d\t%d\t%d\n", synced + 0, changed + 0, extra + 0, m + 0) > report
      close(report)

      if (mode != "apply") exit
      if (last_alias_line == 0) last_alias_line = total
      for (i = 1; i <= total; i++) {
        print lines[i]
        if (i == last_alias_line) {
          for (j = 1; j <= m; j++) print src[missing[j]]
        }
      }
    }
  ' "$DEST_ZSHRC" > "$tmpdir/out"

  read -r _ synced changed extra missing < <(grep '^counts	' "$report" | head -1)

  while IFS=$'\t' read -r kind name a b; do
    case "$kind" in
      missing) echo "  + missing  $name" ; echo "      repo:   $a" ;;
      changed) echo "  ~ changed  $name" ; echo "      target: $a" ; echo "      repo:   $b" ;;
      extra)   echo "  ? extra    $name" ; echo "      target: $a" ;;
    esac
  done < <(grep -v '^counts	' "$report" || true)

  echo "  in sync: $synced   missing: $missing   changed: $changed   extra: $extra"

  if [[ "$missing" -gt 0 || "$changed" -gt 0 ]]; then
    if [[ "$MODE" == "apply" ]]; then
      backup="$DEST_ZSHRC.bak.$(date +%Y%m%d_%H%M%S)"
      cp "$DEST_ZSHRC" "$backup"
      cat "$tmpdir/out" > "$DEST_ZSHRC"
      echo "  applied: added $missing, updated $changed (backup: $backup)"
    else
      drift=1
    fi
  else
    echo "  nothing to do"
  fi

  if [[ "$extra" -gt 0 ]]; then
    echo "  note: 'extra' aliases exist only on the target. Nothing was removed."
    echo "        Add them to $SOURCE_ZSHRC if you want them tracked."
  fi
done

echo
if [[ "$MODE" == "check" && "$drift" -eq 1 ]]; then
  echo "Out of sync. Re-run with --apply to update."
  exit 1
fi

echo "Done."
