#!/bin/bash

# Юзергаент
uag="Mozilla/5.0 (Windows NT 6.3; WOW64; rv:40.0) Gecko/20100101 Firefox/40.0"

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

# Проверка параметров
athid=$1
savedir=$2

if [ "$savedir" = "" ]
then
  if [ "$athid" = "" ]
  then
    echo Не указан ID художника и каталог!
  fi
  echo Использование: $(basename $0) id_художника каталог
  exit 1
fi


# Папка для сохранения вида первая_буква_имени/имя

dirlet=$(echo $2|cut -c-1)
if [ ! -d seiga/$dirlet/$2 ]
then
echo Creating seiga/$dirlet/$2
mkdir -p "seiga/$dirlet/$2"
fi
echo Entering seiga/$dirlet/$2
cd seiga/$dirlet/$2



# ярлык на страницу автора
  echo \[InternetShortcut\] > "$savedir.url"
  echo URL=http\:\/\/seiga\.nicovideo\.jp\/user\/illust\/$athid\?target=illust_all >> "$savedir.url"

# Логинимся (куки в niko.txt)

seigalogin () {
# Логинимся и сохраняем куки
  if [ -e niko.txt ]
  then
    rm niko.txt
  fi
  curl -k -s -c niko.txt -F"mail=${seigaid}" -F"password=${seigapass}" "https://secure.nicovideo.jp/secure/login?site=seiga"

# Чтобы не было запроса подтверждения возраста

  echo "seiga.nicovideo.jp	FALSE	/	FALSE	4564805162	skip_fetish_warning	1" >> niko.txt

# Проверка логина
  checklog=$(cat niko.txt |grep user_session|wc -l)
  if [ $checklog -eq 0 ]
  then
    echo ERROR: Проверьте логин и пароль
    rm niko.txt
    exit 2
  else
    echo OK
  fi

}

seigalogin

# Перебираем все страницы

picnum=1
pagenum=1
athid=$1

until [ $picnum -eq 0 ]
do
  echo Page $pagenum
  curl -# "http://seiga.nicovideo.jp/user/illust/$athid?page=$pagenum&target=illust_all" -b niko.txt -A "$uag" |pcregrep -o -e 'lohas\.nicoseiga\.jp\/\/thumb\/[^q]+'|pcregrep -o -e '\d+'|awk '{ print "http://seiga.nicovideo.jp/image/source/"$0 }' > out.txt
  picnum=$(cat out.txt|wc -l)
  # Если что-то напарсили
  if [ $picnum \> 0 ]
  then
    # Запоминаем
    cat out.txt >> get.seiga.all.txt
    pagenum=$(expr $pagenum + 1)
  fi
done;

# Проверяем уже скаченное

ls *.jp*g *.png *.gif|sed 's/\..*//g'|sort > pres.txt
basename -a $(cat get.seiga.all.txt)|sort > all.txt
comm -2 -3 all.txt pres.txt  | awk '{ print "http://seiga.nicovideo.jp/image/source/" $0 }' > get.seiga.all.txt

# Качаем
if [ -s get.seiga.all.txt ]
then
  # Собираем URL изображений
  # Разбиваем список, чтобы сессия не истекала на больших списках
  split -l 100 -d -a 6 --additional-suffix=.all.txt get.seiga.all.txt get.seiga.
  if [ -f loclist.txt ]
  then
    rm loclist.txt
  fi
  for i in $(ls get.seiga.*.all.txt)
  do
    seigalogin
    cat $i|xargs -l1 -t curl -# -b niko.txt -D - | grep Location > loclist.txt
    # Костыль для awk
    dos2unix loclist.txt
    # Дописываем расширение jpg для всех файлов
    cat loclist.txt| pcregrep -o -e 'http.+'|sed 's#/o/#/priv/#g'|awk -F"/" '{ print $0" -O "$NF".jpg" }' > list.txt
    # Выкачиваем
    seigalogin
    cat list.txt|xargs -t -l1 wget --load-cookies=niko.txt -nc
  done;
fi

# Убираем мусор
if [ ! $3 ]
then
  rm -rf out.txt get.seiga*all.txt niko.txt *list.txt pres.txt all.txt 2> /dev/null
fi
