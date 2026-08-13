# Pinned kernel inputs

- Linux: `ophub/linux-6.6.y@3c7c31e62162ab532313e24a3bfef881c9698796` (`6.6.150`)
- BBRPlus base: `UJX6N/bbrplus-6.6@7d315a874afb298d15816aaa9ed70ea5f124975b`
- Base patch SHA256: `b8911f24dddf29428038cf01c89593efb07adf36e69db6f17a2d4a4d84fd8f89`
- Adapted patch SHA256: `a0feb55ea5e502bc2b33bc880593943b169f56e3aeebd99703f5ff1104730d6f`
- Config base: `ophub/kernel@676d07ee8f76de436a2fcdf3fdafcfa0ac92eead`

`patches/0001-bbrplus-6.6.150.patch` keeps the 6.6 implementation and adds only
the `READ_ONCE`/`WRITE_ONCE` pacing-rate access fixes from newer code. It keeps
the APIs required by the 6.6 BBR implementation and does not port the 6.12
congestion-control callback signatures.

Local config deltas from the ophub base:

- `CONFIG_IPV6_SIT=m`、`CONFIG_IPV6_TUNNEL=m`（基线为 `y`）：改成模块后开机不再
  自动创建 `sit0` / `ip6tnl0` 占位接口，需要隧道时 `modprobe sit` / `modprobe
  ip6_tunnel` 即可。
