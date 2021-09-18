#!/bin/bash

PKGDIR=${PKGDIR:-"/yantra/packages"}
MIRROR_ID=${MIRROR_ID:-"default"}
APPDB_PATH=${APPDB_PATH:-"/var/cache/yaps/"}

# GetDetails <tarfile> <info>
GetDetails() {
    local _tarfile="${1}"
    local _info="${2}"
    local _infofile=$(tar -xaf $_tarfile usr/share/$YDATADIR -O)

    echo "$_infofile" | grep "$_info:" | awk '{$1=""; print $0}' | xargs
}

mv $APPDB_PATH/$MIRROR_ID{,.old}

for i in $PKGDIR/*.yaps ; do
    id=$(GetDetails $i 'id')
    version=$(GetDetails $i 'version')
    release=$(GetDetails $i 'release')
    about=$(GetDetails $i 'about' | tr ' ' '-')
    depends=$(GetDetails $i 'depends')
    if [[ -z "$id" ]] || [[ -z "${version}" ]] || [[ -z "${release}" ]] || [[ -z "${about}" ]] || [[ -z "${depends}" ]]; then
        echo "\$id is not defined for $i, skipping"
        continue
    fi

    echo "$id $version $release $about $depends" >> $APPDB_PATH/$MIRROR_ID

done