#!/usr/bin/env bash
# Shared checks for the isolated off-site tools; never evaluate configuration.
offsite_private_path() {
    local path=$1 kind=$2 mode
    [[ $path == /* && $path != *$'\n'* && $path != *$'\r'* && $path == "$(realpath -e -- "$path")" ]] \
        || fail 'inputs must have absolute canonical paths without symlinks.'
    [[ $path != "$root" && $path != "$root/"* ]] || fail 'inputs must stay outside the repository.'
    [[ ! -L $path && $(stat -c '%u' -- "$path") == "$(id -u)" ]] || fail 'invalid input ownership.'
    mode=$(stat -c '%a' -- "$path")
    if [[ $kind == directory ]]; then
        [[ -d $path ]] && (( (8#$mode & 077) == 0 && (8#$mode & 0700) == 0700 )) \
            || fail 'output directory must be private and writable.'
    else
        [[ -f $path && -s $path ]] || fail 'input must be a nonempty regular file.'
        (( (8#$mode & 0400) != 0 && (8#$mode & 022) == 0 )) || fail 'input permissions are unsafe.'
        [[ $kind != backup && $kind != config ]] || (( (8#$mode & 077) == 0 )) \
            || fail 'data and configuration require owner-only permissions.'
    fi
}
