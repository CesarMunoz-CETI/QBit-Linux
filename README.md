# Qbit-Linux

El sistema QBIT se construirá utilizando una distribución Linux ya instalada (Arch). Este sistema Linux existente (el host) se utilizará como punto de partida para proporcionar los programas necesarios, incluidos un compilador, un enlazador y shell, para construir el nuevo sistema.

Más adelante, este README describe cómo crear una nueva partición nativa de Linux y un sistema de archivos. Este es el lugar donde se compilará e instalará el nuevo sistema QBit. También explica qué paquetes y parches deben descargarse para construir el sistema QBit y cómo almacenarlos en el nuevo sistema de archivos. Más tarde, el README analiza la configuración de un entorno de trabajo apropiado.

En el futuro, el README explicará la instalación de la cadena de herramientas inicial (binutils, `GCC` y `GLIBC`) utilizando técnicas de compilación cruzada para aislar las nuevas herramientas del sistema host, cómo compilar las utilidades básicas utilizando la cadena de herramientas recién construido.

## Preparación del sistema de host

En esta sección, las herramientas de host necesarias para construir QBIT se verifican y, si es necesario, se instalan. Luego se prepara una partición que aloje el sistema QBIT.

El sistema de host tiene el siguiente software con las versiones indicadas. Muchas distribuciones colocarán encabezados de software en paquetes separados, a menudo en forma de "(nombre)-devel" o "(nombre)-dev". Estos están instalados si la distribución los proporciona.

* `Bash-3.2` (`/bin/sh` debe ser un enlace simbólico o duro para la fiesta)
* `Binutils-2.13.1` (no se recomiendan versiones superiores a 2.39, ya que no se han probado)
* `Bison-2.7` (`/usr/bin/yacc` debe ser un enlace a bisonte o script pequeño que ejecute bisonte)
* `Coreutils-6.9`
* `Diffutils-2.8.1`
* `Findutils-4.2.31`
* `Gawk-4.0.1` (`/usr/bin/awk` debería ser un enlace a gawk)
* `GCC-4.8` incluyendo el compilador `C++`, `G++` (no se recomiendan versiones superiores a 12.2.0 ya que no se han probado). Las bibliotecas estándar `C` y `C++` (con encabezados) también deben estar presentes para que el compilador `C++` pueda construir programas alojados
* `Grep-2.5.1a`
* `GZIP-1.3.12`
* `M4-1.4.10`
* `Make-4.0`
* `Patch-2.5.4`
* `Perl-5.8.8`
* `Python-3.4`
* `Sed-4.1.5`
* `Tar-1.22`
* `Texinfo-4.7`
* `XZ-5.0.0`
* `Linux Kernel-3.2`

> La razón del requisito de la versión del kernel es que se requiere esa versión al construir `GLIBC` y `UDEV`

Para ver si el sistema de host tiene todas las versiones apropiadas, escribimos lo siguiente:

```sh
#!/bin/bash
export LC_ALL=C
bash --version | head -n1 | cut -d" " -f2-4
MYSH=$(readlink -f /bin/sh)
echo "/bin/sh -> $MYSH"
echo $MYSH | grep -q bash || echo "ERROR: /bin/sh does not point to bash"
unset MYSH

echo -n "Binutils: "; ld --version | head -n1 | cut -d" " -f3-
bison --version | head -n1

if [ -h /usr/bin/yacc ]; then
  echo "/usr/bin/yacc -> `readlink -f /usr/bin/yacc`";
elif [ -x /usr/bin/yacc ]; then
  echo yacc is `/usr/bin/yacc --version | head -n1`
else
  echo "yacc not found"
fi

echo -n "Coreutils: "; chown --version | head -n1 | cut -d")" -f2
diff --version | head -n1
find --version | head -n1
gawk --version | head -n1

if [ -h /usr/bin/awk ]; then
  echo "/usr/bin/awk -> `readlink -f /usr/bin/awk`";
elif [ -x /usr/bin/awk ]; then
  echo awk is `/usr/bin/awk --version | head -n1`
else
  echo "awk not found"
fi

gcc --version | head -n1
g++ --version | head -n1
grep --version | head -n1
gzip --version | head -n1
cat /proc/version
m4 --version | head -n1
make --version | head -n1
patch --version | head -n1
echo Perl `perl -V:version`
python3 --version
sed --version | head -n1
tar --version | head -n1
makeinfo --version | head -n1  # texinfo version
xz --version | head -n1

echo 'int main(){}' > dummy.c && g++ -o dummy dummy.c
if [ -x dummy ]
  then echo "g++ compilation OK";
  else echo "g++ compilation failed"; fi
rm -f dummy.c dummy
```

## Crear una nueva partición

Como la mayoría de los otros sistemas operativos, QBIT se instalará en una partición dedicada. El enfoque recomendado para construir un sistema Linux es utilizar una partición vacía disponible o, si tenemos suficiente espacio no sarticado, para crear uno.

Un sistema mínimo requiere una partición de alrededor de 10 gigabytes (GB). Esto es suficiente para almacenar todos los tarballs de origen y compilar los paquetes. Sin embargo, si el sistema Linux está destinado a ser el sistema principal, probablemente se instalará un software adicional que requerirá espacio adicional. Una partición de 30 GB es un tamaño razonable para proporcionar crecimiento. El sistema QBIT en sí no ocupará tanto espacio. Una gran parte de este requisito es proporcionar suficiente almacenamiento temporal gratuito, así como para agregar capacidades adicionales después de que se complete QBIT. Además, los paquetes de compilación pueden requerir mucho espacio en disco que se recuperará después de instalar el paquete.

Debido a que no siempre hay suficiente memoria de acceso aleatorio (RAM) disponible para procesos de compilación, es una buena idea usar una pequeña partición de disco como espacio de intercambio. El núcleo utiliza esto para almacenar datos rara vez usados y dejar más memoria disponible para procesos activos. La partición de intercambio para un sistema Linux puede ser la misma que la utilizada por el sistema host, en cuyo caso no es necesario crear otro.

Primero comenzamos un programa de partición de disco como CFDISK o FDISK con una opción de línea de comando que nombra el disco duro en el que se creará la nueva partición, por ejemplo `/dev/sda` para la unidad de disco primaria. Luego creamos una partición nativa de Linux y una partición de intercambio, si es necesario.

### La partición raíz `'/'`
Una partición QBit raíz (que no debe confundirse con el directorio `/root`) de veinte gigabytes es un buen compromiso para la mayoría de los sistemas. Proporciona suficiente espacio para construir QBit, pero es lo suficientemente pequeño como para que se puedan crear fácilmente múltiples particiones para experimentar.

### La partición de SWAP
La mayoría de las distribuciones crean automáticamente una partición de SWAP. En general, el tamaño recomendado de la partición de SWAP es aproximadamente el doble de la cantidad de RAM física, sin embargo, esto rara vez es necesario. Si el espacio en el disco es limitado, mantenga la partición de intercambio a dos gigabytes y monitoree la cantidad de intercambio de disco.

Si queremos usar la función de hibernación (suspender al disco) de Linux, escribe el contenido de RAM a la partición de intercambio antes de apagar la máquina. En este caso, el tamaño de la partición de intercambio debe ser al menos tan grande como la RAM instalada del sistema.

### La partición de BIOS de GRUB
Si el disco de arranque se ha dividido con una tabla de partición GUID (GPT), entonces una pequeña partición, típicamente 1 MB, debe crearse si aún no existe. Esta partición no está formateada, pero debe estar disponible para que Grub lo use durante la instalación del cargador de arranque. Esta partición normalmente se etiquetará con 'BIOS Boot' si usa FDisk o tiene un código de EF02 si usa GDisk.

> La partición GRUB BIOS debe estar en la unidad que usa el BIOS para iniciar el sistema. Este no es necesariamente el mismo disco donde se encuentra la partición raíz de LFS. Los discos en un sistema pueden usar diferentes tipos de tabla de partición. El requisito de esta partición depende solo del tipo de tabla de partición del disco de arranque.

### Otras particiones

`/boot`: muy recomendable. Use esta partición para almacenar núcleos y otra información de arranque. Para minimizar posibles problemas de arranque con discos más grandes, haga de esta la primera partición física en su primera unidad de disco. Un tamaño de partición de 200 megabytes es bastante adecuado.

`/boot/efi`: la partición del sistema EFI, que es necesaria para arrancar el sistema con UEFI.

`/home`: muy recomendable. Comparta su directorio de inicio y la personalización del usuario en múltiples distribuciones o compilaciones LFS. El tamaño es generalmente bastante grande y depende del espacio de disco disponible.

`/usr` - en QBit, `/bin`, `/lib` y `/sbin` son enlaces simbólicos a su contraparte en `/usr`. Entonces `/usr` contiene todos los binarios necesarios para que el sistema se ejecute. Para QBit, normalmente no se necesita una partición separada para `/usr`. Si lo necesita de todos modos, debe hacer una partición lo suficientemente grande como para adaptarse a todos los programas y bibliotecas en el sistema. La partición raíz puede ser muy pequeña (tal vez solo un gigabyte) en esta configuración, por lo que es adecuado para un cliente delgado o una estación de trabajo sin disco (donde `/usr` está montado desde un servidor remoto). Sin embargo, debe tener cuidado de que se necesite un `initramfs` para iniciar un sistema con partición separada `/usr`.

`/opt`: este directorio es más útil para QBit, donde se pueden instalar múltiples instalaciones de paquetes grandes como GNOME o KDE sin incorporar los archivos en la jerarquía `/usr`. Si se usa, de 5 a 10 gigabytes es generalmente adecuado.

`/tmp`: un directorio separado `/tmp` es raro, pero es útil si configura un cliente delgado. Esta partición, si se usa, generalmente no necesitará exceder un par de gigabytes.

## Creación de un sistema de archivos

Despues de configurar una partición en blanco, se puede crear el sistema de archivos. QBit puede usar cualquier sistema de archivos reconocido por el kernel de Linux, pero los tipos más comunes son ext3 y ext4. La elección del sistema de archivos puede ser compleja y depende de las características de los archivos y el tamaño de la partición. Por ejemplo:

#### ext2

Es adecuado para pequeñas particiones que se actualizan con poca frecuencia, como /arranque.

#### ext3

Es una actualización a Ext2 que incluye un diario para ayudar a recuperar el estado de la partición en el caso de un cierre inmundo. Se usa comúnmente como un sistema de archivos de propósito general.

#### ext4

Es la última versión de la familia de sistemas de archivos EXT de tipos de partición. Proporciona varias capacidades nuevas, incluidas las marcas de tiempo nano-segundo, la creación y el uso de archivos muy grandes (16 TB) y mejoras de velocidad.

> QBIT asume que el sistema de archivos raíz `(/)` es de tipo `ext4`. Para crear un sistema de archivos ext4 en la partición QBit, ejecutamos lo siguiente:

```sh
mkfs -v -t ext4 /dev/nombre
mkswap /dev/nombre
```

## Configuración de la variable QBIT

A lo largo de la documentación, la variable de entorno `QBIT` se utilizará varias veces. Esta variable siempre se define en todo el proceso de construcción de QBit. Se establece en el nombre del directorio donde construiremos el sistema QBit: usaremos `/mnt/qbit` como ejemplo. Establecemos la variable con el siguiente comando:

```sh
export QBIT=/mnt/qbit
```

Tener esta variable es beneficioso, ya que los comandos como `mkdir -v $QBIT/tools` se pueden escribir literalmente. El shell reemplazará automáticamente `$QBIT` con `/mnt/qbit` cuando procesa la línea de comando.

## Montando la nueva partición

Ahora que se ha creado un sistema de archivos, la partición debe hacerse accesible. Para hacer esto, la partición debe montarse en un punto de montaje elegido. Para los fines de este proyecto, se supone que el sistema de archivos está montado en el directorio especificado por la variable de entorno `QBIT` como se describe en la sección anterior.

Creamos el punto de montaje ejecutando:

```sh
mkdir -pv $QBIT
mount -v -t ext4 /dev/nombre $QBIT
```

Si usa múltiples particiones para QBIT (por ejemplo, una para `/` y otra para `/home`), las montamos usando:

```sh
mkdir -pv $QBIT
mount -v -t ext4 /dev/nombre $QBIT
mkdir -v $QBIT/home
mount -v -t ext4 /dev/nombre $QBIT/home
```

Esta nueva partición no esta montada con permisos que sean demasiado restrictivos (como las opciones `nosuid` o `nodev`). Ejecutamos el comando de montaje sin ningún parámetros para ver qué opciones están configuradas para la partición de QBit montada. Si se establecen `nosuid` y/o `nodev`, la partición deberá volver a montar.

## Instalación de paquetes

Esta sección incluye una lista de paquetes que deben descargarse para crear un sistema básico de Linux. Los números de versión enumerados corresponden a versiones del software que se sabe que funcionan. Para algunos paquetes, el lanzamiento de Tarball y el repositorio Git se pueden publicar con un nombre de archivo similar. Una liberación de tarball contiene archivos generados (por ejemplo, Configurar script generado por Autoconf), además del contenido de la instantánea del repositorio correspondiente. El proyecto utiliza tarballs de lanzamiento siempre que sea posible.

Los paquetes y parches descargados deberán almacenarse en algún lugar que esté convenientemente disponible en toda la compilación. También se requiere un directorio de trabajo para desempacar las fuentes y construirlas. `$ QBIT/Sources` se puede usar como el lugar para almacenar los tarballas y parches y como un directorio de trabajo. Al usar este directorio, los elementos requeridos se ubicarán en la partición `QBIT` y estarán disponibles durante todas las etapas del proceso de construcción.

Para crear este directorio, ejecutamos el siguiente comando, como raíz del usuario, antes de comenzar la sesión de descarga:

```sh
mkdir -v $QBIT/sources
```

Hicimos este directorio `writeable` y `sticky`. "Sticky" significa que incluso si varios usuarios tienen permiso de escritura en un directorio, solo el propietario de un archivo puede eliminar el archivo dentro de un directorio adhesivo. El siguiente comando habilitará los modos de escritura y sticky:

```sh
chmod -v a+wt $QBIT/sources
```

Hay dos formas de obtener todos los paquetes y parches necesarios para construir QBit:

* Los archivos se pueden descargar individualmente.
* Los archivos se pueden descargar usando wget y una lista de wget.

Para descargar todos los paquetes y parches utilizando wget-list-sysv como entrada al comando wget, usamos:

```sh
wget --input-file=wget-list-sysv --continue --directory-prefix=$QBIT/sources

pushd $QBIT/sources
  md5sum -c md5sums
popd
```

### Lista de todos los paquetes instalados

| `nombre-paquete` (version)             | Tamaño KB    |
|----------------------------------------|---------------
| `acl` (2.3.1)                          | 348 KB
| `attr` (2.5.1)                         | 456 KB
| `autoconf` (2.71)                      | 1,263 KB
| `automake` (1.16.5)                    | 1,565 KB
| `bash` (5.1.16)                        | 10,277 KB
| `bc` (6.0.1)                           | 441 KB
| `binutils` (2.39)                      | 24,578 KB
| `bison` (3.8.2)                        | 2,752 KB
| `bzip2` (1.0.8)                        | 792 KB
| `check` (0.15.2)                       | 760 KB
| `coreutils` (9.1)                      | 5,570 KB
| `dejagnu` (1.6.3)                      | 608 KB
| `diffutils` (3.8)                      | 1,548 KB
| `e2fsprogs` (1.46.5)                   | 9,307 KB
| `elfutils` (0.187)                     | 9,024 KB
| `eudev` (3.2.11)                       | 2,075 KB
| `expat` (2.4.8)                        | 444 KB
| `expect` (5.45.4)                      | 618 KB
| `file` (5.42)                          | 1,080 KB
| `findutils` (4.9.0)                    | 1,999 KB
| `flex` (2.6.4)                         | 1,386 KB
| `gawk` (5.1.1)                         | 3,075 KB
| `gcc` (12.2.0)                         | 82,662 KB
| `gdbm` (1.23)                          | 1,092 KB
| `gettext` (0.21)                       | 9,487 KB
| `glibc` (2.36)                         | 18,175 KB
| `gmp` (6.2.1)                          | 1,980 KB
| `gperf` (3.1)                          | 1,188 KB
| `grep` (3.7)                           | 1,603 KB
| `groff` (1.22.4)                       | 4,044 KB
| `grub` (2.06)                          | 6,428 KB
| `gzip` (1.12)                          | 807 KB
| `iana-etc` (20220812)                  | 584 KB
| `inetutils` (2.3)                      | 1,518 KB
| `intltool` (0.51.0)                    | 159 KB
| `iproute2` (5.19.0)                    | 872 KB
| `kbd` (2.5.1)                          | 1,457 KB
| `kmod` (30)                            | 555 KB
| `less` (590)                           | 348 KB
| `lfs-bootscripts` (20220723)           | 33 KB
| `libcap` (2.65)                        | 176 KB
| `libffi` (3.4.2)                       | 1,320 KB
| `libpipeline` (1.5.6)                  | 954 KB
| `libtool` (2.4.7)                      | 996 KB
| `linux` (5.19.2)                       | 128,553 KB
| `m4` (1.4.19)                          | 1,617 KB
| `make` (4.3)                           | 2,263 KB
| `man-db` (2.10.2)                      | 1,860 KB
| `man-pages` (5.13)                     | 1,752 KB
| `meson` (0.63.1)                       | 2,016 KB
| `mpc` (1.2.1)                          | 820 KB
| `mpfr` (4.1.0)                         | 1,490 KB
| `ncurses` (6.3)                        | 3,500 KB
| `ninja` (1.11.0)                       | 228 KB
| `openssl` (3.0.5)                      | 14,722 KB
| `patch` (2.7.6)                        | 766 KB
| `perl` (5.36.0)                        | 12,746 KB
| `pkg-config` (0.29.2)                  | 1,970 KB
| `procps` (4.0.0)                       | 979 KB
| `psmisc` (23.5)                        | 395 KB
| `python` (3.10.6)                      | 19,142 KB
| `sed` (4.8)                            | 1,317 KB
| `shadow` (4.12.2)                      | 1,706 KB
| `sysklogd` (1.5.1)                     | 88 KB
| `sysvinit` (3.04)                      | 216 KB
| `tar` (1.34)                           | 2,174 KB
| `tcl` (8.6.12)                         | 10,112 KB
| `texinfo` (6.8)                        | 4,848 KB
| `time zone data` (2022c)               | 423 KB
| `udev-lfs-tarball` (udev-lfs-20171102) | 11 KB
| `util-linux` (2.38.1)                  | 7,321 KB
| `vim` (9.0.0228)                       | 16,372 KB
| `wheel` (0.37.1)                       | 65 KB
| `xml::parser` (2.46)                   | 249 KB
| `xz utils` (5.2.6)                     | 1,234 KB
| `zlib` (1.2.12)                        | 1259 KB
| `zstd` (1.5.2)                         | 1,892 KB

## Preparaciones finales

Después de instalar los paquetes, realizamos algunas tareas adicionales para prepararnos para construir el sistema temporal. Creamos un conjunto de directorios en `$QBIT` para la instalación de las herramientas temporales, agregamos un usuario no privilegiado para reducir el riesgo y creamos un entorno de compilación apropiado para ese usuario.

```sh
mkdir -pv $QBIT/{etc,var} $QBIT/usr/{bin,lib,sbin}

for i in bin lib sbin; do
  ln -sv usr/$i $QBIT/$i
done

case $(uname -m) in
  x86_64) mkdir -pv $QBIT/lib64 ;;
esac
```

Cuando se inicia sesión como root, cometer un solo error puede dañar o destruir un sistema. Por lo tanto, los paquetes se construyen como un usuario sin privilegios. Creamos un nuevo usuario llamado `qbit` como miembro de un nuevo grupo (también llamado `qbit`). Para hacerlo como root, emitimos los siguientes comandos para agregar el nuevo usuario:

```sh
groupadd qbit
useradd -s /bin/bash -g qbit -m -k /dev/null qbit
```

Configuramos un entorno de trabajo creando dos nuevos archivos de inicio para `Bash`. Se ejecuta el siguiente comando para crear un nuevo `.bash_profile`:

```sh
cat > ~/.bash_profile << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF
```

El shell inicial suele ser un shell de inicio de sesión que lee el perfil `/etc/profile` del host (probablemente contiene algunas configuraciones y variables de entorno) y luego `.bash_profile`. El comando `ex env -i .../bin/bash` en el archivo `.bash_profile` reemplaza el shell en ejecución con uno nuevo con un entorno completamente vacío, excepto el `HOME`, `TERM` y las variables `PS1`. Esto asegura que ninguna variables de entorno no deseadas y potencialmente peligrosas del sistema host se filtre al entorno de compilación.

La nueva instancia del shell es un shell no login, que no lee, y ejecuta, el contenido de `/etc/profile` o archivos `.bash_profile`, sino que lee y ejecuta el archivo `.bashrc`:

```sh
cat > ~/.bashrc << "EOF"
set +h
umask 022
QBIT=/mnt/qbit
LC_ALL=POSIX
QBIT_TGT=$(uname -m)-qbit-linux-gnu
PATH=/usr/bin
if [ ! -L /bin ]; then PATH=/bin:$PATH; fi
PATH=$QBIT/tools/bin:$PATH
CONFIG_SITE=$QBIT/usr/share/config.site
export QBIT LC_ALL QBIT_TGT PATH CONFIG_SITE
EOF
```

El significado de la configuración en `.bashrc`

`set +h`

El comando `set +h` apaga la función hash de Bash. Normalmente, el hash es una característica útil: Bash utiliza una tabla hash para recordar la ruta completa de los archivos ejecutables para evitar buscar la hora de la ruta y nuevamente para encontrar el mismo ejecutable. Sin embargo, las nuevas herramientas deben usarse tan pronto como se instalen. Al apagar la función hash, el shell siempre buscará la ruta cuando se ejecute un programa. Como tal, el shell encontrará las herramientas recién compiladas en `$QBIT/tools/bin` tan pronto como estén disponibles sin recordar una versión anterior del mismo programa proporcionado por el host, en `/usr/bin` o `/bin`.

`umask 022`

Colocar la máscara de creación de archivos de usuario (`umask`) en `022` asegura que los archivos y directorios recién creados solo sean escritos por su propietario, pero que sea legible y ejecutable por cualquier persona (suponiendo que los modos predeterminados sean utilizados por la llamada del sistema `open(2)`, nuevos archivos, archivos nuevos Terminará con el modo de permiso `644` y directorios con el modo `755`).

`QBIT=/mnt/qbit`

La variable QBIT debe establecerse en el punto de montaje elegido.

`LC_ALL=POSIX`

La variable LC_ALL controla la localización de ciertos programas, haciendo que sus mensajes sigan las convenciones de un país específico. Configurar LC_All en "`POSIX`" o "`C`" (los dos son equivalentes) asegura que todo funcione como se esperaba en el entorno `chroot`.

`QBIT_TGT=(uname -m)-qbit-linux-gnu`

La variable `QBIT_TGT` establece una descripción de la máquina no definitiva, pero compatible, para su uso al construir nuestro compilador y enlazador y al compilar nuestra cadena de herramientas temporal.

`PATH=/usr/bin`

Many modern linux distributions have merged /bin and /usr/bin. When this is the case, the standard PATH variable needs just to be set to /usr/bin/ for the Chapter 6 environment. When this is not the case, the following line adds /bin to the path.

Muchas distribuciones modernas de Linux se han fusionado `/bin` y `/usr/bin`. Cuando este es el caso, la variable de ruta estándar debe establecerse en `/usr/bin/` para el entorno. Cuando este no es el caso, la siguiente línea agrega `/bin` a la ruta.

`if [ ! -L /bin ]; then PATH=/bin:$PATH; fi`

Si `/bin` no es un enlace simbólico, entonces debe agregarse a la variable de `PATH`.

`PATH=$QBIT/tools/bin:$PATH`

Al colocar `$QBIT/tools/bin` por delante de la `PATH` estándar, el compilador instalado es recogido por el shell inmediatamente después de su instalación. Esto, combinado con apagar el hashing, limita el riesgo de que se use el compilador host en lugar del compilador cruzado.

`CONFIG_SITE=$QBIT/usr/share/config.site`

Si esta variable no está configurada, scripts de configuración pueden intentar cargar elementos de configuración específicos para algunas distribuciones de `/usr/share/config.site` en el sistema host.

`export ...`

Si bien los comandos anteriores han establecido algunas variables, para que sean visibles dentro de cualquier subshell, las exportamos.

