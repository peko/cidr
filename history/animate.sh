#!/bin/bash

mkdir /tmp/rkn

# wget https://raw.githubusercontent.com/zapret-info/z-i/master/dump.csv -O data/dump.csv
# iconv -f windows-1251 -t utf-8 < data/dump.csv > data/dump-utf8.csv
dump=/tmp/rkn/dump.csv
wget \
    https://raw.githubusercontent.com/zapret-info/z-i/master/dump.csv \
    -O $dump

iconv               \
    -f windows-1251 \
    -t utf-8        \
    < $dump > $dump.utf8
mv $dump.utf8 $dump

cut -s -d ';' -f 1,6 $dump \
| awk -F ';' '{ split( $1, a, "|"); for(i in a) { print $2 " " a[i]; } }' \
| sed 's/  / /g' \
| sort -k 1 -n   \
| uniq           \
> $dump-ip-date
mv $dump-ip-date $dump

# create blank black image
out=/tmp/rkn/out.png
convert -size 1024x1024 canvas:black $out
list=/tmp/rkn/list.txt

# start date
d=2009-01-01
# iterate over calendar
while [ "$d" != 2019-01-01 ]
do
    csv=/tmp/rkn/$d.csv
    png=/tmp/rkn/$d.png

    # grep by date
    grep $d $dump | cut -d ' ' -f 2 | grep -v '/' | sed -e 's/ *$/\/32/' > $csv
    grep $d $dump | cut -d ' ' -f 2 | grep '/' >> $csv
    
    # if csv not zero size
    if [ -s $csv ]
    then
        # out + new cidrs
        ../hilbert/build/hilbert $csv 2 $out $png
        # backup png -> out
        cp $png $out
        # add date annotation
        mogrify -fill white -annotate +20+20 $d $png
        echo "file '$png'" >> $list
    fi
    rm $csv
    # increment date
    d=$(date -I -d "$d +1 day")
done

# render video
ffmpeg        \
    -f concat \
    -safe 0   \
    -r 10     \
    -i $list  \
    -y        \
    ./rkn.gif

# cleanup
rm -rf /tmp/rkn
