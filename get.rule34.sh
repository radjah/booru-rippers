#!/bin/bash

# ���������
uag="Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:70.0) Gecko/20100101 Firefox/70.0"

# �������� ����������
if [ ! "$2" = "" ]
then
  tags=$1
  savedir=$2
else
  if [ ! "$1" = "" ]
  then
    tags=$1
    savedir=$1
  else
    echo �������������:
    echo $(basename $0) ���� \[�������\]
    exit 1
  fi
fi

# ������� ��� �������
if [ ! -d $savedir ]
then
  echo Creating $savedir...
  mkdir "$savedir"
fi
echo Entering $savedir...
cd "$savedir"

# ���������� ������
postcount=$(curl --compressed -# "https://rule34.xxx/index.php?page=dapi&s=post&q=index&tags=$tags&limit=1" -A "$uag"|pcregrep -o 'posts\ count=\"[^"]+'|sed -e 's/posts\ count=//' -e 's/\"//')

# �������� ����������
if [ $postcount -eq 0 ]
then
  echo �� ��������� "$tags" ������ �� �������.
  exit 3
else
  echo �� ��������� "$tags" ������� ������: $postcount
fi

# �������� �����-������
if [ -s get2.gelbooru.txt ]
then
  rm -f get2.gelbooru.txt
fi

pcount=`expr $postcount / 1000`

for ((i=0; i<=$pcount; i++))
do
  echo Page $i
  curl --compressed -# "https://rule34.xxx/index.php?page=dapi&s=post&q=index&tags=$tags&limit=1000&pid=$i" -A "$uag"|pcregrep -o -e 'file_url=[^ ]+'|sed -e 's/file_url=//g' -e 's/\"//g' >>get2.rule34.txt
done;

wget -nc -i get2.rule34.txt --referer="https://rule34.xxx/" --no-check-certificate

echo Finished!
echo $tags \=\> $savedir
