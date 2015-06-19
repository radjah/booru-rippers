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

if [ ! -d $savedir ]
then
  echo Creating $savedir
  mkdir "$savedir"
fi
echo Entering $savedir
cd "$savedir"

postcount=`curl -# "http://gelbooru.com/index.php?page=dapi&s=post&q=index&tags=$tags&limit=1"|pcregrep -o 'posts\ count=\"[^"]+'|sed -e 's/posts\ count=//' -e 's/\"//'`
echo $postcount posts

if [ -s get2.gelbooru.txt ]
then
  rm -f get2.gelbooru.txt
fi

let "pcount=postcount/1000"

echo $pcount
echo "http://gelbooru.com/index.php?page=dapi&s=post&q=index&tags=$tags&limit=1000&pid=$i"
for ((i=0; i<=$pcount; i++))
do
  curl "http://gelbooru.com/index.php?page=dapi&s=post&q=index&tags=$tags&limit=1000&pid=$i" -A "$uag"|pcregrep -o -e 'file_url=[^ ]+'|sed -e 's/file_url=//g' -e 's/\"//g'  >>get2.gelbooru.txt
done;

wget -nc -i get2.gelbooru.txt --referer="http://gelbooru.com/"
