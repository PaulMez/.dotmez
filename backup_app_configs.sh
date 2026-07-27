#!/bin/bash

# Pull app configs from ~/.config back into this repo (the reverse of the
# install_*_config.sh scripts).
#
# backup_configs.sh only handles flat dotfiles in $HOME and renames them with a
# timestamp. These configs live in nested ~/.config/<app>/ directories and need
# to keep their exact filename to stay deployable, so they get their own script.
#
# This matters most for Fresh, which writes ~/.config/fresh/config.json itself
# whenever you change something in its Settings UI — without a pull-back step the
# repo silently drifts out of date.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# "<app>/<filename>" — relative to ~/.config on the way in, configs/ on the way out.
targets=(
    "fresh/config.json"
    "herdr/config.toml"
    # Uncomment to also track these; both already have install scripts.
    # "zellij/config.kdl"
    # "micro/settings.json"
    # "micro/bindings.json"
)

changed=0
for target in "${targets[@]}"; do
    src="$HOME/.config/$target"
    dest="$script_dir/configs/$target"

    if [ ! -f "$src" ]; then
        echo "skip: $src does not exist"
        continue
    fi

    if [ -f "$dest" ] && cmp -s "$src" "$dest"; then
        echo "same: $target"
        continue
    fi

    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    echo "updated: configs/$target"
    changed=$((changed + 1))
done

echo ""
if [ "$changed" -eq 0 ]; then
    echo "No changes — repo already matches ~/.config."
else
    echo "$changed file(s) updated. Review with 'git diff' before committing."
fi
