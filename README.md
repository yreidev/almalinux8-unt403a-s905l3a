# AlmaLinux 8.10 for UNT403A (S905L3A)

本仓库自动构建 AlmaLinux 8.10 AArch64、Ophub 6.6.150 内核的 S905L3A / UNT403A 刷写包。Ophub 对 UNT403A 的设备表映射为 `meson-g12a-s905l3a-m401a.dtb` 和 `u-boot-e900v22c.bin`。

rootfs 预装 `passwd`、`network-scripts` 和 NetworkManager，`eth0` 默认通过 DHCP 获取地址。

`v1.0.0` 保持不可变，内容为 AlmaLinux 8.10、Ophub 6.6.150 和标准 `BBR + FQ`。
当前发布版本 `v1.1.0-bbrplus` 使用固定的 6.6.150 源码构建 `BBRPlus + FQ`，内核版本为 `6.6.150-bbrplus`。

仓库不保存 500MB 级别的二进制包。GitHub Actions 会在 Ubuntu runner 上下载固定版本/commit 的内核、DTB、U-Boot 和 AlmaLinux 容器，构建并发布刷写包。

## 构建

推送到 `main` 或在 **Actions → Build AlmaLinux 8.10 for UNT403A → Run workflow** 手动运行，只生成测试 Artifact，不会自动覆盖正式版本。正式版本必须推送新的 `v*` 标签；标签会创建同名 Release。BBRPlus 版本使用独立版本号，不会覆盖 `v1.0.0`。Workflow Artifact 文件为：

```text
AlmaLinux8.10-S905L3A-UNT403A.zip
AlmaLinux8.10-S905L3A-UNT403A.zip.sha256
```

压缩包内包含：

```text
AlmaLinux8.10-S905L3A-UNT403A/
├── AlmaLinux-8.10-aarch64-S905L3A-UNT403A-rootfs.tgz
├── AlmaLinux-8.10-S905L3A-UNT403A-boot.zip
├── AlmaLinux8.10-S905L3A-UNT403A刷写说明.txt
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

刷写前备份原 boot 分区和当前 DTB。确认目标设备后，严格按包内 `AlmaLinux8.10-S905L3A-UNT403A刷写说明.txt` 的当前刷写方法执行，不要修改 DTB、U-Boot、挂载步骤或网络配置。

首次启动后立即执行：

```bash
passwd root
cat /etc/almalinux-release
uname -a
ip addr show eth0
sysctl net.ipv4.tcp_congestion_control net.core.default_qdisc
```

默认首次登录为 `root / admin`，联网后必须修改密码。
