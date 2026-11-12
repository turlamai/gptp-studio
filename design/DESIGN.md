# gPTP Studio DESIGN.md — 视觉与交互契约（单一真源）

原型（`design/prototype/`）与实现（`linux/src/main.cpp` DESIGN-TOKENS）都遵循本文件；改视觉先改这里，再同步实现。
Tokens 逐值提取自 `linux/src/main.cpp` 的 `Palette kLight / kDark`（"industrial blue" 主题，自 1.0 演示层移植），保证原型 → GTK 实现零翻译成本；新增 token（状态底色、success 绿）在表中注明推导来源。

## Brief（2026-11-11 家族试点）

- **目标**：非从零重设计。在既有 industrial blue 体系上做 HIG 级打磨；让「同步状态一眼可判、硬件资格可信、证据链可回溯」这个专业主角在界面上站出来；界面达到可直接用于官网宣传的质量（实物截图验收后才能作对外素材）。
- **原型范围**（5 屏 × 亮/暗）：① 同步总览（英雄屏，含 offset 尖峰告警 + 失锁事件）② 链路与网卡（NIC 能力 + Preflight FAIL 态 + 实际时间戳路径）③ 角色与配置（四角色、ptp4l.conf 预览）④ 报文分析（密集报文表 + 解码树 + hex）⑤ 运行与日志（进程 / 聚合日志 / 预设 / 许可证，即设置屏）。
- **Exit 条件**：5 屏关键状态齐（含失锁、告警、Preflight FAIL、冻结视图态）+ 交互逻辑定稿 + HIG 清单全过 + 用户评审通过。
- **不在范围**：新功能与路由/契约变更（不动 `rivet-schema.json` 与 RPC）；参考源、GM 调优两页的完整形态；商业定价/购买流程 UI；真实硬件截图；模拟器故障注入面板。

## 设计原则（HIG 内核 × 专业工具）

- **时间数据可读性**：一切时间量（offset / delay / freq / 时间戳）用等宽 + tabular-nums，右对齐，单位不换行；实时数字刷新不抖动版面。
- **状态一眼可判**：同步状态三级色语义固定——绿=锁定/通过，橙=漂移/警告，红=失锁/错误；颜色永远与文字双编码（SLAVE / UNCALIBRATED / FAIL），色盲与截图归档都可用。
- **能力 ≠ 精度**：NIC 能力、运行时实际 timestamp source、参考平台校准结果三类信息永远分开显示，绝不把纳秒分辨率包装成已校准精度。
- **证据可回溯**：告警关联报文号与引擎事件，报告/日志/诊断一键复制导出；工程师能从一条告警走到对应 Sync 帧再走回配置。
- **防错一致**：真实引擎启动前必先 Preflight；停止引擎、清空报文、移除许可证属破坏性操作需确认；权限路径（CAP_NET_ADMIN 等）由 Doctor/Preflight 明示，绝不静默提权。

## Tokens（语义；值不在此复制）

值类 token 真源 = `linux/src/main.cpp` 的 `Palette kLight / kDark`（"industrial blue" 主题，自 1.0 演示层移植）；原型 `design/prototype/shared.css` 与其一一对应，本表只记语义与推导来源。

| Token | 语义 | 来源 |
|---|---|---|
| `--bg --surface --rail` | 画布 / 卡片 / 侧栏与状态栏 | 实现值 |
| `--topbar-a → b` | 顶栏品牌渐变（只此一处用深蓝大面积） | 实现值 |
| `--line` | 分隔/描边 | 实现值 |
| `--ink --mute` | 主/次级文字 | 实现值 |
| `--accent --accent-strong --hover` | 选中/链接/主按钮/进行态 + 深态 + 悬浮底 | 实现值 |
| `--warn --danger` | 角色徽标/告警线/漂移态 / 失锁·FAIL·错误 | 实现值 |
| `--ok --*-soft` | 锁定/PASS/运行中（GTK stock success 家族对齐）+ 状态徽标 12–16% alpha 弱底 | 新增推导 |

- **字体**：`system-ui, -apple-system, "Segoe UI", Ubuntu, Cantarell, "Noto Sans CJK SC", "PingFang SC", "Microsoft YaHei"`；正文 14px/1.55，卡片标题 12px/600，页面标题 17px/700；等宽 `ui-monospace, "Ubuntu Mono", Menlo, Consolas, monospace`（报文行 12px、指标值 17px/600）。
- **圆角**：窗口 12px · 卡片 10px · 侧栏行 8px · 控件 6px · 徽标 13px。**间距节奏**：4/8/12/16/24。**动效**：120ms ease，不过度。
- **语言**：界面文案中文为主（`app/i18n.rkt` zh 源），协议值（角色名、端口状态、PTP 字段名）按产品约定保留英文不译。

## 组件词汇

`HeaderBar`（深蓝渐变 + 品牌版号 + 6 枚实时 pills：角色/端口/GM/offset/delay/档位）· `SideRail`（六页导航，蓝底白字活动项）· `MetricCard`（caption + 等宽大值）· `SyncCurve`（SVG 曲线 + 阈值虚线 + 尖峰标记）· `PortTable`（端口/角色/状态/对端）· `QualCard`（NIC 能力卡）· `PreflightList`（✓/✗ 检查清单 + 导出诊断）· `PacketTable`（密集等宽行 + 类型徽标）· `DecodeTree`（缩进字段树）· `HexView` · `ConfPreview`（ptp4l.conf 等宽预览）· `LogStream`（级别/来源过滤 + 等宽行）· `LicenseCard`（档位/安装 ID/激活）· `Toast`。

## 不变式

1. `accent` 蓝只给交互、选中与数据主序列（导航活动项、主按钮、选中行、链接、曲线主线）；绿/橙/红只给状态；禁止大面积状态色块（状态以徽标 + 文字呈现）。
2. 层级 ≤3 层表面：画布 < 卡片 < 悬浮/选中；深蓝渐变只属于顶栏品牌带，页面内部不再引入深色大底。
3. 所有时间数值等宽右对齐、单位固定（ns/µs/ms 按量级）；数字刷新不得改变版面布局。
4. 亮暗主题成对设计（GTK 宿主 `ColorScheme` 双套），不存在只有暗态的界面；告警在两态下对比度均达 WCAG AA。
5. 键盘可达走 GTK/焦点惯例（Tab 焦点链、F10 菜单、Ctrl+F 搜索；`Ctrl+1…6` 切页为本原型提出、实现待接），不自造 vim 式单键位；每个可点目标有可见焦点环。
6. 破坏性操作（停止全部、清空报文、移除许可证）永远红色 destructive 且需确认；告警、报告、日志、诊断必可复制或导出。


## 平台映射与差异声明（预钉 · 宿主实现时升级为落点表）

统一层（三平台必须一致，`design/prototype/` 原型已锁定）：信息架构、核心流程、快捷键语义、
语义色与层级词汇。因地制宜层（按平台惯例落地，不预画像素）：

| 维度 | macOS | Windows | Linux |
|---|---|---|---|
| 修饰键 | ⌘ | Ctrl | Ctrl |
| 命令入口 | 原生菜单栏 | 菜单栏/命令行内 | 菜单栏 |
| 字体 | 系统栈 + PingFang SC | 系统栈 + Microsoft YaHei | 系统栈 + Noto Sans CJK |
| 原生控件 | SwiftUI 控件 | WinUI 3 控件 | GTK4 控件 |

差异声明纪律：宿主特例必须先写进本节才能实现；未声明的宿主差异按违约处理
（案例：taskly 漂移台账 D8）。
