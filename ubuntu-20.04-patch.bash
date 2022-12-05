#!/bin/bash

# ChangeLog
#
# ChangeLog

# use sudo script.bash

# clean
sudo apt-get clean -y

# set exclude service 
# sudo apt-mark hold   \
#     golang*        \
#     openjdk*        \
#     vault*

# sudo apt-mark unhold   \
#     golang*        \
#     openjdk*        \
#     vault*


# update and upgrade
sudo apt update && upgrade -y