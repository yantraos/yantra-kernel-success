id=acl
version=2.2.53
release=1
runtime=()
about="Utilities to administer Access Control Lists, which are used to define more fine-grained discretionary access rights for files and directories"
source=("https://download.savannah.gnu.org/releases/${id}/${id}-${version}.tar.gz")

build() {
    cd $id-$version

    #/bin/false # fail here

    ./configure --prefix=/usr

    make
    make install DESTDIR=$pkgdir


}