# BreakEven Framework

来源：

- MQL5 Article: <https://www.mql5.com/en/articles/18111>
- Title: Implementing a Breakeven Mechanism in MQL5 (Part 2): ATR- and RRR-Based Breakeven

定位：

```text
Trade Management / BreakEven Plugin Framework 收藏样例，不是重点交易策略。
```

## 导入范围

本目录从 `MQL5.zip` 中导入源码和测试配置：

- `Experts/Order Block EA MT5.mq5`
- `Include/PositionManagement.mqh`
- `Include/Risk_Management.mqh`
- `Indicators/Order_Block_Indicador_New_Part_2.mq5`
- `Profiles/Tester/*.set`

未导入 `.ex5` 编译产物。

## 核心学习点

真正值得看的是：

```text
Include/PositionManagement.mqh
```

重点模块：

- `CBreakEvenBase` — 抽象基类；
- `CBreakEvenSimple` — 固定点数保本；
- `CBreakEvenAtr` — ATR 倍数保本；
- `CBreakEvenRR` — RRR 保本；
- `CBreakEven` — Manager / Factory / 参数保存；
- `MqlParam[]` — 统一参数配置；
- `position_be` — ticket 级保本状态缓存。

## 架构价值

```text
CBreakEvenBase
        ▲
        │
 ┌──────┼────────┐
 │      │        │
Simple ATR      RRR
        │
        ▼
CBreakEven Manager
```

这套结构适合迁移到：

- Trailing Stop；
- Partial Close；
- Time Exit；
- Stop Loss Engine；
- Risk Guard；
- Position Protection。

## 不建议直接复用的部分

- ATR / RRR 公式本身属于常规实现；
- `ExpertRemove()` 处理参数错误较强硬；
- EA 示例仍绑定 Order Block 策略；
- Manager 暴露内部 `obj` 指针，长期框架建议改成 `Run()` 封装。

推荐用途：

```text
作为 MQL5 Trade Management 插件架构参考。
```
