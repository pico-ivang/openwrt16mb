#!/bin/bash

# Это для TPLINK ARCHER C20 V4
# art у него в другом месте - смотри openwrt dts на него
# размер такой же

# короч. пока гипотеза такая - art даже на больших занимает 1 блок.
# поэтому skip 127

# issues
# чото херово снимается art
# вероятно, я напиздел, ибо загнался, что на больших маршрутниках art - два блока.
# щас перевыну art как один блок на party3-wdr4300 и сравню в party1
#
# upd
# чот херня какая-то. прошивки, что ли, разные. хз. надо fullflash найти на всю эту пижню

echo "Перед началом положите сюда:
- оригинальный фулфлешъ (сдуйте программатором)                      - файл fullflash8.bin
- правильный uboot, умеющий в 16Мб флешку (возьмите в папке files)   - файлом uboot16.bin
- openwrt-firmware-sysupgrade (скачайте у openwrt)                   - файлом openwrt-sysupgrade.bin"
read -p "погнали?"


#read -p "enter initial 8mb fullflash filename [fullflash8.bin]-> " fullflash8
#read -p "enter u-boot 16mb patched filename [uboot16.bin]-> " uboot16

#orig fullflash
fullflash8="fullflash8.bin"

##patched fullflash
uboot16="uboot16.bin"

read -p "вынимаю ART"
dd if=fullflash8.bin of=art.bin bs=64k count=1 skip=123
echo "art снялся норм?"

read -p "вынимаю старый uboot"
dd if=fullflash8.bin of=uboot8.bin bs=64k count=2
echo "оригинальный uboot вынулся норм?"

read -p "лутаю старый uboot за MAC, model_name и WDS pincode"
dd if=uboot8.bin of=macaddr.bin bs=1 skip=130048 count=6
dd if=uboot8.bin of=model.bin bs=1 skip=130304 count=8
dd if=uboot8.bin of=pin.bin bs=1 skip=130560 count=8
echo "чо там, облутали норм?"


read -p "собираю новый u-boot"
dd if=/dev/zero bs=64k count=2 | tr '\000' '\377' > uboot16_new.bin
echo "норм?"

read -p "наполняю новый u-boot - патченный uboot16 + mac + model + wds_pin"
dd if=uboot16.bin of=uboot16_new.bin conv=notrunc
dd if=macaddr.bin of=uboot16_new.bin bs=1 count=6 seek=130048 conv=notrunc
dd if=model.bin of=uboot16_new.bin bs=1 count=8 seek=130304 conv=notrunc
dd if=pin.bin of=uboot16_new.bin bs=1 count=8 seek=130560 conv=notrunc
echo "норм?"

read -p "собираю 16Мб фулфлешъ fullflash16.bin"
dd if=/dev/zero bs=1M count=16 | tr '\000' '\377' > fullflash16.bin
dd if=uboot16_new.bin of=fullflash16.bin conv=notrunc
dd if=openwrt-sysupgrade.bin of=fullflash16.bin bs=64k seek=2 conv=notrunc
echo "норм?"

read -p "вкидываю ART"
## хз# если арт маленький
dd if=art.bin of=fullflash16.bin bs=64k seek=255 conv=notrunc
## хз # если арт большой - вот про вот это надо будет по-подробнее, про большой арт я встретился в 4300-blu
## хз # dd if=art.bin of=fullflash16.bin bs=64k seek=254 conv=notrunc
echo "норм?"

echo "сборку 16Мб фулфлеша - готово."
read -p " шейте fullflash16.bin"


exit
