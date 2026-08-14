# AlmaLinux 8.10 UNT403A 刷写说明

适用平台：AArch64 / Amlogic S905L3A / UNT403A

内核版本：Ophub `6.6.150-bbrplus`

## 默认配置

| 项目 | 配置 |
| --- | --- |
| 用户名 | `root` |
| 密码 | `admin` |
| 主机名 | `AlmaLinux8` |
| 网络 | `eth0` 通过 DHCP 获取 IPv4，不启用 IPv6 |
| 拥塞控制 | BBRPlus + FQ |

本包使用固定源码构建内核、DTB、U-Boot 和启动文件。boot 包只包含 S905L3A
版 UNT403A 所需文件，设备树为：

```text
/dtb/amlogic/meson-g12a-s905l3a-m401a.dtb
```

U-Boot 使用同系列共用的 `u-boot-e900v22c.bin`。请勿用于 S905L3B 版
UNT403A，也不要替换为 CM311 或其他机型的 DTB。

rootfs 预装 NetworkManager、network-scripts、EPEL、ncurses、wget、curl、
vim/nano、sudo、tmux、htop、diff、openssl、DNF plugins、net-tools、
bind-utils、traceroute、tcpdump、ethtool、lsof、rsync、cronie 和常用压缩解压
工具。`crond` 默认自启。

根分区使用 `data=ordered,commit=5`，以降低意外断电的数据丢失风险。
`/etc/sysctl.conf` 参考 Alma8 配置 TCP 缓冲、IPv4 转发并禁用 IPv6；SSH
显式设置 `UseDNS no`。

## 重要提示

1. 这套旧写入方法只能使用 Armbian Bullseye。Jammy 会提示代码或命令错误。
2. 先执行 `lsblk -f`，确认 eMMC 是 `mmcblk1` 还是 `mmcblk2`。下文的
   `mmcblk2` 只是示例。
3. 刷写命令会删除 eMMC 的 boot 和 rootfs 内容。先备份 boot 分区、
   `uEnv.txt`、DTB 和重要数据。
4. 只使用发布包中的 rootfs tgz 和 boot zip。不要混用其他镜像的 `/boot`
   文件。

## 刷写步骤

### 1. 清理当前 eMMC boot

进入当前 eMMC Armbian，删除 boot 系统后关机：

```bash
rm -rf /boot/*
shutdown now
```

### 2. 从 Bullseye U 盘启动

插入原 Armbian Bullseye 烧录 U 盘并开机。把以下两个构建产物上传到
`/root`：

```text
AlmaLinux-8.10-aarch64-S905L3A-UNT403A-rootfs.tgz
AlmaLinux-8.10-S905L3A-UNT403A-boot.zip
```

### 3. 确认分区卷标

将命令中的 `mmcblk2` 换成实际 eMMC 设备：

```bash
blkid /dev/mmcblk2p1 /dev/mmcblk2p2
```

要求 p1 的 LABEL 为 `BOOT_EMMC`、p2 的 LABEL 为 `ROOTFS_EMMC`。不一致时先
修正：

```bash
fatlabel /dev/mmcblk2p1 BOOT_EMMC
e2label /dev/mmcblk2p2 ROOTFS_EMMC
```

`uEnv.txt` 根据 `LABEL=ROOTFS_EMMC` 挂载根分区，卷标错误会导致开机卡死。
`/etc/fstab` 根据 `LABEL=BOOT_EMMC` 挂载 `/boot`，卷标错误会导致 boot 分区
无法挂载。

### 4. 写入系统

```bash
mount /dev/mmcblk2p2 /mnt
mount /dev/mmcblk2p1 /mnt/boot
rm -rf /mnt/*
tar --xattrs --xattrs-include='security.capability' \
  -xvpzf /root/AlmaLinux-8.10-aarch64-S905L3A-UNT403A-rootfs.tgz \
  -C /mnt/
cd /root
unzip AlmaLinux-8.10-S905L3A-UNT403A-boot.zip
cp -a boot/. /mnt/boot/
sync
shutdown now
```

`rm -rf /mnt/*` 可能提示：

```text
rm: cannot remove '/mnt/boot': Device or resource busy
```

这是因为 `/mnt/boot` 是挂载点目录，目录本身无法删除，属于正常现象。两个
分区内的原内容已经清空，可以继续执行后续命令。

### 5. 从 eMMC 启动

拔出 Armbian U 盘，从 eMMC 开机，然后使用 `root / admin` 登录。

## 启动后检查

```bash
cat /etc/almalinux-release
uname -a
lsblk -f
df -h /boot
ip addr show eth0
sysctl net.ipv4.tcp_congestion_control net.core.default_qdisc
```

如写入失败，请保留终端完整输出、`lsblk -f`、当前 `uEnv.txt` 和 TTL 串口
日志。
