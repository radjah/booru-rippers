#!/bin/bash

# Юзергаент
uag="Mozilla/5.0 (Windows NT 6.3; WOW64; rv:40.0) Gecko/20100101 Firefox/40.0"

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
    echo `basename $0` теги \[каталог\]
    exit 1
  fi
fi

# Каталог для закачки
if [ ! -d $savedir ]
then
  echo Creating $savedir
  mkdir "$savedir"
fi
echo Entering $savedir
cd "$savedir"

# Количество постов
postcount=`curl -# "https://e621.net/post/index.xml?tags=$tags&limit=1" -A "$uag"|pcregrep -o 'posts\ count=\"[^"]+'|sed -e 's/posts\ count=//' -e 's/\"//'`
echo $postcount posts

# Проверка количетсва
if [ $postcount -eq 0 ]
then
  echo По сочетанию "$tags" ничего не найдено.
  rm -f tmp.e621.txt
  exit 3
else
  echo По сочетанию "$tags" найдено постов: $postcount
fi

# Удаление файла-списка
if [ -s get.e621.txt ]
then
  rm -f get.e621.txt
fi

# Загрузка до тех пор, пока в выдаче будет 0 ссылок
pagenum=1
picnum=1

until [ $picnum -eq 0 ]
do
  # Получение списка
  echo Page $pagenum
  curl -# "https://e621.net/post/index.xml?tags=$tags&limit=100&page=$pagenum" -A "$uag"|pcregrep -o -e '<file_url>.*<\/file_url>'|sed -e 's#<file_url>##g' -e 's#</file_url>##g' > tmp.e621.txt
  picnum=`cat tmp.e621.txt|wc -l`
  if [ $picnum \> 0 ]
  then
    cat tmp.e621.txt >> get.e621.txt
    pagenum=`expr $pagenum + 1`
  fi
done;

wget --no-check-certificate -nc -i get.e621.txt

rm -f tmp.e621.txt

echo Finished!
echo $tags \=\> $savedir
