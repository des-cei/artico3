/*
 * DMA proxy kernel module
 *
 * Author   : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
 * Date     : July 2017
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <errno.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <fcntl.h>

#include <sys/ioctl.h>
#include "../dmaproxy.h"

#define DEVICE "/dev/dmaproxy0"
#define VALUES (8192)
#define HWADDR (0x83c00000)
//~ #define HWADDR (0x76000000)

#define ITERATIONS (1)

#define printf(...)
#define sleep(...)

int main(int argc, char *argv[]) {
	int fd;
    unsigned int i, j, errors;
	uint32_t *mem = NULL;
	uint32_t *golden = NULL;
    struct dmaproxy_token token;
    
    //~ while (1) {
    for (j = 0; j < ITERATIONS; j++) {
    
        // Allocate memory for golden (SW) copy
        golden = malloc(VALUES * sizeof *golden);
        if (!golden) {
            printf("malloc() failed\n");
            return -ENOMEM;
        }

        // Open file (R/W)
        fd = open(DEVICE, O_RDWR);
        if (!fd) {
            printf("File %s could not be opened\n", DEVICE);
            return -ENODEV;
        }
        printf("Opened %s\n", DEVICE);

        // Map user-space memory to kernel-space, DMA-allocated memory
        mem = mmap(NULL, VALUES * sizeof *mem, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
        if (mem == MAP_FAILED) {
            printf("mmap() failed\n");
            close(fd);
            return -ENOMEM;
        }
        printf("Assigned memory region: %p\n", mem);
        
        // Read from memory
        for (i = 0; i < ((VALUES < 10) ? VALUES : 10); i++) {
            printf("mem [%d] = 0x%08x\n", i, mem[i]);
        }
        printf("Sleeping for 1 second...\n");
        sleep(1);
        
        // Write to memory
        for (i = 0; i < VALUES; i++) {
            mem[i] = rand(); //i + 1;
            golden[i] = mem[i];
        }
        
        // Read from memory
        for (i = 0; i < ((VALUES < 10) ? VALUES : 10); i++) {
            printf("mem [%d] = 0x%08x\n", i, mem[i]);
        }
        printf("Sleeping for 1 second...\n");
        sleep(1);
        
        // Send data from memory to hardware
        token.memaddr = mem;
        token.memoff = 0x00000000;
        token.hwaddr = (void *)HWADDR;
        token.hwoff = 0x00000000;
        token.size = VALUES * sizeof *mem;   
        printf("Sending data to hardware...\n");
        ioctl(fd, DMAPROXY_IOC_DMA_MEM2HW, &token);
        
        // Write to memory
        for (i = 0; i < VALUES; i++) {
            mem[i] = 0;
        }
        
        // Read from memory
        for (i = 0; i < ((VALUES < 10) ? VALUES : 10); i++) {
            printf("mem [%d] = 0x%08x\n", i, mem[i]);
        }
        printf("Sleeping for 1 second...\n");
        sleep(1);
        
        // Send data from hardware to memory
        token.memaddr = mem;
        token.memoff = 0x00000000;
        token.hwaddr = (void *)HWADDR;
        token.hwoff = 0x00000000;
        token.size = VALUES * sizeof *mem; 
        printf("Receiving data from hardware...\n");
        ioctl(fd, DMAPROXY_IOC_DMA_HW2MEM, &token);
        
        // Compare against golden reference
        errors = 0;
        for (i = 0; i < VALUES; i++) {
            if (mem[i] != golden[i]) {
                errors++;
            }            
        }
        printf("Found %d errors\n", errors);        
        
        // Read from memory
        for (i = 0; i < ((VALUES < 10) ? VALUES : 10); i++) {
            printf("mem [%d] = 0x%08x\n", i, mem[i]);
        }    
        printf("Sleeping for 1 second...\n");
        sleep(1);

        // Unmap user-space memory from kernel-space
        munmap(mem, VALUES * sizeof *mem);
        printf("Released memory region\n");

        // Close file
        close(fd);
        printf("Closed %s\n", DEVICE);
        
        // Release memory
        free(golden);
    
    }

	return 0;
}
