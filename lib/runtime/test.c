#include <stdio.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>
#include <time.h>

#include "artico3.h"

#define BLOCKS (10000)
#define VALUES (1024)

int main(int argc, char *argv[]) {
    unsigned int i, errors, blocks;
    struct timeval t0, tf;
    float t;

    a3data_t *a = NULL;
    a3data_t *b = NULL;
    a3data_t *c = NULL;

    /* Command line parsing */

    printf("argc = %d\n", argc);
    for (i = 0; i < argc; i++) {
        printf("argv[%d] = %s\n", i, argv[i]);
    }

    blocks = 0;
    if (argc > 1) {
        blocks = atoi(argv[1]);
    }
    blocks = ((blocks < BLOCKS) && (blocks > 0)) ? blocks : BLOCKS;
    printf("Using %d blocks\n", blocks);

    /* APP */

    artico3_init();

    artico3_kernel_create("addvector", 16384, 3, 3, 3);

    a = artico3_alloc(blocks * VALUES * sizeof *a, "addvector", "a", A3_P_I);
    b = artico3_alloc(blocks * VALUES * sizeof *b, "addvector", "b", A3_P_I);
    c = artico3_alloc(blocks * VALUES * sizeof *c, "addvector", "c", A3_P_O);

    srand(time(NULL));
    for (i = 0; i < (blocks * VALUES); i++) {
        a[i] = rand();
        b[i] = rand();
        c[i] = 0;
    }

    gettimeofday(&t0, NULL);
    artico3_kernel_execute("addvector", (blocks * VALUES), VALUES);
    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Kernel execution : %.6f ms\n", t);

    errors = 0;
    for (i = 0; i < (blocks * VALUES); i++) {
        if ((i % VALUES) < 2) printf("%6d | %08x\n", i, c[i]);
        if (c[i] != a[i] + b[i]) errors++;
    }
    printf("Found %d errors\n", errors);

    artico3_free("addvector", "a");
    artico3_free("addvector", "b");
    artico3_free("addvector", "c");

    artico3_kernel_release("addvector");

    artico3_exit();

    return 0;
}
