#!/bin/bash

wget -O - https://packages.cisofy.com/keys/cisofy-software-public.key | sudo apt-key add -
echo "deb https://packages.cisofy.com/community/lynis/deb/ stable main" | sudo tee /etc/apt/sources.list.d/cisofy-lynis.list
echo 'Acquire::Languages "none";' | sudo tee /etc/apt/apt.conf.d/99disable-translations

sudo apt update

sudo apt install lynis -y

lynis -V