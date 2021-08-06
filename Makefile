SYSROOT = $(PWD)/deps/.install

# Add custom sysroot to paths.
export CPPFLAGS += -I$(SYSROOT)/include
export LDFLAGS += -L$(SYSROOT)/lib
export PATH := $(SYSROOT)/bin:$(PATH)
export PKG_CONFIG_PATH = $(SYSROOT)/lib/pkgconfig
export ACLOCAL_PATH := $(SYSROOT)/share/aclocal:$(ACLOCAL_PATH)

# Common linking flags for all targets.
export LDFLAGS += -s DYNAMIC_EXECUTION=0 -s AUTO_JS_LIBRARIES=0 -s AUTO_NATIVE_LIBRARIES=0 -s ALLOW_UNIMPLEMENTED_SYSCALLS=0

# Common compilation & linking flags for all langs and targets.
COMMON_FLAGS = -Os -flto
export CFLAGS += $(COMMON_FLAGS)
export CXXFLAGS += $(COMMON_FLAGS)
export LDFLAGS += $(COMMON_FLAGS)

## Main API module

libapi.mjs: api.o $(SYSROOT)/lib/libltdl.la $(SYSROOT)/lib/libgphoto2.la
	libtool --verbose --mode=link $(LD) $(LDFLAGS) -o $@ $+ \
		--bind -s ASYNCIFY -s ALLOW_MEMORY_GROWTH \
		-dlpreopen $(SYSROOT)/lib/libgphoto2/2.5.27.1/ptp2.la \
		-dlpreopen $(SYSROOT)/lib/libgphoto2_port/0.12.0/usb1.la

api.o: deps/libgphoto2/configure.ac
api.o: CPPFLAGS += -Ideps/libgphoto2 -Ideps/libgphoto2/libgphoto2_port
api.o: CXXFLAGS += -std=c++17 -fexceptions

## Generic rules for deps

$(SYSROOT):
	mkdir -p $(@D)

## libtool

deps/libtool/configure:
	mkdir -p deps/libtool
	curl -L https://ftpmirror.gnu.org/libtool/libtool-2.4.6.tar.gz | tar zx --strip 1 -C deps/libtool

deps/libtool/Makefile: deps/libtool/configure
	cd $(@D) && ./configure --prefix=$(SYSROOT) --disable-shared

$(SYSROOT)/lib/libltdl.la: deps/libtool/Makefile | $(SYSROOT)
	$(MAKE) -C deps/libtool install

## libgphoto2

deps/libgphoto2/configure.ac deps/libusb/configure.ac &:
	git submodule update --init

deps/libgphoto2/configure: deps/libusb/configure.ac | $(SYSROOT)/lib/libltdl.la
	cd $(@D) && autoreconf -fiv

deps/libgphoto2/Makefile: deps/libgphoto2/configure | $(SYSROOT)/lib/libusb-1.0.la
	./configure --prefix=$(SYSROOT) --disable-shared --host=wasm32 \
		 --without-libxml-2.0 --disable-nls --disable-ptpip --disable-disk \
		 --with-camlibs=ptp2

$(SYSROOT)/lib/libgphoto2.la: deps/libgphoto2/Makefile $(SYSROOT)/lib/libusb-1.0.la $(SYSROOT)/lib/libltdl.la
	$(MAKE) -C deps/libgphoto2 install

## libusb

deps/libusb/configure: deps/libusb/configure.ac | $(SYSROOT)/lib/libltdl.la
	cd $(@D) && autoreconf -fiv

deps/libusb/Makefile: deps/libusb/configure
	cd $(@D) && ./configure --prefix=$(SYSROOT) --disable-shared --host=wasm32

$(SYSROOT)/lib/libusb-1.0.la: deps/libusb/Makefile
	$(MAKE) -C deps/libusb install
