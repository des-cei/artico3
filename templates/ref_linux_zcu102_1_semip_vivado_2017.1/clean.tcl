#
# ARTICo3 IP library script for Vivado
#
# Author      : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
# Date        : May 2018
#
# Description : Cleans output files from Vivado project.
#

proc artico3_clean_project {} {

    open_project myARTICo3.xpr
    reset_project
    config_ip_cache -clear_local_cache
    config_ip_cache -clear_output_repo
    close_project

}

#
# MAIN
#

artico3_clean_project
exit
