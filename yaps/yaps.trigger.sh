checkAndSet() {
    [[ "$1" =~ "$2" ]] && $3=1
}

for i in $(cat /dev/stdin) ; do
    checkAndSet "share/glib-2.0/schemas" "$i" GLIB_SCHEMAS
    checkAndSet "share/applications" "$i" DESKTOP_FILES
    checkAndSet "share/mime" "$i" MIME_DB
done


[[ ! -z ${GLIB_SCHEMAS} ]] && {
    echo "updating glib schemas"
    glib-compile-schemas "/usr/share/glib-2.0/schemas"
}


[[ ! -z ${DESKTOP_FILES} ]] && {
    echo "updating desktop files"
    update-desktop-database
}

[[ ! -z ${MIME_DB} ]] && {
    echo "updating mime database"
    update-update-mime-database /usr/share/mime
}

