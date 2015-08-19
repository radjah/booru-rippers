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
  echo sanlogin=ВАШ ЛОГИН
  echo sanpass=ВАШ ПАРОЛЬ
  exit 5
fi

# логинимся (куки в sankaku.txt)
echo Logging in...
ATH=`curl -# -s -c sankaku.txt -F"commit=Login" -F"user[name]=${sanlogin}" -F"user[password]=${sanpass}" https://chan.sankakucomplex.com/user/authenticate`

# Проверка логина
checklog=`cat sankaku.txt |grep pass_hash|wc -l`
if [ $checklog -eq 0 ]
then
  echo ERROR: Проверьте логин и пароль
  rm sankaku.txt
  exit 2
else
  echo OK
fi

# Удаление старого списка
if [ -e get.sankaku.txt ]
then
  rm -f get.sankaku.txt
fi

# Загрузка до тех пор, пока в выдаче будет 0 ссылок
pagenum=1
picnum=1

until [ $picnum -eq 0 ]
do
  # Получение списка
  wget --no-check-certificate --load-cookies=sankaku.txt "https://chan.sankakucomplex.com/post/index.json?tags=$tags&page=$pagenum" -O out.dat --referer="https://chan.sankakucomplex.com/" -U "$uag"
  cat out.dat | pcregrep --buffer-size=1M -o -e 'file_url\":\"[^\"]+'|sed -e 's/\"//g' -e 's/file_url/https/g' -e 's/\?.*//g' > tmp.sankaku.txt
  picnum=`cat tmp.sankaku.txt|wc -l`
  if [ $picnum \> 0 ]
  then
    cat tmp.sankaku.txt >> get.sankaku.txt
    let "pagenum++"
  fi
done;

# Проверка количетсва
postcount=`cat get.sankaku.txt|wc -l`

if [ $postcount -eq 0 ]
then
  echo По сочетанию "$tags" ничего не найдено.
  exit 3
else
  echo По сочетанию "$tags" найдено постов: $postcount
fi

wget --random-wait --no-check-certificate -nc -i get.sankaku.txt -U "$uag"

# убираем за собой
rm -f tmp.sankaku.txt sankaku.txt out.dat
