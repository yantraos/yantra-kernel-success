#!/bin/bash

ROOTDIR=${ROOTDIR:-'/'}
appid=${1}
YDATADIR=${YDATADIR:-'yaps'}

[[ -z "${appid}" ]] && {
    echo "$0: <appid>"
    exit 1
}

app_datadir="${ROOTDIR}/usr/share/yaps/${appid}"
infofile="${app_datadir}/info"
fileslist="${app_datadir}/files"
installscript="${app_datadir}/install"

# check if app data exist
[[ -d "${app_datadir}" ]] || {
    echo "$0: yaps data missing for ${appid}"
    exit 2
}

[[ -f "${infofile}" ]] || {
    echo "$0: information file missing for ${appid}"
    exit 3
}

[[ -f "${fileslist}" ]] || {
    echo "$0: files list missing for ${appid}"
    exit 4
}

# check and execute preremove() function
echo "=> checking and executing pre-remove script"
[[ -e "${installscript}" ]] && {
    source "${installscript}" || {
        echo "$0: error while sourcing ${installscript}"
        exit 5
    }

    issource=1

    if [[ "$(type -t preremove)" == "function" ]] ; then
        preremove
    fi
}



# remove installed files
echo "cleaning $(cat $fileslist | wc -l) files"
while IFS= read -r line; do
    if [[ -d "$ROOTDIR/$line" ]] ; then
        if [[ ! $(ls -A "$ROOTDIR/$line") ]] ; then
            rmdir "$ROOTDIR/$line"
        fi
    else
        rm -f "$ROOTDIR/$line"
    fi
done < <(tac $fileslist)



# check and execute preremove() function
echo "=> checking and executing post-remove script"
[[ -z "${issource}" ]] || {

    if [[ "$(type -t postremove)" == "function" ]] ; then
        postremove
    fi
}

rm $fileslist
rm -rf $ROOTDIR/usr/share/$YDATADIR/$appid

unset preremove postremove