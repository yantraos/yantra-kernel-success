#!/bin/bash

export ROOTDIR=${ROOTDIR:-'/'}
export YDATADIR=${YDATADIR:-"yaps"}
export REPOSITORY=${REPOSITORY:-"/yantra/repository"}
export YBUILDER=${YBUILDER:-"yaps.build"}
export YINSTALLER=${YINSTALLER:-"yaps.add"}
export YREMOVER=${YREMOVER:-"yaps.remove"}
export YTRIGGERER=${YTRIGGERER:-"yaps.trigger"}

export WORKDIR=${WORKDIR:-"/yantra/cache"}
export SRCDIR=${SIRDIR:-"/yantra/sources"}
export PKGDIR=${PKGDIR:-"/yantra/packages"}

export COMPRESS=${COMPRESS:-"xz"}
export EXTENSION=${EXTENSION:-"yaps"}
export APPDB_PATH=${APPDB_PATH:-"/var/cache/yaps/"}
export MIRROR_PATH=${MIRROR_PATH:-"/etc/yaps.mirror"}

YAPS_VERSION='0.1.0'

checkargs() {
    local _count=${1}
    shift
    if [[ $_count -gt $# ]]; then
        echo "need at least $_count args but $# provided"
        exit 1
    fi
}

yhelp() {
    echo -e "yaps ${YAPS_VERSION}
Package manager for yantra OS

Usage:
      $0 <task> [OPTION] [ARGS]
      
Tasks:
     install            Install packages into system
     remove             Remove packages from the system
     update             Update repository packages database
     info               Print information of specified package
     upgrade            Perform system package updation
     list               List all avaliable packages

     compile            Configure packages from source
     depends            Return list of required dependencies of specified package

Options:
    --roots             Set root directory (default '${ROOTDIR}')
    --ydatadir          Set yaps database (default '${YDATADIR}')
    --debug             Enable debug messages
    --no-install        Set NOINSTALL flags to skip install while compiling
    --work-dir          Set work directory for compilation cache (default '${WORKDIR}')
    --src-dir           Set source directory for source packages (default '${SRCDIR}')
    --pkg-dir           Set packages directory for binary packages (default '${PKGDIR}')
    --update            Set UPDATE flag to update package if already installed
    --force-compile     Use to force the recompilation even if binary package already avaliable
    --no-depends        Skip dependencies resolving
    --installed         Set ONLY_INSTALLED flags to list only installed packages via 'list'
    --compiler-specs    Set $YBUILDER compiler specification file
    "
}

# isInstalled <name> <?version>
# ExitCode: -1  : <name> is not defined
#           -2  : <version> not defined in our info file
#           1   : not installed
#           0   : installed
#           2   : different version is installed
isInstalled() {
    local _name="${1}"
    local _version="${2}"

    [[ -z "${1}" ]] && return -1

    [[ -f "${ROOTDIR}/usr/share/$YDATADIR/$_name/info" ]] || return 1

    [[ -z "${_version}" ]] && return 0

    local _installed_ver=$(cat ${ROOTDIR}/usr/share/$YDATADIR/$_name/info | grep ^version | awk '{print $2}')
    [[ -z "${_installed_ver}" ]] && return -2

    if [[ "$_installed_ver" != "$_version" ]]; then
        return 2
    fi

    return 0
}

yybuildpath() {
    checkargs 1 $@
    for i in $REPOSITORY/*; do
        for j in $i/*; do
            if [[ $(basename $j) == "${1}" ]]; then
                echo $j
            fi
        done
    done
}

__DEPENDS_LIST__=""

# TODO better algo
docontain() {
    local arr="${1}"
    local el="${2}"
    for e in ${arr[@]}; do
        if [[ "$e" == "$el" ]]; then
            return 0
        fi
    done

    return 1
}

listdepends() {
    checkargs 1 $@
    local _appid=${1}

    getdeps() {
        [[ -z "${COMPILETIME}" ]] && {
            echo $(yinfo $1 'depends')
        } || {
            local ypath=$(yybuildpath $1)

            if [[ -z $ypath ]]; then
                echo "$0: no ybuild file found for $1"
                exit 2
            fi
            source $ypath/ybuild
            echo "$runtime $buildtime"
        }
    }

    for i in $(getdeps $_appid); do
        if isInstalled $i; then
            continue
        else
            if ! echo "$__DEPENDS_LIST__" | tr ' ' '\n' | grep -qx $i; then
                listdepends $i
            fi
        fi
    done

    if ! echo "$__DEPENDS_LIST__" | tr ' ' '\n' | grep -qx "$1"; then
        if ! isInstalled $1; then
            __DEPENDS_LIST__="$__DEPENDS_LIST__ $1"
        fi
    fi
}

ydepends() {
    checkargs 1 $@

    listdepends $1
    echo $__DEPENDS_LIST__
}

ygetinfoInstalled() {
    cat $ROOTDIR/usr/share/yaps/$1/info | grep "$2: " | awk '{print $2}'
}

# ygetmirror <appid>
# return the first mirror that contains the information regarding that app
ygetmirror() {
    local _appid="${1}"
    while read -r line ; do
        local _mid="$(echo $line | cut -d '=' -f1)"
        local _murl="$(echo $line | cut -d '=' -f2)"
        if cat ${APPDB_PATH}/$_mid | grep "^${_appid}" ; then
            echo "${_mid}"
            return 0
        fi

    done < <(cat $MIRROR_PATH)
    return 1
        
}

# yinfo_ybuild <appid> <data>
# print information about app from ybuild files
yinfo_ybuild() {
    local _appid="${1}"
    local _data="${2}"

    local _ypath="$(yybuildpath $_appid)"
    if [[ -z "$_ypath" ]] ; then
        echo "ERROR: no ybuild found for $_appid"
        exit 1
    fi

    # source ybuild file
    source $_ypath/ybuild || {
        echo "ERROR: failed to source ybuild file for $_appid ($_ypath/ybuild)"
        exit 2
    }

    case $data in
    "name")
        echo $id
        ;;
    "version")
        echo $version
        ;;
    "release")
        echo $release
        ;;
    "desc")
        echo $about
        ;;
    "depends")
        echo ${runtime[@]} ${buildtime[@]}
        ;;
    "runtime")
        echo ${runtime[@]}
        ;;
    "buildtime")
        echo ${buildtime[@]}
        ;;
    *)
        echo "Name         : ${id}"
        echo "Version      : ${version}"
        echo "Release      : ${release}"
        echo "Description  : ${about}"
        echo "Depends on   : ${runtime[@]} ${buildtime[@]}"
        ;;
    esac


}

# yinfo <appid> <data>
# print information about app from database
yinfo() {
    checkargs 1 $@

    local appid="${1}"
    local data="${2}"

    local _appdb=$(cat $APPDB_PATH | grep "^$appid")
    local _appname=$(echo $_appdb | cut -d ' ' -f1)
    local _appversion=$(echo $_appdb | cut -d ' ' -f2)
    local _apprelease=$(echo $_appdb | cut -d ' ' -f3)
    local _appdesc=$(echo $_appdb | cut -d ' ' -f4 | tr '-' ' ')
    local _appdeps=$(echo $_appdb | cut -d ' ' -f5-)

    [[ -z $WITHOUTSYS ]] && {
        if isInstalled $appid; then
            local _sysver=$(ygetinfoInstalled $appid 'version')
            local _sysrel=$(ygetinfoInstalled $appid 'release')
            if [[ $_appversion != $_sysver ]]; then
                _appversion="$_sysver -> $_appversion"
            fi

            if [[ $_apprelease != $_sysrel ]]; then
                _apprelease="$_sysrel -> $_apprelease"
            fi
        fi
    }

    case $data in
    "name")
        echo $_appname
        ;;
    "version")
        echo $_appversion
        ;;
    "release")
        echo $_apprelease
        ;;
    "desc")
        echo $_appdesc
        ;;
    "depends")
        echo $_appdeps
        ;;
    *)
        echo "Name         : ${_appname}"
        echo "Version      : ${_appversion}"
        echo "Release      : ${_apprelease}"
        echo "Description  : ${_appdesc}"
        echo "Depends on   : ${_appdeps}"
        ;;
    esac

}

# yupdate_mirror <mirror-id> <mirror-url>
# update meta data of <mirror-id> from <mirror-url>
# Environment:
#   APPDB_PATH
yupdate_mirror() {
    local _mirror_id="${1}"
    local _mirror_url="${2}"
    [[ -d ${APPDB_PATH} ]] || mkdir -p ${APPDB_PATH}
    wget -o ${APPDB_PATH}/"${_mirror_id}" "${_mirror_url}"
}

# yupdate
# update the meta data of local system from server
# Environment:
#   APPDB_PATH
yupdate() {
    local _appdb="${APPDB_PATH}"
    
    while read -r line ; do
        local _mid="$(echo $line | cut -d '=' -f1)"
        local _murl="$(echo $line | cut -d '=' -f2)"
        echo "updating $_mid"
        yupdate_mirror $_mid $_murl || {
            echo "failed to update $_mid ($_murl)"
        }
    done < <(cat $MIRROR_PATH)
}

yupgrade() {
    __UPDATE_LIST__=""
    for i in $ROOTDIR/usr/share/yaps/*; do
        local _appid=$(basename $i)
        local _appver=$(yinfo $_appid 'version')
        local _apprel=$(yinfo $_appid 'release')
        if [[ "$_appver" =~ "->" ]] || [[ "$_apprel" =~ "->" ]]; then
            __UPDATE_LIST__="$__UPDATE_LIST__ $_appid"
        fi
    done
    update_count=$(echo $__UPDATE_LIST__ | wc -w)
    if [[ "$update_count" -gt "0" ]]; then
        echo "Found ($update_count) update"
        echo -e "${__UPDATE_LIST__}\nDo you want to update [y|n]: "
        read n
        if [[ "$n" != "y" ]]; then
            echo "cancelled"
            exit 0
        fi

        for i in $__UPDATE_LIST__; do
            export UPDATE=1
            if [[ -z $COMPILE ]]; then
                yinstaller $i
                ret=$?
                [[ $ret != 0 ]] && {
                    echo "failed to update $i ($ret)"
                    exit 5
                }
            else
                ycompiler $i
                ret=$?
                [[ $ret != 0 ]] && {
                    echo "failed to update $i ($ret)"
                    exit 5
                }
            fi
        done
    else
        echo "system is upto date"
    fi
}

# ydownloader <path>
# download file from avaliable mirrors one by one until found
# Environment:
#   MIRROR_PATH:    mirror path
ydownloader() {
    local _path="${1}"

    while read -r line ; do
        local _mid="$(echo $line | cut -d '=' -f1 | awk '{print $1}')"
        local _murl="$(echo $line | cut -d '=' -f2 | awk '{print $1}')"
        echo "downloading $_mid $_murl $path"
        wget $WGETFLAGS -q --show-progress "${_murl}/$_path" -O "${PKGDIR}/$_path.part"
        if [[ $? != 0 ]] ; then
            echo "failed to $_path from $_mid ($_murl)"
        else
            mv ${PKGDIR}/$_path{.part,}
            return 0
        fi
    done < <(cat $MIRROR_PATH)

    return 1
}

yinstaller() {
    checkargs 1 $@

    local appid="${1}"

    local _aver="$(WITHOUTSYS=1 yinfo $appid 'version')"
    local _arel="$(WITHOUTSYS=1 yinfo $appid 'release')"

    local ypkg="${appid}-${_aver}-${_arel}-$(uname -m).yaps"
    if [[ ! -e "${PKGDIR}/$ypkg" ]]; then
        echo "=> downloading binary package"
        ydownloader ${ypkg}
        if [[ $? != 0 ]]; then
            echo "** failed to download ${appid}"
            return 1
        fi
    else
        echo "** found in cache"
    fi

    $YINSTALLER ${PKGDIR}/$ypkg
    ret=$?
    if [[ $ret != 0 ]]; then
        echo "Error Failed to install $appid"
        exit $ret
    fi

    tar -tf $PKGDIR/$ypkg | $YTRIGGERER
    return 0
}

ycompiler() {
    checkargs 1 $@

    local appid=${1}

    local ypath=$(yybuildpath $appid)
    if [[ -z $ypath ]]; then
        echo "$0: no ybuild file found for $appid"
        exit 2
    fi

    source $ypath/ybuild

    echo "=> found ybuild file $ypath"
    local pkgtar="$PKGDIR/$id-$version-$release-$(uname -m).$EXTENSION"

    if [[ ! -e $pkgtar ]] || [[ ! -z "$FORCE_RECOMPILE" ]]; then
        $YBUILDER ${ypath}/ybuild $pkgtar
        ret=$?
        if [[ $ret != 0 ]]; then
            echo "Error Failed to compile $appid"
            exit $ret
        fi

    fi

    if [[ -z "${NOINSTALL}" ]] ; then
        $YINSTALLER $pkgtar
        ret=$?
        if [[ $ret != 0 ]]; then
            echo "Error Failed to install $appid"
            exit $ret
        fi

        tar -tf $pkgtar | $YTRIGGERER
    else
        echo "** Skipping installation **"
    fi
    return 0
}

yinstall() {
    checkargs 1 $@

    local appid=${1}

    if [[ -z "${NO_DEPENDS}" ]]; then
        echo "resolving dependencies..."
        listdepends $appid
        depcount=$(echo $__DEPENDS_LIST__ | tr ' ' '\n' | wc -l)
        if [[ $depcount -gt 1 ]]; then
            echo -e "$__DEPENDS_LIST__\nDo you want to install these dependencies [y/n]: "
            read an
            if [[ "$an" != "y" ]]; then
                echo "cancelled"
                exit 1
            fi
        fi
        for i in $__DEPENDS_LIST__; do
            if ! yinstaller $i; then
                echo "failed to install $i"
                exit 1
            fi
        done
    else
        if ! yinstaller $appid; then
            echo "failed to install $appid"
            exit 1
        fi
    fi
}

# ylist
# ylist list all avaliable packages
# Environment:
#   YDATADIR
ylist() {
    local _datadir="${YDATADIR}"

    for i in ${_datadir}/* ; do 
        [[ -f "${i}" ]] || continue # skip if not a file
        while read -r line ; do
            local _appid="$(cat $line | cut -d ' ' -f1)"
            local _appdesc="$(cat $line | cut -d ' ' -f4 | tr '-' ' ')"
            # is ONLY_INSTALLED                   is not Installed       then skip
            [[ ! -z "${ONLY_INSTALLED}" ]] && {
                isInstalled $_appid || continue
            }

            echo "$_appid: $_appdesc"
        done < <(cat $i)
    done
}

ycompile() {
    checkargs 1 $@

    local appid=${1}

    if [[ -z "${NO_DEPENDS}" ]]; then
        echo "resolving dependencies..."
        COMPILETIME=1 listdepends $appid
        depcount=$(echo $__DEPENDS_LIST__ | tr ' ' '\n' | wc -l)
        if [[ $depcount -gt 1 ]]; then
            echo -e "$__DEPENDS_LIST__\nDo you want to install these dependencies [y/n]: "
            read an
            if [[ "$an" != "y" ]]; then
                echo "cancelled"
                exit 1
            fi
        fi
        for i in $__DEPENDS_LIST__; do
            if ! ycompiler $i; then
                echo "failed to install $i"
                exit 1
            fi
        done
    else
        if ! ycompiler $appid; then
            echo "failed to compile $appid"
            exit 1
        fi
    fi
}

yremove() {
    checkargs 1 $@
    local appid=${1}

    $YREMOVER $appid
    ret=$?
    if [[ $? != 0 ]]; then
        echo "Error failed to remove $appid"
        exit $ret
    fi
}


# yversion
# print current yaps version
yversion() {
    echo $YAPS_VERSION
    exit 0
}

main() {
    ARGS=()
    while [[ $# -gt 0 ]]; do
        _key="${1}"

        case "$_key" in
        --roots)
            export ROOTDIR=${2}
            shift
            ;;

        --ydatadir)
            export YDATADIR=${2}
            shift
            ;;

        --debug)
            export DEBUG=1
            shift
            ;;

        --no-install)
            export NOINSTALL=1
            ;;

        --work-dir)
            export WORKDIR=${2}
            shift
            ;;

        --src-dir)
            export SRCDIR=${2}
            shift
            ;;

        --pkg-dir)
            export PKGDIR=${2}
            shift
            ;;

        --update)
            export UPDATE=1
            ;;

        --force-compile)
            export FORCE_RECOMPILE=1
            ;;

        --no-depends)
            NO_DEPENDS=1
            ;;

        --installed)
            ONLY_INSTALLED=1
            ;;

        --compiler-specs)
            export COMPILER_SPECS=${2}
            shift
            ;;

        *)
            ARGS+=("$1")
            ;;
        esac
        shift
    done

    local _task=${ARGS[0]}
    ARGS=("${ARGS[@]/$_task/}")

    if [[ "$(type -t y${_task})" != "function" ]]; then
        echo "Invalid task $_task"
        yhelp
        exit 1
    fi

    y${_task} ${ARGS[@]}
}

main $@
