# openwrt16mb
openwrt 16mb spi flash on  wdr3600/4300 

Предположим, надыбали мы маршрутизатор.
Хороший такой, чтоб wifi двухдиапазанный, прям mimo 3x3x3,
Да чтоб два USB-порта.
Да вывод UART и JTAG.

Например, tp-link wdr3600. 
Или даже wdr-4300.

Но стоковая прошивка - фигня. Да еще со стоковым http(s)-бекдором. 
Будем менять на openWrt.
Искаропки на wdr4300/wdr3600 идет флешка 25q64 на 8 мбайт. 
Маловато.

Глядь - а у нас на шкафу лежат чипы 25q128. На 16Мб.
А с ними рядом - программатор ch341a.
А на ноуте - linux. И прога flashrom, которая этот программатор умеет.

Достаем с антресолей паяльный фен. Или пяльник. 
И сплав Вуда/Розэ.

16Мбайт - не сильно много. В идеале бы конечно еще больше - тут кашу маслом не испортить.  
Но все равно, драматически место не увеличить.

за вменяемые деньги мне удалось найти только 25q256, да и то в корпусе не sop-8, а sop-16.
sop-16 на наш маршрутник, по идее, станет - выводы для этого есть.

Но 25q256 уже имеет немного другую адресацию и потребует углубленного изучения сырцов openWrt для адаптации.
Короче говоря, пока будем делать 16Мб + usb-флешка для потенциального перетыка на нее overlayFS. 

Сначала сдуваем оригинальную флешъ. 
Втыкаем в программатор. И аккураттненько, с дублированием куда-ньть, сливаем с нее полный дамп.
Основной лут - это последние 64кб флешки. Там содержится раздел ART (atheros radio test).
Там содержится калибровачная инфа для wifi. 
Если его нет - wifi на маршрутизаторе не будет. 
art, по идее, у всех разный. Поэтому его прям бекапим как зеницу ока.

Сливаем флешъ.
sudo flashrom -p ch341a_spi -r wdr4300_orig_8mb_full.bin -V


Файл 8Мб.
Это 8 388 608 байт.
Это 128 блоков по 64кб (по 65 536 байт)

Выделим оттуда ART раздел в отдельный файл 
dd if=wdr4300_orig_8mb_full.bin of=art.bin bs=64k skip=127

т.е. мы пропускаем 127 блоков по 64к, и dd-шим весь оставшийся один 128 блок размером 64к.

Отлично. 
ART и фулфлешъ - на флешку и в сервант за стекло.


Наша новая флешка - 16Мб. 
Это 16 777 216 байт. 
Либо  256 блоков по 64кб.
И последним блоком должен быть ART раздел.

А первыми двумя блоками по 64кб,
т.е. первые 128кб, первые 131 072 байта
Должен быть модифицированный загрузчик, который умеет 16Мб флешки.
u-boot с патчем. Либо китайский breed тут подойдут.

Я нагуглил патченный u-boot.
uboot-mod.bin

вынем оригинальный u-boot из оригинальной прошивки - там содержится MAC-адрес

dd if=wdr4300_orig_8mb_full.bin of=uboot.bin bs=64k count=2

Отлично.

Теперь соберем фулфлешъ с openWRT для флешки на 16Мб.
Сначала uboot


dd if=uboot.bin of=macaddr.bin bs=1 skip=130048 count=6
dd if=uboot.bin of=model.bin bs=1 skip=130304 count=8
dd if=uboot.bin of=pin.bin bs=1 skip=130560 count=8

dd if=/dev/zero bs=64k count=2 | tr '\000' '\377' > uboot-new.bin

dd if=uboot_mod.bin of=uboot-new.bin conv=notrunc
dd if=macaddr.bin of=uboot-new.bin bs=1 count=6 seek=130048 conv=notrunc
dd if=model.bin of=uboot-new.bin bs=1 count=8 seek=130304 conv=notrunc
dd if=pin.bin of=uboot-new.bin bs=1 count=8 seek=130560 conv=notrunc

собрали uboot-new.bin

Для начала возьмем готовую сборку openWrt - она не будет уметь все 16Мб нового флеша.
Но сперва мы запустим так. А потом соберем openWrt под наши нужды.

Короч, качаем какая там версия подходит openwrt-..-sysupgrade.bin

Собираем fullflash


dd if=/dev/zero bs=1M count=16 | tr '\000' '\377' > wdr4300-16Mb-fullflash.bin
dd if=uboot-new.bin of=wdr4300-16Mb-fullflash.bin conv=notrunc
dd if=openwrt-ath79-generic-tplink_tl-wdr3600-16m-squashfs-sysupgrade.bin of=wdr4300-16Mb-fullflash.bin bs=64k seek=2 conv=notrunc
dd if=art.bin of=wdr4300-16Mb-fullflash.bin bs=64k seek=255 conv=notrunc

супер. Теперь надеваем 16Мб флешку на программатор и льем в него новый фулфлешъ

sudo flashrom -p ch341a_spi -w wdr4300-16Mb-fullflash.bin -V

flashrom после записи проверяет, правильно ли он записал.
В моем случае проверка не проходила.
Поэтому я разнес это на два действия.
Сперва пишу без проверки, потом проверяю.

sudo flashrom -p ch341a_spi -n -w wdr4300-16Mb-fullflash.bin -V
sudo flashrom -p ch341a_spi -v wdr4300-16Mb-fullflash.bin -V

Паяем на маршрутник, подтыкаемся к uart-консоли - смотрим как стартует.

Первый старт долгий. Прям долгий - надо чтоб распаковалось все и настроился overlayFS.

Будет что-то типа 

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

Я, кстати, не очень уверен, что изменения dts придут с -sysupgrade.
Скорее всего, нужен будет -factory. 
А оно потрет art. 
Поэтому нужно будет указывать и -factory для прошивки 
и art.

не забудьте вернуть wps pin и MAC-адрес!
можно сделать через u-boot


Если собираем openWRt с сырцов - получим свой набор пакетов.
Ядро получится кастомное. И на собранное с сырцов openwrt может получать отлуп из-за несовпадения 
версии накомпиленного

короч. на компе куда-ньть надо nginx ом вставить накомпиленную репу.



lte-модем HUAWEI 827F, прошитый в hilink (режим ndis) подключился так:

opkg install usb-modeswitch kmod-usb-net-cdc-ether

после этого модем стал видиться как сетевой интерфейс eth1 
на него надо сделать dhcp-клиент интерфейс в настройке сети - и все гут.


модем ZTE MF823D, прошитый в hilink (режим ndis) подключился так

opkg install usb-modeswitch \
kmod-usb-net-rndis kmod-usb-acm kmod-usb-core \
kmod-usb-ohci kmod-usb-serial comgt \
kmod-usb-serial-option kmod-usb-storage \
kmod-usb-uhci kmod-usb2 \

модем стал видиться как сетевой интерфейс usb0.
на него надо сделать dhcp-клиент интерфейс в настройке сети - и все гут.

Далее прикрутим флешку.

[ ну, пока в работе]


