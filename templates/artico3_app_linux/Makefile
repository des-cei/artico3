#
# ARTICo3 Linux Application
#
# Author   : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
# Date     : May 2018
#

<a3<artico3_preproc>a3>

CC = $(CROSS_COMPILE)gcc
MAKE = make

<a3<if DEVICE=="zynq">a3>
CFLAGS = -Wall -Wextra -I <a3<REPO_REL>a3>/lib/runtime/aarch32/include <a3<CFLAGS>a3>
LDFLAGS = -L <a3<REPO_REL>a3>/lib/runtime/aarch32 -Wl,-R,. <a3<LDFLAGS>a3>
<a3<end if>a3>
<a3<if DEVICE=="zynqmp">a3>
CFLAGS = -Wall -Wextra -I <a3<REPO_REL>a3>/lib/runtime/aarch64/include <a3<CFLAGS>a3>
LDFLAGS = -L <a3<REPO_REL>a3>/lib/runtime/aarch64 -Wl,-R,. <a3<LDLIBS>a3>
<a3<end if>a3>
LDLIBS = -lartico3 <a3<LDLIBS>a3>
LDLIBS_DBG = -lartico3dbg <a3<LDLIBS>a3>

MKDIRP = mkdir -p

OBJS = <a3<generate for OBJS>a3><a3<Source>a3> <a3<end generate>a3>

BUILD_OBJS = $(OBJS:%=_build/%)

.PHONY: static
static: <a3<DEVICE>a3> $(BUILD_OBJS)
	$(CC) $(LDFLAGS) -static $(BUILD_OBJS) $(LDLIBS) -lm -lpthread -o <a3<NAME>a3>

.PHONY: shared
shared: <a3<DEVICE>a3> $(BUILD_OBJS)
	$(CC) $(LDFLAGS) $(BUILD_OBJS) $(LDLIBS) -o <a3<NAME>a3>

.PHONY: static_dbg
static_dbg: <a3<DEVICE>a3>_dbg $(BUILD_OBJS)
	$(CC) $(LDFLAGS) -static $(BUILD_OBJS) $(LDLIBS_DBG) -lm -lpthread -o <a3<NAME>a3>

.PHONY: shared_dbg
shared_dbg: <a3<DEVICE>a3>_dbg $(BUILD_OBJS)
	$(CC) $(LDFLAGS) $(BUILD_OBJS) $(LDLIBS_DBG) -o <a3<NAME>a3>

.PHONY: <a3<DEVICE>a3>
<a3<DEVICE>a3>:
	cd <a3<REPO_REL>a3>/lib/runtime && $(MAKE) <a3<DEVICE>a3>

.PHONY: <a3<DEVICE>a3>_dbg
<a3<DEVICE>a3>_dbg:
	cd <a3<REPO_REL>a3>/lib/runtime && $(MAKE) <a3<DEVICE>a3>_dbg

.PHONY: clean
clean:
	rm -rf _build <a3<NAME>a3>

.PHONY: distclean
distclean: clean
	cd <a3<REPO_REL>a3>/lib/runtime && $(MAKE) clean

_build/%.o: %.c
	$(MKDIRP) $(@D)
	$(CC) $(CFLAGS) -x c -c $< -o $@

_build/%.o: %.cpp
	$(MKDIRP) $(@D)
	$(CC) $(CFLAGS) -x c -c $< -o $@
