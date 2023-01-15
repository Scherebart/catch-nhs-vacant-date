#!/usr/bin/env bash

RES_FOUND=100
RES_NETWORK_ERROR=10
RES_TICK=0

function dostep() {
  timestamp="$1"
  rm current_parsed

  curl "https://terminyleczenia.nfz.gov.pl/?search=true&Case=2&ForChildren=true&ServiceName=PORADNIA+NEUROLOGICZNA+DLA+DZIECI&State=&Locality=WARSZAWA" \
  -o current_source.html
  if [ $? -ne 0 ]; then
    echo NETWORK ERROR > "output/${timestamp}_ERROR"
    return $RES_NETWORK_ERROR
  fi

  cat current_source.html | \
  grep '^[ ]*<span class="visuallyhidden">Nazwa szpitala albo przychodni : </span>' | \
  sed 's/[ ]*<span class="visuallyhidden">Nazwa szpitala albo przychodni : <\/span>\(.*\)/\1/' | \
  tee -a current_parsed

  cat current_source.html | \
  grep '^[ ]*<p class="result-date">' | \
  sed 's/[ ]*<p class="result-date">\([0-9]\{2\}\.[0-9]\{2\}\.[0-9]\{4\}\).*/\1/' | \
  awk 'NR % 2 == 1' | \
  tee -a current_parsed

  local res=$RES_TICK

  if [ -f last_parsed ]; then
    diff -q current_parsed last_parsed
    if [ $? -ne 0 ]; then 
      echo NEW DATA > "output/${timestamp}_NEW_DATA"
      res=$RES_FOUND
  
    fi
  fi

  cat current_parsed > last_parsed
  cat current_parsed > "output/${timestamp}_parsed"

  return $res
}

while true
do
  timestamp=$(date +"%F@%R:%S")
  dostep "$timestamp"
  res=$?
  echo -------------------

  case $res in
    $RES_TICK)
      echo --- TICK! ---
      echo -------------
      play -q -V0 mixkit-confirmation-tone-2867.wav gain -n -15

      sleep 67
      ;;
    $RES_FOUND)
      echo --- NEW DATA! ---
      echo -----------------
      for i in {0..5}
      do
        play -q -V0 mixkit-christmas-reveal-tones-2988.wav gain -n 15
        sleep 3
      done
      spd-say -i +100 -r -15 "There is NEW DATA!"

      sleep 30
      ;;
    $RES_NETWORK_ERROR)
      echo --- NETWORK ERROR! ---
      echo ----------------------
      play -q -V0 mixkit-wrong-long-buzzer-954.wav gain -n 10

      sleep 5
      ;;
      
    *)
      echo --- UNEXPECTED ERROR! ---
      echo -------------------------
      play -q -V0 mixkit-wrong-long-buzzer-954.wav gain -n 10 repeat 5 reverb
      exit 1
      ;;
  esac
done
