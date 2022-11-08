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

# Получение логина и пароля

if [ -f ~/.config/boorulogins.conf ]
then
  . ~/.config/boorulogins.conf
else
  echo Файл с данными для авторизации не найден!
  echo Создайте файл ~/.config/boorulogins.conf и поместите в него следующие строки:
  echo sanlogin=ВАШ ЛОГИН
  echo sanpass=ВАШ ПАРОЛЬ
  exit 5
fi

# логинимся
echo -n Logging in...
AUTH=$(curl -s "https://capi-v2.sankakucomplex.com/auth/token?lang=english" -d "{\"login\":\"${sanlogin}\",\"password\":\"${sanpass}\"}" -H "Accept: application/vnd.sankaku.api+json;v=2" -A "$uag" -H "Content-Type: application/json"| jq -r "select(.success=="true") | .access_token")

# Проверка логина
if [ -z $AUTH ]
then
  echo ERROR: Проверьте логин и пароль
  exit 2
else
  echo OK
fi

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
  curl -# --compressed -A "$uag" "https://capi-v2.sankakucomplex.com/posts?tags=$tags&page=$pagenum&limit=100" -H "Authorization: Bearer $AUTH" | jq -r ".[].file_url" > tmp.sankaku.txt
  picnum=$(cat tmp.sankaku.txt|wc -l)
  if [ $picnum \> 0 ]
  then
    cat tmp.sankaku.txt >> get.sankaku.txt
    pagenum=$(expr $pagenum + 1)

    aria2c --remote-time --auto-file-renaming=false -j3 -i tmp.sankaku.txt \
    --allow-overwrite=true \
    --conditional-get=true -c -m20 --retry-wait=10
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

# убираем за собой
rm -f tmp.sankaku.txt 2> /dev/null

echo Finished!
echo $tags \=\> $savedir
