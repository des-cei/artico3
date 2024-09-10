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
CFLAGS_ARTICo3 = $(CFLAGS_IN)-Wall -Wextra -fpic -I <a3<REPO_REL>a3>/linux
<a3<end if>a3>
<a3<if DEVICE=="zynqmp">a3>
CFLAGS_ARTICo3 = $(CFLAGS_IN)-DZYNQMP -Wall -Wextra -fpic -I <a3<REPO_REL>a3>/linux
<a3<end if>a3>
LDFLAGS_ARTICo3 = -Wl,-R,. -shared
LDLIBS_ARTICo3 = -lm -lpthread

CFLAGS_APP = $(CFLAGS_IN)-Wall -Wextra -I runtime <a3<CFLAGS>a3>
LDFLAGS_APP = $(LDFLAGS_IN)-L . -Wl,-R,. <a3<LDFLAGS>a3>
LDLIBS_APP = -lartico3 -lm -lpthread -lrt <a3<LDLIBS>a3>

OBJS1 = runtime/artico3_rcfg.o runtime/artico3_hw.o runtime/artico3_user.o runtime/artico3.o
ARTICo3_OBJS = $(OBJS1:%=_build/%)

OBJS2 = <a3<generate for OBJS>a3><a3<Source>a3> <a3<end generate>a3>

APP_OBJS = $(OBJS2:%=_build/%)

MKDIRP = mkdir -p
CPF = cp -f

.PHONY: app
app: runtime $(APP_OBJS)
	$(CC) $(LDFLAGS_APP) $(APP_OBJS) $(LDLIBS_APP) -o <a3<NAME>a3>

.PHONY: runtime
runtime: $(ARTICo3_OBJS)
	$(CC) $(LDFLAGS_ARTICo3) $^ $(LDLIBS_ARTICo3) -o libartico3.so
	$(AR) rcs libartico3.a $^

.PHONY: clean
clean:
	rm -rf _build libartico3.so libartico3.a <a3<NAME>a3>

_build/runtime/%.o: runtime/%.c
	$(MKDIRP) $(@D)
	$(CC) $(CFLAGS_ARTICo3) -c $< -o $@

_build/application/%.o: application/%.c
	$(MKDIRP) $(@D)
	$(CC) $(CFLAGS_APP) -x c -c $< -o $@

_build/application/%.o: application/%.cpp
	$(MKDIRP) $(@D)
	$(CC) $(CFLAGS_APP) -x c -c $< -o $@
