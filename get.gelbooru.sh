#! /bin/bash

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


dldr='aria2c --remote-time'
if [ ! -d $savedir ]
then
  echo Creating $savedir
  mkdir "$savedir"
else
  dldr='wget -nc'
fi
echo Entering $savedir
cd "$savedir"

#export proxy=127.0.0.1:19999
#postcount=`curl --socks5 $proxy -# "http://gelbooru.com/index.php?page=dapi&s=post&q=index&tags=$tags&limit=1"|pcregrep -o 'posts\ count=\"[^"]+'|sed -e 's/posts\ count=//' -e 's/\"//'`
postcount=`curl -# "http://gelbooru.com/index.php?page=dapi&s=post&q=index&tags=$tags&limit=1"|pcregrep -o 'posts\ count=\"[^"]+'|sed -e 's/posts\ count=//' -e 's/\"//'`
echo $postcount posts
rm -f get2.gelbooru.txt

let "pcount=postcount/1000"

echo $pcount
echo "http://gelbooru.com/index.php?page=dapi&s=post&q=index&tags=$tags&limit=1000&pid=$i"
for ((i=0; i<=$pcount; i++))
do
  #curl  --socks5 $proxy "http://gelbooru.com/index.php?page=dapi&s=post&q=index&tags=$tags&limit=1000&pid=$i" -A "$uag"|pcregrep -o -e 'file_url=[^ ]+'|sed -e 's/file_url=//g' -e 's/\"//g'  >>get2.gelbooru.txt
  curl "http://gelbooru.com/index.php?page=dapi&s=post&q=index&tags=$tags&limit=1000&pid=$i" -A "$uag"|pcregrep -o -e 'file_url=[^ ]+'|sed -e 's/file_url=//g' -e 's/\"//g'  >>get2.gelbooru.txt
done;

# $dldr -i get2.gelbooru.txt

wget -nc -i get2.gelbooru.txt --referer="http://gelbooru.com/"
