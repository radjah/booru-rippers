#!/bin/bash

# Проверка параметров
athid=$1
savedir=$2
if [ "$savedir" = "" ]
then
  if [ "$athid" = "" ]
  then
    echo Не указан ID художника и каталог!
  fi
  echo Использование: `basename $0` id_художника каталог
  exit 1
fi


dldr='aria2c --remote-time'
dirlet=`echo $savedir|cut -c-1`

if [ ! -d ${dirlet,,}/$savedir ]
then
  echo Creating ${dirlet,,}/$savedir
  mkdir -p "${dirlet,,}/$savedir"
else
  dldr='wget -nc'
fi
echo Entering ${dirlet,,}/$savedir
cd ${dirlet,,}/$savedir

# настройки
# id художника (athid) берется из URL вида http://www.pixiv.net/member_illust.php?id=18530, где 18530 и есть искомый параметр.
if [ -f ~/.config/boorulogins.conf ]
then
  . ~/.config/boorulogins.conf
else
  echo Файл с данными для авторизации не найден!
  echo Создайте файл ~/.config/boorulogins.conf и поместите в него следующие строки:
  echo pixid=ВАШ ЛОГИН
  echo pixpass=ВАШ ПАРОЛЬ
  exit 5
fi

# поиск и удаление дублей
finddups () {
  fdupes . |grep -v .txt| grep -v "^$" > dups.pixiv.txt
  if [ -s dups.pixiv.txt ]
  then
    cat dups.pixiv.txt |grep -v _|xargs -l1 rm
    cat dups.pixiv.txt |grep _big|xargs -l1 rm
  fi
} # finddups

# логинимся (куки в pixiv.txt)
pixlogin () {
# ярлык на страницу автора для общей кучи
echo \[InternetShortcut\] > "$savedir.url"
echo URL=http\:\/\/www.pixiv.net\/member_illust.php\?id=$athid >> "$savedir.url"
echo Logging in...
AUTH=`curl -k -s -c pixiv.txt -F"mode=login" -F"pass=${pixpass}" -F"pixiv_id=${pixid}" -F"skip=1" https://www.secure.pixiv.net/login.php`

# Проверка логина
checklog=`cat pixiv.txt |grep device_token|wc -l`
if [ $checklog -eq 0 ]
then
  echo ERROR: Проверьте логин и пароль
  rm pixiv.txt
  exit 2
else
  echo OK
fi
}

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
  basename -a `cat get.pixiv.$2.txt| grep img-inf`|sed 's/\..*//'| sed 's/-.*//g' > get.pixiv.$2.alt.txt
fi

if [ -s out.new.$2.txt ]
then
  # Третья редакция. basename может ругнуться
  basename -a `cat out.new.$2.txt`|sed 's/\..*//'| sed 's/_p0_master1200//g'| sed 's/-.*//g' > get.pixiv.$2.new.txt
fi

} # getlist

# удаляем мусор
rmtrash () {
if [ ! $1 ]
then
  rm -f get*.txt *pixiv.txt list* out.*
fi
} # rmtrash

#########################
# Одиночные изображения #
#########################

procsingle () {

# Отделяем альбомы от одиночных изображений. Актуально для новых ссылок.
# И костылик для альбомов, которые в категории "Манга", но на самом деле одиночные изображения

for i in `cat get.pixiv.pics.new.txt get.pixiv.album.new.txt`
do
  ismanga=`wget --load-cookies=pixiv.txt "http://www.pixiv.net/member_illust.php?mode=medium&illust_id=$i" -O - --referer="http://www.pixiv.net/"|pcregrep --buffer-size=1M  -o -e 'mode=manga[^\"]+'|wc -l`
  if [ $ismanga -gt 0 ]
  then
    echo $i >> get.pixiv.album.new.txt
    echo [*] $i is album
  else
    echo $i >> get.pixiv.pics.alt.txt
    echo [*] $i is single image
  fi
done;

# Сортируем и вычленяем настоящие альбомы.
cat get.pixiv.album.new.txt|sort|uniq > get.pixiv.album.new.sort.txt
cat get.pixiv.pics.alt.txt|sort > get.pixiv.pics.alt.sort.txt
comm -2 -3 get.pixiv.album.new.sort.txt get.pixiv.pics.alt.sort.txt > get.pixiv.album.new.txt

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

} # procsingle

###########################
# Альбомы с изображениями #
###########################

#############################
# Обработка старых альбомов #
#############################

procoldalbums () {

if [ -s get.pixiv.album.alt.txt ]
then
  for i in `cat get.pixiv.album.alt.txt`
  do
    wget "http://www.pixiv.net/member_illust.php?mode=manga&illust_id=$i&type=scroll" --load-cookies=pixiv.txt --referer="http://www.pixiv.net/" -O -|pcregrep --buffer-size=1M -o -e "http\:\/\/i\d{1,3}\.pixiv\.net\/img\d{1,3}\/img\/[^(\'|\?|\")]+" -e "http\:\/\/i\d{1,3}\.pixiv\.net\/img-inf\/img\/[^(\'|\?|\")]+"| sed -e 's/\?.*//'>> get.pixiv.album.dl.alt.txt
  done;
fi

# Чистка от мусора и левых ссылок
if [ -s get.pixiv.album.dl.alt.txt ]
then
  cat get.pixiv.album.dl.alt.txt|grep -v '\/mobile\/'|sort|uniq > get.pixiv.album.dl.clean.txt
  mv get.pixiv.album.dl.clean.txt get.pixiv.album.dl.alt.txt
  # Костыль для обхода  _p в именах юзеров
  dirname `cat get.pixiv.album.dl.alt.txt` > get.pixiv.album.dl.alt.dir.txt
  basename -a `cat get.pixiv.album.dl.alt.txt`|sed -e 's/_p/_big_p/g' > get.pixiv.album.dl.alt.fn.txt
  paste -d "/" get.pixiv.album.dl.alt.dir.txt get.pixiv.album.dl.alt.fn.txt|sort > get.pixiv.album.dl.alt.txt
  # Закачка
  $dldr -i get.pixiv.album.dl.alt.txt --referer="http://www.pixiv.net/"
fi

# Список скаченного
ls *.jpg *.png *.gif|grep big|sed 's/_big[^\.]*//g'|sed 's/\..*//g'|sort|uniq > get.pixiv.album.dld.txt

# get.pixiv.album.dl.alt.txt   - список id всех альбомов
# get.pixiv.album.dld.txt      - список скаченного
# get.pixiv.album.small.txt    - список нескаченного

cat get.pixiv.album.alt.txt|sort > get.pixiv.album.sort.alt.txt
comm -2 -3 get.pixiv.album.sort.alt.txt get.pixiv.album.dld.txt|sort|uniq -u > get.pixiv.album.small.txt

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

} # procoldalbums

############################
# Обработка новых альбомов #
############################

procnewalbums () {

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
  basename -a `cat get.pixiv.album.dl.new.txt`|sed -e 's#_.*##g' -e 's/-.*//g' |uniq > get.pixiv.albums.bad.txt
  for i in `cat get.pixiv.albums.bad.txt`
  do
    # Если файлов меньше одного, то альбом не скачался
    if [ `ls $i*|wc -l` -lt `cat get.pixiv.album.dl.new.txt|grep $i|wc -l` ]
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
    else
      echo [*] $i already downloaded.
    fi
  done;
  if [ -s get.pixiv.albums.new.list.txt ] 
  then
    $dldr -i get.pixiv.albums.new.list.txt --referer="http://www.pixiv.net/"
  fi
fi

} # procnewalbums

######################
# Архивы с анимацией #
######################

procanim () {

# Здесь важны только id
if [ -s get.pixiv.anim.txt ]
then
  for i in `cat get.pixiv.anim.alt.txt get.pixiv.anim.new.txt`
  do
    # Получение страницы
    wget "http://www.pixiv.net/member_illust.php?mode=medium&illust_id=$i" --load-cookies=pixiv.txt --referer="http://www.pixiv.net/member_illust.php?mode=medium&illust_id=$i" -O out.ugo
    # Получение ссылки
    cat out.ugo|pcregrep --buffer-size=1M -o -e 'FullscreenData.+?\.zip'|pcregrep -o -e 'http.+'|sed 's/\\//g' >> get.pixiv.anim.dl.txt
    # Сохранение информации для анимацией
    cat out.ugo|pcregrep --buffer-size=1M -o -e 'ugokuIllustFullscreenData.*\}\]\}'|pcregrep -o -e 'frames.*\}\]\}'|sed -e 's#},{#\n#g' -e 's/frames\"\:\[{//g' -e 's/\}\]\}//g' > ${i}_ugoira1920x1080.txt
  done;
fi

# Скачивание
if [ -s get.pixiv.anim.dl.txt ] 
then
  $dldr -i get.pixiv.anim.dl.txt --referer="http://www.pixiv.net/"
fi

} # procanim

# очистка в любом случае
trap rmtrash 1 2 3 15

# Обработка всего и вся

# Блокировка

exec < .
flock -n 0


# Если никто каталог не занял, то работаем

if [ $? -eq 0 ]
then
  pixlogin
  echo [*] Building illust list...
  getlist illust pics
  echo [*] Building albums list...
  getlist manga album
  echo [*] Building animation list...
  getlist ugoira anim
  echo [*] Processing illust list...
  procsingle
  echo [*] Processing albums list...
  echo [*] 1/2 old
  procoldalbums
  echo [*] 2/2 new
  procnewalbums
  echo [*] Processing animation list...
  procanim
  echo [*] Removing dups...
  finddups
  echo [*] Removing trash...
  rmtrash $3
  flock -u 0
  echo [*] FINISHED!
else
  echo [!] ERROR! Каталог сохранения уже обрабатывается!
  exit 4
fi
