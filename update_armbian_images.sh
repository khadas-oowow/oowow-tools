#!/bin/bash

## hyphop ##

#= update armian images catalog for our server
#> https://dl.khadas.com/products/oowow/images/armbian/
#? CRONTAB: */5 * * * * USER=storage ~/update_armbian_images.sh >> ~/update_armbian_images.log 2>&1

export TZ=

SRC=https://www.armbian.com/all-images.json
NAME=${SRC##*/}
CADIR=/tmp
CACHE="$CADIR/$NAME"
HEAD="$CACHE".headers
DIR=/storage/products/oowow/images/armbian
LOCK=/dev/shm/storage.lock
TMP=/tmp/armbian.images

PID=$$

lowcase(){ echo "$@" | tr '[:upper:]' '[:lower:]' ; }
upcase(){ echo "$@" | tr '[:lower:]' '[:upper:]' ; }
CMD(){ echo "# $@" >&2 ; "$@" ;}
DIE(){ echo "! $@" >&2 ; exit 1;}
OKAY(){ echo "OKAY $@" >&2 ; exit 0;}

ASK(){
    echo "? $@"
#    echo "press ENTER otr Ctrl+C">&2
#    read YES
    "$@"
}

STOP(){
    echo "[$PID] STOP" >&2
    [ -s $LOCK ] && CMD rm $LOCK
    exit 0
}

trap STOP kill int term exit

for a in "$@"; do
    case $a in
	-f|--force)
	echo "FORCE refresh"
	[ -s "$HEAD" ] && CMD rm "$HEAD"
	;;
	-o|--offline)
	echo "NO RE DOWNLOAD list"
	NO_DL=1
	;;
    esac
done

echo "[$PID] START - Update Armbian images - $(date)"

jq=${jq:-$(which jq)}

[ "$jq" ] || ASK sudo apt install jq

[ "$NO_DL" ] || {

for ETAG in $(CMD curl -sjkLI "$SRC" | grep -m1 etag | sed 's/\r$//'); do
    ETAG=${ETAG//\"/}
done

[ "$ETAG" ] || DIE "cant get information from $SRC"

ETAG=${ETAG:-etag-empty}
echo "ETAG: <$ETAG>"

CMD grep -q "${ETAG}" "$CACHE".headers && OKAY "no need update $(date)"

#[ -s "$CACHE" ] || \
CMD curl -jkL \
    --dump-header "$HEAD".tmp \
    "$SRC" \
    -o"$CACHE".tmp || DIE "download problems"

[ -s $CACHE.tmp ] || DIE "ooops list is empty"


CMD ls -l1 "$CACHE".*
CMD mv "$CACHE.tmp" "$CACHE"
CMD mv "$HEAD.tmp" "$HEAD"
}

[ -s "$CACHE" ] || DIE "Cache empty $CACHE"

echo $PID | CMD tee $LOCK

BOARDS="edge2 vim1s vim3 vim3l vim4"

[ -d "$DIR" ] || CMD mkdir -p "$DIR"
[ -d "$TMP" ] || CMD mkdir -p "$TMP"

CMD cd   "$TMP"
CMD find "$TMP" -type f -exec rm {} \;

for B in $BOARDS; do
    D="$DIR/../$B/armbian"
#    [ -e "$D" ] || CMD ln -s "../armbian/$B" "$D"
done

jq -r \
'.[][] |
    select((.board_slug | test("^khadas-")) and .file_extension == "oowow.img.xz") |
    "\(.board_slug) \(.file_url) \(.file_updated)"
' "$CACHE" | sort | while read board_slug url update ; do

    board=${board_slug##khadas-}
    img=${url##*/}

    img2=$(lowcase $img)
    img2=${img2//_/-}
    img2=${img2/khadas-/}
    img2=${img2/.oowow.img/.img}

    [ -d "$board" ] || mkdir -p "$board"
    echo [$board] $img2 $url :: $update

    F="$board/$img2"
    echo "$url" > "$F"
    CMD chmod 0667 "$F"
    CMD touch -d"$update" "$F"

done

echo SORT

CMD rsync \
    -rcv   \
    --delete \
    "$TMP/" \
    "$DIR/"

# refresh board folder if need it
for B in $BOARDS; do
#    echo $B
#    stat "$DIR/$B"

    M=
    D="$DIR/../$B/armbian"
    [ -e "$D" ] && {
        M=$(stat -c%y $D)
	N=$(stat -c%y "$DIR/$B")
        [ "$M" != "$N" ] && echo "$M != $N" && CMD rm "$D"
    }

    [ -e "$D" ] || {
        CMD ln -s "../armbian/$B" "$D"
        CMD touch -h -r"$DIR/$B" "$D"
    }

#    stat "$DIR/../$B/armbian"
done

echo DONE $(date)
exit 0

<<EOF

.board_slug == "khadas-vim3" and
.file_extension == "oowow.img.xz"

https://github.com/armbian/distribution/releases/download/24.8.1/Armbian_24.8.1_Khadas-vim3_trixie_current_6.6.46-kali.oowow.img.xz

https://www.armbian.com/all-images.json

"file_extension": "oowow.img.xz"

