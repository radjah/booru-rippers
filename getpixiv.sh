#!/bin/bash

# Переменные
uag="Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:56.0) Gecko/20100101 Firefox/56.0"

# Проверка параметров
athid=$1
savedir=$2
if [ "$athid" = "" ]
then
  echo Не указан ID художника!
  echo Использование: `basename $0` id_художника [каталог]
  exit 1
fi

# Качалка
dldr='aria2c --always-resume=false --max-resume-failure-tries=0 --remote-time'

# Каталог для сохранения
createdir () {
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
} # createdir

# Проверка конфига
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
  # Список скаченного
  ls *.jp*g *.png *.gif|grep -v big|grep _|sed 's/_.*//g'|sort|uniq > downloaded.pixiv.txt
  # Список совпадающего из старья
  if [ -s downloaded.pixiv.txt ]
  then
    cat downloaded.pixiv.txt | while read i
    do
      ls ${i}.* ${i}_big* 2>/dev/null >> fordel.pixiv.txt
    done;
  fi
  # Удаление
  if [ -s fordel.pixiv.txt ]
  then
    cat fordel.pixiv.txt|xargs -l1 rm
  fi

} # finddups

# Создать ссылку на страницу художника
gensc () {
  # ярлык на страницу автора для общей кучи
  echo \[InternetShortcut\] > "$savedir.url"
  echo URL=https\:\/\/www.pixiv.net\/member_illust.php\?id=$athid >> "$savedir.url"
} # gensc

# логинимся (куки в pixiv.txt, access_token в AUTH)
# client_id и client_secret от приложения для iphone
pixlogin () {
  echo Logging in...
  AUTH=`curl --compressed -k -s --data "username=${pixid}&password=${pixpass}&grant_type=password&client_id=bYGKuGVw91e0NMfPGp44euvGt59s&client_secret=HP3RmkgAmEGro0gn1x9ioawQE8WMfvLXDz3ZqxpK" https://oauth.secure.pixiv.net/auth/token -A "$uag"|pcregrep -o -e 'access_token\":\"[^\"]+'|sed 's#access_token":"##g'`
  # Проверка логина
  if [ -z $AUTH ]
  then
    echo ERROR: Проверьте логин и пароль
    exit 2
  else
    echo OK
  fi
} # pixlogin

# функция получения имени пользователя

getaccname() {
  savedir=`curl --compressed -# "https://app-api.pixiv.net/v1/user/detail?user_id=$athid" -H "Authorization: Bearer $AUTH"|pcregrep -o -e '\"account\":\"[^\"]*'|sed 's#"account":"##g'`
  echo Found username: $savedir
} # getaccname

# функция для получения списков
getlist () {

# счетчики
picnum=1
pagenum=1

# пустые файлы
touch get.pixiv.illist.txt get.pixiv.anim.txt json.pixiv.txt

# перебор страниц
until [ $picnum -eq 0 ]
do
  # страница для парсинга во временный файл
  echo Page $pagenum
  curl --compressed -# "https://public-api.secure.pixiv.net/v1/users/$athid/works.json?image_sizes=large&page=$pagenum&per_page=100" -H "Authorization: Bearer $AUTH"|sed 's#},{#\n#g' > tmp.json.pixiv.txt
  cat tmp.json.pixiv.txt|pcregrep --buffer-size 1M -o -e '\"id\"\:[^,]+\,\"title\"'|sort|uniq > out.tmp.txt
  # Сколько нашли на текущей странице?
  picnum=`cat out.tmp.txt|wc -l`
  if [ $picnum \> 0 ]
  then
    # парсим
    # иллюстрации сразу в список для закачки
    cat tmp.json.pixiv.txt|grep -v '"is_manga":true'|grep -v ugoira0.|pcregrep --buffer-size 1M -o -e 'large\"\:\"[^\"]+'|sed 's#large":"##g'|sort|uniq >> get.pixiv.dl.txt
    # id альбомов для дальнейшей обработки в отдельный список
    cat tmp.json.pixiv.txt|grep '"is_manga":true'|grep -v ugoira0.|pcregrep --buffer-size 1M -o -e '\"id\"\:[^,]+\,\"title\"'|sed -e 's#"id":##g' -e 's#,"title"##g'|sort|uniq >> get.pixiv.illist.txt
    # id анимации для дальнейшей обработки в отдельный список
    cat tmp.json.pixiv.txt|grep ugoira0.|pcregrep --buffer-size 1M -o -e '\"id\"\:[^,]+\,\"title\"'|sed -e 's#"id":##g' -e 's#,"title"##g'|sort|uniq >> get.pixiv.anim.txt
    pagenum=`expr $pagenum + 1`
  fi
done;

} # getlist

########################
# Илюстрации и альбомы #
########################

procillist () {
  touch get.pixiv.dl.txt
  # Обрабатываем все найденные ID
  for i in `cat get.pixiv.illist.txt`
  do
    echo Processing $i...
    curl --compressed -# "https://public-api.secure.pixiv.net/v1/works/$i.json?image_sizes=large" -H "Authorization: Bearer $AUTH"|pcregrep --buffer-size 1M -o -e 'large\"\:\"[^\"]+'|sed 's#large":"##g'|sort|uniq >> get.pixiv.dl.txt
  done;
  # Скачивание
  if [ -s get.pixiv.dl.txt ]
  then
    $dldr -i get.pixiv.dl.txt --referer="http://www.pixiv.net/"
  fi
} # procillist

######################
# Архивы с анимацией #
######################

procanim () {
# Здесь важны только id
if [ -s get.pixiv.anim.txt ]
then
  for i in `cat get.pixiv.anim.txt`
  do
    # Получение страницы
    curl --compressed -# "https://public-api.secure.pixiv.net/v1/works/$i.json?image_sizes=large" -H "Authorization: Bearer $AUTH" -A "$uag" > out.ugo
    # Получение ссылки
    cat out.ugo|pcregrep -o -e '\"ugoira[^\"]+":"[^\"]+'|pcregrep -o -e 'http.+'|sed 's#_ugoira[^.]*#_ugoira1920x1080#g' >> get.pixiv.anim.dl.txt
    # Сохранение информации для анимацией без имен файлов, но в нужном порядке
    cat out.ugo|pcregrep -o -e '\"frames\"\:\[\{.+\}\]\}'|sed -e 's#},{#\n#g' -e 's#}]}##g' -e 's#\"frames\"\:\[{##g' > ${i}_ugoira1920x1080.txt
  done;
fi

# Скачивание
if [ -s get.pixiv.anim.dl.txt ] 
then
  wget -nc -i get.pixiv.anim.dl.txt --referer="http://www.pixiv.net/"
fi
} # procanim

# удаляем мусор
rmtrash () {
if [ ! $1 ]
then
  rm -f get*.txt *pixiv.txt list* out.*
fi
} # rmtrash

# очистка в любом случае
trap rmtrash 1 2 3 15

# Обработка всего и вся

pixlogin
# если каталог сохранения не указан, то получаем его с помощь API
if [ -z $savedir ]
then
  getaccname
fi
# если каталог получили, то начинаем работу
if [ ! -z $savedir ]
then
  createdir
  # Блокировка
  exec < .
  flock -n 0
  flres=$?
  # Если никто каталог не занял, то работаем
  if [ $flres -eq 0 ]
  then
    gensc
    echo [*] Building list...
    getlist
    echo [*] Processing illust and albums list...
    procillist
    pixlogin
    echo [*] Processing animation list...
    procanim
    echo [*] Removing dups...
    finddups
    echo [*] Removing trash...
    rmtrash $3
    flock -u 0
    echo [*] FINISHED!
    echo [*] Ripped ID=$athid to ${dirlet,,}/$savedir
  else
    echo [!] ERROR! Каталог сохранения уже обрабатывается!
    exit 4
  fi
fi
