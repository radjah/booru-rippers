#!/bin/bash

# Юзергаент
uag="Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:51.0) Gecko/20100101 Firefox/51.0"

# Проверка параметров
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
    echo $(basename $0) теги \[каталог\]
    exit 1
  fi
fi

# Каталог для закачки
if [ ! -d $savedir ]
then
  echo Creating $savedir...
  mkdir "$savedir"
fi

echo Entering $savedir...
cd "$savedir"

# Количество постов
postcount=$(curl --compressed -# "https://gelbooru.com/index.php?page=dapi&s=post&q=index&tags=$tags&limit=1" -A "$uag"|pcregrep -o 'posts\ count=\"[^"]+'|sed -e 's/posts\ count=//' -e 's/\"//')

# Проверка количетсва
if [ $postcount -eq 0 ]
then
  echo По сочетанию "$tags" ничего не найдено.
  exit 3
else
  echo По сочетанию "$tags" найдено постов: $postcount
fi

# Удаление файла-списка
if [ -s get2.gelbooru.txt ]
then
  rm -f get2.gelbooru.txt
fi

pcount=$(expr $postcount / 1000)

for ((i=0; i<=$pcount; i++))
do
  echo Page $i
  curl --compressed -# "https://gelbooru.com/index.php?page=dapi&s=post&q=index&tags=$tags&limit=1000&pid=$i" -A "$uag"|pcregrep -o -e 'file_url=[^ ]+'|sed -e 's/file_url=//g' -e 's/\"//g' >>get2.gelbooru.txt
done;

wget -nc -i get2.gelbooru.txt --referer="https://gelbooru.com/" --no-check-certificate

echo Finished!
echo $tags \=\> $savedir
