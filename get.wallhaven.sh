#!/bin/bash

# Юзергаент
uag="Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/109.0"

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

# Получение логина и пароля

if [ -f ~/.config/boorulogins.conf ]
then
  . ~/.config/boorulogins.conf
else
  echo Файл с данными для авторизации не найден!
  echo Создайте файл ~/.config/boorulogins.conf и поместите в него следующую строку:
  echo whapikey=ВАШ API-КЛЮЧ
  exit 5
fi

# Удаление старого списка
if [ -e get.wallhaven.txt ]
then
  rm -f get.wallhaven.txt
fi

# Загрузка до тех пор, пока в выдаче не будет 0 ссылок
pagenum=1
picnum=1

until [ $picnum -eq 0 ]
do
  # Получение списка
  echo Page $pagenum
  curl -# --compressed -A "$uag" "https://wallhaven.cc/api/v1/search?q=$tags&purity=111&page=$pagenum" -H "X-API-Key: $whapikey" | jq -r ".data[].path" > tmp.wallhaven.txt
  picnum=$(cat tmp.wallhaven.txt|wc -l)
  if [ $picnum -gt 0 ]
  then
    cat tmp.wallhaven.txt >> get.wallhaven.txt
    pagenum=$(expr $pagenum + 1)
  fi
  # чтобы не упереться в ratelimit
  sleep 2
done;

# Проверка количетсва и загрузка
postcount=$(cat get.wallhaven.txt|wc -l)

if [ $postcount -eq 0 ]
then
  echo По сочетанию "$tags" ничего не найдено.
  rm -f tmp.wallhaven.txt
  exit 3
else
  echo По сочетанию "$tags" найдено постов: $postcount
  wget -U "$uag" -nc -i get.wallhaven.txt
fi

# убираем за собой
rm -f tmp.wallhaven.txt 2> /dev/null

echo Finished!
echo $tags \=\> $savedir
