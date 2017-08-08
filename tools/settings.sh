#!/bin/bash
artico3=$(dirname $BASH_SOURCE)/..
artico3=$(cd $artico3 && pwd)

echo "ARTICo3=$artico3"
echo "PYTHONPATH=$artico3/tools/_pypack:\$PYTHONPATH"
echo "PATH=$artico3/tools:\$PATH"

export ARTICo3=$artico3
export PYTHONPATH=$artico3/tools/_pypack:$PYTHONPATH
export PATH=$artico3/tools:$PATH
