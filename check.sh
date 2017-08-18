#!/bin/sh

#this code is tested un fresh 2015-11-21-raspbian-jessie-lite Raspberry Pi image
#by default this script should be located in two subdirecotries under the home

#sudo apt-get update -y && sudo apt-get upgrade -y
#sudo apt-get install git -y
#mkdir -p /home/pi/detect && cd /home/pi/detect
#git clone https://github.com/catonrug/pdfsam-detect.git && cd pdfsam-detect && chmod +x check.sh && ./check.sh

#check if script is located in /home direcotry
pwd | grep "^/home/" > /dev/null
if [ $? -ne 0 ]; then
  echo script must be located in /home direcotry
  return
fi

#it is highly recommended to place this directory in another directory
deep=$(pwd | sed "s/\//\n/g" | grep -v "^$" | wc -l)
if [ $deep -lt 4 ]; then
  echo please place this script in deeper directory
  return
fi

#set application name based on directory name
#this will be used for future temp directory, database name, google upload config, archiving
appname=$(pwd | sed "s/^.*\///g")

#set temp directory in variable based on application name
tmp=$(echo ../tmp/$appname)

#create temp directory
if [ ! -d "$tmp" ]; then
  mkdir -p "$tmp"
fi

#check if database directory has prepared
if [ ! -d "../db" ]; then
  mkdir -p "../db"
fi

#set database variable
db=$(echo ../db/$appname.db)

#if database file do not exist then create one
if [ ! -f "$db" ]; then
  touch "$db"
fi

#check if google drive config directory has been made
#if the config file exists then use it to upload file in google drive
#if no config file is in the directory there no upload will happen
if [ ! -d "../gd" ]; then
  mkdir -p "../gd"
fi

if [ -f ~/uploader_credentials.txt ]; then
sed "s/folder = test/folder = `echo $appname`/" ../uploader.cfg > ../gd/$appname.cfg
else
echo google upload will not be used cause ~/uploader_credentials.txt do not exist
fi

#set url
name=$(echo "PDFSaM")
download=$(echo "https://sourceforge.net/projects/pdfsam/rss?path=/")

wget -S --spider -o $tmp/output.log "$download"

grep -A99 "^Resolving" $tmp/output.log | grep "HTTP.*200 OK"
if [ $? -eq 0 ]; then
#if file request retrieve http code 200 this means OK

#get all exe english installers
filelist=$(wget -qO- "$download" | sed "s/http/\nhttp/g;s/download/download\n/g" | grep "^http.*\/download$" | sort | uniq | grep "msi\|zip" | grep -v "src" | grep "pdfsam-" | sed '$alast line')

#count how many links are in download page. substract one fake last line from array
links=$(echo "$filelist" | head -n -1 | wc -l)
if [ $links -gt 1 ]; then
echo $links download links found
echo

printf %s "$filelist" | while IFS= read -r url
do {

#calculate filename
filename=$(echo $url | sed "s/\//\n/g" | grep "zip\|msi")

#check if this filename is in database
grep "$filename" $db > /dev/null
if [ $? -ne 0 ]; then
echo

#download file
echo Downloading $filename
wget $url -O $tmp/$filename -q

#check downloded file size if it is fair enought
size=$(du -b $tmp/$filename | sed "s/\s.*$//g")
if [ $size -gt 51200 ]; then
echo

#detect version from url
version=$(echo "$url" | sed "s/^.*\/pdfsam\///g;s/\/.*$//g")

#check if version matchs version pattern
echo $version | grep "^[0-9]\+"
if [ $? -eq 0 ]; then
echo

echo creating md5 checksum of file..
md5=$(md5sum $tmp/$filename | sed "s/\s.*//g")
echo

echo creating sha1 checksum of file..
sha1=$(sha1sum $tmp/$filename | sed "s/\s.*//g")
echo

echo "$filename">> $db
echo "$version">> $db
echo "$md5">> $db
echo "$sha1">> $db
echo >> $db

#if google drive config exists then upload and delete file:
if [ -f "../gd/$appname.cfg" ]
then
echo Uploading $filename to Google Drive..
echo Make sure you have created \"$appname\" direcotry inside it!
../uploader.py "../gd/$appname.cfg" "$tmp/$filename"
echo
fi

#addititonal words in email subject. sequence is important
case "$url" in
*zip*)
type=$(echo "Portable")
;;
*msi*)
type=$(echo "msi")
;;
esac

#lets send emails to all people in "posting" file
emails=$(cat ../posting | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "$name $version $type" "$url 
$md5
$sha1

https://drive.google.com/drive/folders/0B_3uBwg3RcdVa2NyOU5UdlhMWTA 
"
} done
echo

else
#version do not match version pattern
echo version "$version" do not match version pattern
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "$name" "Version do not match version pattern:
$url "
} done
fi

else
#downloaded file size is to small
echo downloaded file size is to small
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "$name" "Downloaded file size is to small:
$url
$size"
} done
fi

else
#$filename is already in database
echo "$filename" is already in database
fi

rm -rf $tmp/*

} done

else
#only $links download links found
echo only $links download links found
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "$name" "only $links download links found:
$download "
} done
fi

else
#if http status code is not 200 ok
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "$name" "the following link do not retrieve good http status code:
$url"
} done
echo
echo
fi

#clean and remove whole temp direcotry
rm $tmp -rf > /dev/null
