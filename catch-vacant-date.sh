#!/usr/bin/env bash

function env() {
  ENV=$(echo "${1:-PROD}" | tr '[:lower:]' '[:upper:]')

  if [[ ! "$ENV" =~ ^(DEV|PROD)$ ]]; then
    echo BAD ENV "\"$ENV\""
    exit 1
  fi

  echo ================
  echo === ENV $ENV ===
  echo ================
}

function config() {
  RET_FOUND=100
  RET_NETWORK_ERROR=10
  RET_TICK=0

  case $ENV in
    PROD)
      CHECK_INTERVAL=67
      RETRY_INTERVAL=5
      ;;
    DEV)
      CHECK_INTERVAL=10
      RETRY_INTERVAL=3
      ;;
    *)
      exit 1
  esac
}

function dostep() {
  timestamp="$1"
  rm -f current_parsed

  curl "https://terminyleczenia.nfz.gov.pl/?search=true&Case=2&ForChildren=true&ServiceName=PORADNIA+NEUROLOGICZNA+DLA+DZIECI&State=&Locality=WARSZAWA" \
  -o current_source.html \
  --connect-timeout 15
  if [ $? -ne 0 ]; then
    echo NETWORK ERROR > "output/${timestamp}_ERROR"
    return $RET_NETWORK_ERROR
  fi

  cat current_source.html | \
  grep '^[ ]*<span class="visuallyhidden">Nazwa szpitala albo przychodni : </span>' | \
  sed 's/[ ]*<span class="visuallyhidden">Nazwa szpitala albo przychodni : <\/span>\(.*\)/\1/' > \
  current_parsed_facilities 
 
  cat current_source.html | \
  grep '^[ ]*<p class="result-date">' | \
  sed 's/[ ]*<p class="result-date">\([0-9]\{2\}\.[0-9]\{2\}\.[0-9]\{4\}\).*/\1/' | \
  awk 'NR % 2 == 1' > \
  current_parsed_vacant_dates

  cat current_source.html | \
  grep '^[ ]*<span>Pierwszy wolny termin<br />(<span class="date-info">' | \
  sed 's/[ ]*<span>Pierwszy wolny termin<br \/>(<span class="date-info">stan na \([0-9]\{2\}\.[0-9]\{2\}\.[0-9]\{4\}\).*/\1/' > \
  current_parsed_status_dates

  paste -d '\n' current_parsed_facilities current_parsed_vacant_dates current_parsed_status_dates > current_parsed
  cat current_parsed

  local ret=$RET_TICK

  if [ -f previous_parsed ]; then
    diff -q current_parsed previous_parsed
    if [ $? -ne 0 ]; then 
      echo NEW DATA > "output/${timestamp}_NEW_DATA"
      ret=$RET_FOUND
    fi
  fi

  cat current_parsed > previous_parsed
  cat current_parsed > "output/${timestamp}_parsed"

  return $ret
}

env "$@"
config

while true
do
  timestamp=$(date +"%F@%R:%S")
  dostep "$timestamp"
  ret=$?
  echo -------------------

  case $ret in
    $RET_TICK)
      echo --- CHECK $timestamp ---
      echo ------------------------
      play -q -V0 mixkit-on-or-off-light-switch-tap-2585.wav gain -n -10

      sleep $CHECK_INTERVAL
      ;;
    $RET_FOUND)
      echo --- NEW DATA! ---
      echo -----------------
      for i in {0..5}
      do
        play -q -V0 mixkit-christmas-reveal-tones-2988.wav gain -n 15
        sleep 3
      done
      spd-say -i +100 -r -15 "There is NEW DATA!"

      sleep $CHECK_INTERVAL
      ;;
    $RET_NETWORK_ERROR)
      echo --- NETWORK ERROR! ---
      echo ----------------------
      play -q -V0 mixkit-wrong-long-buzzer-954.wav gain -n 10

      sleep $RETRY_INTERVAL
      ;;
      
    *)
      echo --- UNEXPECTED ERROR! ---
      echo -------------------------
      play -q -V0 mixkit-wrong-long-buzzer-954.wav gain -n 10 repeat 5 reverb

      exit 1
      ;;
  esac
done
