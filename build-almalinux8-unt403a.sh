#!/usr/bin/env bash
set -Eeuo pipefail

base_dir="$(cd "$(dirname "$0")" && pwd)"
out_dir="$base_dir/AlmaLinux8.10-S905L3A-UNT403A"
version="6.6.150"
kernel_sha256="933b402760bbdc6d9ae0ed441131a11dbd6951f45e18c4cea59f0c9576cf45f8"
amlogic_commit="33e3b6f6da0e2b3c1b3e64efd2467d880882446f"
uboot_commit="a1d43b60f524cfa187bd91d95d6e54be8610d199"
alma_digest="sha256:4a87d2615a770506e204c27d6248ac97f4df67f4e41e2e9c47c81f0ed0be98cb"
image="almalinux8-s905l3a-unt403a:8.10"
binfmt_image="tonistiigi/binfmt@sha256:400a4873b838d1b89194d982c45e5fb3cda4593fbfd7e08a02e76b03b21166f0"
container=""
tmp_dir="$(mktemp -d "$base_dir/.ophub-build.XXXXXX")"

cleanup() {
    [[ -z "$container" ]] || docker rm -f "$container" >/dev/null 2>&1 || true
    rm -rf "$tmp_dir"
}
trap cleanup EXIT

for command_name in awk bsdtar curl docker file git gzip sha256sum tar unzip zip; do
    command -v "$command_name" >/dev/null || { echo "缺少命令：$command_name" >&2; exit 1; }
done

if ! docker run --rm --platform linux/arm64 "almalinux:8@$alma_digest" true >/dev/null 2>&1; then
    docker run --privileged --rm "$binfmt_image" --install arm64 >/dev/null
fi

mkdir -p "$out_dir"
kernel_tar="$tmp_dir/$version.tar.gz"
curl -LfsS --retry 3 --retry-delay 2 "https://github.com/ophub/kernel/releases/download/kernel_stable/$version.tar.gz" -o "$kernel_tar"
printf '%s  %s\n' "$kernel_sha256" "$kernel_tar" | sha256sum -c -
for source in amlogic u-boot; do
    case "$source" in
        amlogic) url=https://github.com/ophub/amlogic-s9xxx-armbian.git; commit="$amlogic_commit" ;;
        u-boot) url=https://github.com/ophub/u-boot.git; commit="$uboot_commit" ;;
    esac
    git clone --filter=blob:none --no-checkout "$url" "$tmp_dir/$source"
    git -C "$tmp_dir/$source" fetch --depth 1 origin "$commit"
    git -C "$tmp_dir/$source" checkout --detach "$commit"
done

mkdir -p "$tmp_dir/kernel" "$tmp_dir/boot-input" "$tmp_dir/dtb-input" "$tmp_dir/modules"
tar -xzf "$kernel_tar" -C "$tmp_dir/kernel"
(cd "$tmp_dir/kernel/$version" && sha256sum -c sha256sums)
tar -xzf "$tmp_dir/kernel/$version/boot-$version-ophub.tar.gz" -C "$tmp_dir/boot-input"
tar -xzf "$tmp_dir/kernel/$version/dtb-amlogic-$version-ophub.tar.gz" -C "$tmp_dir/dtb-input"
tar -xzf "$tmp_dir/kernel/$version/modules-$version-ophub.tar.gz" -C "$tmp_dir/modules"

mkdir -p "$tmp_dir/firmware/rtl_bt"
for firmware_name in rtl8761b_config.bin rtl8761b_fw.bin; do
    curl -LfsS "https://raw.githubusercontent.com/ophub/firmware/main/firmware/rtl_bt/$firmware_name" -o "$tmp_dir/firmware/rtl_bt/$firmware_name"
done

docker build --platform linux/arm64 -t "$image" -f - "$base_dir" <<DOCKERFILE
FROM almalinux:8@$alma_digest
RUN dnf -y install NetworkManager NetworkManager-tui network-scripts passwd openssh-server openssh-clients chrony iproute procps-ng kmod e2fsprogs dosfstools parted && dnf clean all && rm -rf /var/cache/dnf
RUN printf 'AlmaLinux\\n' > /etc/hostname && printf 'root:admin\\n' | chpasswd && ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && printf 'SELINUX=disabled\\nSELINUXTYPE=targeted\\n' > /etc/selinux/config && sed -ri -e 's/^[#[:space:]]*PermitRootLogin[[:space:]].*/PermitRootLogin yes/' -e 's/^[#[:space:]]*PasswordAuthentication[[:space:]].*/PasswordAuthentication yes/' /etc/ssh/sshd_config && systemctl enable NetworkManager sshd chronyd getty@tty1.service serial-getty@ttyAML0.service && systemctl set-default multi-user.target && rm -f /etc/machine-id /var/lib/dbus/machine-id /var/lib/systemd/random-seed /etc/ssh/ssh_host_* && touch /etc/machine-id
RUN rm -f /etc/NetworkManager/system-connections/eth0.nmconnection && mkdir -p /etc/sysconfig/network-scripts /usr/lib/firmware/rtl_bt && printf '%s\\n' 'TYPE=Ethernet' 'PROXY_METHOD=none' 'BROWSER_ONLY=no' 'DEVICE=eth0' 'NAME=eth0' 'ONBOOT=yes' 'BOOTPROTO=dhcp' 'DEFROUTE=yes' 'IPV4_FAILURE_FATAL=no' 'IPV6INIT=yes' 'IPV6_AUTOCONF=yes' 'IPV6_DEFROUTE=yes' 'IPV6_FAILURE_FATAL=no' 'IPV6_ADDR_GEN_MODE=stable-privacy' 'PEERDNS=yes' 'NM_CONTROLLED=yes' > /etc/sysconfig/network-scripts/ifcfg-eth0 && chmod 600 /etc/sysconfig/network-scripts/ifcfg-eth0
DOCKERFILE

container="$(docker create --platform linux/arm64 "$image")"
docker cp "$tmp_dir/modules/$version-ophub" "$container:/usr/lib/modules/"
docker cp "$tmp_dir/firmware/rtl_bt/." "$container:/usr/lib/firmware/rtl_bt/"
docker export -o "$tmp_dir/rootfs.tar" "$container"
bsdtar -cf "$tmp_dir/rootfs-clean.tar" --format=gnutar --exclude='.dockerenv' "@$tmp_dir/rootfs.tar"

rootfs="$out_dir/AlmaLinux-8.10-aarch64-S905L3A-UNT403A-rootfs.tgz"
rm -f "$rootfs"
gzip -1c "$tmp_dir/rootfs-clean.tar" > "$rootfs"
boot_stage="$tmp_dir/boot"
mkdir -p "$boot_stage/dtb/amlogic"
cp -a "$tmp_dir/amlogic/build-armbian/armbian-files/platform-files/amlogic/bootfs/." "$boot_stage/"
cp "$tmp_dir/boot-input/vmlinuz-$version-ophub" "$boot_stage/zImage"
cp "$tmp_dir/boot-input/uInitrd-$version-ophub" "$boot_stage/uInitrd"
cp "$tmp_dir/boot-input"/*-"$version"-ophub "$boot_stage/"
cp "$tmp_dir/dtb-input"/*.dtb "$boot_stage/dtb/amlogic/"
cp "$tmp_dir/u-boot/u-boot/amlogic/overload/u-boot-e900v22c.bin" "$boot_stage/u-boot.ext"
cp "$tmp_dir/u-boot/u-boot/amlogic/overload/u-boot-e900v22c.bin" "$boot_stage/u-boot.emmc"
cp "$tmp_dir/u-boot/u-boot/amlogic/bootloader/e900v22c-u-boot.bin.sd.bin" "$boot_stage/"
chmod +x "$boot_stage/u-boot.ext" "$boot_stage/u-boot.emmc"
printf '%s\n' \
    'LINUX=/zImage' \
    'INITRD=/uInitrd' \
    'FDT=/dtb/amlogic/meson-g12a-s905l3a-m401a.dtb' \
    'APPEND=root=LABEL=ROOTFS_EMMC rootflags=data=writeback rw rootwait rootfstype=ext4 console=ttyAML0,115200n8 console=tty0 no_console_suspend consoleblank=0 fsck.fix=yes fsck.repair=yes net.ifnames=0 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1 selinux=0' \
    > "$boot_stage/uEnv.txt"
boot_zip="$out_dir/AlmaLinux-8.10-S905L3A-UNT403A-boot.zip"
rm -f "$boot_zip"
(cd "$tmp_dir" && zip -qr -9 "$boot_zip" boot)
cp "$base_dir/AlmaLinux8.10-S905L3A-UNT403A刷写说明.txt" "$out_dir/"
printf '%s\n' \
    "AlmaLinux image digest: $alma_digest" \
    "ophub/kernel release: $version.tar.gz" \
    "ophub/kernel sha256: $kernel_sha256" \
    "ophub/amlogic-s9xxx-armbian commit: $(git -C "$tmp_dir/amlogic" rev-parse HEAD)" \
    "ophub/u-boot commit: $(git -C "$tmp_dir/u-boot" rev-parse HEAD)" \
    "UNT403A S905L3A DTB: meson-g12a-s905l3a-m401a.dtb" \
    "u-boot-e900v22c.bin sha256: $(sha256sum "$tmp_dir/u-boot/u-boot/amlogic/overload/u-boot-e900v22c.bin" | awk '{print $1}')" \
    "e900v22c-u-boot.bin.sd.bin sha256: $(sha256sum "$tmp_dir/u-boot/u-boot/amlogic/bootloader/e900v22c-u-boot.bin.sd.bin" | awk '{print $1}')" \
    > "$out_dir/SOURCE-MANIFEST.txt"
tar -xOzf "$rootfs" usr/bin/bash | file - | grep 'ARM aarch64' >/dev/null
tar -xOzf "$rootfs" etc/almalinux-release | grep '8.10' >/dev/null
tar -tzf "$rootfs" | grep "usr/lib/modules/$version-ophub/kernel/" >/dev/null
tar -tzf "$rootfs" | grep 'usr/lib/firmware/rtl_bt/rtl8761b_fw.bin' >/dev/null
tar -tzf "$rootfs" | grep -Fx 'usr/bin/passwd' >/dev/null
tar -tzf "$rootfs" | grep -Fx 'usr/sbin/ifup' >/dev/null
tar -xOzf "$rootfs" etc/sysconfig/network-scripts/ifcfg-eth0 | grep -Fx 'BOOTPROTO=dhcp' >/dev/null
if tar -xOzf "$rootfs" etc/sysconfig/network-scripts/ifcfg-eth0 | grep -Eq '^(UUID|HWADDR|IPADDR|PREFIX|GATEWAY)='; then
    echo 'ifcfg-eth0 中存在设备或网络专属配置' >&2
    exit 1
fi
if tar -tzf "$rootfs" | grep -Fx 'etc/NetworkManager/system-connections/eth0.nmconnection' >/dev/null; then
    echo 'rootfs 中存在与 ifcfg-eth0 冲突的 eth0.nmconnection' >&2
    exit 1
fi
tar -tzf "$rootfs" | grep -Fx 'etc/systemd/system/multi-user.target.wants/NetworkManager.service' >/dev/null
unzip -t "$boot_zip" >/dev/null
unzip -p "$boot_zip" boot/uEnv.txt | grep '^FDT=/dtb/amlogic/meson-g12a-s905l3a-m401a.dtb$' >/dev/null
unzip -Z1 "$boot_zip" | grep -Fx 'boot/u-boot.ext' >/dev/null
unzip -Z1 "$boot_zip" | grep -Fx 'boot/u-boot.emmc' >/dev/null
unzip -Z1 "$boot_zip" | grep -Fx 'boot/e900v22c-u-boot.bin.sd.bin' >/dev/null
(cd "$out_dir" && sha256sum "$(basename "$rootfs")" "$(basename "$boot_zip")" AlmaLinux8.10-S905L3A-UNT403A刷写说明.txt SOURCE-MANIFEST.txt > SHA256SUMS)
echo "完成：$out_dir"
