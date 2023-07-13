#!/bin/bash

# Юзергаент
uag="Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:70.0) Gecko/20100101 Firefox/70.0"

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

postcount=$(curl -k -# "https://yande.re/post/index.xml?tags=$1&limit=1" -A "$uag"|pcregrep -o 'posts\ count=\"[^"]+'|sed -e 's/posts\ count=//' -e 's/\"//')

# Проверка количества
if [ $postcount -eq 0 ]
then
  echo По сочетанию "$tags" ничего не найдено.
  exit 3
else
  echo По сочетанию "$tags" найдено постов: $postcount
fi

# Удаление файла-списка
if [ -e get2.yandere.txt ]
then
  rm -f get2.yandere.txt
fi

pcount=$(expr $postcount / 1000 + 1)

for ((i=1; i<=$pcount; i++))
do
  echo Page $i
  curl -# "https://yande.re/post/index.xml?tags=$1&limit=1000&page=$i" -A "$uag" |pcregrep -o -e 'file_url=[^ ]+'|sed -e 's/file_url=//g' -e 's/\"//g' >> get2.yandere.txt
done;

# Дробление списка
cat get2.yandere.txt |sed 's/\/yande\.re.*//g' > get2.yandere.md5.txt
cat get2.yandere.txt | awk -F "." '{print $(NF) }' > get2.yandere.ext.txt
# Соединение
paste -d "." get2.yandere.md5.txt get2.yandere.ext.txt > get2.yandere.txt

wget --no-check-certificate -nc -i get2.yandere.txt

rm -f get2.yandere.*.txt 2> /dev/null

echo Finished!
echo $tags \=\> $savedir
