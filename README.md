TP-Link WDR3600/4300 - увеличение внутренней памяти до 16Мб 
======================================
#### с последующей установкой OpenWRT, собранной из сырцов


Часть вводная
=============


Предположим, мы налутали маршрутизатор.   
Приличный такой, прям wifi двухдиапазонный, прям mimo 3x3x3.  
Да два USB-порта.  
Да вывод UART и JTAG под пины.  
 
Например, __tp-link wdr3600__.  
Или даже __tp-link wdr-4300__.  

Но.  
Стоковая прошивка на нем - __фигня__.   
Да еще, похоже, со стоковым __http(s)-бекдором__.

**Будем менять на OpenWrt**

Искаропки на wdr4300/wdr3600 идет чип ПЗУ памяти (внутренняя флешка) w25q64 на 8 мбайт в корпусе sop-8.  
Маловато.


Глядь - а у нас на шкафу лежат чипы w25q128. На 16Мб.  
А с ними рядом - программатор ch341a.  
А на ноуте - linux. И прога flashrom, которая этот программатор умеет.

Достаем с антресолей паяльный фен. Или пяльник и сплав Вуда/Розэ.

16Мбайт - не сильно много. В идеале бы, конечно, еще больше - тут кашу маслом не испортить.
Но все равно, драматически место не увеличить, а головняка в пересборку образа openWRT для такого развития событий добавится.



за вменяемые деньги мне удалось найти только w25q256, однако уже корпусе sop-16, а не sop-8.

sop-16 на наш маршрутник, по идее, станет, т.к. выводы для этого есть.  
Но w25q256 уже имеет немного другую адресацию и потребует углубленного изучения сырцов openWrt для адаптации.

Пока отложим идею в сторону. Все равно, USB-флешка на 32гига за шапку сухарей - гораздо более экономически целесообразно.


Диспозиция (допили)
=========
Маршрутизатор wdr3600/4300 собраны на atheros 9xxx ()

в терминах openWRT wdr4300 - архитектура ath79

[ Картинку бы маршрутников.
Закрытый
Открытый
Распаяные UART
Фотка флешки
Расписон про sop8/sop16
ссылка на openWRT раздел про 4300 ]



Часть аппаратная
================
Будем менять штатную 8Мб флешку на 16Мб + usb-флешка для потенциального переноса на нее overlayFS, чтобы вместо 16Мб после загрузки openWRT получить прям несколько гигов "места на диске".

Сначала сдуваем с платы маршрутизатора оригинальную флешку.  
Втыкаем в программатор. 
И аккуратненько, с последующим дублированием куда-ньть, сливаем с нее полный дамп. получаем фуллфлешЪ.

Основная ценность дампа - раздел ART (atheros radio test), в котором содержатся калибровачные данные для wifi.  
Без этих данных wifi на таких atheros чипах не заводится.

Есть еще mac-адрес и WDS-pin, но эти цифры можно и с корпуса маршрутника списать и потом руками поправить-переделать. 

Главное - __НЕ ПОТЕРЯЙТЕ ART оригинальный.__

Linux ядро openWRT (для этих tp-linkов - точно) использует DTS - Linux Device Tree для "detecting undetectable hardware" - определения неопределяемого железа.  
Например, чтобы видеть разделы на SPI флешке. Она - не hdd, там не все так просто.

Посмотреть разблюдовку разделов мы будем в сырцах openWRT.
Считать будем будем блоками по 64к.

**первые 128кб - два блока по 64k - загрузчик**

стоковый загрузчик весит килобайт немного меньше, чем 128k=2x64k. 
Но все равно, делаем кратно блокам 64кб.

**последние 64кб - раздел ART**.
**UPD** это утверждение оказалось верно для wdr3600-wdr4300, а так же для wr842/wr841 старых ревизий.

Для archer_C20 оказалось, что раздел ART начинается раньше на несколько 64к блоков.
Поэтому тут лучше в каждом конкретном случае лучше смотреть исходный DTS-файл маршрутизатора от команды openWRT. 



**все, что последине - это сама прошивка**


Основной лут - это последние 64кб флешки. Там содержится раздел ART (atheros radio test).



Сливаем фуллфлешЪ.
------------------

	

Файл 8Мб.

Это 8 388 608 байт.

Это 128 блоков по 64кб (по 65 536 байт)



Вынем оттуда ART-раздел в отдельный файл.
------------------------------------------

мы пропускаем (skip) 127 блоков по 64к, и dd-шим весь оставшийся один блок №128 размером 64к

	dd if=wdr4300_orig_8mb_full.bin of=wdr4300_art.bin bs=64k skip=127



Отлично.

ART и фуллфлешЪ нужно скопировать на usb-флешку, и положить её в сервант за стекло, в хрустальную вазочку для аджики (не все поймут, немногие вспомнят).



Наша новая флешка имеет размер 16Мб.

Это 16 777 216 байт.

Оно же 256 блоков по 64кб.


И последним блоком №256 должен быть ART раздел, полученный нами на предыдущем шаге.


А первыми двумя блоками по 64кб, т.е. первые 128кб, первые 131 072 байта,

должен быть модифицированный загрузчик, который умеет 16Мб флешки.

u-boot с патчем на поддержку 16мб. (см в папке files).
Либо китайский breed тоже подойдет.



Загрузчик расположен по таким hex-адресам:


	0x000000000000-0x000000020000 : "u-boot"

Я нагуглил патченный u-boot.(см в папке files).

**uboot16.bin**


Давайте вынем оригинальный u-boot из оригинальной прошивки - там содержатся MAC-адреса и PIN для WDS.


	dd if=wdr4300_orig_8mb_full.bin of=uboot-orig.bin bs=64k count=2



Теперь соберем фуллфлешЪ с openWRT для флешки на 16Мб.


Собираем модифицированный uboot16:
----------------------------------

из файла со стоковой прошивкой вынимаем:

	dd if=uboot-orig.bin of=macaddr.bin bs=1 skip=130048 count=6
	dd if=uboot-orig.bin of=model.bin bs=1 skip=130304 count=8
	dd if=uboot-orig.bin of=pin.bin bs=1 skip=130560 count=8
	


Готовим файл для нового uboot16

	dd if=/dev/zero bs=64k count=2 | tr '\000' '\377' > uboot16.bin

	dd if=uboot_mod.bin of=uboot16.bin conv=notrunc
	dd if=macaddr.bin of=uboot16.bin bs=1 count=6 seek=130048 conv=notrunc
	dd if=model.bin of=uboot16.bin bs=1 count=8 seek=130304 conv=notrunc
	dd if=pin.bin of=uboot16.bin bs=1 count=8 seek=130560 conv=notrunc
	
**собрали uboot16.bin**


Для первого раза, чтобы разобраться с uboot на 16Мб, возьмем готовую сборку openWrt - она не будет уметь использовать все 16Мб нового флеша.

*Оригинальный образ openWRT будет содержать ядро, собраное с DTS под размер оригинальной флешки - 8Мб. Соответственно, будет ожидать ART-раздел в конце этих 8 Мб.
Получившийся у нас 16Мб фулфлеш имеет ART в конце 16Мб. И ядро его не увидит, wifi не будет на тестах.

Но мы запустимся пока так. 
А потом соберем openWrt из сырцов с правильной картой разделов под наши нужды. Образ под карту DTS компилится на этапе make из сырцов - поэтому руками поправить уже готовое пока никак.


Короч, качаем какая там версия для нашего маршрутизатора подходит файл *openwrt-..-sysupgrade.bin*



Собираем фуллфлешЪ
-------------------

	dd if=/dev/zero bs=1M count=16 | tr '\000' '\377' > wdr4300-16Mb-fullflash.bin
	dd if=uboot-new.bin of=wdr4300-16Mb-fullflash.bin conv=notrunc
	dd if=openwrt-ath79-generic-tplink_tl-wdr4300-16m-squashfs-sysupgrade.bin of=wdr4300-16Mb-fullflash.bin bs=64k seek=2 conv=notrunc

**внимательно! seek 255 - у нас 16Мб флеш образ. это 256 блоков по 64кб. и ART нам надо записать в последний блок 16Мб**

	dd if=art.bin of=wdr4300-16Mb-fullflash.bin bs=64k seek=255 conv=notrunc


есть вариантец сборщика  в папке files ( *надо бы сюда вставить ссылку на скриптец* )



супер. Теперь надеваем 16Мб флешку на программатор и льем в него новый фуллфлешЪ

	sudo flashrom -p ch341a_spi -w wdr4300-16Mb-fullflash.bin -V

flashrom после записи проверяет, правильно ли он записал.

В моем случае (ubuntu 20.04 + самый дешманский программатор) автоматическая проверка не проходила, валилась с ошибкой.

Поэтому я разнес это на два действия.

Сперва пишу без проверки, потом сверяю с файлом то, что записалось.


	sudo flashrom -p ch341a_spi -n -w wdr4300-16Mb-fullflash.bin -V
	sudo flashrom -p ch341a_spi -v wdr4300-16Mb-fullflash.bin -V
	


Паяем на маршрутник, подтыкаемся к uart-консоли маршрутизатора, включаем аппарат и наблюдаем как стартует.

Первый старт долгий. Прям долгий - надо чтоб распаковалось все и настроился overlayFS.

В конце будет что-то типа:

	jffs2_scan_eraseblock(): End of filesystem marker found at 0x10000
	[    9.728657] jffs2_build_filesystem(): unlocking the mtd device...
	[    9.728710] done.
	[    9.736951] jffs2_build_filesystem(): erasing all blocks after the end marker... 
	[   57.265196] done.
	[   57.274803] jffs2: notice: (483) jffs2_build_xattr_subsystem: complete building xattr subsystem, 0 of xdatum (0 unchecked, 0 orphan) and 0 of xref (0 dead, 0 	orphan) found.
	[   57.291806] mount_root: overlay filesystem has not been fully initialized yet
	[   57.303130] mount_root: switching to jffs2 overlay
	[   57.332760] overlayfs: upper fs does not support tmpfile.

это означит, что все ок.


Если старт произошел, все прокатило, ```ip a``` показывает устройства, в т.ч. wlan0/1, а df -h говорит, что overlay где-то 3.5Мб -
то все отлично, можно переходить к запилу своей версии openWRT.



Часть программная
=================

подготавливаем сборочный цех https://openwrt.org/docs/guide-developer/toolchain/install-buildsystem
----------------------------

**для debian-ubuntu**

	apt install build-essential ccache ecj fastjar file g++ gawk \
	gettext git java-propose-classpath libelf-dev libncurses5-dev \
	libncursesw5-dev libssl-dev python python2.7-dev python3 unzip wget \
	python3-distutils python3-setuptools rsync subversion swig time \
	xsltproc zlib1g-dev libcap-dev llvm-12-dev clang-12  libstdc++-12-dev


это нужно сделать чтобы сработала проверка на qosify в openwrt-22

	ln -s /usr/bin/clang-12 /usr/bin/clang
	mkdir /home/egi/openwrt22/staging_dir/host/llvm-bpf/bin/
	sudo ln -s /usr/bin/clang /home/egi/openwrt22/staging_dir/host/llvm-bpf/bin/clang


**для redhat/centos/oraclelinux**

	dnf --skip-broken install bash-completion bzip2 gcc gcc-c++ git \
	make ncurses-devel patch perl-Data-Dumper perl-Thread-Queue python2 \
	python3 rsync tar unzip wget perl-base perl-File-Compare \
	perl-File-Copy perl-FindBin diffutils which

**для alpine**

	apk add asciidoc bash bc binutils bzip2 cdrkit coreutils diffutils \
	findutils flex g++ gawk gcc gettext git grep intltool libxslt \
	linux-headers make ncurses-dev openssl-dev patch perl python2-dev \
	python3-dev rsync tar unzip util-linux wget zlib-dev subversion \
	ca-certificates libcap-dev


тянем с гита сырцы
-------------------
на момент работы над статьей, актуальная openWRT была 19.07

	git clone https://github.com/openwrt/openwrt/
        git checkout openwrt-19.07         
	cd openwrt

Версию ветки, на какую сделать checkout можете посмотреть через git __branch -r__

UPD: на версиях 22.03.7 (final 22) и 23.05.5 (final 23) у luCI какие-то проблемы на tplink wdr3600/wdr4300. luCI регулярно падает и команды ей надо подтыкать по нескольку раз. если это не пугает- шейте свежие версии.

тянем фиды && устанавливаем фиды
--------------------------------

	./scripts/feeds update -a  && ./scripts/feeds install -a


патчим DTS
--------------------

Идем менять мап разделов в образе флешки на версию 16Мб.

	nano openwrt/target/linux/ath79/dts/ar9344_tplink_tl-wdr4300-v1.dts

Он, оказывается, использует файл

	nano openwrt/target/linux/ath79/dts/ar9344_tplink_tl-wdr4300.dtsi

Он, оказывается, использует файл
	
	nano openwrt/target/linux/ath79/dts/ar9344_tplink_tl-wdrxxxx.dtsi

в нем ищем  блок, где описано, какого размера будет раздел с firmware
и откуда начнется раздел art

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

формат записи reg = <начало_раздела размер_раздела>

прибавим к размеру раздела firmware еще 8Мб (это 0x800000)  
0x7d0000 + 0x80000 = 0xfd0000

и сдвинем начало раздела art, ибо firmware у нас будет размером больше  
было 0x20000 + 0x7d0000             = 0x7f0000
стало 0x20000 + 0x7d0000 + 0x800000 = 0xff0000 

**меняем размер раздела firmware с 0x7d0000 на 0xfd0000  
начало art с 0x7f0000 на 0xff0000**

таким образом art у нас закончится по адресу 0x1000000
что равно 16 777 216 байтам = 16Мб


патчим firmware size
--------------------

Нужно сделать, чтобы образ собирался не под 8Мб, а под 16М - иначе, если вы через menuconfig наберете софта больше, чем на 8 - при сборке получите ошибку "overlay is too big- не могу запихать все, что вы тута понавыбрали"

        mcedit openwrt/target/linux/ath79/image/generic-tp-link.mk

ищем модель маршрутника - 3600 или 4300 

	define Device/tplink_tl-wdr3600-v1
	  	$(Device/tplink-8mlzma)

вторую строчку меняем на 16mlzma

	define Device/tplink_tl-wdr3600-v1
		$(Device/tplink-16mlzma)

теперь при сборке openwrt будет считать, что нужно собрать образ размером 16Мб

обратите внимание, если будете пилить это под другой какой аппарат - не все аппараты норм жуют lzma (привет tplink wr841)
Поэтому если в define Device стоит 8m без lzma - **стоит сделать 16m без lzma**


**скачаем конфиг, которым собран оригинальный образ openWRT под наш аппарат**

	wget https://downloads.openwrt.org/releases/19.07.0/targets/ath79/generic/config.buildinfo  -O .config


**Так можно сказать, чтобы на сборку отправились все пакеты - мы тогда можем сделать свой репозиторий для OPKG**

	mcedit .config
	...
	CONFIG_ALL=y 


Можно сделать через меню make menuconfig
**Global build settings --> Select all userspace packages by default**



**ставим таргет  - tplink 4300 v1**
**UPD: в 21 версии oWRT можно указать multiple targets и в пункте ниже этого выбрать какие таргеты собирать - к примеру, сразу и 3600 и 4300**

	make menuconfig


**конфигуряем сборку**

	make menuconfig


**можно сначала выкачать все, что будет нужно - чтоб могло в многопоточную сборку**

	make download


**компиляй**

***DO NOT RUN THIS FROM ROOT!!***
Run this from usual user

	make -j<number_of_cores+1> V=s IGNORE_ERRORS="n m"

оно же

	make -j<nproc+1> V=s IGNORE_ERRORS="n m"

> так вообще почтитайте тут
> https://openwrt.org/docs/guide-developer/build-system/use-buildsystem


**Получились файлы в <папка_openwrt>/targets/ath79/generic -factory.bin и -sysupgrade.bin**

супер.


**можно сцедить diff**
	
	scripts/diffconfig.sh > mydiffconfig (save your changes in the text file mydiffconfig).


Когда оно прошъется, перезагрузится, - проверяем df -h overlay



Через модифицированный u-boot тоже можно шиться через web
----------------------------------------------------------

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


Внимание
--------
Если собираем openWRT с сырцов - получим свой набор пакетов.
Ядро получится кастомное. И на собранное с сырцов openwrt может получать отлуп из-за несовпадения версии накомпиленного

короч. на компе куда-ньть надо nginx'ом выставить накомпиленную репу.
и подоткнуть ее в /etc/opkg/distfeeds.conf вместо оригинального таргета

Как подоткнуть оф репку opkg для работы с кастомным билдом - напишу как узнаю

как костыль - можно **bin/packages** и **bin/targets** выставить по http при помощи nginx.  
А в **/etc/opkg.conf** закомментировать `option Signature_check`.  
Иначе оно бородит, ругаясь про signature check в Packages.sig

Кстати, перегенерить в своей кастомной сборке Packages.gz и Packages.sig можно так

    make package/intex



## USB  PowerCycle

оказалось, что USB в 3600/4300 питаются отдельной линией.  
И, соответственно, нет возможности "переткнуть" usb-девайс (модем) программно
Обломно.
Придется колхозить реле.

Есть GPIO пины. Можно их попробовать заюзать.


Прикрутим USB-модемы
--------------------


для поддержки **usb-wifi китайского донгла 3g/4g->wifi+rndis**

    opkg install \  
    kmod-usb-net-cdc-eem \  
    kmod-usb-net-cdc-ether \  
    kmod-usb-net-cdc-mbim \  
    kmod-usb-net-cdc-ncm \  
    kmod-usb-net-cdc-subset \  
    kmod-usb-net-dm9601-ether \  
    kmod-usb-net-hso \  
    kmod-usb-net-ipheth \  
    kmod-usb-net-kalmia \  
    kmod-usb-net-kaweth \  
    kmod-usb-net-mcs7830 \  
    kmod-usb-net-pegasus \  
    kmod-usb-net-qmi-wwan \  
    kmod-usb-net-sierrawireless \  
    kmod-usb-net-smsc95xx \  
    kmod-usb-net-rndis \  
    umbim    

Весьма вероятно, что не вся пачка нужна.
Надо бы потестить, что из этого потенциально не нужно

Тут появится интерфейс usb0.  
Когда USB-девайс появился в системе, надо сделать на него сетевой интерфейс и добавить в группу WAN на фаере, чтоб оно заработало


lte-модем **HUAWEI 827F**, прошитый в hilink (режим ndis) подключился так:

	opkg install \
	usb-modeswitch \
	kmod-usb-net-cdc-ether

***usb-modeswitch** в openwrt_22 называется по-другом*

после этого модем стал видиться как сетевой интерфейс eth1.  
Когда eth1 появился в системе, надо сделать на него сетевой интерфейс и добавить в группу WAN на фаере, чтоб оно заработало


модем **ZTE MF823D**, прошитый в hilink (режим ndis) подключился так

    opkg install \
    usb-modeswitch \
    kmod-usb-net-rndis \
    kmod-usb-acm \
    kmod-usb-core \
    kmod-usb-ohci \
    kmod-usb-serial \
    comgt \
    kmod-usb-serial-option \
    kmod-usb-storage \
    kmod-usb-uhci \
    kmod-usb2

***usb-modeswitch** в openwrt_22 называется по-другом*

модем стал видеться как сетевой интерфейс usb0.  
Когда USB-девайс появился в системе, надо сделать на него сетевой интерфейс и добавить в группу WAN на фаере, чтоб оно заработало


Прикрутим USB-флешку.
-----------------

[ это пока в работе]

	opkg install \
	kmod-usb-storage \
	kmod-usb-storage-extras \
	kmod-scsi-core \
	block-mount \
	kmod-fs-ext4 \
	e2fsprogs \
	kmod-fs-vfat \
	kmod-nls-cp437 \
	kmod-nls-iso8859-1


Перетащим overlay на флешку, чтоб больше места в /root было
--------------------------

Разделы на флешке готовите сами.

Чтоб на всякий случай замонтируем оригинальный mtd-раздел с /rootfs в /rwm

    DEVICE="$(sed -n -e "/\s\/overlay\s.*$/s///p" /etc/mtab)"
    uci -q delete fstab.rwm
    uci set fstab.rwm="mount"
    uci set fstab.rwm.device="${DEVICE}"
    uci set fstab.rwm.target="/rwm"
    uci commit fstab

либо руками

Сперва выясняем у mtd, кто где /root

`grep -e rootfs_data /proc/mtd`

    mtd4: 00a10000 00010000 "rootfs_data"

запишем

`mcedit /etc/config/fstab`

    config mount 'rwm'
        option device '/dev/mtdblock4'
        option target '/rwm'

#### `mount -a` тут не сработает. вероятно, сработает при перезагрузке  

    

А кто у нас флешка?

`block info`

    /dev/mtdblock3: UUID="3c933fa2-461a3e9c-e2fc716c-8dde8a0a" VERSION="4.0" MOUNT="/rom" TYPE="squashfs"       
    /dev/mtdblock4: MOUNT="/overlay" TYPE="jffs2"  
    /dev/sda1: UUID="47e4c5f4-e163-44d2-b9a4-4b534aa7ba7a" VERSION="1.0" MOUNT="/mnt" TYPE="ext4"     

флешка /dev/sda1.

Копируем /root

    mkdir -p /tmp/cproot
    mount --bind /overlay /tmp/cproot
    mount /dev/sda1 /mnt
    tar -C /tmp/cproot -cvf - . | tar -C /mnt -xf -
    umount /tmp/cproot /mnt

теперь скажем, чтоб монтировал /overlay с флешки

    DEVICE="/dev/sda1"
    eval $(block info ${DEVICE} | grep -o -e "UUID=\S*")
    uci -q delete fstab.overlay
    uci set fstab.overlay="mount"
    uci set fstab.overlay.uuid="${UUID}"
    uci set fstab.overlay.target="/overlay"
    uci commit fstab

или руками

`mcedit /etc/config/fstab`

    config mount 'overlay'
        option uuid '47e4c5f4-e163-44d2-b9a4-4b534aa7ba7a'
        option target '/overlay'

Все. го в ребут   

    reboot


Добавим Swap
------------

проаллоцируем место под свап

    dd if=/dev/zero of=/swapfile1 bs=1M count=1000

форматируем файл как блочник своп

    mkswap /swapfile1

добавим в fstab

    uci -q delete fstab.swap1
    uci set fstab.swap1="mount"
    uci set fstab.swap1.device="/swapfile1"
    uci set fstab.swap1.target="swap"
    uci commit fstab

или руками

    config mount 'swap1'
        option device '/swapfile1'
        option target 'swap'


и получаем `failed to swapon /swapfile1`

Хрен знает почему. буду потом.


OpenWRT + MWAN3 = несколько провайдеров.
----------------------------------------

(https://openwrt.org/docs/guide-user/network/wan/multiwan/mwan3)


Ура. Нам провели еще один инет.
А для USB-4G модема наконец-то появился подходящий тариф.


Диспозиция следующая:
инет1. pppoe-justlan
инет2. eth0.3 (vlan-ned) dhcp (и там где-то на выходе из провайдера - nat)
инет3. usb-hilink. В системе видно как eth1

Задача - Настроить load-balance+failover на первых двух.
инет3 подымать, если и первый и второй подохли.

(Ну там еще уведомления, то-сё. Их прикрутим по факту как поедем)

	opkg update 
	opkg install mwan3

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


пилим конфиг на переключатор MWAN3

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


Стартуем

	/etc/init.d/mwan3 start

	/etc/init.d/mwan3 enable


	mwan3 interfaces
	mwan3 status


Подергаем провода - посмотрим, как все чотенько отрабатывает.


*Значца, у мну было такое глючок.

У мну не подымался обратно PPPoE, пока я не поставил **LCP echo failure threshold = 40**, а **LCP echo interval = 5**

После этого ppp стал чотко понимать, что туннель подох - ставил его на авторестарт, рестартовал, когда в проводах вновь появлялся тырнет.

угу-мс, заработало авторекавери*




Docker
---------

Если скомпилили с softFPU - пробуем установить докер

    opkg install docker dockerd docker-compose
    /etc/init.d/dockerd enable




###### А еще далее - прикрутим **apcupsd**, потом **usb-звуковуху**, потом, если повезет с дровами - **usb-видеокарту**.


###  NodeJS

Это будет непросто, ибо FP (floating point) поддержки в камнях на этих маршрутниках нет. Надо будет прям покрутить.
Вроде бы есть решение  
https://forum.openwrt.org/t/how-to-enable-mips-fpu-emulator-when-compiling/80997/5

Если коротенько - то нужно включить **FP-emulator**    
Говорят, если нагрузка на FP небольшая - он норм работает  

ЧоКак:

    make menuconfig
    # (finish and close menuconfig)
    echo "CONFIG_KERNEL_MIPS_FP_SUPPORT=y" >> .config
    # (do not open menuconfig)
    make # start compiling OpenWrt


### Надо б еще запилить тему **ImageBuilder**

очень удобно - за ночь скомпилять ВЕСЬ openWRT в модуля. 

И ImageBuilder пусть тоже соберет.

А потом, имея на руках ядро с правильными всеми делами, ImageBuilder'ом уже собирать назные сборки софта.

Ну, расскажу как-ньть.


Bon Chance!
