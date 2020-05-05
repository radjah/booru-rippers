#!/bin/bash

# Переменные
uag="PixivAndroidApp/5.0.156 (Android 9; ONEPLUS A6013)"
client_id="MOBrBDS8blbauoSck0ZfDbtuzpyT"
client_secret="lsACyCD94FhDUtGTXi3QzcFE2uU1hqtDaKeqrdwj"
hash_secret="28c1fdd170a5204386cb1313c7077b34f83e4aaf4aa829ce78c231e05b0bae2c"

ugoid=$1
outformat=$2

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
if [ "$ugoid" = "" ]
then
  echo "Не указан ID анимации!"
  echo "Использование: $(basename $0) id_анимации формат"
  echo "Формат может быть:"
  echo "gif  - gif-анимация"
  echo "webp - webp-анимация"
  echo "apng - анимированный png-файл"
  echo "coub - mp4-файл с видео в формате x264."
  echo "       Понятен большинству плееров и редактору на сайте coub.com."
  echo "mkv  - mkv-файл с видео в формате x264 без специальной обработки."
  echo "Если не указан, то mp4 без специальной обработки."
  exit 1
fi
} # checkparam

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
  DTH=$(date --iso-8601=seconds)
  DTHASH=$(echo -n $DTH$hash_secret | md5sum | cut -d' ' -f 1)
  AUTHJS=$(curl --compressed -k -s -H "Accept-Language: en_US" \
                              -H "X-Client-Time: $DTH" \
                              -H "X-Client-Hash: $DTHASH" \
                              -H "app-os: android" \
                              -H "app-os-version: 5.0.156" \
  --data "get_secure_url=true&client_id=${client_id}&client_secret=${client_secret}&grant_type=password&username=${pixid}&password=${pixpass}" \
  https://oauth.secure.pixiv.net/auth/token -A "$uag")
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

# Обновление access_token с помощью refresh_token
refreshlogin () {
  echo -n Refresh login...
  if [ -f ~/.config/pixivtoken.conf ]
  then
    . ~/.config/pixivtoken.conf
    DTH=$(date --iso-8601=seconds)
    DTHASH=$(echo -n $DTH$hash_secret | md5sum | cut -d' ' -f 1)
    AUTHJS=$(curl --compressed -k -s -H "Accept-Language: en_US" \
                                    -H "X-Client-Time: $DTH" \
                                    -H "X-Client-Hash: $DTHASH" \
                                    -H "app-os: android" \
                                    -H "app-os-version: 5.0.156" \
    --data "get_secure_url=true&client_id=${client_id}&client_secret=${client_secret}&grant_type=refresh_token&refresh_token=$AUTHREF" \
    https://oauth.secure.pixiv.net/auth/token -A "$uag")
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

######################
# Архивы с анимацией #
######################

procanim () {
  # Получение страницы
  curl --compressed -# "https://public-api.secure.pixiv.net/v1/works/$ugoid.json?image_sizes=large" -H "Authorization: Bearer $AUTH" -A "$uag" > out.ugo
  # Проверка типа
  posttype=$(cat out.ugo| jq 'select(.status == "success" )' | jq -r '.response[].type')
  if [[ $posttype != "ugoira" ]]
  then
    if [ -z $posttype ]
    then
      echo Пост с ID $ugoid не найден!
    else
      echo Неправильный тип поста по ID $ugoid\: $posttype
    fi
    cleantmp
    exit 6
  fi
  # Получение файла
  echo Trying to use local file...
  accname=$(cat out.ugo | jq -r '.response[].user.account')
  echo Found username: $accname
  dirlet=$(echo -n $accname| tr "[:upper:]" "[:lower:]" | cut -c-1)
  if [ -s $curdir/$dirlet/$accname/${ugoid}_ugoira1920x1080.zip ]
  then
    echo Found local file $curdir/$dirlet/$accname/${ugoid}_ugoira1920x1080.zip
    echo Copying...
    cp $curdir/$dirlet/$accname/${ugoid}_ugoira1920x1080.zip ./
  else
    echo Local file not found: $curdir/$dirlet/$accname/${ugoid}_ugoira1920x1080.zip
    echo Downloading...
    cat out.ugo|jq -r '.response[].metadata.zip_urls[]' |sed 's#_ugoira[^.]*#_ugoira1920x1080#g' | wget -nc -i - -O ${ugoid}_ugoira1920x1080.zip --referer="https://www.pixiv.net/"
  fi
  # Сохранение информации о времени кадров
  cat out.ugo|jq -Mc '{delay_msec: .response[].metadata.frames[].delay_msec}' > ${ugoid}_ugoira1920x1080.txt
} # procanim

# генерация файла таймкодов
createtc () {
  echo "# timestamp format v2" > ../timecodes.tc
  delay_sum=0
  echo $delay_sum >> ../timecodes.tc
  for i in ${!arrdelay[@]}
  do
    delay_sum=$(expr $delay_sum + ${arrdelay[i]})
    echo $delay_sum >> ../timecodes.tc
  done
  echo $delay_sum >> ../timecodes.tc
} # createtc

# сборка анимации
convertugo () {
  if [ -f ${ugoid}_ugoira1920x1080.txt ]
  then
    arrdelay=($(cat ${ugoid}_ugoira1920x1080.txt | jq -r .delay_msec))
  else
    echo Файл с описанием кадров ${ugoid}_ugoira1920x1080.txt не найден!
    cleantmp
    exit 6
  fi
  if [ -f ${ugoid}_ugoira1920x1080.zip ]
  then
    echo Extracting...
    cd files
    unzip -q ../${ugoid}_ugoira1920x1080.zip
    arrfile=($(ls *))
  else
    echo Архив ${ugoid}_ugoira1920x1080.zip не найден!
    cleantmp
    exit 6
  fi
  if [[ ${#arrfile[@]} -eq ${#arrdelay[@]} ]]
  then
      echo -n Converting\ 
      case $outformat in
        gif)
          echo to gif...
          outfile=$curdir/${ugoid}.gif
          # генерация команды
          convcmd="convert -loop 0 "
          for i in ${!arrfile[@]}
          do
            convcmd="$convcmd -delay ${arrdelay[i]}x1000 ${arrfile[i]} "
          done;
          $convcmd -layers Optimize gif:$outfile
          convret=$?
          ;;
        webp)
          echo to webp...
          outfile=$curdir/${ugoid}.webp
          # генерация команды
          convcmd="img2webp -lossy -q 85 -loop 0 "
          for i in ${!arrfile[@]}
          do
            convcmd="$convcmd -d ${arrdelay[i]}x1000 ${arrfile[i]} "
          done;
          $convcmd -o $outfile
          convret=$?
          ;;
        apng)
          echo to apng...
          outfile=$curdir/${ugoid}.png
          mkdir ../png
          if [ -d ../png ]
          then
            cd ../png
          else
            echo Не удалось создать $tmpdir/png!
            exit 6
          fi
          # конвертирование jpg в png
          mogrify -path . -format png ../files/*.jpg
          # удаление расширения из имени файлов
          arrfile=($(echo ${arrfile[@]} | sed -r 's/\.[a-zA-Z]+//g'))
          # запись контрольных файлов с задержками кадров
          for i in ${!arrdelay[@]}
          do
            echo delay=${arrdelay[i]}/1000 > ${arrfile[i]}.txt
          done;
          # сборка apng
          apngasm $outfile *.png
          convret=$?
          ;;
        coub)
          echo to coub-mp4...
          outfile=$curdir/${ugoid}.coub.mp4
          createtc
          # преобразование кадров в видео 15 fps
          ffmpeg -hide_banner -v warning -stats -y -framerate 15 -i '%06d.jpg' -vf "crop=trunc(iw/2)*2:trunc(ih/2)*2:0:0" ../${ugoid}.tmp.mkv
          # запись таймкодов в файл
          mkvmerge -o ../${ugoid}.mkv -q -A --timecodes 0:../timecodes.tc ../${ugoid}.tmp.mkv
          # преобразование mkv в vfr mp4
          ffmpeg -hide_banner -v warning -y -vsync 2 -c:v copy $outfile -i ../${ugoid}.mkv
          convret=$?
          ;;
        mkv)
          echo to mkv...
          outfile=$curdir/${ugoid}.mkv
          createtc
          ffmpeg -hide_banner -v warning -stats -y -framerate 15 -i '%06d.jpg' ../${ugoid}.tmp.mkv
          mkvmerge -o $outfile -q -A --timecodes 0:../timecodes.tc ../${ugoid}.tmp.mkv
          convret=$?
          ;;
        *)
          echo to mp4...
          outfile=$curdir/${ugoid}.mp4
          createtc
          ffmpeg -hide_banner -v warning -stats -y -framerate 15 -i '%06d.jpg' ../${ugoid}.tmp.mp4
          mkvmerge -o ../${ugoid}.mkv -q -A --timecodes 0:../timecodes.tc ../${ugoid}.tmp.mp4
          ffmpeg -hide_banner -v warning -y -vsync 2 -c:v copy $outfile -i ../${ugoid}.mkv
          convret=$?
          ;;
      esac
      if [ $convret -eq 0 ]
      then
        echo Сохранено в $outfile
      else
        echo Ошибка записи в $outfile
      fi
  else
    echo arrfile \!= arrdelay Что-то пошло не так.
  fi
} # convertugo

# удаление мусора
cleantmp () {
  cd $curdir
  rm -rf $tmpdir
} # cleantmp

# Обработка

checkapp curl
checkapp wget
checkapp unzip
checkapp jq
case $outformat in
  gif)
    checkapp convert
    ;;
  webp)
    checkapp img2webp
    ;;
  apng)
    checkapp mogrify
    checkapp apngasm
    ;;
  *)
    checkapp ffmpeg
    checkapp mkvmerge
    ;;
esac

checkparam
checkcfg
refreshlogin

# каталоги
curdir="$(pwd)"
tmpdir="$(mktemp -d)"
if [ ! -z $tmpdir ] && [ -d $tmpdir ]
then
  cd $tmpdir
  mkdir files
else
  echo Ошибка создания временного каталога!
  exit 6
fi

procanim
convertugo
cleantmp
