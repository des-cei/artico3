#include "artico3_hw.h"

int main(int argc, char *argv[]) {
    int ret;

    ret = artico3_init();
    if (ret) {
        return ret;
    }

    artico3_exit();

    return 0;
}
