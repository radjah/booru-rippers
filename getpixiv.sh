#!/bin/bash

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
picnum=1
pagenum=1
athid=$1

# логинимся (куки в pixiv.txt)
echo Logging in...
AUTH=`curl -k -s -c pixiv.txt -F"mode=login" -F"pass=${pixpass}" -F"pixiv_id=${pixid}" -F"skip=1" https://www.secure.pixiv.net/login.php`

# качаем все страницы с картинками и парсим их на ходу
# out.new.all.txt для дальнейшей фильтрации
until [ $picnum -eq 0 ]
do
  wget --load-cookies=pixiv.txt "http://www.pixiv.net/member_illust.php?id=$athid&p=$pagenum" -O - --referer="http://www.pixiv.net/" > out.dat
  
  # Самый старый формат
  cat out.dat|pcregrep -o -e 'http\:\/\/i\d{1,3}\.pixiv\.net\/img\d{1,3}\/img\/[^\"]+' > out.int.txt
  # Вторая редакция
  cat out.dat|pcregrep -o -e 'http\:\/\/i\d{1,3}\.pixiv\.net\/img-inf\/img\/[^\"]+' >> out.int.txt
  # Третья редакция (26.09.2014) Заканчивается на _p0
  cat out.dat|pcregrep -o -e "http\:\/\/i\d{1,3}\.pixiv\.net\/c\/150x150\/img-master[^\"]+" > out.new.txt
  # Дописываем ко всем
  cat out.new.txt >> out.int.txt
  # Все вместе
  cat out.int.txt|sed 's/_s\./\./' | sed 's/\?.*//' | sed 's/_p0_master1200\./\./g' > out.txt
  # Сколько нашли на текущей странице?
  picnum=`cat out.txt|wc -l`
  if [ $picnum \> 0 ]
  then
    cat out.txt >> get.pixiv.all.txt
    if [ -s out.new.txt ]
    then
      cat out.new.txt >> out.new.all.txt
    fi
    let "pagenum++"
  fi
done;

# Отделяем новые хитрые ссылки и составляем список всех id работ
# Вторая редация
basename -a `cat get.pixiv.all.txt| grep img-inf`|sed 's/\..*//' > get.pixiv.alt.txt
# Третья редакция. basename может ругнуться
basename -a `cat get.pixiv.all.txt| grep img-master\/img`|sed 's/\..*//' > get.pixiv.new.txt
cat get.pixiv.new.txt >> get.pixiv.alt.txt
# id всех работ
basename -a `cat get.pixiv.all.txt`| sed 's/\..*//g'|sort > pixiv.allid.txt
# Первая редация
cat get.pixiv.all.txt | grep -v img-inf|grep -v img-master\/img > get.pixiv.txt

# Специальная обработка для третьей редакции
# Сначала считаем все id альбомами

for i in `cat get.pixiv.new.txt`
do
    wget "http://www.pixiv.net/member_illust.php?mode=manga&illust_id=$i&type=scroll" --load-cookies=pixiv.txt --referer="http://www.pixiv.net/" -O -|pcregrep --buffer-size=1M -o -e "http\:\/\/i\d{1,3}\.pixiv\.net\/c[^\"]+"| sed -e 's#c\/1200x1200\/img-master#img-original#g' -e 's/_master1200//'>> get.pixiv.albums.new.txt
done;

$dldr -i get.pixiv.albums.new.txt --referer="http://www.pixiv.net/"

# URL больших картинок могут не совпадать с маленькими
# Отдельный парсер для таких случаев
basename -a `cat get.pixiv.albums.new.txt`|sed 's#_.*##g'|uniq > get.pixiv.albums.bad.txt
for i in `cat get.pixiv.albums.bad.txt`
do
  # Если файлов меньше двух (точно альбом, а не одиночная картинка)
  if [ `ls $i*|wc -l` -le 2 ]
    then
      pagenum=0
      picnum=1
      # пока ни одной сслыки не будет найдено (страница с ошибкой)
      until [ $picnum -eq 0 ]
      do
        wget "http://www.pixiv.net/member_illust.php?mode=manga_big&illust_id=$i&page=$pagenum"  --load-cookies=pixiv.txt --referer="http://www.pixiv.net/member_illust.php?mode=manga&illust_id=$i" -O out.dat
        picnum=`cat out.dat|pcregrep -o  -e 'http\:\/\/i\d{1,3}\.pixiv\.net\/img[^\"]+'|grep -v ugoira|wc -l`
        cat out.dat|pcregrep -o  -e 'http\:\/\/i\d{1,3}\.pixiv\.net\/img[^\"]+'|grep -v ugoira >> get.pixiv.albums.new.list.txt
        let "pagenum++"
      done;
  fi
done;

$dldr -i get.pixiv.albums.new.list.txt --referer="http://www.pixiv.net/"
# Парсим страницы
# Парсим ссылки редации 2 и 3
for i in `cat get.pixiv.alt.txt`
do
  wget "http://www.pixiv.net/member_illust.php?mode=big&illust_id=$i" --load-cookies=pixiv.txt --referer="http://www.pixiv.net/member_illust.php?mode=medium&illust_id=$i" -O -|pcregrep -o  -e 'http\:\/\/i\d{1,3}\.pixiv\.net\/img[^\"]+'|grep -v ugoira >> get.pixiv.txt
done;

# Чистка от левых дописок к имени файла
cat get.pixiv.txt| sed 's/\?.*//' > get.pixiv.txt.tmp
mv get.pixiv.txt.tmp get.pixiv.txt

# Получаем id всего, что напарсили, кроме анимации
basename -a `cat get.pixiv.txt`| sed 's/\..*//g'| sed 's/\_p0//g'|sort > pixiv.dlid.txt
# Выдергиваем id постов с анимацией, для них не нашли URL-картинок.
comm -2 -3 pixiv.allid.txt pixiv.dlid.txt|sort > pixiv.animid.txt

# Качаем анимацию

for i in `cat pixiv.animid.txt`
do
  wget "http://www.pixiv.net/member_illust.php?mode=medium&illust_id=$i" --load-cookies=pixiv.txt --referer="http://www.pixiv.net/member_illust.php?mode=medium&illust_id=$i" -O -|pcregrep --buffer-size=1M -o -e 'FullscreenData.+\.zip'|pcregrep -o -e 'http.+'|sed 's/\\//g' >> get.pixiv.anim.txt
done;

# качаем все картинки, которые нашли

$dldr -i get.pixiv.txt --referer="http://www.pixiv.net/"

# список id всего напарсеннго
# list1 - список всех id
basename -a `cat get.pixiv.txt`| sed 's/\..*//g'| sed 's/\_p0//g'|sort|uniq > list1
# список id всего из папки
# list2 - список преобразованных имен файлов из папки без альбомов
ls *.jpg *.png *.gif|grep -v _ |sed 's/\..*//g' > list2.tmp
# Дописываем третью редакию
# Отдельно id для третьей редакции
if [ -s out.new.all.txt ]
then
  basename -a `cat out.new.all.txt`|sed 's/_p0_master1200\..*//g' > out.new.id.txt
else
  touch out.new.id.txt
fi
cat out.new.id.txt list2.tmp|sort|uniq > list2
# выводим id из первого файла, для которых нет файлов в папке
comm -2 -3 list1 list2|sort > list3

# list3 список недокаченного. Скорее всего альбомы

if [ -s list3 ]
then
  for i in `cat list3`
  do
    wget "http://www.pixiv.net/member_illust.php?mode=manga&illust_id=$i&type=scroll" --load-cookies=pixiv.txt --referer="http://www.pixiv.net/" -O -|pcregrep --buffer-size=1M -o -e "http\:\/\/i\d{1,3}\.pixiv\.net\/img\d{1,3}\/img\/[^(\'|\?|\")]+" -e "http\:\/\/i\d{1,3}\.pixiv\.net\/img-inf\/img\/[^(\'|\?|\")]+"| sed -e 's/_p/_big_p/g' -e 's/\?.*//'>> get.pixiv.albums.txt
  done;
fi

# Чистка от мусора в выдаче

if [ -s get.pixiv.albums.txt ]
then
  cat get.pixiv.albums.txt|grep -v '\/mobile\/'|sort|uniq > get.pixiv.albums.clean.txt
  mv get.pixiv.albums.clean.txt get.pixiv.albums.txt
  $dldr -i get.pixiv.albums.txt --referer="http://www.pixiv.net/"
  rm get.pixiv.albums.txt
fi

# Докачиваем альбомы без _big
ls *.jpg *.png *.gif|grep big|sed 's/_big[^\.]*//g'|sed 's/\..*//g'|sort|uniq > list4
# list4 - список преобразованных имен файлов из альбомов (id альбомов)

if [ -s list4 ]
then
  comm -2 -3 list3 list4|sort|uniq -u > list5
  for i in `cat list5`
  do
    wget "http://www.pixiv.net/member_illust.php?mode=manga&illust_id=$i&type=scroll" --load-cookies=pixiv.txt --referer="http://www.pixiv.net/" -O -|pcregrep --buffer-size=1M -o -e "http\:\/\/i\d{1,3}\.pixiv\.net\/img\d{1,3}\/img\/[^(\'|\?|\")]+" -e "http\:\/\/i\d{1,3}\.pixiv\.net\/img-inf\/img\/[^(\'|\?|\")]+" >> get.pixiv.albums.txt
  done;
  if [ -s get.pixiv.albums.txt ] 
  then
    cat get.pixiv.albums.txt|grep -v '\/mobile\/'|sort|uniq > get.pixiv.albums.clean.txt
    mv get.pixiv.albums.clean.txt get.pixiv.albums.txt
    $dldr -i get.pixiv.albums.txt --referer="http://www.pixiv.net/"
  fi
else
  # Чтобы comm не ругалась
  touch list5
fi

# Добиваем анимацию

# Список id посленего скаченного
# list6 - список id скаченного в последнем проходе по альбомам

if [ -s get.pixiv.albums.txt ]
then
  basename -a `cat get.pixiv.albums.txt`|sed 's/_.*//g'|sort|uniq > list6
  comm -2 -3 list5 list6|sort > list7

  for i in `cat list7`
  do
    wget "http://www.pixiv.net/member_illust.php?mode=medium&illust_id=$i" --load-cookies=pixiv.txt --referer="http://www.pixiv.net/member_illust.php?mode=medium&illust_id=$i" -O -|pcregrep --buffer-size=1M -o -e 'FullscreenData.+\.zip'|pcregrep -o -e 'http.+'|sed 's/\\//g' >> get.pixiv.anim.txt
  done;
fi

# Докачиваем анимацию
if [ -s get.pixiv.anim.txt ] 
  then
    $dldr -i get.pixiv.anim.txt --referer="http://www.pixiv.net/"
fi

# удаляем палево

rm -f *.txt list* out.*
