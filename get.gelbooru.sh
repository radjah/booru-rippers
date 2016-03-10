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
if [ -d "/u/PicturesHR-T/$savedir" ]
then
  savedir="/u/PicturesHR-T/$savedir"
else
  if [ ! -d $savedir ]
  then
    echo Creating $savedir
    mkdir "$savedir"
  fi
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
  echo gellogin=ВАШ ЛОГИН
  echo gelpass=ВАШ ПАРОЛЬ
  exit 5
fi

if [ -e gelbooru.txt ]
then
  rm -f gelbooru.txt
fi

# логинимся (куки в gelbooru.txt)
echo Logging in...
AUTH=`curl -s -c gelbooru.txt --data "user=${gellogin}&pass=${gelpass}&submit=Log+in" "http://gelbooru.com/index.php?page=account&s=login&code=00" -A "$uag"`

if [ ! -e gelbooru.txt ]
then
  echo ERROR: Проверьте логин и пароль
  exit 2
else
  echo OK
fi

# Количество постов
postcount=`curl -b gelbooru.txt -# "http://gelbooru.com/index.php?page=dapi&s=post&q=index&tags=$tags&limit=1" -A "$uag"|pcregrep -o 'posts\ count=\"[^"]+'|sed -e 's/posts\ count=//' -e 's/\"//'`

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

let "pcount=postcount/1000"

for ((i=0; i<=$pcount; i++))
do
  echo Page $i
  curl -b gelbooru.txt -# "http://gelbooru.com/index.php?page=dapi&s=post&q=index&tags=$tags&limit=1000&pid=$i" -A "$uag"|pcregrep -o -e 'file_url=[^ ]+'|sed -e 's/file_url=//g' -e 's/\"//g'  >>get2.gelbooru.txt
done;

wget -nc -i get2.gelbooru.txt --referer="http://gelbooru.com/"

rm gelbooru.txt
