#!/bin/bash

uag="Mozilla/5.0 (Windows; U; Windows NT 5.1; ru; rv:1.9.1.1) Gecko/20090715 Firefox/3.5.1 (.NET CLR 3.5.30729)"

if [ ! "$2" = "" ]
then
  tags=$1
  savedir=$2
else
  if [ ! "$1" = "" ]
  then
    tags=$1
    savedir=$1
  else
    echo Использование:
    echo `basename $0` теги \[каталог\]
    exit 1
  fi
fi


dldr='aria2c --remote-time --check-certificate=false'
if [ ! -d $savedir ]
then
  echo Creating $savedir
  mkdir "$savedir"
else
  dldr='wget --no-check-certificate -nc'
fi
echo Entering $savedir
cd "$savedir"

postcount=`curl -# "https://e621.net/post/index.xml?tags=$tags&limit=1"|pcregrep -o 'posts\ count=\"[^"]+'|sed -e 's/posts\ count=//' -e 's/\"//'`
echo $postcount posts

if [ -s get2.e621.txt ]
then
  rm -f get2.e621.txt
fi

let "pcount=postcount/100+1"

echo $pcount
for ((i=1; i<=$pcount; i++))
do
  curl "https://e621.net/post/index.xml?tags=$tags&limit=100&page=$i" -A "$uag"|pcregrep -o -e 'file_url=[^ ]+'|sed -e 's/file_url=//g' -e 's/\"//g'  >>get2.e621.txt
done;

$dldr -i get2.e621.txt
