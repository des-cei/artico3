<a3<artico3_preproc>a3>

CC = $(CROSS_COMPILE)gcc
CFLAGS += -Wall -I <a3<REPO_REL>a3> -I lib/include <a3<CFLAGS>a3>
LDFLAGS += -static <a3<LDFLAGS>a3>

MKDIRP = mkdir -p

OBJS = <a3<generate for OBJS>a3><a3<Source>a3> <a3<end generate>a3>

BUILD_OBJS = $(OBJS:%=_build/%)

all: $(BUILD_OBJS)
	$(CC) $(BUILD_OBJS) $(LDFLAGS) -o <a3<NAME>a3>

install: all
	cp <a3<NAME>a3> $(PREFIX)

clean:
	rm -rf _build <a3<NAME>a3>

_build/%.o: %.c
	$(MKDIRP) $(@D)
	$(CC) $(CFLAGS) -x c -c $< -o $@

_build/%.o: %.cpp
	$(MKDIRP) $(@D)
	$(CC) $(CFLAGS) -x c -c $< -o $@
