#!/bin/sh

#set applicaition name
appname="PDFSaM"

#set database variable
db="$appname.db"

#if database file do not exist then create one
if [ ! -f "$db" ]; then
  touch "$db"
fi

#set download link
download=$(echo "https://sourceforge.net/projects/pdfsam/rss?path=/")

#download all links and put every link in the loop
#do not include links with "src" in the url
wget -qO- "$download" | sed "s/http/\nhttp/g;s/download/download\n/g" | \
grep "^http.*\/download$" | \
sort | uniq | grep "msi\|zip" | grep -v "src" | grep "pdfsam-" | \
while IFS= read -r url; do

#calculate filename from URL
filename=$(echo $url | sed "s/\//\n/g" | grep "msi\|zip")

#look if this filename is in database
grep "$filename" $db > /dev/null
if [ $? -ne 0 ]; then

#extract version number from URL
version=$(echo "$url" | sed "s/^.*\/pdfsam\///g;s/\/.*$//g")

#show details on the screen
echo $url
echo $filename
echo $version
echo

#put all information in the database
echo $url>> $db
echo $filename>> $db
echo $version>> $db
echo >> $db

else
  echo $filename is already in the database
fi

done
