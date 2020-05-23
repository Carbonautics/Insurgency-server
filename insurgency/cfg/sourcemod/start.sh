#!/bin/sh
export LD_LIBRARY_PATH=/home/insurgency_s1/insurgency:/home/insurgency_s1/insurgency/bin:{$LD_LIBRARY_PATH}
cd insurgency
./srcds_linux -console +map buhriz_coop checkpoint +maxplayers 50 -ip 213.163.73.54 -port 27015

