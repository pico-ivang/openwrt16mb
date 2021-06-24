#!/bin/bash

# preparing - FROM ROOT

apt-add-repository universe
apt-add-repository multiverse
apt -y update

apt install build-essential ccache ecj fastjar file g++ gawk \
gettext git java-propose-classpath libelf-dev libncurses5-dev \
libncursesw5-dev libssl-dev python python2.7-dev python3 unzip wget \
python3-distutils python3-setuptools rsync subversion swig time \
xsltproc zlib1g-dev


# FROM NON-priv user

git clone https://github.com/openwrt/openwrt/
cd openwrt

./scripts/feeds update -a  && \
./scripts/feeds install -a

read -p "edit DTS and MK"

wget https://downloads.openwrt.org/releases/19.07.0/targets/ath79/generic/config.buildinfo  -O .config

echo "Global build settings - Select all userspace packages by default"
read -p "set CONFIG_ALL=y"
make menuconfig
make download
make -j<number_of_cores> V=s IGNORE_ERRORS="n m"	
