#include <stdio.h>
#include "artico3_hw.h"

#define VALUES (1024)

int main(int argc, char *argv[]) {
    unsigned int i, errors;
    volatile a3data_t *a = NULL;
    volatile a3data_t *b = NULL;
    volatile a3data_t *c = NULL;

    artico3_init();

    artico3_kernel_create("dummy", 4096, 2, 2, 2);
    artico3_kernel_create("addvector", 16384, 3, 3, 3);

    a = artico3_alloc(3 * VALUES * sizeof *a, "addvector", "a", 1);
    b = artico3_alloc(3 * VALUES * sizeof *b, "addvector", "b", 1);
    c = artico3_alloc(3 * VALUES * sizeof *c, "addvector", "c", 0);

    for (i = 0; i < (VALUES * 3); i++) {
        a[i] = i;
        b[i] = i + 2;
    }

    artico3_kernel_execute("addvector", 3, 1);

    errors = 0;
    for (i = 0; i < (VALUES * 3); i++) {
        if ((i % VALUES) < 4) printf("%4d | %08x\n", i, c[i]);
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
