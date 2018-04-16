#!/bin/bash

DEST=$1
mkdir -p $DEST

ANACONDA2_DIR=$DEST/anaconda2

export PATH=$ANACONDA2_DIR/bin:$PATH


pip install numpy
pip install scipy
pip install nibabel
pip install pydicom
pip install nose
pip install sphinx

if [ -e /tmp/gradunwarp ]
then
    rm -rf /tmp/gradunwarp
fi


git clone https://github.com/kaitj/gradunwarp.git /tmp/gradunwarp && cd /tmp/gradunwarp  && rm -rf build  && python setup.py install && cd
