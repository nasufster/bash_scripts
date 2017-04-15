export QTDIR=~/Qt/5.5/clang_64
PATH=$QTDIR/bin/:$PATH
export PATH
ccmake -DVTK_QT_VERSION:STRING="5" -DVTK_DIR:STRING=/usr/local/lib/vtk-7.0 -DQT_QMAKE_EXECUTABLE:STRING=~/Qt/5.5/clang_64/bin/qmake ../VTK
