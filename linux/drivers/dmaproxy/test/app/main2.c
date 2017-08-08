#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>

#include <sys/ioctl.h>
#include "../dmaproxy.h"

#define DEVICE "/dev/dmaproxy0"
#define AREAS  (10)
#define VALUES (64*1024/4)
#define HWADDR (0x83c00000)
//~ #define HWADDR (0x76000000)

#define ITERATIONS (100)

#define printf(...)

int main(int argc, char *argv[]) {
    int fd;
    unsigned int i, j, k, errors;
    uint32_t *mem[AREAS] = {NULL};
    struct dmaproxy_token token;
    
    //~ while (1) {
    for (k = 0; k < ITERATIONS; k++) {
    
        fd = open(DEVICE, O_RDWR);
        
        for (i = 0; i < AREAS; i++) {
            mem[i] = mmap(0, VALUES * sizeof *mem[i], PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);    
            printf("mmap() #%d -> %p\n", i, mem[i]);
        }
        
        for (i = 0; i < AREAS; i++) {
            
            for (j = 0; j < ((VALUES < 10) ? VALUES : 10); j++) {
                printf("mem[%d][%d] = 0x%08x\n", i, j, mem[i][j]);
            }
            
            for (j = 0; j < VALUES; j++) {
                mem[i][j] = i*VALUES + j + 1;
            }
            
            for (j = 0; j < ((VALUES < 10) ? VALUES : 10); j++) {
                printf("mem[%d][%d] = 0x%08x\n", i, j, mem[i][j]);
            }
            
            token.memaddr = mem[i];
            token.memoff = 0x00000000;
            token.hwaddr = (void *)HWADDR;
            token.hwoff = 0x00000000;
            token.size = VALUES * sizeof *mem[i];   
            printf("Sending data to hardware...\n");
            ioctl(fd, DMAPROXY_IOC_DMA_MEM2HW, &token);
            
            for (j = 0; j < VALUES; j++) {
                mem[i][j] = 0;
            }
            
            for (j = 0; j < ((VALUES < 10) ? VALUES : 10); j++) {
                printf("mem[%d][%d] = 0x%08x\n", i, j, mem[i][j]);
            }
            
            token.memaddr = mem[i];
            token.memoff = 0x00000000;
            token.hwaddr = (void *)HWADDR;
            token.hwoff = 0x00000000;
            token.size = VALUES * sizeof *mem[i]; 
            printf("Receiving data from hardware...\n");
            ioctl(fd, DMAPROXY_IOC_DMA_HW2MEM, &token);
            
            for (j = 0; j < ((VALUES < 10) ? VALUES : 10); j++) {
                printf("mem[%d][%d] = 0x%08x\n", i, j, mem[i][j]);
            }
            
            errors = 0;
            for (j = 0; j < VALUES; j++) {
                if (mem[i][j] != (i*VALUES + j + 1)) errors++;
            }
            printf("Found %d errors\n", errors);
            
        }
        
        for (i = 0; i < AREAS; i++) {
            printf("munmap() #%d -> %p\n", i, mem[i]);
            munmap(mem[i], VALUES * sizeof *mem[i]);        
        }
        
        close(fd);
        
    }
        
    return 0;
}
