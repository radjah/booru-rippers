#!/bin/bash

# Проверка параметров

printhelp () {
echo Использование: $0 id_художника каталог
}

if [ "$2" = "" ]
then
  echo Каталог для сохранения не указан.
  if [ "$1" = "" ]
  then
    echo ID ходжника не указан.
  fi
  printhelp
  exit 1
fi


dldr='aria2c --remote-time'
dirlet=`echo $2|cut -c-1`

if [ ! -d ${dirlet,,}/$2 ]
then
  echo Creating ${dirlet,,}/$2
  mkdir -p "${dirlet,,}/$2"
else
  dldr='wget -nc'
fi
echo Entering ${dirlet,,}/$2
cd ${dirlet,,}/$2

# ярлык на страницу автора
echo \[InternetShortcut\] > "$2.url"
echo URL=http\:\/\/www.pixiv.net\/member_illust.php\?id=$1 >> "$2.url"

# настройки
# id художника (athid) берется из URL вида http://www.pixiv.net/member_illust.php?id=18530, где 18530 и есть искомый параметр.
pixid=ЛОГИН
pixpass=ПАРОЛЬ
athid=$1

# логинимся (куки в pixiv.txt)
echo Logging in...
AUTH=`curl -k -s -c pixiv.txt -F"mode=login" -F"pass=${pixpass}" -F"pixiv_id=${pixid}" -F"skip=1" https://www.secure.pixiv.net/login.php`

# функция для получения списков
getlist () {

# счетчики
picnum=1
pagenum=1

until [ $picnum -eq 0 ]
do
  # страница для парсинга
  wget --load-cookies=pixiv.txt "http://www.pixiv.net/member_illust.php?type=$1&id=$athid&p=$pagenum" -O - --referer="http://www.pixiv.net/" > out.dat
  
  # Самый старый формат (скорее всего уже ничего не даст, но пусть будет)
  cat out.dat|pcregrep -o -e 'http\:\/\/i\d{1,3}\.pixiv\.net\/img\d{1,3}\/img\/[^\"]+' > out.int.txt
  # Вторая редакция (основная масса)
  cat out.dat|pcregrep -o -e 'http\:\/\/i\d{1,3}\.pixiv\.net\/img-inf\/img\/[^\"]+' >> out.int.txt
  # Третья редакция (26.09.2014). Заканчивается на _p0
  cat out.dat|pcregrep -o -e "http\:\/\/i\d{1,3}\.pixiv\.net\/c\/150x150\/img-master[^\"]+" > out.new.txt
  # Все вместе
  cat out.int.txt|sed 's/_s\./\./' | sed 's/\?.*//' > out.txt
  # Сколько нашли на текущей странице?
  picnum=`cat out.txt out.new.txt|wc -l`
  if [ $picnum \> 0 ]
  then
    cat out.txt >> get.pixiv.$2.txt
    if [ -s out.new.txt ]
    then
      cat out.new.txt >> out.new.$2.txt
    fi
    let "pagenum++"
  fi
done;

# Если вдруг вообще ничего не нашли
touch get.pixiv.$2.txt get.pixiv.$2.alt.txt get.pixiv.$2.new.txt

if [ -s get.pixiv.$2.txt ]
then
  # Отделяем вторую редакцию от всего списка
  basename -a `cat get.pixiv.$2.txt| grep img-inf`|sed 's/\..*//' > get.pixiv.$2.alt.txt
fi

if [ -s out.new.$2.txt ]
then
  # Третья редакция. basename может ругнуться
  basename -a `cat out.new.$2.txt`|sed 's/\..*//'| sed 's/_p0_master1200//g' > get.pixiv.$2.new.txt
fi

}

getlist illust pics
getlist manga album
getlist ugoira anim

#########################
# Одиночные изображения #
#########################

# Отделяем альбомы от одиночных изображений. Актуально для новых ссылок.

for i in `cat get.pixiv.pics.new.txt`
do
  ismanga=`wget --load-cookies=pixiv.txt "http://www.pixiv.net/member_illust.php?mode=medium&illust_id=$i" -O - --referer="http://www.pixiv.net/"|pcregrep --buffer-size=1M  -o -e 'mode=manga[^\"]+'|wc -l`
  if [ $ismanga -gt 0 ]
  then
    echo $i >> get.pixiv.album.new.txt
  else
    echo $i >> get.pixiv.pics.alt.txt
  fi
done;

# Обрабатываем отфильтрованное
for i in `cat get.pixiv.pics.alt.txt`
do
  wget "http://www.pixiv.net/member_illust.php?mode=big&illust_id=$i" --load-cookies=pixiv.txt --referer="http://www.pixiv.net/member_illust.php?mode=medium&illust_id=$i" -O -|pcregrep --buffer-size=1M -o -e 'http\:\/\/i\d{1,3}\.pixiv\.net\/img[^\"]+' >> get.pixiv.pics.dl.txt
done;

# Скачивание
if [ -s get.pixiv.pics.dl.txt ] 
then
  cat get.pixiv.pics.dl.txt| sed 's/\?.*//'  > get.pixiv.pics.clean.txt
  $dldr -i get.pixiv.pics.clean.txt --referer="http://www.pixiv.net/"
fi

###########################
# Альбомы с изображениями #
###########################

#############################
# Обработка старых альбомов #
#############################

if [ -s get.pixiv.album.alt.txt ]
then
  for i in `cat get.pixiv.album.alt.txt`
  do
    wget "http://www.pixiv.net/member_illust.php?mode=manga&illust_id=$i&type=scroll" --load-cookies=pixiv.txt --referer="http://www.pixiv.net/" -O -|pcregrep --buffer-size=1M -o -e "http\:\/\/i\d{1,3}\.pixiv\.net\/img\d{1,3}\/img\/[^(\'|\?|\")]+" -e "http\:\/\/i\d{1,3}\.pixiv\.net\/img-inf\/img\/[^(\'|\?|\")]+"| sed -e 's/_p/_big_p/g' -e 's/\?.*//'>> get.pixiv.album.dl.alt.txt
  done;
fi

# Чистка от мусора и левых ссылок
if [ -s get.pixiv.album.dl.alt.txt ]
then
  cat get.pixiv.album.dl.alt.txt|grep -v '\/mobile\/'|sort|uniq > get.pixiv.album.dl.clean.txt
  mv get.pixiv.album.dl.clean.txt get.pixiv.album.dl.alt.txt
  $dldr -i get.pixiv.album.dl.alt.txt --referer="http://www.pixiv.net/"
fi

# Список скаченного
ls *.jpg *.png *.gif|grep big|sed 's/_big[^\.]*//g'|sed 's/\..*//g'|sort|uniq > get.pixiv.album.dld.txt

# get.pixiv.album.dl.alt.txt   - список id всех альбомов
# get.pixiv.album.dld.txt      - список скаченного
# get.pixiv.album.small.txt    - список нескаченного

cat get.pixiv.album.alt.txt|sort > get.pixiv.album.sort.alt.txt
comm -2 -3 get.pixiv.album.dld.txt get.pixiv.album.sort.alt.txt|sort|uniq -u > get.pixiv.album.small.txt

if [ -s get.pixiv.album.small.txt ]
then
  for i in `cat get.pixiv.album.small.txt`
  do
    wget "http://www.pixiv.net/member_illust.php?mode=manga&illust_id=$i&type=scroll" --load-cookies=pixiv.txt --referer="http://www.pixiv.net/" -O out.dat
    cat out.dat|pcregrep --buffer-size=1M -o -e "http\:\/\/i\d{1,3}\.pixiv\.net\/img\d{1,3}\/img\/[^(\'|\?|\")]+" -e "http\:\/\/i\d{1,3}\.pixiv\.net\/img-inf\/img\/[^(\'|\?|\")]+" >> get.pixiv.album.dl.small.txt
    # для обработки скриптового листания манги
    cat out.dat|sed 's#\\\/#\/#g'|pcregrep --buffer-size=1M -o -e "http\:\/\/i\d{1,3}\.pixiv\.net\/img\d{1,3}\/img\/[^(\'|\?|\")]+" -e "http\:\/\/i\d{1,3}\.pixiv\.net\/img[^\")]+"|grep -v '/mobile/'|grep 'big' >> get.pixiv.album.dl.small.txt
  done;
  if [ -s get.pixiv.album.dl.small.txt ] 
  then
    cat get.pixiv.album.dl.small.txt|grep -v '\/mobile\/'|sort|uniq > get.pixiv.album.dl.small.clean.txt
    mv get.pixiv.album.dl.small.clean.txt get.pixiv.album.dl.small.txt
    $dldr -i get.pixiv.album.dl.small.txt --referer="http://www.pixiv.net/"
  fi
fi

############################
# Обработка новых альбомов #
############################

if [ -s get.pixiv.album.new.txt ]
then
  for i in `cat get.pixiv.album.new.txt`
  do
    wget "http://www.pixiv.net/member_illust.php?mode=manga&illust_id=$i&type=scroll" --load-cookies=pixiv.txt --referer="http://www.pixiv.net/" -O -|pcregrep --buffer-size=1M -o -e "http\:\/\/i\d{1,3}\.pixiv\.net\/c[^\"]+"| sed -e 's#c\/1200x1200\/img-master#img-original#g' -e 's/_master1200//'>> get.pixiv.album.dl.new.txt
  done;
  if [ -s get.pixiv.album.dl.new.txt ] 
  then
    $dldr -i get.pixiv.album.dl.new.txt --referer="http://www.pixiv.net/"
  fi
fi

# URL больших картинок могут не совпадать с маленькими
# Отдельный парсер для таких случаев
if [ -s get.pixiv.album.dl.new.txt ]
then
  basename -a `cat get.pixiv.album.dl.new.txt`|sed 's#_.*##g'|uniq > get.pixiv.albums.bad.txt
  for i in `cat get.pixiv.albums.bad.txt`
  do
    # Если файлов меньше одного, то альбом не скачался
    if [ `ls $i*|wc -l` -le `cat get.pixiv.album.dl.new.txt|grep $i|wc -l` ]
      then
        pagenum=0
        picnum=1
        # пока ни одной сслыки не будет найдено (страница с ошибкой)
        until [ $picnum -eq 0 ]
        do
          wget "http://www.pixiv.net/member_illust.php?mode=manga_big&illust_id=$i&page=$pagenum"  --load-cookies=pixiv.txt --referer="http://www.pixiv.net/member_illust.php?mode=manga&illust_id=$i" -O out.dat
          picnum=`cat out.dat|pcregrep -o  -e 'http\:\/\/i\d{1,3}\.pixiv\.net\/img[^\"]+'|grep -v ugoira|wc -l`
          cat out.dat|pcregrep -o  -e 'http\:\/\/i\d{1,3}\.pixiv\.net\/img[^\"]+' >> get.pixiv.albums.new.list.txt
          let "pagenum++"
        done;
    fi
  done;
  if [ -s get.pixiv.albums.new.list.txt ] 
  then
    $dldr -i get.pixiv.albums.new.list.txt --referer="http://www.pixiv.net/"
  fi
fi


######################
# Архивы с анимацией #
######################

# Здесь важны только id
if [ -s get.pixiv.anim.txt ]
then
  for i in `cat get.pixiv.anim.alt.txt get.pixiv.anim.new.txt`
  do
    wget "http://www.pixiv.net/member_illust.php?mode=medium&illust_id=$i" --load-cookies=pixiv.txt --referer="http://www.pixiv.net/member_illust.php?mode=medium&illust_id=$i" -O -|pcregrep --buffer-size=1M -o -e 'FullscreenData.+\.zip'|pcregrep -o -e 'http.+'|sed 's/\\//g' >> get.pixiv.anim.dl.txt
  done;
fi

# Скачивание
if [ -s get.pixiv.anim.dl.txt ] 
then
  $dldr -i get.pixiv.anim.dl.txt --referer="http://www.pixiv.net/"
fi

# удаляем мусор

if [ ! $3 ]
then
  rm -f *.txt list* out.*
fi
