#include <stdio.h>
#include <sys/time.h>
#include <time.h>
#include "artico3_hw.h"

#define BLOCKS (300)
#define VALUES (1024)

int main(int argc, char *argv[]) {
    unsigned int i, errors;
    struct timeval t0, tf;
    float t;

    volatile a3data_t *a = NULL;
    volatile a3data_t *b = NULL;
    volatile a3data_t *c = NULL;

    artico3_init();

    artico3_kernel_create("dummy", 4096, 2, 2, 2);
    artico3_kernel_create("addvector", 16384, 3, 3, 3);

    a = artico3_alloc(BLOCKS * VALUES * sizeof *a, "addvector", "a", 1);
    b = artico3_alloc(BLOCKS * VALUES * sizeof *b, "addvector", "b", 1);
    c = artico3_alloc(BLOCKS * VALUES * sizeof *c, "addvector", "c", 0);

    srand(time(NULL));
    for (i = 0; i < (BLOCKS * VALUES); i++) {
        a[i] = rand();//i;
        b[i] = rand();//i + 2;
        c[i] = 0;
    }

    gettimeofday(&t0, NULL);
    artico3_kernel_execute("addvector", (BLOCKS * VALUES), VALUES);
    gettimeofday(&tf, NULL);
    t = ((tf.tv_sec - t0.tv_sec) * 1000.0) + ((tf.tv_usec - t0.tv_usec) / 1000.0);
    printf("Kernel execution : %.6f ms\n", t);

    errors = 0;
    for (i = 0; i < (BLOCKS * VALUES); i++) {
        if ((i % VALUES) < 2) printf("%6d | %08x\n", i, c[i]);
        if (c[i] != a[i] + b[i]) errors++;
    }
    printf("Found %d errors\n", errors);

    artico3_free("addvector", "a");
    artico3_free("addvector", "b");
    artico3_free("addvector", "c");

    artico3_kernel_release("addvector");
    artico3_kernel_release("dummy");

    artico3_exit();

    return 0;
}
