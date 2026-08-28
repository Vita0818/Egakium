# NEXT_TARGET

文档状态：当前无获准的下一业务目标
最近核对：2026-08-28
产品基线：v0.4（build 50）

Intatis Runtime 直接接入、Egakium shared snapshot 删除以及本地 Debug build/test/bundle validation 已完成。
当前没有用户明确授权的下一项产品功能、UI 改造、Canvas durable schema、CEF 升级或发行工作。

下列事项是 release/后续验证缺口，不自动构成实施授权：

- 将当前所需 Intatis dirty working-tree changes 收敛为 clean、可审计 revision；
- 在 clean revision 与 clean machine 上重跑 dependency/runtime/license gates；
- 真实 provider Code/Cowork 与完整手工 UI/Canvas E2E；
- Developer ID signing、notarization、staple、Gatekeeper、DMG/ZIP release；
- durable Canvas Element/layout/event/native bridge；
- Intatis/CEF/runtime version 或 architecture 升级。

开始其中任何一项前，必须获得 exact scope 的新指令；不得自行增加 fallback、兼容层、第二 runtime、
renderer 或历史 snapshot。
