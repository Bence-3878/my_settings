#!/bin/bash

pacman -Suuy
echo -e "\e[31mfrisités\e[39;49m"

VALAMI=""

for i in $VALAMI; do
pacman -S $i
echo -e "\e[31m"$i "csomag telepitése\e[39;49m"
done