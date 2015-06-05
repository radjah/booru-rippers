#!/bin/bash

# Данные учетки

if [ -f ~/.config/boorulogins.conf ]
then
  . ~/.config/boorulogins.conf
else
  echo Файл с данными для авторизации не найден!
  echo Создайте файл ~/.config/boorulogins.conf и поместите в него следующие строки:
  echo seigaid=ВАШ ЛОГИН
  echo seigapass=ВАШ ПАРОЛЬ
  exit 5
fi


# Папка для сохранения вида первая_буква_имени/имя

dirlet=`echo $2|cut -c-1`
if [ ! -d seiga/${dirlet,,}/$2 ]
then
echo Creating seiga/${dirlet,,}/$2
mkdir -p "seiga/${dirlet,,}/$2"
fi
echo Entering seiga/${dirlet,,}/$2
cd seiga/${dirlet,,}/$2

# ярлык на страницу автора
echo \[InternetShortcut\] > "$2.url"
echo URL=http\:\/\/seiga\.nicovideo\.jp\/user\/illust\/$1\?target=illust_all >> "$2.url"

# Логинимся и сохраняем куки

curl -k -s -c niko.txt -F"mail=${seigaid}" -F"password=${seigapass}" "https://secure.nicovideo.jp/secure/login?site=seiga"

# Чтобы не было запроса подтверждения возраста

echo "seiga.nicovideo.jp	FALSE	/	FALSE	4564805162	skip_fetish_warning	1" >> niko.txt

# Перебираем все страницы

picnum=1
pagenum=1
athid=$1

until [ $picnum -eq 0 ]
do
wget "http://seiga.nicovideo.jp/user/illust/$athid?page=$pagenum&target=illust_all" --load-cookies=niko.txt -O - |pcregrep -o -e 'lohas\.nicoseiga\.jp\/\/thumb\/[^q]+'|pcregrep -o -e '\d+'|awk '{ print "http://seiga.nicovideo.jp/image/source/"$0 }' > out.txt
  picnum=`cat out.txt|wc -l`
  # Если что-то напарсили
  if [ $picnum \> 0 ]
  then
    # Запоминаем
    cat out.txt >> get.seiga.all.txt
    let "pagenum++"
  fi
done;

# Проверяем уже скаченное

ls *.jp*g *.png *.gif|sed 's/\..*//g'|sort > pres.txt
basename -a `cat get.seiga.all.txt`|sort > all.txt
comm -2 -3 all.txt pres.txt  | awk '{ print "http://seiga.nicovideo.jp/image/source/" $0 }' > get.seiga.all.txt


# Качаем
if [ -s get.seiga.all.txt ]
then
  # Собираем URL изображений
  cat get.seiga.all.txt|xargs -l1 curl -b niko.txt -D - | grep Location > loclist.txt
  # Костыль для awk
  dos2unix loclist.txt
  # Дописываем расширение jpg для всех файлов
  cat loclist.txt| pcregrep -o -e 'http.+'|sed 's#/o/#/priv/#g'|awk -F"/" '{ print $0" -O "$NF".jpg" }' > list.txt
  # cat loclist.txt| pcregrep -o -e 'http.+'|sed 's#/o/#/priv/#g' > list.txt
  # Выкачиваем
  cat list.txt|xargs -t -l1 wget --load-cookies=niko.txt -nc
  # wget --content-disposition --load-cookies=niko.txt -nc -R "http://lohas.nicoseiga.jp/" -i list.txt
fi

# Убираем мусор
if [ ! $3 ]
then
  rm -rf out.txt get.seiga.all.txt niko.txt list.txt loclist.txt pres.txt all.txt
fi
