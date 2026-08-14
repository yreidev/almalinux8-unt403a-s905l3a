# AlmaLinux 8.10 for UNT403A (S905L3A)

本仓库自动构建 AlmaLinux 8.10 AArch64、Ophub 6.6.150 内核的 S905L3A / UNT403A 刷写包。Ophub 对 UNT403A 的设备表映射为 `meson-g12a-s905l3a-m401a.dtb` 和 `u-boot-e900v22c.bin`。boot 包只包含这台机器的启动脚本、这一份 DTB 和对应 U-Boot，不含 CM311、E900V22C、GT King 等其他机型文件。

rootfs 预装 NetworkManager、`network-scripts`、EPEL、`ncurses`，以及 `wget`、`curl`、`vim`/`nano`、`sudo`、`tmux`、`htop`、`diff`、`openssl`、DNF plugins、`net-tools`、`bind-utils`、`traceroute`、`tcpdump`、`ethtool`、`lsof`、`rsync`、`cronie`（`crond` 自启）、压缩解压等常用工具；`eth0` 默认通过 DHCP 获取 IPv4 地址且不启用 IPv6。`/etc/fstab` 按 `LABEL=ROOTFS_EMMC` / `LABEL=BOOT_EMMC` 挂载根分区和 `/boot`，根分区使用 `data=ordered,commit=5` 降低意外断电的数据丢失风险。rootfs 以 pax 格式打包，保留 `arping`、`clockdiff`、`newuidmap`、`newgidmap` 的文件 capabilities。

`/etc/sysctl.conf` 参考 Alma8 配置 TCP 缓冲、IPv4 转发并禁用 IPv6；SSH 显式设置 `UseDNS no`。

默认主机名为 `AlmaLinux8`。

`v1.0.0` 保持不可变，内容为 AlmaLinux 8.10、Ophub 6.6.150 和标准 `BBR + FQ`。
当前发布版本 `v1.2.0-bbrplus` 使用固定的 6.6.150 源码构建 `BBRPlus + FQ`，内核版本为 `6.6.150-bbrplus`。

仓库不保存 500MB 级别的二进制包。GitHub Actions 会在 Ubuntu runner 上下载固定版本/commit 的内核、DTB、U-Boot 和 AlmaLinux 容器，构建并发布刷写包。

## 构建

推送 `v*` 标签（如 `v1.2.0`）即触发正式构建并自动创建同名 Release；也可在 **Actions → Build AlmaLinux 8.10 for UNT403A → Run workflow** 手动运行，只生成测试 Artifact，不会发布。`v1.0.0` 保持不可变，推送新标签不会覆盖旧 Release。

产物文件名固定，版本由标签区分：

```text
AlmaLinux8.10-S905L3A-UNT403A.zip
AlmaLinux8.10-S905L3A-UNT403A.zip.sha256
```

压缩包内包含：

```text
AlmaLinux8.10-S905L3A-UNT403A/
├── AlmaLinux-8.10-aarch64-S905L3A-UNT403A-rootfs.tgz
├── AlmaLinux-8.10-S905L3A-UNT403A-boot.zip
├── AlmaLinux8.10-S905L3A-UNT403A刷写说明.md
├── SHA256SUMS
└── SOURCE-MANIFEST.txt
```

## 刷写

只使用 **Armbian Bullseye** 启动 U 盘或 TF 卡。Jammy 版本不要使用这套旧方法。

先从 Armbian 启动，确认 eMMC 设备名。下面的 `mmcblk2` 只是示例，实际可能是 `mmcblk1`：

```bash
lsblk -f
cat /boot/uEnv.txt
uname -a
```

刷写前备份原 boot 分区和当前 DTB。确认目标设备后，严格按包内 `AlmaLinux8.10-S905L3A-UNT403A刷写说明.md` 的当前刷写方法执行，不要修改 DTB、U-Boot、挂载步骤或网络配置。

默认登录为 `root / admin`。登录后检查：

```bash
cat /etc/almalinux-release
uname -a
df -h /boot
ip addr show eth0
sysctl net.ipv4.tcp_congestion_control net.core.default_qdisc
```
