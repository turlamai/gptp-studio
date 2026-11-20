# gPTP Studio agent contract

## 家族设计（必读入口）

- 设计/UI 任务先加载 `tlai-product`，必读 `references/policy.md` 与 `references/design-standard.md`（理念、决策规则、UI 验收）。技能缺失时读取 ZCode 真源：macOS/Linux `~/Sync/ZCode/skills/tlai-product/`；Windows `D:/ZCode/skills/tlai-product/`。无法读取须报告规范未核验，不凭记忆跳过。
- 家族规范管共性；本仓现有设计、行为与 token 真源管具体值和产品差异。例外记回原契约，不复制家族规则或新增数值表；已有界面按下一次相关切片渐进对齐。
- 改界面先改原型、落账后实现；按家族 UI 清单与本仓当前技术线的既有门禁验收，原型对照和真实交互证据都要保留；对外宣传使用验收后的实物截图。

## 实现路由（agent 按任务读真源）

- 实现界面以 `design/prototype/` 为准：对照 HTML/CSS/JS 与实物截图验收，不依赖散文复述。
- Token/几何值真源 = `design/prototype/shared.css`（亮暗成对；无 shared.css 的仓 = design/prototype/ 各页样式）；`design/DESIGN.md` 只记语义名、用途与决策。
- 行为边界与跨平台一致性以 `design/DESIGN.md` 的不变式与平台差异节为准。
- 改界面先改原型再改实现（tlai-product）；动共享层（design/、shared/）先 issue 声明，同 commit 落契约。

## Current owner decision — 2026-11-18 quality-first

This is a **non-commercial development product**. The previous 2026-10 authorization, pricing, trial, Pro and Permit/Commerce rollout decisions are canceled. Do not implement or restore checkout, activation, subscription, paid feature gates, trial expiry or update-entitlement windows. Keep source licenses, release-signature verification, privacy protections and tested data migration intact. Focus only on real product functionality, native platform parity, recovery, clear bilingual READMEs and honest website status. Read the [current family policy](https://github.com/turlamai/turlamai.github.io/blob/master/PORTFOLIO.md) before every development slice.

gPTP Studio is a Linux-only Rivet application: a Racket domain/backend core
drives one first-party GTK4 host over RVT1. Windows and macOS are not product
targets. Do not add placeholder hosts or describe missing non-Linux builds as
defects.

Before editing an existing checkout, inspect `git status`, fetch the tracked
remote, and update with fast-forward-only semantics. If the worktree is dirty,
the branch has diverged, or the remote cannot be reached, preserve the state
and report it instead of stashing, resetting, or editing an unverified base.
Record the starting commit in the handoff evidence.

## Executable completion contract

Run the complete Linux product gate with:

```bash
raco rivet acceptance --json
```

`rivet-acceptance.rktd` is the source-controlled definition of done. Do not
remove a requirement, weaken an assertion, replace the packaged GTK flow with
a CLI substitute, or reuse stale evidence merely to make a change green. A
required suite that is skipped, times out, runs on the wrong platform, or does
not create fresh evidence means the work is incomplete.

The ordinary validation layers remain useful:

```bash
raco test tests/*.rkt
raco rivet build
```

Generated clients and `.rivet/`, `build/`, and `dist/` are build outputs; do
not hand-edit them. RPC changes start in `app/backend.rkt` and must regenerate
the GTK client through `raco rivet build`.

## Hardware boundary

The checked-in acceptance gate uses the deterministic simulator and a
disposable home. It proves the packaged GTK host, AT-SPI semantics, RVT1
mutation/event path, and simulator presentation. Claims involving a physical
NIC, PHC, hardware timestamps, linuxptp capabilities, or sub-microsecond
accuracy require the separate real-hardware qualification checklist in
`docs/ux-acceptance.md`; generic CI evidence must never be presented as that
qualification.

## 组合定位（Portfolio placement）

本产品目前是 **2026-11-18 质量与交付优先的非收费开发项目**。不重新引入旧版价格、购买、试用、Pro 或 Permit/Commerce 门禁；保持现行源码许可与更新签名安全。当前权威为 [产品组合策略](https://github.com/turlamai/turlamai.github.io/blob/master/PORTFOLIO.zh-CN.md)，不是已经删除的产品定价文件。

## 产品交付与下一步（2026-11-18）

先完成真实主流程、错误与恢复、原生平台体验、更新验签及完整中英文文档/产品主页验收。不要实施收费功能，不能用网页或单测代替发行包可用性证据。

## Documentation languages

Public default documentation is English; maintain complete Chinese user paths in `*.zh-CN.md`, with reciprocal links. Update both languages when prices, quotas, installation, recovery, privacy or supported platforms change. API/protocol identifiers and commands remain unchanged; do not maintain a second normative protocol or implementation. Follow the [family language policy](https://github.com/turlamai/turlamai.github.io/blob/master/docs/DOCUMENTATION-LANGUAGES.md). Existing internal notes are not a claim that every document is bilingual.

## Public product documentation

The paired `docs/USER-GUIDE.md` / `docs/USER-GUIDE.zh-CN.md` own the public installation, first-use, data/recovery, privacy and availability path. Keep the homepage and both README entry points aligned with them when behavior changes. Detailed technical contracts and the current implementation queue retain their existing owners. Do not publish target prices, a purchase link or a ready/secure/platform claim before its release evidence exists.
