#!/usr/bin/env bash

function step() {
  timestamp=$(date +"%F@%R:%S")
  rm current_parsed

  curl "https://terminyleczenia.nfz.gov.pl/?search=true&Case=2&ForChildren=true&ServiceName=PORADNIA+NEUROLOGICZNA+DLA+DZIECI&State=&Locality=WARSZAWA" \
  -o current_source.html

  cat current_source.html | \
  grep '^[ ]*<span class="visuallyhidden">Nazwa szpitala albo przychodni : </span>' | \
  sed 's/[ ]*<span class="visuallyhidden">Nazwa szpitala albo przychodni : <\/span>\(.*\)/\1/' | \
  tee -a current_parsed

  cat current_source.html | \
  grep '^[ ]*<p class="result-date">' | \
  sed 's/[ ]*<p class="result-date">\([0-9]\{2\}\.[0-9]\{2\}\.[0-9]\{4\}\).*/\1/' | \
  awk 'NR % 2 == 1' | \
  tee -a current_parsed

  if [ -f last_parsed ]; then
    diff -q current_parsed last_parsed
    if [ $? -ne 0 ]; then 
      echo NEW DATA > "output/${timestamp}_NEW_DATA"
      spd-say "There is NEW DATA!";
      play -q -V0 mixkit-alarm-clock-beep-988.wav gain -n 15
    fi
  fi

  cat current_parsed > last_parsed
  cat current_parsed > "output/${timestamp}_parsed"
}

while true
do
  step
  echo -------------------
  sleep 67
done
