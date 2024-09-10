#
# ARTICo3 Linux Application
#
# Author   : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
# Date     : March 2020
#

<a3<artico3_preproc>a3>

CC = $(CROSS_COMPILE)gcc
MAKE = make

<a3<if DEVICE=="zynq">a3>
CFLAGS_ARTICo3D = $(CFLAGS_IN)-Wall -Wextra -fpic -I <a3<REPO_REL>a3>/linux -I <a3<REPO_REL>a3>/lib/runtime/common
<a3<end if>a3>
<a3<if DEVICE=="zynqmp">a3>
CFLAGS_ARTICo3D = $(CFLAGS_IN)-DZYNQMP -Wall -Wextra -fpic -I <a3<REPO_REL>a3>/linux -I <a3<REPO_REL>a3>/lib/runtime/common
<a3<end if>a3>
LDFLAGS_ARTICo3D = -Wl,-R,. -shared
LDLIBS_ARTICo3D = -lm -lpthread -lrt

<a3<if DEVICE=="zynq">a3>
CFLAGS_ARTICo3 = $(CFLAGS_IN)-Wall -Wextra -fpic -I <a3<REPO_REL>a3>/lib/runtime/common
<a3<end if>a3>
<a3<if DEVICE=="zynqmp">a3>
CFLAGS_ARTICo3 = $(CFLAGS_IN)-DZYNQMP -Wall -Wextra -fpic -I <a3<REPO_REL>a3>/lib/runtime/common
<a3<end if>a3>
LDFLAGS_ARTICo3 = -Wl,-R,. -shared
LDLIBS_ARTICo3 = -lm -lpthread -lrt

CFLAGS_APP = $(CFLAGS_IN)-Wall -Wextra -I runtime/user -I runtime/common <a3<CFLAGS>a3>
LDFLAGS_APP = $(LDFLAGS_IN)-L . -Wl,-R,. <a3<LDFLAGS>a3>
LDLIBS_APP = -lartico3 -lm -lpthread -lrt <a3<LDLIBS>a3>

CFLAGS_DAEMON = $(CFLAGS_IN)-Wall -Wextra -I runtime/daemon -I runtime/common <a3<CFLAGS>a3>
LDFLAGS_DAEMON = $(LDFLAGS_IN)-L . -Wl,-R,. <a3<LDFLAGS>a3>
LDLIBS_DAEMON = -lartico3d -lm -lpthread -lrt <a3<LDLIBS>a3>

OBJS1 = runtime/daemon/artico3_rcfg.o runtime/daemon/artico3_hw.o runtime/daemon/artico3.o
ARTICo3D_OBJS = $(OBJS1:%=_build/%)

OBJS2 = runtime/user/artico3.o
ARTICo3_OBJS = $(OBJS2:%=_build/%)

OBJS3 = runtime/daemon/artico3d.o
DAEMON_OBJS = $(OBJS3:%=_build/%)

OBJS4 = <a3<generate for OBJS>a3><a3<Source>a3> <a3<end generate>a3>

APP_OBJS = $(OBJS4:%=_build/%)

MKDIRP = mkdir -p
CPF = cp -f

.PHONY: app
app: runtime_user $(APP_OBJS)
	$(CC) $(LDFLAGS_APP) $(APP_OBJS) $(LDLIBS_APP) -o <a3<NAME>a3>

.PHONY: daemon
daemon: runtime_daemon $(DAEMON_OBJS)
	$(CC) $(LDFLAGS_DAEMON) $(DAEMON_OBJS) $(LDLIBS_DAEMON) -o daemon

.PHONY: runtime_user
runtime_user: $(ARTICo3_OBJS)
	$(CC) $(LDFLAGS_ARTICo3) $^ $(LDLIBS_ARTICo3) -o libartico3.so
	$(AR) rcs libartico3.a $^

.PHONY: runtime_daemon
runtime_daemon: $(ARTICo3D_OBJS)
	$(CC) $(LDFLAGS_ARTICo3D) $^ $(LDLIBS_ARTICo3D) -o libartico3d.so
	$(AR) rcs libartico3d.a $^

.PHONY: clean
clean:
	rm -rf _build libartico3.so libartico3.a libartico3d.so libartico3d.a daemon <a3<NAME>a3>

_build/runtime/daemon/%.o: runtime/daemon/%.c
	$(MKDIRP) $(@D)
	$(CC) $(CFLAGS_ARTICo3D) -c $< -o $@

_build/runtime/user/%.o: runtime/user/%.c
	$(MKDIRP) $(@D)
	$(CC) $(CFLAGS_ARTICo3) -c $< -o $@

_build/application/%.o: application/%.c
	$(MKDIRP) $(@D)
	$(CC) $(CFLAGS_APP) -x c -c $< -o $@

_build/application/%.o: application/%.cpp
	$(MKDIRP) $(@D)
	$(CC) $(CFLAGS_APP) -x c -c $< -o $@
