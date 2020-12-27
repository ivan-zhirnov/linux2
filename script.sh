#!/bin/bash

input_file=$1
set -e
set -o pipefail

echo "\"$input_file\""
# Если путь не был указана - завершаем работу с кодом 10
if [[ $input_file == "" ]]
then
  echo "Error: Enter a path to file in the first argument"
  exit 10
fi
echo "1 step is done"
# Если переданный параметр - не файл, то завершаем работу кодом 20
if [[ ! -f $input_file ]]
then
  echo "Error: File \"$input_file\" is empty or does not exist."
  exit 20
fi
echo "2 step is done"
# Защита от мультизапуска
if (( $(ps aux | grep $0 | wc -l) > 4 ))
then
  echo "Error: The Instance of this \"$input_file\" script is already running"
  exit 99
fi
echo "3 step is done"


temp=/tmp/log_analyser_dates.tmp
current_data=$(date "+%d/%b/%Y:%T")
current_data_sec=$(date +%s)
my_str="ЗАПИСИ ОБРАБОТАНЫ "$current_data

#Выводим текущую дату
echo "Текущая дата: $current_data"

# Проверяем, запускался ли скрипт до этого момента. Если да, то получаем дату последнего запуска
if [ -f $temp ]
then
    last_data_sec=$(cat $temp | tail -n 1)
    last_data=$(date --date=@$last_data_sec "+%d/%b/%Y:%T")
    echo "Прошлая дата анализа: $last_data"
fi

# Считаем количество новых записей в логе
echo "Начат подсчет новых записей"
#date "+%s" --date="$(tail -n1 nginx_logs | awk -F "[" {'print $2'} | awk {'print $1'} | sed "s/\//\ /g" | sed "s/:/ /" )"
new_records_count=$( tac $1 | awk '{  if ( $1=="ЗАПИСИ" && $2=="ОБРАБОТАНЫ" ) exit 0 ; else print }' | wc -l || true )
#echo "$(tac $1 | awk '{ if ( $1=="ЗАПИСИ" && $2=="ОБРАБОТАНЫ" ) { exit 0 } else { print } }' | wc -l)"

if [ $new_records_count -le 0 ]
then
    echo "Нет новых записей в $1 с $last_data"
    echo $current_data_sec >> $temp
    exit 0
fi
#let new_records_count--
echo "Количество новых записей в log-файле: $new_records_count"
echo $my_str >> $1

start_time_rande=$(cat $1 | head --line -1 | cut -d ' ' -f 4 | tail -n $new_records_count | sort -n | head -n1 | awk -F"[" '{print $2}' || true)
finish_time_rande=$(cat $1 | head --line -1 | cut -d ' ' -f 4 | tail -n $new_records_count | sort -nr | head -n1 | awk -F"[" '{print $2}' || true)
echo -e "Обрабатываемый диапазон: $start_time_rande - $finish_time_rande"

echo -e "\nТоп-5 IP-адресов, с которых посещался сайт\n"
cat $1 | head --line -1 | tail -n $new_records_count | cut -d ' ' -f 1 | sort | uniq -c | sort -nr | head -n 5 | awk '{ t = $1; $1 = $2; $2 = t; print $1,"\t\t",$2; }' || true

echo -e "\nТоп-5 ресурсов сайта, которые запрашивались клиентами\n"
cat $1 | head --line -1 | tail -n $new_records_count | cut -d ' ' -f 7 | sort | uniq -c | sort -nr | head -n 5 | awk '{ t = $1; $1 = $2; $2 = t; print $1,"\t",$2; }' || true

echo -e "\nСписок всех кодов возврата\n"
cat $1 | head --line -1 | tail -n $new_records_count | cut -d ' ' -f 9 | sort | sed 's/[^0-9]*//g' | awk -F '=' '$1 > 100 {print $1}' | uniq -c  | head -n 15 | awk '{ t = $1; $1 = $2; $2 = t; print $1,"\t\t\t",$2; }'|| true

echo -e "\nСписок кодов возврата 4xx и 5xx (только ошибки)\n"
cat $1 | head --line -1 | tail -n $new_records_count | cut -d ' ' -f 9 | sort | sed 's/[^0-9]*//g' | awk -F '=' '$1 > 400 {print $1}' | uniq -c  | head -n 15 | awk '{ t = $1; $1 = $2; $2 = t; print $1,"\t\t\t",$2; }'|| true

# Записываем дату последнего запуска скрипта
echo $current_data_sec >> $temp
