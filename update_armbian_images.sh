#!/bin/bash

## hyphop ##

#= update armian images catalog for our server
#> https://dl.khadas.com/products/oowow/images/armbian/
#? CRONTAB: */5 * * * * USER=storage ~/update_armbian_images.sh >> ~/update_armbian_images.log 2>&1

SRC=https://www.armbian.com/all-images.json
NAME=${SRC##*/}
CADIR=/tmp
CACHE="$CADIR/$NAME"
DIR=/storage/products/oowow/images/armbian

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

echo "Update Armbian images: $(date)"

jq=${jq:-$(which jq)}

[ "$jq" ] || ASK sudo apt install jq

for ETAG in $(CMD curl -sjkLI "$SRC" | grep -m1 etag | sed 's/\r$//'); do
    ETAG=${ETAG//\"/}
done

[ "$ETAG" ] || DIE "cant get information from $SRC"

ETAG=${ETAG:-etag-empty}
echo "ETAG: <$ETAG>"

CMD grep -q "${ETAG}" "$CACHE".headers && OKAY "no need update $(date)"

#[ -s "$CACHE" ] || \
CMD curl -jkL \
    --dump-header "$CACHE".headers.tmp \
    "$SRC" \
    -o"$CACHE".tmp || DIE "download problems"

[ -s $CACHE.tmp ] || DIE "ooops list is empty"


CMD ls -l1 "$CACHE".*
CMD mv "$CACHE.tmp" "$CACHE"
CMD mv "$CACHE.headers.tmp" "$CACHE.headers"

CMD rm "$DIR"/*/*.xz

[ -s "DIR" ] || CMD mkdir -p $DIR

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

    mkdir -p "$DIR/$board"
    echo [$board] $img2 $url :: $update

    F="$DIR/$board/$img2"
    echo "$url" > "$F"
    CMD chmod 0667 "$F"

done

echo DONE $(date)

exit 0

<<EOF

.board_slug == "khadas-vim3" and
.file_extension == "oowow.img.xz"

https://github.com/armbian/distribution/releases/download/24.8.1/Armbian_24.8.1_Khadas-vim3_trixie_current_6.6.46-kali.oowow.img.xz

https://www.armbian.com/all-images.json

"file_extension": "oowow.img.xz"

