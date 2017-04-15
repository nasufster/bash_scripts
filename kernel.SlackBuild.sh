#!/bin/bash 
#
#  kernel.SlackBuild
#  Version 2.14

#  Copyright (c) 2011, Gary Langshaw. <gary.langshaw@ntlworld.com>
#  Permission to use, copy, modify, and/or distribute this software for any
#  purpose with or without fee is hereby granted, provided that the above
#  copyright notice and this permission notice appear in all copies.
#
#  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
#  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
#  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
#  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
#  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
#  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
#  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

#  Description:
#
#    This script will create an all-in-one kernel+modules package
#    for use on Slackware Linux. The build process will make use of
#    an out of tree build directory, allowing the kernel sources to be
#    read-only and remain pristine.  
#
#    It is recommended that The source directory be in pristine state
#    (make mrproper) prior to running this build script.
#
#    This script may be run by root or a non-root user. In the later case
#    the script will prompt the user for the root password which is required
#    to execute the final 'makepkg' stage only.

#  BUGS/TODO:
#    o  Not tested with a non-release development kernel 
#       with CONFIG_LOCALVERSION_AUTO set.
#    o  Only x86 and x86_64 archs supported at present. 
#       (patches welcome)

## Environment Setup:  #################################################

#  before we do anything else, sanitise the environment
unset IFS
PATH="/bin:/usr/bin:/sbin:/usr/sbin"

umask 0022    

# be kind, renice.
renice -n 19 $$ >/dev/null 2>&1 


## Constants and defaults:  ############################################

TMP="${TMPDIR:-/tmp/build}"
OUTPUT="${OUTPUT:-$TMP}"

BUILD="${BUILD:-1}"
TAG="${TAG:-_local}"

CONFIG="${CONFIG:-/proc/config.gz}"
SRCDIR="${SRCDIR:-/usr/src/linux}"

NUMJOBS="${NUMJOBS:-7}"

if [ -z "$ARCH" ]; then
  case "$( uname -m )" in
    i?86) ARCH=i486 ;;
    arm*) ARCH=arm ;;
       *) ARCH=$( uname -m ) ;;
  esac
fi

unset CLEAN

## Functions:  ########################################################

function exit_error ()
{
	echo "$*" >&2
	exit 1
}

function showUsage() 
{
	cat <<-_EOD
	Build all-in-one kernel + modules package for Slackware Linux.

	usage:

	  $0 [OPTION]...

	options:

	  [-c|--config] <kernel config-file> 

	  [-s|--src] <kernel source directory>

	  [-C|--localversion] <localversion string> 
	      Override existing LOCALVERSION specified within config file
                <space> characters will be converted to underscores.
                <localversion string> must not be null.

	  --clean  
	      removes temporary package build directory on exit
	
	  --help  
	      show help and exit.

	  --version
	      show version.
	
	notes:

	  kernel source search order:
	    1. --src command line argument
	    2. \$SRCDIR environment variable
	    3. /usr/src/linux

	  kernel config-file search order:
	    1. --config command line argument
	    2. \$CONFIG environment variable
	    3. /proc/config.gz

	_EOD
}

function alter_localversion()
{
        sed -e "s/\\(^CONFIG_LOCALVERSION=\"\\)\\(.*\\)\\(\"\\)/\\1${LOCALVERSION}\\3/"
}


## Main:  #############################################################

# Parse command line options

if [ "$1" = "--help" ]; then
  showUsage
  exit 0
fi

while [ ! -z "$1" -a "$1" != "--" ]
do
  case "$1" in
    -c | --config ) if [ ! -z "$2" -a "${2:0:1}" != "-" ] ; then
          CONFIG="$2"
          shift 2
        else
          echo "usage: -c <kernel-config file>" >&2
          exit 1
        fi 
        ;;
    -C | --localversion ) if [ ! -z "$2" ] ; then
          LOCALVERSION="${2// /_}"
          shift 2
        else
          echo "usage: -C <localversion string>" >&2
          exit 1
        fi 
        ;;
    -s | --src ) if [ ! -z "$2" -a "${2:0:1}" != "-" ] ; then
          SRCDIR="$2"
          shift 2
        else
          echo "usage: -s <kernel-source dir>" >&2
          exit 1
        fi 
        ;;
    --clean) CLEAN=1
        shift
        ;;
    --version) echo "$0: Version 2.14"
        exit 0
        ;;
     *) echo "unknown option: $1"
        shift
        ;;
  esac
done


# Canonicalise directories to ensure there are no surprises later on.

SRCDIR="$( readlink -e "${SRCDIR}" )" \
|| exit_error "Can't find source directory" 

CONFIG="$( readlink -e "${CONFIG}" )" \
|| exit_error "Can't find config file"
 

# Check target arch.

case "$ARCH" in
    i?86)  PKGARCH='i486' 
           ;;
  x86_64)  PKGARCH='x86_64' 
           ;;
       *)  exit_error "Sorry, This script currently only supports x86/x86_64"
           ;;
esac

#  Confirm files exist.

if [ ! -f "$SRCDIR/Makefile" ]; then
   exit_error "Can't find Makefile in source directory $SRCDIR"
fi


# Parse makefile and extract version information
 
while read line
do
  case "$line" in

    VERSION\ =\ *)         VERSION=${line#VERSION\ = }
                           ;;
    PATCHLEVEL\ =\ *)      PATCHLEVEL=${line#PATCHLEVEL\ = }
                           ;;
    SUBLEVEL\ =\ *)        SUBLEVEL=${line#SUBLEVEL\ = }
                           ;;
    EXTRAVERSION\ =\ *)    EXTRAVERSION=${line#EXTRAVERSION\ = }
                           ;;
  esac
done < "$SRCDIR/Makefile"


# Set uncompress command for config file (support /proc/config.gz)

if [[ "$CONFIG" =~ .*\.gz$ ]] ; then
      CATCMD_CONFIG='zcat'
   else
      CATCMD_CONFIG='cat'
fi

# Parse config file and extract LOCALVERSION string

if [ -z "$LOCALVERSION" ]; then
   while read line
   do
     case "$line" in

       CONFIG_LOCALVERSION=*)    line=${line#CONFIG_LOCALVERSION=\"}
                                 LOCALVERSION=${line%\"}
                                 ;;
     esac
   done < <( $CATCMD_CONFIG "$CONFIG" )
fi


# Set version number

OBJVER="${VERSION}.${PATCHLEVEL}.${SUBLEVEL}${EXTRAVERSION}${LOCALVERSION}"

# Generate package file name

PKGFILE="kernel-${OBJVER//-/_}-${PKGARCH}-${BUILD}${TAG}.txz"

# Display Confirmation

echo "------------------------------------------------------------------------"
echo "Kernel Build Information"
echo ""
echo "Source Directory:    $SRCDIR"
echo ""
echo "Config File:         $CONFIG"
echo "LOCALVERSION string: $LOCALVERSION"
echo ""
echo "OUTPUT PACKAGE:      $OUTPUT/$PKGFILE"
echo ""
echo "------------------------------------------------------------------------"
echo "Press enter to continue or ctrl-c to abort"
read 


# Build

PKGROOT="$( mktemp -t -d kernel-package.XXXXXX )" \
|| exit_error "Couldn't create temp directory for package root"

cd $PKGROOT || exit 1 

mkdir -p "usr/obj/${OBJVER}" lib boot install

cat > install/slack-desc <<_EOF
kernel: Kernel ${OBJVER}
kernel:
kernel: This is an all-in-one package that contains
kernel: a linux kernel, its modules and its build directory.
kernel:
kernel: Package includes:
kernel:   /boot/vmlinuz-${OBJVER}
kernel:   /boot/System.map-${OBJVER}
kernel:   /lib/modules/${OBJVER}/...
kernel:   /usr/obj/${OBJVER}/...
kernel:
_EOF

# CONFIG File

cd "${PKGROOT}/usr/obj/${OBJVER}" \
  && $CATCMD_CONFIG "$CONFIG" | alter_localversion > .config \
  || exit_error "Problem adding .config file to build directory"

# BUILD
#    arch/x86 is a symlink to x86_64 on 64 bit and will cater for both archs

cd "${SRCDIR}" \
  && make O="$PKGROOT/usr/obj/${OBJVER}" oldconfig \
  && make -j $NUMJOBS O="$PKGROOT/usr/obj/${OBJVER}" bzImage modules \
  && make -j $NUMJOBS O="$PKGROOT/usr/obj/${OBJVER}" modules_install INSTALL_MOD_PATH="$PKGROOT" \
  && cp "$PKGROOT/usr/obj/${OBJVER}/arch/x86/boot/bzImage" "$PKGROOT/boot/vmlinuz-${OBJVER}" \
  && cp "$PKGROOT/usr/obj/${OBJVER}/System.map" "$PKGROOT/boot/System.map-${OBJVER}" \
  && make -j $NUMJOBS O="$PKGROOT/usr/obj/${OBJVER}" clean \
  || exit_error "Problem with build phase" 


# Package

cd $PKGROOT || exit 1

find $PKGROOT -type d -exec chmod 755 {} +

ln -sf -T "/usr/obj/${OBJVER}" "$PKGROOT/lib/modules/${OBJVER}/build"


PKGCMD="makepkg -c y -l y $OUTPUT/$PKGFILE"

if [ "$EUID" = "0" ]; then
   $PKGCMD
else
   GROUP="$(id -gn $USER)"
   PRECMD="chown -R root:root $PKGROOT"
   POSTCMD="chown -R ${USER}:${GROUP} ${OUTPUT}/$PKGFILE $PKGROOT"
   echo ""
   echo "Kernel Build script needs to run the following as root:"
   echo "  $PRECMD"
   echo "  && $PKGCMD"
   echo "  && $POSTCMD"
   echo "Please enter root password, when prompted."
   su root -c "$PRECMD && $PKGCMD && $POSTCMD"
fi

# Cleanup

[ "$CLEAN" ] && rm -rf "$PKGROOT"


exit 0

## Done. ##############################################################
