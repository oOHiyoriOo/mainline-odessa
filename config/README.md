# Keys

`authorized_keys.pub` contains the **throwaway build key** used for the
reference device (public key only). It is shipped so the released image can be
reproduced byte-for-byte. Replace it for any other device:

```bash
cp ~/.ssh/id_ed25519.pub authorized_keys.pub
```

It is installed in two places:

- the initramfs (`/root/.ssh/authorized_keys`) for SSH before the rootfs is
  ready,
- the rootfs (`/root/.ssh/authorized_keys`) by `rootfs/prepare-rootfs.sh`.

`config.env.example` points `AUTHKEY` at this file.

The shipped `artifacts/odessa-6.12-boot.img` still contains the original build
key. Replace `/root/.ssh/authorized_keys` on the running device, or rebuild
the image with your key.
