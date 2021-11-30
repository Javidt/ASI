#!/bin/bash

# Script que realiza el backup, recibe como parámetro:
# 
# "$ORIGEN" "$SERVIDOR" "$DESTINO" "$PERIODO"
# 
sudo rsync --recursive $ORIGEN $SERVIDOR:$DESTINO
