#!/bin/bash

ROOTDIR=${ROOTDIR:-'/'}
YDATADIR=${YDATADIR:-"yaps"}

# GetDetails <tarfile> <info>
GetDetails() {
    local _tarfile="${1}"
    local _info="${2}"
    local _infofile=$(tar -xaf $_tarfile usr/share/$YDATADIR -O)

    echo "$_infofile" | grep "$_info:" | awk '{$1=""; print $0}' | xargs
}

# VerifyPackage <tarfile>
# verfiy tarfile if <tarfile> installable yaps package
# Return:
#           0   verification pass
#           1   input error
#           2   tarfile missing
#           3   verification failed
VerifyPackage() {
    local _tarfile=${1}

    [[ -z "${_tarfile}" ]] && return 1

    [[ -f "${_tarfile}" ]] || return 2

    for i in id version release; do
        [[ -z $(GetDetails $_tarfile 'id') ]] && return 3
    done

    return 0
}


# isexist <tarfile> <path>
isexist() {
    tar -taf "$1" "$2" &>/dev/null
}

# readfile_from_tar <tarfile> <path>
readfile_from_tar() {
    if isexist "$1" "$2"; then
        tar -xaf "${1}" "${2}" -O
    fi
}

# check_and_exec <tarfile> <path> <func>
check_and_exec() {
    local _tarfile="${1}"
    local _fpath="${2}"
    local _fid="${3}"
    local _pkgname=$(GetDetails $_tarfile id)
    local _pkgversion=$(GetDetails $_tarfile version)

    isexist "$_tarfile" "$_fpath" || return 52
    [[ "$(type -t $_fid)" == "function" ]] || return 62

    $_fid "$(readfile_from_tar $_tarfile $_fpath)" $_pkgname $_pkgversion
}

# eval wrapper
evaluator() {
    eval "${1}"
}

# install_script_fn "data" info
# check and execute pre or post install fn
preinstall_script_fn() {
    eval "${1}"
    shift
    [[ $(type -t preinstall) == "function" ]] && preinstall $@
}

# install_script_fn "data" info
# check and execute pre or post install fn
postinstall_script_fn() {
    eval "${1}"
    shift
    [[ $(type -t postinstall) == "function" ]] && postinstall $@
}

# DoExtract <tarfile>
# ENV:
#   ROOTDIR:    root directory
# Return:
#   1   : tarfile missing
DoExtract() {
    local _tarfile="${1}"
    local _roots="${ROOTDIR}"
    local _pkgname=$(GetDetails $_tarfile 'id')

    [[ -e "${_tarfile}" ]] || return 1

    [[ -d ${_roots} ]] || mkdir -p ${_roots}

    local _total_files=$(tar -taf "${_tarfile}" | wc -l)
    local _prgs=0

    local _pdata=$ROOTDIR/usr/share/$YDATADIR/$pkgname
    if [[ -f "$_pdata/info" ]] && [[ -f "$_pdata/files" ]]; then
        if [[ -z "$UPDATE" ]]; then
            echo "Internal Error: database already exist and no \$UPDATE flag set"
            return 5
        else
            echo "=> Updating $_pkgname"
            mv $_pdata/info{,.old}
            mv $_pdata/files{,.old}
        fi
    fi

    tar xvpf "${_tarfile}" -C ${_roots} 2>&1 |
        while read line; do
            _prgs=$(($_prgs + 1))
            echo -ne "\tdone $_prgs/$_total_files..\r"
        done

    tar -tf "${_tarfile}" >$ROOTDIR/usr/share/$YDATADIR/$_pkgname/files

    # Do update here
    [[ -z "$UPDATE" ]] || {
        local _uncommonfiles=$(grep -Fxv -f $_pdata/files $_pdata/files.old)
        echo "=> cleaning $(echo "$_uncommonfiles" | wc -l) deprecated files"
        for line in $_uncommonfiles; do
            echo "cleaning $line"
            if [[ -d "$ROOTDIR/$line" ]]; then
                if [[ ! $(ls -A "$ROOTDIR/$line") ]]; then
                    rmdir "$ROOTDIR/$line"
                fi
            else
                rm -f "$ROOTDIR/$line"
            fi
        done
    }

}

# Exit Code:
#   1   : invalid input
#   2   : internal error
#   3   : tarfile missing
#   4   : extraction failed
main() {
    local _tarfile="${1}"

    [[ -z "${_tarfile}" ]] && {
        echo "$0: <yaps-package>"
        exit 1
    }

    # Verify package
    echo "=> verifying yaps package"
    VerifyPackage "$_tarfile"
    ret=$?
    case $ret in
    0)
        echo "=> verification pass"
        ;;
    1)
        echo "$0: Internal error: \$_tarfile variable not set"
        exit 2
        ;;
    2)
        echo "$0: $_tarfile missing"
        exit 3
        ;;

    3)
        echo "$0: verification failed: $_tarfile is not a verified yaps package"
        exit 4
        ;;
    *)
        echo "$0: Internal Error: invalid output return $ret"
        exit 2
        ;;
    esac

    pkgname=$(GetDetails $_tarfile 'id')
    pkgversion=$(GetDetails $_tarfile 'version')

    # check user group req
    echo "=> checking user & group requirement"
    check_and_exec $_tarfile usr/share/$YDATADIR/$pkgname/usrgrp evaluator

    # check dir req
    echo "=> checking directory requirement"
    check_and_exec $_tarfile usr/share/$YDATADIR/$pkgname/dir evaluator

    # check and exec preinstall script
    echo "=> checking and executing preinstall script"
    check_and_exec $_tarfile usr/share/$YDATADIR/$pkgname/install preinstall_script_fn

    # extract file into $ROOTS
    echo "=> extracting files into $ROOTDIR"
    DoExtract $_tarfile || {
        echo "$0: Internal Error while extracting tarfile"
        exit 4
    }

    # check and exec postinstall script
    echo "=> checking and executing postinstall script"
    check_and_exec $_tarfile usr/share/$YDATADIR/$pkgname/install postinstall_script_fn

    return 0
}

main $@
