/*
 * ARTICo3 Linux-based FPGA reconfiguration API
 *
 * Author      : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
 * Date        : November 2017
 * Description : This file contains the reconfiguration functions to
 *               load full and partial bitstreams under Linux. A macro
 *               controls the type of implementation used:
 *                   1. Legacy  : xdevcfg
 *                   2. Default : fpga_manager (Linux framework)
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>

#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>

#include "artico3_rcfg.h"
#include "artico3_dbg.h"

#if A3_LEGACY_RCFG

/*
 * Main reconfiguration function (legacy -> xdevcfg)
 *
 * This function loads a bitstream file (either total or partial) using
 * the xdevcfg reconfiguration interface.
 *
 * @name       : name of the bitstream file to be loaded
 * @is_partial : flag to indicate whether the bitstream file is partial
 *
 * Return : 0 on success, error code otherwise
 *
 */
int fpga_load(const char *name, uint8_t is_partial) {
    int fd;
    FILE *fp;
    uint32_t buffer[1024];
    int ret;

    // Set flag when partial reconfiguration is required
    if (is_partial) {

        // Open configuration file
        fd = open("/sys/bus/platform/devices/f8007000.devcfg/is_partial_bitstream", O_RDWR);
        if (fd < 0) {
            a3_print_error("[artico3-hw] open() /sys/bus/platform/devices/f8007000.devcfg/is_partial_bitstream failed\n");
            ret = -ENODEV;
            goto err_xdevcfg;
        }

        // Enable partial reconfiguration
        write(fd, "1", strlen("1"));
        a3_print_debug("[artico3-hw] DPR enabled\n");

        // Close configuration file
        close(fd);

    }

    // Open device file
    fd = open("/dev/xdevcfg", O_RDWR);
    if (fd < 0) {
        a3_print_error("[artico3-hw] open() /dev/xdevcfg failed\n");
        ret = -ENODEV;
        goto err_xdevcfg;
    }

    // Open bitstream file
    fp = fopen(name, "rb");
    if (!fp) {
        a3_print_error("[artico3-hw] fopen() %s failed\n", name);
        ret = -ENOENT;
        goto err_bit;
    }
    a3_print_debug("[artico3-hw] opened partial bitstream file %s\n", filename);

    // Read bitstream file and write to reconfiguration engine
    while (!feof(fp)) {

        // Read from file
        ret = fread(buffer, sizeof (uint32_t), 1024, fp);

        // Write to reconfiguration engine
        if (ret > 0) {
            write(fd, buffer, ret * sizeof (uint32_t));
        }

    }

    // Close bitstream file
    fclose(fp);

    // Close device file
    close(fd);

    // Unset flag when partial reconfiguration is required
    if (is_partial) {

        // Open configuration file
        fd = open("/sys/bus/platform/devices/f8007000.devcfg/is_partial_bitstream", O_RDWR);
        if (fd < 0) {
            a3_print_error("[artico3-hw] open() /sys/bus/platform/devices/f8007000.devcfg/is_partial_bitstream failed\n");
            ret = -ENODEV;
            goto err_xdevcfg;
        }

        // Disable partial reconfiguration
        write(fd, "0", strlen("0"));
        a3_print_debug("[artico3-hw] DPR disabled\n");

        // Close configuration file
        close(fd);

    }

    return 0;

err_bit:
    close(fd);

err_xdevcfg:
    return ret;
}

#else

/*
 * Main reconfiguration function (default -> fpga_manager)
 *
 * This function loads a bitstream file (either total or partial) using
 * the fpga_manager reconfiguration interface. This also assumes that
 * there is only one fpga, called fpga0.
 *
 * @name       : name of the bitstream file to be loaded
 * @is_partial : flag to indicate whether the bitstream file is partial
 *
 * Return : 0 on success, error code otherwise
 *
 */
int fpga_load(const char *name, uint8_t is_partial) {
    int fd;
    int ret;
    char cwd[128];
    char filename[256];
    char state[256];

    // Remove symlink of the bitstream file in /lib/firmware
    unlink("/lib/firmware/a3_bitstream");

    // Create symlink of the bitstream file in /lib/firmware
    getcwd(cwd, sizeof(cwd));
    sprintf(filename, "%s/%s", cwd, name);
    ret = symlink(filename, "/lib/firmware/a3_bitstream");
    if (ret) {
        goto err_fpga;
    }

    // Set flag when partial reconfiguration is required
    if (is_partial) {

        // Open configuration file
        fd = open("/sys/class/fpga_manager/fpga0/flags", O_RDWR);
        if (fd < 0) {
            a3_print_error("[artico3-hw] open() /sys/class/fpga_manager/fpga0/flags failed\n");
            ret = -ENODEV;
            goto err_fpga;
        }

        // Enable partial reconfiguration
        write(fd, "1", strlen("1"));
        a3_print_debug("[artico3-hw] DPR enabled\n");

        // Close configuration file
        close(fd);

    }

    // Open firmware path file
    fd = open("/sys/class/fpga_manager/fpga0/firmware", O_WRONLY);
    if (fd < 0) {
        a3_print_error("[artico3-hw] open() /sys/class/fpga_manager/fpga0/firmware failed\n");
        ret = -ENODEV;
        goto err_fpga;
    }

    // Write firmware file path
    write(fd, "a3_bitstream", strlen("a3_bitstream"));
    a3_print_debug("[artico3-hw] Firmware written\n");

    // Close firmware path file
    close(fd);

    // Unset flag when partial reconfiguration is required
    if (is_partial) {

        // Open configuration file
        fd = open("/sys/class/fpga_manager/fpga0/flags", O_RDWR);
        if (fd < 0) {
            a3_print_error("[artico3-hw] open() /sys/class/fpga_manager/fpga0/flags failed\n");
            ret = -ENODEV;
            goto err_fpga;
        }

        // Enable partial reconfiguration
        write(fd, "0", strlen("0"));
        a3_print_debug("[artico3-hw] DPR disabled\n");

        // Close configuration file
        close(fd);

    }

    // Open FPGA Manager state
    fd = open("/sys/class/fpga_manager/fpga0/state", O_RDONLY);
    if (fd < 0) {
        a3_print_error("[artico3-hw] open() /sys/class/fpga_manager/fpga0/state failed\n");
        ret = -ENODEV;
        goto err_fpga;
    }

    // Read FPGA Manager state
    ret = read(fd, state, sizeof state);
    char *token = strtok(state, "\n");
    a3_print_debug("[artico3-hw] FPGA Manager state : %s\n", token);
    if (strcmp(token, "operating") != 0) {
        a3_print_error("[artico3-hw] FPGA Manager state error (%s)\n", token);
        ret = -EBUSY;
        goto err_state;
    }

    // Close FPGA Manager state
    close(fd);

    // Remove symlink of the bitstream file in /lib/firmware
    unlink("/lib/firmware/a3_bitstream");

    return 0;

err_state:
    // Close FPGA Manager state
    close(fd);

err_fpga:
    // Remove symlink of the bitstream file in /lib/firmware
    unlink("/lib/firmware/a3_bitstream");

    return ret;
}

#endif /* A3_LEGACY_RCFG */
