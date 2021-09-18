#!/bin/bash

# path to ybuild script
YBUILD_PATH=${YBUILD_PATH:-$PWD}
YBUILD=${YBUILD:-'ybuild'}

WORKDIR=${WORKDIR:-"/yantra/cache"}

SRCDIR=${SIRDIR:-"/yantra/sources"}
PKGDIR=${PKGDIR:-"/yantra/packages"}
YDATADIR=${YDATADIR:-"yaps"}
EXTRACTOR=${EXTRACTOR:-"bsdtar"}
EXTRACTOR_ARGS=${EXTRACTOR_ARGS:-"-xf"}

COMPRESS=${COMPRESS:-"xz"}
EXTENSION=${EXTENSION:-"yaps"} # acl-1.07.1-1.yaps
COMPILER_SPECS=${COMPILER_SPECS:-"/etc/yaps.build.conf"}

export YSOURCEURL=${YSOURCEURL:-"http://35.154.131.43/ysarchives/"}
export YSRC_VERSION=${YSRC_VERSION:-'0.1'}


clean() {
    if [[ -z "${NOCLEAN}" ]] && [[ ! -z ${WORKDIR} ]] && [[ -d ${WORKDIR} ]]; then
        echo "=> clearing cache"
        rm -fr ${WORKDIR}
    fi
}

# trap "interrupted" 1 2 3 15
# interrupted() {
#     echo
#     Abort 1
# }

Abort() {
    clean
    exit ${1}
}

# VerifyScript <scriptfile>
# verify ybuild file for minimal requirements
# Return:
#       0   : verification pass
#       1   : failed to source file
#       2   : 'id' not set
#       3   : 'version' not set
#       4   : 'release' not set
VerifyScript() {
    local _scriptfile="${1}"

    # check if file exist
    [[ -f ${_scriptfile} ]] || return 1

    source ${_scriptfile} || {
        echo "failed to source ${_scriptfile}"
        return 1
    }

    [[ -z "${id}" ]] && {
        echo "\$id not set"
        return 2
    }

    [[ -z "${version}" ]] && {
        echo "\$version not set"
        return 3
    }

    [[ -z "${release}" ]] && {
        echo "\$release not set"
        return 4
    }

    return 0

}

# DownloadSource <source[@]>
# download list of files and save then to $SRCDIR
# ENV: SRCDIR       :   location to save sourcefiles
DownloadSource() {

    local _source="${@}"
    local _srcdirloc="${SRCDIR}" # loc to save file

    [[ -z "${_source}" ]] && return 1
    [[ -z "${_srcdirloc}" ]] && return 2

    # check and build if not exist srcdir
    [[ -d "${_srcdirloc}" ]] || mkdir -p "${_srcdirloc}"

    # _downloadsrc <url> <loc>
    _downloadsrc() {
        local _url="${1}"
        local _loc="${2}"
        local _tarfile="$(basename $_url)"

        if [[ -e "${_loc}/${_tarfile}" ]]; then
            echo "** ${_tarfile} already in cache"
            return 0
        fi

        wget $WGETFLAGS -q --show-progress "${_url}" -O "${_loc}/$_tarfile.part"
        if [[ $? != 0 ]]; then
            echo "** failed to download ${_tarfile}"
            return 1
        fi

        mv "${_loc}/${_tarfile}.part" "${_loc}/${_tarfile}"
    }

    for i in ${_source[@]}; do
        case $i in
        http* | https* | ftp*)
            echo "-> Downloading $i"
            _downloadsrc "${i}" "${_srcdirloc}"
            ;;
        *)
            echo "-> Skipping $i"
            ;;
        esac
        if [[ $? != 0 ]]; then
            return 5
        fi
    done

}

# PrepareSource <source[@]>
# preare source files
# : extract tarfile to $srcdir
# : copy local, patchs to $srcdir
# ENV:  SRCDIR
#    :  WORKDIR
#    :  YBUILD_PATH
PrepareSource() {
    local _source="${@}"         # source[@]
    local _srcdirloc="${SRCDIR}" # global loc of source codes
    local _srcdir="$WORKDIR/src" # local source code dir for specific package
    local _ybuildpath="${YBUILD_PATH}"

    [[ -z "${_source}" ]] && return 1
    [[ -z "${_srcdirloc}" ]] && return 1

    [[ -d "${_srcdirloc}" ]] || return 2
    [[ -d "${_srcdir}" ]] || mkdir -p "${_srcdir}"

    for i in ${_source[@]}; do
        case $i in
        http* | https* | ftp*)
            case $i in
            *.tar.* | *.tgz | *.zip)
                _lfile="${_srcdirloc}/$(basename $i)"
                _lmode="extract"
                ;;
            *)
                _lfile="${_srcdirloc}/$(basename $i)"
                _lmode="copy"
                ;;
            esac
            ;;

        *)
            case $i in
            *.tar.* | *.tgz | .*zip)
                _lfile="${_ybuildpath}/$i"
                _lmode="extract"
                ;;
            *)
                _lfile="${_ybuildpath}/${i}"
                _lmode="copy"
                ;;
            esac
            ;;
        esac

        if [[ ! -e ${_lfile} ]]; then
            echo "MISSING $_lfile"
            return 4
        fi

        case $_lmode in
        "extract")
            echo "=> extracting ${_lfile}"
            $EXTRACTOR ${EXTRACTOR_ARGS} "${_lfile}" -C "${_srcdir}"
            ;;
        "copy")
            echo "=> copying ${_lfile}"
            cp "${_lfile}" "${_srcdir}"
            ;;
        esac
        if [[ $? != 0 ]]; then
            echo "** Failed to prepare ${_lfile}"
            return 5
        fi
    done
}

# DoBuild <srcdir> <pkgdir> <ybuildpath>
# do compilation process
DoBuild() {
    srcdir="${1}"
    pkgdir="${2}"
    local _ybuildpath="${3}"

    source "$_ybuildpath" || {
        echo "** FAILED to source $_ybuildpath"
        return 2
    }

    [[ -d "${srcdir}" ]] || {
        if [[ -z "${source}" ]] ; then
            mkdir -p $srcdir
        else
            echo "${srcdir} not set"
            return 3
        fi
    }

    export srcdir
    export pkgdir

    cd $srcdir
    echo "=> Compiling..."
    (
        set -e
        build 2>&1
    )
    ret=$?
    if [[ $ret != 0 ]]; then
        echo "** ERROR failed to execute do build"
        return 5
    fi
}

DoStrip() {
    if [[ "$nostrip" ]]; then
        for i in ${nostrip[@]}; do
            xstrip="$xstrip -e $i"
        done
        FILTER="grep -v $xstrip"
    else
        FILTER="cat"
    fi

    find . -type f -printf "%P\n" 2>/dev/null | $FILTER | while read -r binary; do
        case "$(file -bi "$binary")" in
        *application/x-sharedlib*) # Libraries (.so)
            ${CROSS_COMPILE}strip --strip-unneeded "$binary" 2>/dev/null
            ;;

        *application/x-pie-executable*) # Libraries (.so)
            ${CROSS_COMPILE}strip --strip-unneeded "$binary" 2>/dev/null
            ;;

        *application/x-archive*) # Libraries (.a)
            ${CROSS_COMPILE}strip --strip-debug "$binary" 2>/dev/null
            ;;

        *application/x-object*)
            case "$binary" in
            *.ko) # Kernel module
                ${CROSS_COMPILE}strip --strip-unneeded "$binary" 2>/dev/null
                ;;

            *)
                continue
                ;;
            esac
            ;;

        *application/x-executable*) # Binaries
            ${CROSS_COMPILE}strip --strip-all "$binary" 2>/dev/null
            ;;

        *)
            continue
            ;;
        esac
    done

}

CompressManpages() {
    find . -type f -path "*/man/man*/*" | while read -r file; do
        if [ "$file" = "${file%%.gz}" ]; then
            gzip -9 -f "$file"
        fi
    done

    find . -type l -path "*/man/man*/*" | while read -r file; do
        FILE="${file%%.gz}.gz"
        TARGET="$(readlink $file)"
        TARGET="${TARGET##*/}"
        TARGET="${TARGET%%.gz}.gz"
        DIR=$(dirname "$FILE")
        rm -f $file
        if [ -e "$DIR/$TARGET" ]; then
            ln -sf $TARGET $FILE
        fi
    done
    if [ -d usr/share/info ]; then
        (
            cd usr/share/info
            for file in $(find . -type f); do
                if [ "$file" = "${file%%.gz}" ]; then
                    gzip -9 "$file"
                fi
            done
        )
    fi
}

# CleanLibarchive
CleanLibarchive() {
    find . -type f -name "*.la" -delete
}

# DoPack <pkgdir> <ybuildpath> <tarfile>
# ENV: PKGDIR       global package directory
DoPack() {
    local _pkgdir=${1}
    local _ybuildpath=${2}
    local _tarfile=${3:-"$PKGDIR/$id-$version-$release-$(uname -m).$EXTENSION"}
    local _ybuild=$(dirname "$_ybuildpath")

    [[ -z "${_pkgdir}" ]] && return 1

    source "$_ybuildpath" || {
        echo "** ERROR while source $_ybuildpath"
        return 2
    }

    [[ -d ${_pkgdir} ]] || {
        echo "** ERROR no $_pkgdir created"
        return 3
    }

    cd $_pkgdir

    # creating pkginfo
    mkdir -p usr/share/$YDATADIR/$id/

    for i in users dirs install; do
        [[ -e "${_ybuild}/$i" ]] && cp "${_ybuild}/$i" usr/share/$YDATADIR/$id/
    done

    DoStrip

    CompressManpages

    CleanLibarchive

        echo "
id: $id
version: $version
release: $release
about: $about
depends: ${runtime[@]}
build: $(date +'%r %D')
size: $(du -hs | cut -f1)
" >usr/share/$YDATADIR/$id/info

    [[ -d $PKGDIR ]] || mkdir -p $PKGDIR
    # compression
    tar -cf $_tarfile --$COMPRESS *
    if [[ $? != 0 ]]; then
        echo "ERROR ** failed to compress"
        return 5
    fi
}

main() {
    [[ -z "${1}" ]] && {
        echo "Usage: $0 <scriptfile>"
        exit 1
    }
    local _scriptfile="$(realpath ${1})"
    local _pkgtar=${2:-"$PKGDIR/$id-$version-$release-$(uname -m).$EXTENSION"}
    [[ -z "$_scriptfile" ]] && {
        echo "$0 <ybuild>"
        exit 1
    }

    [[ -f "$_scriptfile" ]] || {
        echo "$0: script file missing"
        exit 2
    }

    echo "=> verifying ybuild file"
    VerifyScript $_scriptfile
    ret=$?

    case $ret in
    0)
        echo ":: pass :: verification pass"
        ;;
    1)
        echo "Internal Error: $_scriptfile missing"
        exit 2
        ;;
    2)
        echo "'id' is not defined in ybuild file"
        exit 3
        ;;
    3)
        echo "'version' is not yet defined in ybuild file"
        exit 3
        ;;
    4)
        echo "'release' is not yet defined in ybuild file"
        exit 3
        ;;
    *)
        echo "Internal Error: invalid return code $ret"
        exit 4
        ;;
    esac

    
    source $_scriptfile || {
        echo "Error while source script file"
        exit 5
    }

    if [[ -n "${source}" ]] ; then
        echo "=> Downloading source codes"
        DownloadSource "${source[@]}"
        ret=$?
        if [[ $ret != 0 ]]; then
            echo "Error while downloading source codes"
            Abort 6
        fi

        echo "=> Preparing source codes"
        YBUILD_PATH=$(yaps ybuildpath $id) \
        PrepareSource "${source[@]}"
        ret=$?
        if [[ $ret != 0 ]]; then
            echo "Error while preparing source codes"
            Abort 7
        fi

    fi

    echo "=> Compiling source codes"
    DoBuild "$WORKDIR/src" "$WORKDIR/pkg" "$_scriptfile"
    ret=$?
    if [[ $ret != 0 ]]; then
        echo "Error while compiling source codes"
        Abort 8
    fi

    if [[ -z ${skippack} ]] ; then
        echo "=> Compressing into installable package"
        DoPack "$WORKDIR/pkg" "$_scriptfile" $_pkgtar
        ret=$?
        if [[ $ret != 0 ]]; then
            echo "Error while compressing package"
            Abort 8
        fi

        [[ -e "$_pkgtar" ]] || {
            echo "Internal error tarfile not generated"
            Abort 9
        }

        echo ":: Success :: tarfile is ready $_pkgtar"
    fi
    clean
}

[[ -f ${COMPILER_SPECS} ]] && {
    echo "using compiler specification: ${COMPILER_SPECS}"
    source ${COMPILER_SPECS}
}

main $@
