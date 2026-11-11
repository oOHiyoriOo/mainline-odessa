# odessa-linux-6.12 — reproducible build targets
#
#   make check        verify the shipped artifacts against SHA256SUMS
#   make initramfs    build initramfs from artifacts/rootfs-install.tar.gz
#   make fit          pack kernel + DTB + initramfs into a FIT image
#   make bootimg      wrap U-Boot + FIT + stock DTB into a boot.img
#   make rootfs-tar   unpack the payload to build/rootfs.tar
#   make rootfs-img   build a 2 GiB ext4 image from the payload (needs sudo)
#   make simg         convert the ext4 image to an Android sparse image
#   make wlan-modules build the Wi-Fi helper modules against build/linux-6.12
#
SHELL := /bin/sh
REPO  := $(CURDIR)
JOBS  ?= 12
AUTHKEY ?= $(REPO)/config/authorized_keys.pub
export AUTHKEY JOBS

.PHONY: all check check-rootfs boot-check initramfs fit bootimg rootfs-tar rootfs-tree rootfs-img simg wlan-modules bt-modules clean

all: bootimg rootfs-img simg

# --ignore-missing: the big artifacts are build outputs (see .gitignore) and
# are absent in a fresh clone
check:
	@cd artifacts && sha256sum -c --ignore-missing SHA256SUMS
	@echo "artifacts OK (present files only)"

# Static regression check of the prepared rootfs tree (screen-off, masked
# getty/backlight, RFS plumbing, firmware). Run after prepare-rootfs.sh.
check-rootfs:
	./rootfs/check-rootfs.sh build/rootfs-tree build/debs-combined.tar

# Post-boot smoke test over SSH (screen really dark, RFS stack up, firmware).
boot-check:
	./tools/dev/check-boot.sh $(HOST)

initramfs:
	./initramfs/build-initramfs.sh

fit: initramfs
	./kernel/build-fit.sh

bootimg: fit
	./uboot/pack-bootimg.sh

rootfs-tar:
	./rootfs/unpack-payload.sh

rootfs-tree: wlan-modules bt-modules
	./rootfs/unpack-payload.sh --extract

# out-of-tree helper modules (SMMU bypass, WLAN rails, SMEM mmi_unit_info);
# requires the kernel from kernel/build-kernel.sh
wlan-modules:
	./wlan/modules/build-modules.sh

# Bluetooth stack modules (BT is a module set, see docs/HARDWARE.md)
bt-modules:
	./bt/modules/build-modules.sh

rootfs-img: rootfs-tree
	@command -v mke2fs >/dev/null || { echo "mke2fs missing (e2fsprogs)" >&2; exit 1; }
	sudo rm -f build/rootfs.img
	truncate -s 2G build/rootfs.img
	sudo mke2fs -q -t ext4 -O ^orphan_file -L odessa-root -d build/rootfs-tree build/rootfs.img
	sudo e2fsck -fy build/rootfs.img >/dev/null || true
	@echo "build/rootfs.img ready"

simg: rootfs-img
	python3 rootfs/make-simg.py build/rootfs.img build/rootfs.simg

clean:
	rm -rf build
