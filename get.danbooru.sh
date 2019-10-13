#!/bin/bash

# Юзергаент
uag="Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:56.0) Gecko/20100101 Firefox/56.0"

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
  echo Создайте файл ~/.config/boorulogins.conf и поместите в него следующие строки:
  echo danlogin=ВАШ ЛОГИН
  echo danapikey=ВАШ API-КЛЮЧ
  echo API-ключ находится на странице профиля
  exit 5
fi

# Удаление старого списка
if [ -e get.danbooru.txt ]
then
  rm -f get.danbooru.txt
fi

# Загрузка до тех пор, пока в выдаче не будет 0 ссылок
pagenum=1
picnum=1

until [ $picnum -eq 0 ]
do
  # Получение списка
  echo Page $pagenum
  curl -# -k "https://danbooru.donmai.us/posts.json?tags=$tags&limit=200&page=$pagenum" -u $danlogin:$danapikey -A "$uag"|jq -r '.[].file_url|values' > tmp.danbooru.txt
  picnum=$(cat tmp.danbooru.txt|wc -l)
  if [ $picnum \> 0 ]
  then
    cat tmp.danbooru.txt >> get.danbooru.txt
    pagenum=$(expr $pagenum + 1)
  fi
done;

# Проверка количетсва
postcount=$(cat get.danbooru.txt|wc -l)

if [ $postcount -eq 0 ]
then
  echo По сочетанию "$tags" ничего не найдено.
  rm -f tmp.danbooru.txt
  exit 3
else
  echo По сочетанию "$tags" найдено постов: $postcount
fi

wget -U "$uag" -nc -i get.danbooru.txt

# уборка
rm -f tmp.danbooru.txt 2> /dev/null

echo Finished!
echo $tags \=\> $savedir
