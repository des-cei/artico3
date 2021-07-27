/*
 * ARTICo3 HLS kernel C testbench
 *
 * Author : Álvaro Ortega Lozano <alvaro.ortega.lozano@alumnos.upm.es>
 * Date   : May 2021
 *
 */

<a3<artico3_preproc>a3>

#include <stdio.h>
#include <stdlib.h>
#include "artico3.h"

/*
 * ARTICo3 kernel function header
 *
 */
A3_KERNEL(<a3<ARGS>a3>);

/*
 * ARTICo3 write-read functions declaration
 *
 */
void write_mem(a3data_t *m, int n, int i){
	*(m+i) = n;
}

void write_reg(a3data_t *r, int n){
	*(r) = n;
}

a3data_t read_mem(a3data_t *m, int i){
	return *(m+i);
}

a3data_t read_reg(a3data_t *r){
	return *(r);
}

/*
 * ARTICo3 main function
 *
 */
int main(){

/*
 * ARTICo3 registers declaration
 *
 */
<a3<generate for REGS>a3>
	a3data_t *<a3<rname>a3>;
	<a3<rname>a3> = (a3data_t*)malloc(sizeof(a3data_t));
<a3<end generate>a3>

/*
 * ARTICo3 ports declaration
 *
 */
<a3<generate for PORTS>a3>
	a3data_t *<a3<pname>a3>; //punteros
	<a3<pname>a3> = (a3data_t*)malloc(<a3<MEMPOS>a3> * sizeof(a3data_t));
<a3<end generate>a3>

	a3data_t values = <a3<MEMPOS>a3>;

/*
 * ARTICo3 ports writing: function (port, value_to_write, memory_location)
 *
 * NOTE: for output ports remove the write_mem function and for input ports
 *       change the value to write and the memory location according to 
 *       kernel application
 *
 * NOTE: for floating point use write_mem(port, ftoa3(value_to_write), memory_location);
 *
 */
<a3<generate for PORTS>a3>
	write_mem(<a3<pname>a3>, <a3<pid>a3>, 0);
<a3<end generate>a3>

/*
 * ARTICo3 register writing: function (register, value_to_write)
 *
 * NOTE: change the value to write according to kernel application 
 *
 */
<a3<generate for REGS>a3>
	write_reg(<a3<rname>a3>, 9);
<a3<end generate>a3>

/*
 * ARTICo3 kernel execution
 *
 */
	<a3<NAME>a3>(<a3<generate for REGS>a3> <a3<rname>a3>, <a3<end generate>a3>
<a3<generate for PORTS>a3> <a3<pname>a3>, <a3<end generate>a3>
values); 

/*
 * ARTICo3 ports reading: function (port, memory_location)
 *
 * NOTE: for input ports remove the read_mem function and change
 *       the memory location according to the writing ports
 *
 * NOTE: for floating point use printf("%.3f \n", a3tof(read_mem(port, memory_location)))
 *
 */
<a3<generate for PORTS>a3>
	printf("%d \n", read_mem(<a3<pname>a3>, 0)); 
	free (<a3<pname>a3>);
<a3<end generate>a3>

/*
 * ARTICo3 register reading: function (register)
 *
 */
<a3<generate for REGS>a3>
	printf("%d \n" ,read_reg(<a3<rname>a3>));
	free (<a3<rname>a3>);
<a3<end generate>a3>
}


