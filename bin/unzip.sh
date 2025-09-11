#!/bin/bash

for i in "$@"; do
    #if [[ "$i" =~ ^[+-]?[0-9]+$ ]]; then
    #    if (( 10#$i == 0 )); then
    #        echo "nulla"
    #    fi
    #else
    if [ "${i:(-4)}" = ".zip" ]; then
        d="${i%/*}"
        cd "$d"
        n="${i##*/}" #echo "${i##*/}" | sed 's/\.zip$//'
        n="${n%????}"
        mkdir "$n"
        #cd "${i%????}"
        cd "$n"
        unzip "$i"
        rm "$i"
    fi
done