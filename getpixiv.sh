#! /bin/bash

dldr='aria2c --remote-time'
dirlet=`echo $3|cut -c-1`
if [ ! -d ${dirlet,,}/$3 ]
then
echo Creating ${dirlet,,}/$3
mkdir -p "${dirlet,,}/$3"
else
dldr='wget -nc'
fi
echo Entering ${dirlet,,}/$3
cd ${dirlet,,}/$3

# ярлык на страницу автора
echo \[InternetShortcut\] > "$3.url"
echo URL=http\:\/\/www.pixiv.net\/member_illust.php\?id=$1 >> "$3.url"

# настройки
# id художника (athid) берется из URL вида http://www.pixiv.net/member_illust.php?id=18530, где 18530 и есть искомый параметр.
pixid=ЛОГИН
pixpass=ПАРОЛЬ
picnum=$2
let "pagenum=picnum/20+1"
athid=$1

# логинимся (куки в pixiv.txt)
# AUTH=`curl -s -c pixiv.txt -F"mode=login" -F"pass=${pixpass}" -F"pixiv_id=${pixid}" -F"skip=1" http://www.pixiv.net/index.php`
AUTH=`curl -k -s -c pixiv.txt -F"mode=login" -F"pass=${pixpass}" -F"pixiv_id=${pixid}" -F"skip=1" https://www.secure.pixiv.net/login.php`

# качаем все страницы с картинками и парсим их на ходу
for ((i=1;i<=$pagenum;i++))
do
wget --load-cookies=pixiv.txt "http://www.pixiv.net/member_illust.php?id=$athid&p=$i" -O - --referer="http://www.pixiv.net/"|pcregrep -o  -e 'http\:\/\/i\d{1,3}\.pixiv\.net\/img-inf\/img\/[^\"]+' -e 'http\:\/\/i\d{1,3}\.pixiv\.net\/img\d{1,3}\/img\/[^\"]+'|sed 's/_s\./\./' | sed 's/\?.*//'>> get.pixiv.all.txt
done;

# Чистка от левых дописок к имени файла
cat get.pixiv.all.txt| sed 's/\?.*//' > get.pixiv.all.txt.tmp
mv get.pixiv.all.txt.tmp get.pixiv.all.txt

# Отделяем новые хитрые ссылки и составляем список всех id работ
basename -a `cat get.pixiv.all.txt| grep img-inf`|sed 's/\..*//' > get.pixiv.alt.txt
basename -a `cat get.pixiv.all.txt`| sed 's/\..*//g'|sort > pixiv.allid.txt
cat get.pixiv.all.txt | grep -v img-inf > get.pixiv.txt.tmp
mv get.pixiv.txt.tmp get.pixiv.txt

# Парсим страницы
# Парсим "новые" типы ссылок
for i in `cat get.pixiv.alt.txt`
do
wget "http://www.pixiv.net/member_illust.php?mode=big&illust_id=$i" --load-cookies=pixiv.txt --referer="http://www.pixiv.net/member_illust.php?mode=medium&illust_id=$i" -O -|pcregrep -o  -e 'http\:\/\/i\d{1,3}\.pixiv\.net\/img\d{1,3}\/img\/[^\"]+' >> get.pixiv.txt
done;

# Чистка от левых дописок к имени файла
cat get.pixiv.txt| sed 's/\?.*//' > get.pixiv.txt.tmp
mv get.pixiv.txt.tmp get.pixiv.txt

# Получаем id всего, что напарсили, кроме анимации
basename -a `cat get.pixiv.txt`| sed 's/\..*//g'|sort > pixiv.dlid.txt
# Выдергиваем id постов с анимацией
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
cat get.pixiv.txt |sed 's/http\:\/\/i[^\/]*\/img[0-9]*\/img\/[^\/]*\///g'|sed 's/\..*//g'|sort|uniq > list1
# список id всего из папки
# list2 - список преобразованных имен файлов из папки без альбомов
ls *.jpg *.png *.gif|grep -v _ |sed 's/\..*//g'|sort > list2
# выводим id из первого файла, для которых нет файлов в папке
# cat list1 list2|sort|uniq -u > list3
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
  if [ -s get.pixiv.anim.txt ] 
  then
    $dldr -i get.pixiv.anim.txt --referer="http://www.pixiv.net/"
  fi
fi

# удаляем палево

rm -f *.txt list*
