#!/bin/bash


. yaps.build.sh

wdir="$(pwd)/cache/work"

id=acl
version=2.2.53
release=1

source=("https://download.savannah.gnu.org/releases/${id}/${id}-${version}.tar.gz")

YBUILD_PATH="$(pwd)/tests"
YBUILD="ybuild.sh"
DoPack "$wdir/pkg" "$YBUILD_PATH/$YBUILD"