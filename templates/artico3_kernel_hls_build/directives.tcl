#
# ARTICo3 HLS kernel C synthesis interface directives
#
# Author : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
# Date   : August 2017
#

<a3<artico3_preproc>a3>

set_directive_interface -mode ap_ctrl_hs "<a3<NAME>a3>"

<a3<generate for PORTS>a3>
set_directive_interface -mode bram -name bram_<a3<bid>a3> "<a3<NAME>a3>" <a3<pid>a3>
set_directive_resource -core RAM_1P_BRAM "<a3<NAME>a3>" <a3<pid>a3>
<a3<end generate>a3>
