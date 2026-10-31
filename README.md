### Android 9 Pie device configuration for Raspberry Pi 3 Model B & B+

This repo contains updated instructions to build Android 9 Pie for Raspberry Pi
Model B & B+ on modern systems.

Namely, we tackle outdated packages, and the introduction on ASLR on the host.

`nix` is the only prerequisite, all other packages will be downloaded via it and
exposed in a nix shell.

#### Setup build environment

I am running NixOS 26.05 on a x86_64 host.

Use the nix shell to get all packages at once:

```
cd nix-aosp
nix develop
cd ..
```

#### Download source code

1. Download The Android 9 Pie official source code.

```bash
repo init -u https://android.googlesource.com/platform/manifest -b android-9.0.0_r8
```

2. Download Raspberry Pi 3 device configuration files

```bash
mkdir -pv device/brobwind
git clone https://github.com/brobwind/pie-device-brobwind-rpi3 device/brobwind/rpi3
```

3. Add local manifest file

```bash
mkdir -p .repo/local_manifests
ln -sv ../../device/brobwind/rpi3/local_manifest.xml .repo/local_manifests/
```

4. Downloading

```bash
repo sync -c -j4
```

#### Apply patch to Android framework

The following patch must be applied:

```patch
diff --git a/services/core/java/com/android/server/wm/DisplayContent.java b/services/core/java/com/android/server/wm/DisplayContent.java
index cd8fdbf..6918bc3 100644
--- a/services/core/java/com/android/server/wm/DisplayContent.java
+++ b/services/core/java/com/android/server/wm/DisplayContent.java
@@ -769,7 +769,7 @@ class DisplayContent extends WindowContainer<DisplayContent.DisplayChildWindowCo
         // appropriately arbitrary number. Eventually we would like to give SurfaceFlinger
         // layers the ability to match their parent sizes and be able to skip
         // such arbitrary size settings.
-        mSurfaceSize = Math.max(mBaseDisplayHeight, mBaseDisplayWidth) * 2;
+        mSurfaceSize = (int)(Math.max(mBaseDisplayHeight, mBaseDisplayWidth) * 1.4);
 
         final SurfaceControl.Builder b = mService.makeSurfaceBuilder(mSession)
                 .setSize(mSurfaceSize, mSurfaceSize)
```

#### Apply patches to `fat16copy.py`

Edit `build/make/tools/fat16copy.py`:

- edit `class fat(object)` to add this method:

```python
def fat_start(self):
    return self.reserved_sectors * self.bytes_per_sector
```

- edit `__init__` so it becomes:

```python
class fat(object):
    "A FAT image"

    def __init__(self, path):
        """
        path: Path to an image file containing a FAT file system.
        """
        f = open(path, "r+b")

        self.f = f

        f.seek(0xB)
        self.bytes_per_sector = read_le_short(f)
        sectors_per_cluster = read_byte(f)

        self.bytes_per_cluster = self.bytes_per_sector * sectors_per_cluster

        self.reserved_sectors = read_le_short(f)
        # assert reserved_sectors == 1, \
        #    "Can only handle FAT with 1 reserved sector"

        fat_count = read_byte(f)
        assert fat_count == 2, "Can only handle FAT with 2 tables"

        self.root_entries = read_le_short(f)

        skip_short(f)  # Image size. Sort of. Useless field.
        skip_byte(f)  # Media type. We don't care.

        self.fat_size = read_le_short(f) * self.bytes_per_sector
        self.root = fat_dir(root_dentry_file(self))
```

- replace all occurences of `FAT_TABLE_START` with `self.fat_start()`

#### Apply patch to `art`

Apply
[this patch](https://android-review.googlesource.com/c/platform/art/+/2226578/2/runtime/mem_map.cc#511)
to `art/runtime/mem_map.cc`.

#### Configure build environment

```bash
$ . build/envsetup.sh
$ lunch rpi3-eng
```

#### Build target

```bash
$ m -j
```

It will take about 1 hour 32 minutes for CPU: intel I5 8500T; RAM: 8G DDR42666;
HDD: 1TB

Then you will get following images in the out/target/product/rpi3 folder:

1. rpiboot.img
2. boot.img
3. system.img
4. vendor.img
5. userdata.img

#### Flash images

1. Flash images to sdcard directly

We cannot use (and should not force) `sudo` inside the FHS.\
The best solution is to give yourself access to the SD card without `sudo`.
Outside the nix shell, run:

```bash
sudo setfacl -m u:yourusername:rw /path/to/sdcard
```

To revert:

```bash
sudo setfacl -b /path/to/sdcard
```

Then inside the nix shell:

```bash
OUT=${OUT} device/brobwind/rpi3/boot/create_partition_table.sh /path/to/sdcard
```

After executing the command, it will also install following images to sdcard:

- out/target/product/rpi3/rpiboot.img
- out/target/product/rpi3/boot.img
- out/target/product/rpi3/system.img
- out/target/product/rpi3/vendor.img
- device/brobwind/rpi3/boot/images/oem\_bootloader\_a.img
- device/brobwind/rpi3/boot/images/zero\_4k.bin

2. Using fastboot command

Please refer to
https://github.com/brobwind/pie-device-brobwind-rpi3-u-boot/blob/pie-device-brobwind-rpi3/README.md

#### For detail info, please refer:

1. https://www.brobwind.com/archives/1575
2. https://www.brobwind.com/archives/1541
