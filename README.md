# openwrt 16mb spi flash on  wdr3600/4300 

# Часть аппаратная
Предположим, надыбали мы маршрутизатор.
Приличный такой, прям wifi двухдиапазанный, прям mimo 3x3x3,
Да два USB-порта.
Да вывод UART и JTAG под пины.

Например, tp-link wdr3600. 
Или даже wdr-4300.

Но. стоковая прошивка - фигня. Да еще со стоковым http(s)-бекдором.
Будем менять на openWrt.

Искаропки на wdr4300/wdr3600 идет флешка 25q64 на 8 мбайт.
Маловато.

Глядь - а у нас на шкафу лежат чипы 25q128. На 16Мб.
А с ними рядом - программатор ch341a.
А на ноуте - linux. И прога flashrom, которая этот программатор умеет.

Достаем с антресолей паяльный фен. Или пяльник. И сплав Вуда/Розэ.

16Мбайт - не сильно много. В идеале бы конечно еще больше - тут кашу маслом не испортить.
Но все равно, драматически место не увеличить, а головняка добавится.

за вменяемые деньги мне удалось найти только 25q256, да и то в корпусе не sop-8, а sop-16.
sop-16 на наш маршрутник, по идее, станет - выводы для этого есть.
Но 25q256 уже имеет немного другую адресацию и потребует углубленного изучения сырцов openWrt для адаптации.

Короче говоря, пока будем делать 16Мб + usb-флешка для потенциального перетыка на нее overlayFS.

Сначала сдуваем оригинальную флешЪ.
Втыкаем в программатор. И аккураттненько, с дублированием куда-ньть, сливаем с нее полный дамп.
Основной лут - это последние 64кб флешки. Там содержится раздел ART (atheros radio test).
Там содержится калибровачная инфа для wifi. 
Если его нет - wifi на маршрутизаторе работать не будет.
art, по идее, у всех разный. Поэтому его прям бекапим, как зеницу ока.

Сливаем фуллфлешЪ.
sudo flashrom -p ch341a_spi -r wdr4300_orig_8mb_full.bin -V

Файл 8Мб.
Это 8 388 608 байт.
Это 128 блоков по 64кб (по 65 536 байт)

Вынем оттуда ART-раздел в отдельный файл.
dd if=wdr4300_orig_8mb_full.bin of=art.bin bs=64k skip=127

(т.е. мы пропускаем 127 блоков по 64к, и dd-шим весь оставшийся один 128 блок размером 64к)

это если ART - на один диапазон wifi
Если два - ннада б два блока по 64

Отлично.
ART и фуллфлешЪ - на флешку и в сервант за стекло.


Наша новая флешка - 16Мб.
Это 16 777 216 байт.
Либо  256 блоков по 64кб.
И последним блоком должен быть ART раздел.

А первыми двумя блоками по 64кб, т.е. первые 128кб, первые 131 072 байта,
должен быть модифицированный загрузчик, который умеет 16Мб флешки.
u-boot с патчем. Либо китайский breed тут подойдут.

Я нагуглил патченный u-boot.
uboot-mod.bin

вынем оригинальный u-boot из оригинальной прошивки - там содержится MAC-адрес

dd if=wdr4300_orig_8mb_full.bin of=uboot.bin bs=64k count=2

Отлично.

Теперь соберем фуллфлешЪ с openWRT для флешки на 16Мб.
Сначала uboot:

из стока вынимаем:
dd if=uboot.bin of=macaddr.bin bs=1 skip=130048 count=6
dd if=uboot.bin of=model.bin bs=1 skip=130304 count=8
dd if=uboot.bin of=pin.bin bs=1 skip=130560 count=8

dd if=/dev/zero bs=64k count=2 | tr '\000' '\377' > uboot-new.bin

dd if=uboot_mod.bin of=uboot-new.bin conv=notrunc
dd if=macaddr.bin of=uboot-new.bin bs=1 count=6 seek=130048 conv=notrunc
dd if=model.bin of=uboot-new.bin bs=1 count=8 seek=130304 conv=notrunc
dd if=pin.bin of=uboot-new.bin bs=1 count=8 seek=130560 conv=notrunc

собрали uboot-new.bin

Для первого раза возьмем готовую сборку openWrt - она не будет уметь все 16Мб нового флеша.
Но мы запустим так. А потом соберем openWrt из сырцов под наши нужды.

Короч, качаем какая там версия подходит openwrt-..-sysupgrade.bin

Собираем фуллфлешЪ


dd if=/dev/zero bs=1M count=16 | tr '\000' '\377' > wdr4300-16Mb-fullflash.bin
dd if=uboot-new.bin of=wdr4300-16Mb-fullflash.bin conv=notrunc
dd if=openwrt-ath79-generic-tplink_tl-wdr3600-16m-squashfs-sysupgrade.bin of=wdr4300-16Mb-fullflash.bin bs=64k seek=2 conv=notrunc
dd if=art.bin of=wdr4300-16Mb-fullflash.bin bs=64k seek=255 conv=notrunc


есть вариантец сборщика 
#!/bin/bash

#read -p "enter initial 8mb fullflash [8fullflash.bin]-> " 8fullflash
#read -p "enter u-boot 16mb patched [uboot16.bin]-> " uboot16

# orig fullflash
#8fullflash = "8fullflash.bin"
# патченный
#uboot16 = "uboot16.bin"


echo "вынимаю ART"
# это - если wifi однотактный
#dd if=8fullflash.bin of=art.bin bs=64k skip=127
# так - если wdr4300 v1.3 с синими ламочками - у него, походу, арт двойной
dd if=8fullflash.bin of=art.bin bs=64k skip=126

read -p "норм?"
echo "вынимаю старый uboot"
dd if=8fullflash.bin of=uboot.bin bs=64k count=2

read -p "норм?"
echo "дербанил старый u-boot"
dd if=uboot.bin of=macaddr.bin bs=1 skip=130048 count=6
dd if=uboot.bin of=model.bin bs=1 skip=130304 count=8
dd if=uboot.bin of=pin.bin bs=1 skip=130560 count=8

read -p "норм?"
echo "делаем новый u-boot"
dd if=/dev/zero bs=64k count=2 | tr '\000' '\377' > uboot_new.bin

read -p "норм?"
echo "собираем новый u-boot"
dd if=uboot16.bin of=uboot_new.bin conv=notrunc
dd if=macaddr.bin of=uboot_new.bin bs=1 count=6 seek=130048 conv=notrunc
dd if=model.bin of=uboot_new.bin bs=1 count=8 seek=130304 conv=notrunc
dd if=pin.bin of=uboot_new.bin bs=1 count=8 seek=130560 conv=notrunc

read -p "норм?"
echo "собираем 16fullflash"
dd if=/dev/zero bs=1M count=16 | tr '\000' '\377' > 16fullflash.bin
dd if=uboot_new.bin of=16fullflash.bin conv=notrunc
dd if=openwrt-sysupgrade.bin of=16fullflash.bin bs=64k seek=2 conv=notrunc

read -p "норм?"
# если арт маленький
#dd if=art.bin of=16fullflash.bin bs=64k seek=255 conv=notrunc
# если арт большой
dd if=art.bin of=16fullflash.bin bs=64k seek=254 conv=notrunc

read -p "готово"


exit



супер. Теперь надеваем 16Мб флешку на программатор и льем в него новый фуллфлешЪ

sudo flashrom -p ch341a_spi -w wdr4300-16Mb-fullflash.bin -V

flashrom после записи проверяет, правильно ли он записал.
В моем случае автоматическая проверка не проходила.
Поэтому я разнес это на два действия.
Сперва пишу без проверки, потом сверяю с файлом то, что записалось.

sudo flashrom -p ch341a_spi -n -w wdr4300-16Mb-fullflash.bin -V
sudo flashrom -p ch341a_spi -v wdr4300-16Mb-fullflash.bin -V

Паяем на маршрутник, подтыкаемся к uart-консоли - смотрим как стартует.

Первый старт долгий. Прям долгий - надо чтоб распаковалось все и настроился overlayFS.

В конце будет что-то типа:

jffs2_scan_eraseblock(): End of filesystem marker found at 0x10000
[    9.728657] jffs2_build_filesystem(): unlocking the mtd device...
[    9.728710] done.
[    9.736951] jffs2_build_filesystem(): erasing all blocks after the end marker... 
[   57.265196] done.
[   57.274803] jffs2: notice: (483) jffs2_build_xattr_subsystem: complete building xattr subsystem, 0 of xdatum (0 unchecked, 0 orphan) and 0 of xref (0 dead, 0 orphan) found.
[   57.291806] mount_root: overlay filesystem has not been fully initialized yet
[   57.303130] mount_root: switching to jffs2 overlay
[   57.332760] overlayfs: upper fs does not support tmpfile.

это означит, что все ок.


Если старт произошел, все прокатило, ip a показывает устройства wlan, а df -h говорит, что overlay где-то 3.5Мб -
то все отлично, можно переходить к запилу своей версии openWRT.


# подготавливаем сборочный цех

apt install build-essential ccache ecj fastjar file g++ gawk \
gettext git java-propose-classpath libelf-dev libncurses5-dev \
libncursesw5-dev libssl-dev python python2.7-dev python3 unzip wget \
python3-distutils python3-setuptools rsync subversion swig time \
xsltproc zlib1g-dev

# тянем с гита
git clone https://github.com/openwrt/openwrt/ -b openwrt-19.07
cd openwrt 

кстати. там-то появилась уже 21.02 
с ядром посвежее, кароч

# тянем фиды && устанавливаем фиды
./scripts/feeds update -a  && \
./scripts/feeds install -a


теперь нужно поменять мап разделов в образе флешки на версию на 16Мб.

nano openwrt/target/linux/ath79/dts/ar9344_tplink_tl-wdr4300-v1.dts
Он, оказывается, использует файл
nano openwrt/target/linux/ath79/dts/ar9344_tplink_tl-wdr4300.dtsi
Он, оказывается, использует файл
nano openwrt/target/linux/ath79/dts/ar9344_tplink_tl-wdrxxxx.dtsi

в нем ищем  блок, где описано, до какого адреса будет раздел с firmware
и откуда начнется art

	partition@20000 {
				compatible = "tplink,firmware";
				label = "firmware";
				reg = <0x020000 0x7d0000>;
			};

			art: partition@7f0000 {
				label = "art";
				reg = <0x7f0000 0x010000>;
				read-only;
			};

меняем конец  раздела firmware с 0x7d0000 на 0xfd0000
начало art с 0x7f0000 на 0xff0000

сохраняем.


# ставим таргет  - tplink 4300 v1
make menuconfig

# для таргета делается default config
make defconfig
и
# make kernel_menuconfig (optional :!: it's highly likely that kernel modules from the repositories won't work when you make changes here).

# конфигуряй
make menuconfig

тут можно поправить dts файл
# можно сначала выкачать все, что будет нужно - чтоб могло в многопоточную сборку
make download


scripts/diffconfig.sh > mydiffconfig (save your changes in the text file mydiffconfig).

# start the build process.
make




Получилось в in/targets/ath79/generic -factory.bin и -sysupgrade.bin

супер. Можно вкидывать в маршрутник в /tmp 
и делать на него sysupgrade без сохранения конфигов.


Оно прошъется, перезагрузится, - проверяем df -h overlay


Через модифицированный u-boot тоже можно шиться 

Подключив заранее консолью в uart, сразу после старта будет момент 
"Hit any key to stop autoboot:"
надо тыкнуть enter

U-Boot 1.1.4 (Nov 23 2014 - 01:36:04)

DB120 (AR9344 - Wasp 1.2) U-Boot
DRAM:  128 MB
Flash: Winbond W25Q128 (16 MB)
Using default environment

Clocks: CPU:560MHz, DDR:450MHz, AHB:225MHz, Ref:40MHz
In:    serial
Out:   serial
Err:   serial
Net:   ag934x_enet_initialize...
Fetching MAC Address from 0x9f01fc00
Fetching MAC Address from 0x9f01fc00
WASP ----> S17 PHY *
GMAC: cfg1 0x7 cfg2 0x7114
eth0: 00:23:45:67:89:ab
athrs17_reg_init: complete
eth0 up
eth0
Hit any key to stop autoboot:  0 

ar7240> 
ar7240> httpd

Топчите в этот момент enter
Зайдется в режим работы с загрузчиком

Командой httpd можно поднять встроенный в загрузчик http-сервер на lan-портах по адресу 192.168.1.1 
(или какой он там скажет)

После чего через браузер можно вкинуть образ флешки для прошивки.
Но лучше тогда и  art добавлять в список прошиваемых

Я, кстати, не очень уверен, что изменения dts придут с образом -sysupgrade.
Скорее всего, нужен будет образ -factory.
А оно при прошивке потрет art.
Поэтому при прошивке через u-boot нужно будет указывать и -factory и art.

не забудьте вернуть wps pin и MAC-адрес!
можно сделать через u-boot


Если собираем openWRt с сырцов - получим свой набор пакетов.
Ядро получится кастомное. И на собранное с сырцов openwrt может получать отлуп из-за несовпадения версии накомпиленного

короч. на компе куда-ньть надо nginx'ом выставить накомпиленную репу.
и подоткнуть ее в /etc/opkg/distfeeds.conf вместо оригинального таргета

Далее

lte-модем HUAWEI 827F, прошитый в hilink (режим ndis) подключился так:

opkg install 
usb-modeswitch \
+ kmod-usb-net-cdc-ether

после этого модем стал видиться как сетевой интерфейс eth1 
на него надо сделать dhcp-клиент интерфейс в настройке сети - и все гут.


модем ZTE MF823D, прошитый в hilink (режим ndis) подключился так

opkg install 
+ usb-modeswitch \
+ kmod-usb-net-rndis \
+ kmod-usb-acm \
+ kmod-usb-core \
+ kmod-usb-ohci \
+ kmod-usb-serial \
+ comgt \
+ kmod-usb-serial-option \
+ kmod-usb-storage \
+ kmod-usb-uhci \
+ kmod-usb2 \

модем стал видиться как сетевой интерфейс usb0.
на него надо сделать dhcp-клиент интерфейс в настройке сети - и все гут.


Далее прикрутим флешку.
[ это пока в работе]
+ kmod-usb-storage
+ kmod-usb-storage-extras
+ kmod-scsi-core
+ block-mount 
+ kmod-fs-ext4  
+ e2fsprogs
+ kmod-fs-vfat 
+ kmod-nls-cp437 
+ kmod-nls-iso8859-1


OpenWRT + MWAN3 
несколько провайдеров.

(https://openwrt.org/docs/guide-user/network/wan/multiwan/mwan3)


Ура. Нам провели еще один инет.
А для USB-4G модема наконец-то появился подходящий тариф.

Супер.

Диспозиция следующая:
инет1. pppoe-justlan
инет2. eth0.3 (vlan-ned) dhcp (и там где-то на выходе из провайдера - nat)
инет3. usb-hilink. В системе видно как eth1

Задача - Настроить load-balance+failover на первых двух.
инет3 подымать, если и первый и второй подохли.

(Ну там еще уведомления, то-сё. Их прикрутим по факту как поедем)

opkg update 
opkg install mwan3


part1.1

Мы сделали оба интерфейса через luci-interfaces
Теперь идем и ставим метрики роутинга на каждый из обоих основных интерфейсах

interfaces -> pppoe-justlan -> advanced -> use gateway metrics = 20
interfaces -> eth0.3 -> advanced -> use gateway metrics = 10

проверяем, что применилось
root@OpenWrt:~# ip route show
default via 10.0.3.2 dev eth1  proto static  src 10.0.3.15  metric 10 
default via 10.0.4.2 dev eth2  proto static  src 10.0.4.15  metric 20

попингуем, чтоб проверить
$ ping ya.ru -I eth0.3 -c 3
PING ya.ru (87.250.250.242): 56 data bytes
64 bytes from 87.250.250.242: seq=0 ttl=56 time=16.843 ms
64 bytes from 87.250.250.242: seq=1 ttl=56 time=16.784 ms
64 bytes from 87.250.250.242: seq=2 ttl=56 time=16.832 ms

$ ping ya.ru -I pppoe-justlan -c 3
PING ya.ru (87.250.250.242): 56 data bytes
64 bytes from 87.250.250.242: seq=0 ttl=55 time=11.733 ms
64 bytes from 87.250.250.242: seq=1 ttl=55 time=11.538 ms
64 bytes from 87.250.250.242: seq=2 ttl=55 time=11.702 ms



mcedit /etc/config/mwan3
config globals 'globals'
    option enabled '1'
    option mmx_mask '0x3F00'

config interface 'justlan'
    option enabled '1'
    list track_ip '8.8.4.4'
    list track_ip '8.8.8.8'
    list track_ip 'ya.ru'
    option track_method 'ping'
    option reliability '1'
    option count '1'
    option timeout '2'
    option interval '5'
    option failure_interval '5'
    option recovery_interval '5'
    option down '3'
    option up '8'
    option family 'ipv4'

config interface 'ts'
    option enabled '1'
    list track_ip '8.8.4.4'
    list track_ip '8.8.8.8'
    list track_ip 'ya.ru'
    option track_method 'ping'
    option reliability '1'
    option count '1'
    option timeout '2'
    option interval '5'
    option failure_interval '5'
    option recovery_interval '5'
    option down '3'
    option up '8'
    option family 'ipv4'

config member 'wan1'
    option interface 'justlan'
    option metric '1'
    option weight '3'

config member 'wan2'
    option interface 'ts'
    option metric '2'
    option weight '3'

config policy 'balanced'
        list use_member 'wan1'
        list use_member 'wan2'

config rule 'https'
    option sticky '1'
    option dest_port '443'
    option proto 'tcp'
    option use_policy 'balanced'

config rule 'default_rule_v4'
    option dest_ip '0.0.0.0/0'
    option use_policy 'balanced'
    option family 'ipv4'



/etc/init.d/mwan3 start

/etc/init.d/mwan3 enable


mwan3 interfaces
mwan3 status


Подергаем провода - посмотрим, как все чотенько отрабатывает.
Значца, у мну было такое глючок.
У мну не подымался обратно PPPoE, пока я не поставил "LCP echo failure threshold" =40, а LCP echo interval = 5
После этого ppp стал чотко понимать, что туннель подох - ставил его на авторестарт, рестартовал, когда в проводах вновь появлялся тырнет.
Короч, заработало авторекавери


А еще далее - прикрутим apcupsd, потом usb-звуковуху, потом, если повезет с дровами - usb-видеокарту.
