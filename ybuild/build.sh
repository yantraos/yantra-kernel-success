#!/bin/bash

COMPILER_SPECS=$(pwd)/yaps.build.conf
source $COMPILER_SPECS

export OSNAME='yantra'
export OSVERSION='0.1.0'
export SRCDIR=$YDIR/yantra/sources
export PKGDIR=$YDIR/yantra/packages
export WORKDIR=$YDIR/yantra/cache

mkdir -p $SRCDIR $PKGDIR $WORKDIR
[[ -d $TCDIR ]] || mkdir -p $TCDIR

export PATH=/tools/bin:$PATH
export REPOSITORY=$(pwd)/

[[ -d /tools ]] && mv /tools{,.old}

ln -srvf $YDIR/tools /tools
[[ -d $YDIR/tools/installed ]] || mkdir -p $YDIR/tools/installed

# toolchain
for i in binutils-pass1 gcc-pass1 kernel-api-headers glibc-tc \
         test-pass1 libstdc++-pass1 \
         binutils-pass2 gcc-pass2 \
         test-pass2 tcl-tc expect-tc \
         dejagnu-tc m4-tc ncurses-tc \
         bash-tc bison-tc bzip2-tc \
         coreutils-tc diffutils-tc \
         file-tc findutils-tc gawk-tc \
         gettext-tc grep-tc gzip-tc \
         make-tc patch-tc perl-tc \
         python-tc sed-tc tar-tc texinfo-tc \
         util-linux-tc xz-tc openssl-tc  yaps-tc wget-tc; do 
    [[ -e $YDIR/tools/installed/$i ]] && {
        echo "skipping $i, already configured"
        continue
    }
    echo "=> compiling $i"
    echo -e '\033k' compiling $i '\033\\'
    yaps compile $i --no-install --no-depends --compiler-specs $COMPILER_SPECS
    if [[ $? != 0 ]] ; then
        echo "ERROR failed to compile $i"
        exit 1
    fi

    touch $YDIR/tools/installed/$i
done

echo "** Toolchain completed **"

if [[ -z "${NO_BACKUP}" ]] ; then
    echo "backing up toolchain"
    mksquashfs $YDIR/tools toolchain-$(uname -m).squa || {
        echo "Failed to backup toolchain"
        exit 1
    }
fi

# system build
[[ -e "${YDIR}/etc/yantra-release" ]] || {
    echo "creating filesystem"

    mkdir -p ${YDIR}/{dev/pts,proc,sys,run}
    mknod -m 600 ${YDIR}/dev/console c 5 1
    mknod -m 666 ${YDIR}/dev/null c 1 3

    mkdir -pv ${YDIR}/{bin,boot,etc/{opt,sysconfig},home,lib/firmware,mnt,opt}
    mkdir -pv ${YDIR}/{media/{floppy,cdrom},sbin,srv,var}

    install -v -d -m 0750 $YDIR/root
    install -v -d -m 1777 $YDIR/tmp $YDIR/var/tmp
    mkdir -pv ${YDIR}/usr/{,local/}{bin,include,lib,sbin,src}
    mkdir -pv ${YDIR}/usr/{,local/}share/{color,dict,doc,info,locale,man}
    mkdir -v ${YDIR}/usr/{,local/}share/{misc,terminfo,zoneinfo}
    mkdir -v ${YDIR}/usr/libexec
    mkdir -pv ${YDIR}/usr/{,local/}share/man/man{1..8}
    mkdir -v ${YDIR}/usr/lib/pkgconfig

    case $(uname -m) in
    	x86_64) mkdir -v ${YDIR}/lib64 ;;
    esac

    mkdir -v ${YDIR}/var/{log,mail,spool}
    ln -sv /run ${YDIR}/var/run
    ln -sv /run/lock ${YDIR}/var/lock
    mkdir -pv ${YDIR}/var/{opt,cache,lib/{color,misc,locate},local}
    
    cp files/{passwd,group,shells,inputrc,nsswitch.conf,ld.so.conf,vimrc} $YDIR/etc/
    touch $YDIR/var/log/{btmp,lastlog,faillog,wtmp}
    chgrp -v 13 $YDIR/var/log/lastlog
    chmod -v 664 $YDIR/var/log/lastlog
    chmod -v 600 $YDIR/var/log/btmp
    
    echo "$OSVERSION" > $YDIR/etc/yantra-release

    ln -sv /tools/bin/{bash,cat,chmod,dd,echo,ln,mkdir,pwd,rm,stty,touch} $YDIR/bin
    ln -sv /tools/bin/{env,install,perl,printf} $YDIR/usr/bin
    ln -sv /tools/lib/libgcc_s.so{,.1} $YDIR/usr/lib
    ln -sv /tools/lib/libstdc++.{a,so{,.6}} $YDIR/usr/lib
    ln -sv bash $YDIR/bin/sh

    #ln -s ../proc/self/mounts $YDIR/etc/mtab
    ln -sv /proc/self/mounts $YDIR/etc/mtab
}

# ychroot <args>...
# execute command inside chroot
ychroot() {

    [[ -d $YDIR/yantra/repository ]] || mkdir -p $YDIR/yantra/repository

    _mount() {
        mount -v --bind /dev $YDIR/dev
        mount -v -t proc proc $YDIR/proc
        mount -v -t sysfs sysfs $YDIR/sys
        mount -v -t tmpfs tmpfs $YDIR/run
        mount -vt devpts devpts $YDIR/dev/pts -o gid=5,mode=620

        mount --bind $(realpath .) $YDIR/yantra/repository
    }

    _umount() {
        umount $YDIR/yantra/repository
        umount $YDIR/dev/pts
        umount $YDIR/run
        umount $YDIR/sys
        umount $YDIR/proc
        umount $YDIR/dev
    }


    # mount pseudo filesystem
    _mount

    echo "executing $@"
    # chroot command
    chroot "$YDIR" /tools/bin/env -i \
    HOME=/root \
    TERM="$TERM" \
    PS1='toolchain (yantra) \u:\w \$ ' \
    PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin \
    $@

    retval=$?

    sleep 1
    # un-mount
    _umount

    if [[ "$retval" != "0" ]] ; then
        echo "Failed to do '$@'"
        exit 1
    fi

    return $retval
}

if [[ $1 == "chroot" ]] ; then
    echo "Chrooting into system"
    ychroot /tools/bin/bash
    exit $?
fi

cp yaps.build.conf $YDIR/

for i in linux-api-headers man-pages glibc adjtoolchain zlib file          \
         m4 bc binutils gmp mpfr mpc shadow          \
         gcc bzip2 pkg-config ncurses readline attr acl libcap         \
         sed psmisc iana-etc bison flex grep bash libtool     \
         gdbm gperf expat inetutils perl XML-Parser           \
         intltool autoconf automake xz kmod gettext elfutils  \
         libffi openssl Python ninja meson \
         help2man coreutils check diffutils gawk findutils groff grub less gzip iproute2    \
         kbd libpipeline make patch man-db tar texinfo        \
         vim systemd dbus procps-ng util-linux e2fsprogs linux-kernel; do
    
    [[ -d $YDIR/usr/share/yaps/$i ]] && {
        echo "skipping $i, (already configured)"
        continue
    }

    echo "=> compiling $i"
    ychroot /tools/bin/yaps compile $i --no-depends --compiler-specs /yaps.build.conf

    
done
