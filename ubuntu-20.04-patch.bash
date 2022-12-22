#!/bin/bash

# ChangeLog
#
# ChangeLog

# use sudo script.bash

# clean
apt-get clean -y

# set exclude service 
# sudo apt-mark hold   \
#     golang*        \
#     openjdk*        \
#     vault*

# sudo apt-mark unhold   \
#     golang*        \
#     openjdk*        \
#     vault*

apt update && apt upgrade -y