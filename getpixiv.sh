#!/bin/bash

# Переменные
uag="Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/109.0"
client_id="MOBrBDS8blbauoSck0ZfDbtuzpyT"
client_secret="lsACyCD94FhDUtGTXi3QzcFE2uU1hqtDaKeqrdwj"
hash_secret="28c1fdd170a5204386cb1313c7077b34f83e4aaf4aa829ce78c231e05b0bae2c"

athid=$1
savedir=$2

# проверка наличия команд
checkapp () {
if ! which $1 2>&1 > /dev/null
then
  echo $1 not found!
  exit 6
fi
} # checkapp

# Проверка параметров
checkparam () {
if [ "$athid" = "" ]
then
  echo Не указан ID художника!
  echo Использование: $(basename $0) id_художника [каталог]
  exit 1
fi
} # checkparam

# Качалка
dldr='aria2c --always-resume=false --max-resume-failure-tries=0 --remote-time'

# Каталог для сохранения
createdir () {
  dirlet=$(echo -n $savedir| tr "[:upper:]" "[:lower:]" | cut -c-1)
  if [ ! -d $dirlet/$savedir ]
  then
    echo Creating $dirlet/$savedir...
    mkdir -p "$dirlet/$savedir"
  else
    dldr='wget -nc'
  fi
  if [ -d $dirlet/$savedir ]
  then
    echo Entering $dirlet/$savedir...
    cd "$dirlet/$savedir"
  else
    echo Ошибка создания каталога для сохранения!
    exit 3
  fi
} # createdir

# Проверка конфига
checkcfg () {
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
} # checkcfg

# поиск и удаление дублей
finddups () {
  # Список скаченного
  ls *.jp*g *.png *.gif 2>/dev/null |grep -v big|grep _|sed 's/_.*//g'|sort|uniq > downloaded.pixiv.txt
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
    cat fordel.pixiv.txt|xargs rm
  fi

} # finddups

# Создать ссылку на страницу художника
gensc () {
  # ярлык на страницу автора для общей кучи
  echo \[InternetShortcut\] > "$savedir.url"
  echo URL=https\:\/\/www\.pixiv\.net\/en\/users\/${athid}\/artworks >> "$savedir.url"
} # gensc

# логинимся (access_token в AUTH, refresh_token в AUTHREF)
pixlogin () {
  echo -n Logging in...
  DTH=$(date -u --iso-8601=seconds)
  DTHASH=$(echo -n $DTH$hash_secret | md5sum | cut -d' ' -f 1)
  AUTHJS=$(curl --compressed -k -s \
                                    -H "App-OS: ios" \
                                    -H "App-OS-Version: 13.1.2" \
                                    -H "App-Version: 7.7.6" \
                                    -H "User-Agent: PixivIOSApp/7.7.6 (iOS 13.1.2; iPhone11,8)" \
                                    -H "Referer: https://app-api.pixiv.net/" \
                                    -H "X-Client-Time: $DTH" \
                                    -H "X-Client-Hash: $DTHASH" \
  --data "get_secure_url=true&client_id=${client_id}&client_secret=${client_secret}&grant_type=password&username=${pixid}&password=${pixpass}" \
  "https://oauth.secure.pixiv.net/auth/token")
  AUTH=$(echo $AUTHJS | jq -r ".response.access_token")
  AUTHREF=$(echo $AUTHJS | jq -r ".response.refresh_token")
  AUTHDEV=$(echo $AUTHJS | jq -r ".response.device_token")
  # Проверка логина
  if [ -z $AUTH ]
  then
    echo ERROR: Проверьте логин и пароль
    exit 2
  else
    echo AUTHREF=$AUTHREF > ~/.config/pixivtoken.conf
    echo OK
  fi
} # pixlogin

# Обнвление refresh_token
refreshlogin () {
  echo -n Refresh login...
  if [ -f ~/.config/pixivtoken.conf ]
  then
    . ~/.config/pixivtoken.conf
    DTH=$(date -u --iso-8601=seconds)
    DTHASH=$(echo -n $DTH$hash_secret | md5sum | cut -d' ' -f 1)
    AUTHJS=$(curl --compressed -k -s \
                                    -H "App-OS: ios" \
                                    -H "App-OS-Version: 13.1.2" \
                                    -H "App-Version: 7.7.6" \
                                    -H "User-Agent: PixivIOSApp/7.7.6 (iOS 13.1.2; iPhone11,8)" \
                                    -H "Referer: https://app-api.pixiv.net/" \
                                    -H "X-Client-Time: $DTH" \
                                    -H "X-Client-Hash: $DTHASH" \
    --data "get_secure_url=true&client_id=${client_id}&client_secret=${client_secret}&grant_type=refresh_token&refresh_token=$AUTHREF" \
    "https://oauth.secure.pixiv.net/auth/token")
    AUTH=$(echo $AUTHJS | jq -r ".response.access_token")
    AUTHREF=$(echo $AUTHJS | jq -r ".response.refresh_token")
    # Проверка логина
    if [ -z $AUTH ]
    then
      pixlogin
    else
      echo AUTHREF=$AUTHREF > ~/.config/pixivtoken.conf
      echo OK
    fi
  else
    pixlogin
  fi
} # refreshlogin

# функция получения имени пользователя
getaccname() {
  savedir=$(curl --compressed -# "https://app-api.pixiv.net/v1/user/detail?user_id=$athid" -H "Authorization: Bearer $AUTH"|jq -r ".user.account")
  echo Found username: $savedir
} # getaccname

# функция для получения списков
getlist () {

# счетчики
picoffset=0
picnum=1
pagenum=1

# пустые файлы
touch get.pixiv.anim.txt

# перебор страниц
until [ $picnum -eq 0 ]
do
  # страница для парсинга во временный файл
  echo Offset $picoffset
  curl --compressed -# "https://app-api.pixiv.net/v1/user/illusts?user_id=$athid&offset=$picoffset" \
                                     -H "App-OS: ios" \
                                     -H "App-OS-Version: 10.3.1" \
                                     -H "App-Version: 6.7.1" \
                                     -H "User-Agent: PixivIOSApp/6.7.1 (iOS 10.3.1; iPhone8,1)" \
                                     -H "Referer: https://app-api.pixiv.net/" \
                                     -H "Authorization: Bearer $AUTH" > tmp.json.pixiv.txt
  # Сколько постов нашли?
  picnum=$(cat tmp.json.pixiv.txt | jq '.illusts | length')
  # Разгребаем полученное
  if [ $picnum -gt 0 ]
  then
    # парсим
    # одиночные иллюстрации
    cat tmp.json.pixiv.txt | jq -r '.illusts[] | select(.type != "ugoira")  | select(.page_count == 1) | .meta_single_page.original_image_url' >> get.pixiv.dl.txt
    # альбомы 
    cat tmp.json.pixiv.txt | jq -r '.illusts[] | select(.type != "ugoira")  | select(.page_count > 1) | .meta_pages[].image_urls.original' >> get.pixiv.dl.txt
    # id анимации для дальнейшей обработки в отдельный список
    cat tmp.json.pixiv.txt | jq -r '.illusts[] | select(.type == "ugoira") | .id' >> get.pixiv.anim.txt
    picoffset=$(expr $picoffset + 30)
  fi
done;
  # Скачивание
  if [ -s get.pixiv.dl.txt ]
  then
    $dldr -i get.pixiv.dl.txt --referer="https://www.pixiv.net/"
  fi
} # getlist

######################
# Архивы с анимацией #
######################

procanim () {
# Здесь важны только id
if [ -s get.pixiv.anim.txt ]
then
  for i in $(cat get.pixiv.anim.txt)
  do
    # взвод ошибки
    errval=1
    until [ $errval -eq 0 ]
    do
      curl --compressed -# "https://app-api.pixiv.net/v1/ugoira/metadata?illust_id=$i" \
                                     -H "App-OS: ios" \
                                     -H "App-OS-Version: 10.3.1" \
                                     -H "App-Version: 6.7.1" \
                                     -H "User-Agent: PixivIOSApp/6.7.1 (iOS 10.3.1; iPhone8,1)" \
                                     -H "Referer: https://app-api.pixiv.net/" \
                                     -H "Authorization: Bearer $AUTH" -A "$uag" > out.${i}.ugo
      # проверка на наличие ошибки
      # обычно Rate Limit
      errval=$(cat out.${i}.ugo | jq -r '.error | length')
      if [ $errval -gt 0 ]
      then
        echo Rate Limit! Waiting 15 sec...
        sleep 15
      fi
    done;
    # Получение ссылки
    cat out.${i}.ugo | jq -r '.ugoira_metadata.zip_urls.medium' | sed 's#_ugoira[^.]*#_ugoira1920x1080#g' >> get.pixiv.anim.dl.txt
    # Сохранение информации о времени кадров
    cat out.${i}.ugo | jq -Mc '{delay_msec: .ugoira_metadata.frames[].delay}' > ${i}_ugoira1920x1080.txt
  done;
fi

# Скачивание
if [ -s get.pixiv.anim.dl.txt ] 
then
  wget -nc -i get.pixiv.anim.dl.txt --referer="https://www.pixiv.net/"
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
checkparam
checkapp curl
checkapp wget
checkapp jq
checkcfg
refreshlogin
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
    refreshlogin
    echo [*] Processing animation list...
    procanim
    echo [*] Removing dups...
    finddups
    echo [*] Removing trash...
    rmtrash $3
    flock -u 0
    echo [*] FINISHED!
    echo [*] Ripped ID=$athid to $dirlet/$savedir
  else
    echo [!] ERROR! Каталог сохранения уже обрабатывается!
    exit 4
  fi
fi