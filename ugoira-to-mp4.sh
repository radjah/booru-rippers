#!/bin/bash

# Переменные
uag="PixivAndroidApp/5.0.156 (Android 9; ONEPLUS A6013)"
client_id="MOBrBDS8blbauoSck0ZfDbtuzpyT"
client_secret="lsACyCD94FhDUtGTXi3QzcFE2uU1hqtDaKeqrdwj"
hash_secret="28c1fdd170a5204386cb1313c7077b34f83e4aaf4aa829ce78c231e05b0bae2c"

# Проверка параметров
ugoid=$1
if [ "$ugoid" = "" ]
then
  echo Не указан ID анимации!
  echo Использование: `basename $0` id_анимации
  exit 1
fi

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

# логинимся (access_token в AUTH, refresh_token в AUTHREF)
pixlogin () {
  echo -n Logging in...
  DTH=`date --iso-8601=seconds`
  DTHASH=`echo -n $DTH$hash_secret | md5sum | cut -d' ' -f 1`
  AUTHJS=`curl --compressed -k -s -H "Accept-Language: en_US" \
                              -H "X-Client-Time: $DTH" \
                              -H "X-Client-Hash: $DTHASH" \
                              -H "app-os: android" \
                              -H "app-os-version: 5.0.156" \
  --data "get_secure_url=true&client_id=${client_id}&client_secret=${client_secret}&grant_type=password&username=${pixid}&password=${pixpass}" \
  https://oauth.secure.pixiv.net/auth/token -A "$uag"` 
  AUTH=`echo $AUTHJS | jq -r ".response.access_token"`
  AUTHREF=`echo $AUTHJS | jq -r ".response.refresh_token"`
  AUTHDEV=`echo $AUTHJS | jq -r ".response.device_token"`
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
    DTH=`date --iso-8601=seconds`
    DTHASH=`echo -n $DTH$hash_secret | md5sum | cut -d' ' -f 1`
    AUTHJS=`curl --compressed -k -s -H "Accept-Language: en_US" \
                                    -H "X-Client-Time: $DTH" \
                                    -H "X-Client-Hash: $DTHASH" \
                                    -H "app-os: android" \
                                    -H "app-os-version: 5.0.156" \
    --data "get_secure_url=true&client_id=${client_id}&client_secret=${client_secret}&grant_type=refresh_token&refresh_token=$AUTHREF" \
    https://oauth.secure.pixiv.net/auth/token -A "$uag"` 
    AUTH=`echo $AUTHJS | jq -r ".response.access_token"`
    AUTHREF=`echo $AUTHJS | jq -r ".response.refresh_token"`
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

######################
# Архивы с анимацией #
######################

procanim () {
# Здесь важны только id
  # Получение страницы
  curl --compressed -# "https://public-api.secure.pixiv.net/v1/works/$ugoid.json?image_sizes=large" -H "Authorization: Bearer $AUTH" -A "$uag" > out.ugo
  # Проверка типа
  posttype=`cat out.ugo|jq -r '.response[].type'`
  if [[ $posttype != "ugoira" ]]
  then
    echo Неправильный тип пост по ID $ugoid
    cleantmp
    exit 3
  fi
  # Получение ссылки
  echo Downloading...
  cat out.ugo|jq -r '.response[].metadata.zip_urls[]' |sed 's#_ugoira[^.]*#_ugoira1920x1080#g' | wget -nc -i - -O ${ugoid}_ugoira1920x1080.zip --referer="http://www.pixiv.net/"
  # Сохранение информации для анимацией без имен файлов, но в нужном порядке
  cat out.ugo|jq -Mc '{delay_msec: .response[].metadata.frames[].delay_msec}' > ${ugoid}_ugoira1920x1080.txt
} #procanim

# сборка анимации
convertugo () {
  if [ -f ${ugoid}_ugoira1920x1080.txt ]
  then
    arrdelay=(`cat ${ugoid}_ugoira1920x1080.txt | jq -r .delay_msec`)
  else
    echo Файл с описанием кадров ${ugoid}_ugoira1920x1080.txt не найден!
    cleantmp
    exit 3
  fi
  if [ -f ${ugoid}_ugoira1920x1080.zip ]
  then
    echo Extracting...
    cd files
    unzip ../${ugoid}_ugoira1920x1080.zip
    arrfile=(`ls *`)
  else
    echo Архив ${ugoid}_ugoira1920x1080.zip не найден!
    cleantmp
    exit 3
  fi
  if [[ ${#arrfile[@]} -eq ${#arrdelay[@]} ]]
  then
    convcmd="convert -loop 0 "
    for i in ${!arrfile[@]}
    do
      convcmd="$convcmd -delay ${arrdelay[i]}x1000 ${arrfile[i]} "
    done;
      echo Converting...
      convcmd="$convcmd mpeg:$curdir/${ugoid}.mp4"
      $convcmd
      echo Done!
  else
    echo arrfile \!= arrdelay Что-то пошло не так.
  fi
}

cleantmp () {
  cd $curdir
  rm -rf $tmpdir
} # cleantmp

checkcfg
refreshlogin

# каталоги
curdir="$(pwd)"
tmpdir="`mktemp -d`"
cd $tmpdir
mkdir files

procanim
convertugo
cleantmp