#!/bin/bash

if [ "$#" -lt 1 ];then
	echo "Usage: $0 <install folder (absolute path)>"
	echo "For sudoer recommend: $0 /opt"
	echo "For normal user recommend: $0 $HOME/app"
	exit 0
fi

echo -n "installing c3d..." #-n without newline

DEST=$1
mkdir -p $DEST

C3D_DIR=$DEST/c3d
if [ -d $C3D_DIR ]; then
	rm -rf $C3D_DIR
fi

mkdir -p $C3D_DIR

VERSION=c3d-1.1.0-Linux-x86_64
curl -s -L --retry 6 https://cfhcable.dl.sourceforge.net/project/c3d/c3d/Experimental/$VERSION.tar.gz | tar zx -C $C3D_DIR --strip-components=1

if [ -e $HOME/.profile ]; then #ubuntu
	PROFILE=$HOME/.profile
elif [ -e $HOME/.bash_profile ]; then #centos
	PROFILE=$HOME/.bash_profile
else
	echo "Add PATH manualy: PATH=$C3D_DIR/bin"
	exit 0
fi

#check if PATH already exist in $PROFILE
if grep -xq "export PATH=$C3D_DIR/bin:\$PATH" $PROFILE #return 0 if exist
then 
	echo "PATH=$C3D_DIR/bin" in the PATH already.
else
	#create init script
	echo "" >> $PROFILE
	echo "#C3D" >> $PROFILE
	echo "export PATH=$C3D_DIR/bin:\$PATH" >> $PROFILE
#left out dep for c3d_gui to avoid potential conflicts
#	echo "LD_LIBRARY_PATH=$C3D_DIR/lib/c3d_gui-1.1.0:\$LD_LIBRARY_PATH" >> $PROFILE
fi

#test installation
source $PROFILE

#test installation
echo "test c3d install: "
c3d -h >/dev/null
if [ $? -eq 0 ]; then
	echo "SUCCESS"
	echo "To update PATH of current terminal: source $PFORFILE"
	echo "To update PATH of all terminal: re-login"
else
    echo 'FAIL.'
fi

