<a3<artico3_preproc>a3>

open_project hls
set_top <a3<NAME>a3>
add_files artico3.h
add_files [ glob *.cpp ]
open_solution sol
set_part {<a3<PART>a3>}
create_clock -period 10 -name default
source directives.tcl
csynth_design
exit
