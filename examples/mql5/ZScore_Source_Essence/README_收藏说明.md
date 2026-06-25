# ZScore 源码精华收藏版

保留的设计：

1. SignalEngineBase.mqh
   - 抽象信号接口
   - 以后 RSI、ATR、Entropy、Hurst 都可以继承同一接口

2. ZScoreEngine_Essence.mqh
   - Z-Score 计算引擎
   - 与 EA / Indicator 解耦
   - 默认使用 shift=1，只基于已完成K线
   - 检查 Bars、CopyClose、StdDev=0

3. OncePerBar.mqh
   - EA 每根新K线只执行一次
   - 避免 OnTick 高频重复计算

4. EA_ZScore_Template.mq5
   - 最小EA模板
   - 负责交易，不负责数学计算

5. Ind_ZScore_Template.mq5
   - 最小指标模板
   - 与EA复用同一套计算引擎

建议继续升级：

- 把手工 Mean / StdDev 改成 iMA + iStdDev handle
- 增加 Rolling Cache，避免每次 CopyClose
- 增加 RiskEngine，不要固定手数
- Hedging账户下改用 ticket loop 管理持仓
- 把 CZScoreEngine 扩展成 FeatureEngine 框架
