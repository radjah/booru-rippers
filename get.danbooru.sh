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

# Загрузка до тех пор, пока в выдаче будет 0 ссылок
pagenum=1
picnum=1

until [ $picnum -eq 0 ]
do
  # Получение списка
  echo Page $pagenum
  curl -# "http://$danlogin:$danapikey@danbooru.donmai.us/post/index.xml?tags=$tags&limit=100&page=$pagenum" -A "$uag"|pcregrep -o -e 'file_url=\"[^\"]+'|sed -e 's/file_url=/http\:\/\/danbooru\.donmai\.us/g' -e 's/\"//g' > tmp.danbooru.txt
  picnum=`cat tmp.danbooru.txt|wc -l`
  if [ $picnum \> 0 ]
  then
    cat tmp.danbooru.txt >> get.danbooru.txt
    let "pagenum++"
  fi
done;

# Проверка количетсва
postcount=`cat get.danbooru.txt|wc -l`

if [ $postcount -eq 0 ]
then
  echo По сочетанию "$tags" ничего не найдено.
  exit 3
else
  echo По сочетанию "$tags" найдено постов: $postcount
fi

wget -U "$uag" -nc -i get.danbooru.txt

# уборка
rm -f danbooru.txt tmp.danbooru.txt
