# gPTP Studio

**面向 Automotive Ethernet 的 Linux 原生 gPTP / IEEE 802.1AS 专业调试工作站。**

[![CI](https://github.com/turlamai/gptp-studio/actions/workflows/ci.yml/badge.svg)](https://github.com/turlamai/gptp-studio/actions/workflows/ci.yml) ![Platform](https://img.shields.io/badge/platform-Linux-blue) ![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04%20LTS-E95420) ![Racket](https://img.shields.io/badge/Racket-9F1D20?logo=racket&logoColor=white) [![License](https://img.shields.io/badge/license-Apache--2.0-blue)](LICENSE)

[English](README.md) · **中文**

gPTP Studio 现在明确定位为 **Linux-only 产品**。原因不是 UI 能不能跨平台，而是专业 gPTP 调试真正依赖的能力集中在 Linux：**PHC、硬件时间戳、`SO_TIMESTAMPING`、linuxptp、sysfs 网卡信息以及明确可控的权限模型**。如果一个平台只能做软时间戳或离线分析，就不应该与真实 GM/Slave 调试放在同一个“正式支持平台”里。

针对 AUTOSAR EthTSyn / IEEE 802.1AS 场景，一台 Linux 工作站可以在 **GrandMaster / 从钟 / 被动监听** 三种角色之间切换，实时显示同步收敛、解码线上每一条 gPTP 报文，并把 offset 突跳与对应报文和引擎状态关联起来。

项目使用 [Racket](https://racket-lang.org/) + [Rivet](https://github.com/turlamai/rivet)：原生 GTK4 桌面宿主经类型化 RPC/事件契约驱动内嵌 Racket 后端，真实时间路径交给 Linux 原生 PHC / hardware timestamp / linuxptp。同步收敛曲线由 Rivet 共享的实时图表数据面渲染。

## 开始使用

工程预览。规划有官方专业版，此处尚不提供购买或硬件精度保证。 仅支持 Linux，提供 x64 和 arm64 发布附件。Windows 和 macOS 不属于产品目标。真实抓包与 PHC 操作需要兼容硬件和适当权限。

[安装、首次使用、隐私与备份恢复](docs/USER-GUIDE.zh-CN.md) · [English](docs/USER-GUIDE.md)

## 核心能力

- **四角色一台工作站**：GrandMaster、从钟、双端口 Boundary Clock（多接口 `ptp4l` + `phc2sys -a -r`）、被动监听，自动生成 `ptp4l.conf`
- **linuxptp 生命周期管理**：统一监督 `ptp4l`、`phc2sys`、`pmc`
- **硬件时钟资格检查**：启动真实引擎前检查 HW timestamp、PHC、驱动和权限路径
- **实时同步曲线**：`offsetFromMaster` / `meanPathDelay`、告警、端口状态
- **gPTP 抓包与完整解码**：libpcap 抓取 EtherType `0x88f7`，支持 Sync / Follow_Up / Announce / PDelay_* / Signalling、精确 sec+nsec 元数据、hex、pcap/pcapng
- **时间路径透明**：网卡“能力”与当前抓包“实际 timestamp source”分开显示，不把纳秒分辨率包装成已校准精度
- **无头 Doctor**：`--doctor` / `--doctor-json` 不打开 GUI 就能输出 NIC、PHC、linuxptp、权限和角色就绪状态，默认不输出 MAC/IP
- **内置模拟器 + 故障注入**：合成 802.1AS 帧继续走真实 encode/decode/store 管线；可注入 Sync/Announce 丢弃、Follow_Up 延迟、sequenceId 跳变与 offset 尖峰，对告警、BMCA 判读与报告做负向测试
- **GM 运行时调优**：经 `pmc GRANDMASTER_SETTINGS_NP` 在线修改 clockClass、clockAccuracy、timeSource 与 BMCA 优先级，无需重启引擎（Pro）
- **Wireshark 一键联动**：实时（gPTP 捕获过滤器）或回放保留报文；工程报告导出 JSON/Markdown
- **聚合日志与预设**：引擎、抓包、应用事件统一观察
- **离线授权**：适合内网和保密研发环境，不依赖云端许可服务

## 正式支持平台

产品契约现在只有 **Linux**。

| 项目 | 支持范围 |
|---|---|
| 首要验证发行版 | Ubuntu 24.04 LTS（GTK4 宿主要求 GTK 4.10+；22.04 的 4.6 低于下限） |
| 桌面 UI | Rivet 宿主（GTK4 原生控件，无 WebView） |
| 真实 GM / 从钟引擎 | linuxptp（`ptp4l`、`phc2sys`、`pmc`） |
| 时间硬件 | 支持 hardware timestamp 的 NIC + PHC（`/dev/ptpN`） |
| 抓包 | libpcap，并显示运行时实际时间戳来源 |
| 官方包 | `.deb` / `.rpm` / `.AppImage` + 可移植 `.tar.gz`（另有便携 `.zip`）；每个资产带 `.sha256` 侧车，发布附带聚合 `SHA256SUMS` |
| 其他操作系统 | 产品层面不支持 |

网卡报告支持硬件时间戳并存在 `/dev/ptpN`，只代表它具备 linuxptp 所需能力；这**不等于**已经证明端到端时间测量精度。Studio 会把硬件能力、运行时 timestamp source 与未来参考平台校准结果分别管理。

## 安装

从[对应版本的 GitHub Release](https://github.com/turlamai/gptp-studio/releases/latest)
选择与 Linux 架构、安装方式一致的**带版本号附件**。例如 `v0.4.0`
发布 `gptp-studio-0.4.0-linux-amd64.deb`、
`gptp-studio-0.4.0-linux-x64.tar.gz` 和
`gptp-studio-0.4.0-linux-x86_64.AppImage`。
`gptp-studio-linux-amd64.deb` 等无版本号副本只是便捷别名，
**不能**作为固定版本身份。为保证安装可复现，文档及 CI 应固定
Release tag、带版本的文件名，并核对该版本提供的校验和。

### Debian / Ubuntu 包

```bash
TAG=v0.4.0  # 以 Releases 页面上需要安装的版本为准
VERSION="${TAG#v}"
curl -fLO "https://github.com/turlamai/gptp-studio/releases/download/$TAG/gptp-studio-$VERSION-linux-amd64.deb"
sudo apt install "./gptp-studio-$VERSION-linux-amd64.deb"
/opt/gptp-studio/gptp-studio --doctor
/opt/gptp-studio/gptp-studio
```

deb 安装到 `/opt/gptp-studio` 并带桌面入口；上面的命令分别是无头
诊断与直接启动形态。

`.deb` 会声明 Linux 运行依赖，并安装桌面入口、图标和许可证材料。安装过程**不会偷偷执行 `setcap`**，也不会自动授予 `CAP_NET_ADMIN`、`CAP_NET_RAW`、`CAP_SYS_TIME`。Doctor / Preflight 会明确告诉用户当前权限路径，由工程师自己决定系统安全配置。

### 可移植 tarball

```bash
TAG=v0.4.0  # 以 Releases 页面上需要安装的版本为准
VERSION="${TAG#v}"
curl -fLO "https://github.com/turlamai/gptp-studio/releases/download/$TAG/gptp-studio-$VERSION-linux-x64.tar.gz"
tar -xzf "gptp-studio-$VERSION-linux-x64.tar.gz"
cd gptp-studio-distributed
./gptp-studio --doctor
./gptp-studio
```

### RPM 系发行版

从[发布页](https://github.com/turlamai/gptp-studio/releases/latest)
下载 `gptp-studio-<版本>-<build>-linux-x86_64.rpm`（或 `-aarch64.rpm`）
后安装：

```bash
sudo dnf install ./gptp-studio-<版本>-<build>-linux-x86_64.rpm
gptp-studio --doctor
```

### AppImage（任意发行版，免安装）

AppImage 自带 GTK4 依赖闭包，比 deb/rpm 能跑在更老的宿主上；GUI 之前
同样可以走 `--doctor` 无头面：

```bash
TAG=v0.4.0  # 以 Releases 页面上需要安装的版本为准
VERSION="${TAG#v}"
curl -fLO "https://github.com/turlamai/gptp-studio/releases/download/$TAG/gptp-studio-$VERSION-linux-x86_64.AppImage"
chmod +x "gptp-studio-$VERSION-linux-x86_64.AppImage"
"./gptp-studio-$VERSION-linux-x86_64.AppImage" --doctor
"./gptp-studio-$VERSION-linux-x86_64.AppImage"
```

### 源码运行

```bash
sudo apt install linuxptp libpcap-dev ethtool iproute2 libcap2-bin \
  libgtk-4-dev libglib2.0-dev libsecret-1-dev libncurses-dev zlib1g-dev liblz4-dev \
  rpm desktop-file-utils

raco pkg install --auto --no-docs https://github.com/turlamai/rivet.git
raco pkg install --auto --no-docs https://github.com/turlamai/permit.git
raco rivet generate
raco rivet build          # 构建 GTK4 宿主（产物在 .rivet/build/linux/）
raco test tests/          # 后端测试套件
raco rivet dev            # 运行应用；构建出的二进制同样支持 --doctor
```

真机调试建议固定流程：先跑 `gptp-studio --doctor`，处理结构性 FAIL，再在 GUI 对目标接口执行 Preflight，最后才启动真实 GM/Slave。详见 [docs/support-doctor.md](docs/support-doctor.md) 与 [docs/hardware-qualification.md](docs/hardware-qualification.md)。

### 更新检查

Linux 更新渠道使用 Ed25519 签名的
[`update-stable.json` 清单](update-stable.json)。启动后可能执行静默检查
（最长每四小时一次）；手动**检查更新**可以绕过该节流。网络失败或签名错误
不得触发未验证的安装。发现新版本后，下载与应用都需要用户同意；
**不会在后台自动安装更新**。

安装行为取决于原来的包形态：

- **`.deb`**：暂存已验证的带版本号安装包，向操作者展示明确的
  `sudo apt-get install` 安装命令；同意后可选择由 `pkexec` 发起授权安装。
- **可移植 `.tar.gz`**：先验证包布局，再保护性替换；失败时尝试恢复
  旧 payload，并要求重启应用。
- **AppImage**：通过 Releases 手动下载新版本的带版本号 AppImage。
  应用内的安装流程**不负责 AppImage 自动更新**。

气隙主机可使用 `--no-update-check` 禁止启动后的静默检查。
更新鉴权、失败恢复及安装形态详见
[Linux 更新契约](docs/update-contract.md)。签名清单与已发布附件本身
并不能证明每一种安装/重启路径已经通过原生验收。

## 六页工作区

| 页面 | 功能 |
|---|---|
| 同步总览 | 实时 offset/delay 曲线、端口状态、当前 GM、告警阈值 |
| 链路与网卡 | NIC HW timestamp / PHC 能力 + 实际抓包 timestamp path |
| 角色与配置 | 角色切换、gPTP 参数、生成 `ptp4l.conf`、启动/停止 |
| 参考源 | `phc2sys` 参考源生命周期管理 |
| 报文分析 | 抓包、报文表、解码树、精确时间戳元数据、hex、导入导出 |
| 运行与日志 | 进程状态、日志、预设、许可证 |

## 版本与授权

| | 官方 Free | 官方 Pro |
|---|---|---|
| 监听抓包 + 报文解码 | ✅ | ✅ |
| 离线 pcap 导入 | ✅ | ✅ |
| 模拟器 | ✅ | ✅ |
| 配置编辑 + `ptp4l.conf` 预览 | ✅ | ✅ |
| GM / 从钟引擎控制 | — | ✅ |
| 参考源（`phc2sys`） | — | ✅ |
| pcap 导出 | — | ✅ |
| 报文存储 | 2,000 帧 | 50,000 帧 |

源码采用 Apache-2.0。Free / Pro 描述的是**官方分发版本**中的产品体验、更新 entitlement 与支持服务，不会撤销或缩小 Apache-2.0 已经授予的权利。自行构建或修改的 Apache-2.0 版本不自动成为官方 Pro 构建，也不附带官方更新、支持和参考平台验证承诺。

每个官方安装包自带 14 天 Pro 试用。定价见 [PRICING.md](PRICING.zh-CN.md)，许可模型见 [docs/licensing-model.md](docs/licensing-model.md)。

## 架构原则

一个 Racket 后端进程向原生 GTK4 宿主提供类型化 RPC/事件契约；真正的时间路径交给 Linux 原生能力：linuxptp 子进程、PHC/hardware timestamp、libpcap。Racket/GUI 是控制面与分析面，不是纳秒时间戳产生源。详见 [docs/architecture.md](docs/architecture.md)。

## 许可证

gPTP Studio 源码以及官方分发物中受 Apache-2.0 覆盖的部分继续适用 Apache-2.0。[EULA.md](EULA.md) 约束官方 Pro entitlement、许可证凭据、官方更新/支持和官方身份关系，但不会覆盖或撤销适用的开源权利。第三方归属见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
