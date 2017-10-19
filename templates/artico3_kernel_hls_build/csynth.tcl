#
# ARTICo3 HLS kernel C synthesis script
#
# Author : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
# Date   : August 2017
#

<a3<artico3_preproc>a3>

open_project hls
set_top <a3<NAME>a3>
#~ add_files artico3.h
add_files [ glob *.cpp *.c *.h]
open_solution sol
set_part {<a3<PART>a3>}
create_clock -period 10 -name default
#~ config_rtl -reset all -reset_level low
config_rtl -reset_level low
source directives.tcl
csynth_design
exit
