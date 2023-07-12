#!/bin/bash

# Юзергаент
uag="booru-rippers v0.1 by Radjah"

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
  echo e621login=ВАШ ЛОГИН
  echo e621api=ВАШ API-КЛЮЧ
  echo API-ключ получается на странице профиля
  exit 5
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
  curl -# --compressed "https://e621.net/posts.json?tags=$tags&limit=320&page=$pagenum" -A "$uag" -u $e621login:$e621api | jq -r .posts[].file.url > tmp.e621.txt
  # Чтобы не получить 503 из-за частого опроса
  sleep 1
  picnum=$(cat tmp.e621.txt|wc -l)
  if [ $picnum \> 0 ]
  then
    cat tmp.e621.txt >> get.e621.txt
    pagenum=$(expr $pagenum + 1)
  fi
done;

# Проверка количества
postcount=$(cat get.e621.txt|wc -l)

if [ $postcount -eq 0 ]
then
  echo По сочетанию "$tags" ничего не найдено.
  rm -f tmp.e621.txt
  exit 3
else
  echo По сочетанию "$tags" найдено постов: $postcount
fi

wget --no-check-certificate -nc -i get.e621.txt

rm -f tmp.e621.txt 2> /dev/null

echo Finished!
echo $tags \=\> $savedir
