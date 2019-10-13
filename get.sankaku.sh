#!/bin/bash

# Юзергаент
uag="Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:61.0) Gecko/20100101 Firefox/61.0"

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
  echo Creating $savedir
  mkdir "$savedir"
fi
echo Entering $savedir
cd "$savedir"

# Удаление старого списка
if [ -e get.sankaku.txt ]
then
  rm -f get.sankaku.txt
fi

# Загрузка до тех пор, пока в выдаче не будет 0 ссылок
pagenum=1
picnum=1

until [ $picnum -eq 0 ]
do
  # Получение списка
  echo Page $pagenum
  curl -# --compressed -A "$uag" "https://capi-v2.sankakucomplex.com/posts?tags=$tags&page=$pagenum&limit=100" | pcregrep --buffer-size=1M -o -e 'file_url\":\"[^\"]+' | sed -e 's#"##g' -e 's#file_url:##g' > tmp.sankaku.txt
  picnum=$(cat tmp.sankaku.txt|wc -l)
  if [ $picnum \> 0 ]
  then
    cat tmp.sankaku.txt >> get.sankaku.txt
    pagenum=$(expr $pagenum + 1)
  fi
done;

# Проверка количетсва
postcount=$(cat get.sankaku.txt|wc -l)

if [ $postcount -eq 0 ]
then
  echo По сочетанию "$tags" ничего не найдено.
  rm -f tmp.sankaku.txt sankaku.txt
  exit 3
else
  echo По сочетанию "$tags" найдено постов: $postcount
fi

aria2c --allow-overwrite=true --auto-file-renaming=false --conditional-get=true --remote-time -x10 -s10 -i get.sankaku.txt

# убираем за собой
rm -f tmp.sankaku.txt 2> /dev/null

echo Finished!
echo $tags \=\> $savedir
