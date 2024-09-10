/*
 * ARTICo3 APIs - debug configuration
 *
 * Author      : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
 * Date        : August 2017
 * Description : This file contains definitions to customize the debug
 *               behavior in the ARTICo3 APIs (basically, the amount of
 *               messages and info that is printed to the console.)
 *
 */


#ifndef _ARTICO3_DBG_H_
#define _ARTICO3_DBG_H_

#include <stdio.h>

// If not defined by command line, disable debug
#ifndef A3_DEBUG
    #define A3_DEBUG 0
#endif

// Debug messages
#if A3_DEBUG
    #define a3_print_debug(msg, args...) printf(msg, ##args)
    #define a3_print_info(msg, args...) printf(msg, ##args)
#else
    #define a3_print_debug(msg, args...)
    #if A3_INFO
        #define a3_print_info(msg, args...) printf(msg, ##args)
    #else
        #define a3_print_info(msg, args...)
    #endif
#endif

// Error messages
#define a3_print_error(msg, args...) printf(msg, ##args)

#endif /* _ARTICO3_DBG_H_ */
