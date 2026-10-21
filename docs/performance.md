# 性能验证

## 可复现命令

```sh
swift run -c release SwiftKLineBenchmark
swift run -c release SwiftKLineBenchmark 100000
swift test
```

`Benchmarks/main.swift` 同时保留原来的窗口遍历算法和新的滚动算法。两者在相同数据上计算，取 5 次耗时的中位数并输出末值 checksum，避免只测空循环或只测不同工作量。

2026-10-21，本机 Apple Silicon、Swift 6.2.3、Release，20,000 根蜡烛、周期 200：

| 计算 | 原窗口实现 | 当前实现 |
| --- | ---: | ---: |
| WMA 全量 | 25.125 ms | 0.103 ms |
| BOLL 全量 | 181.515 ms | 0.373 ms |
| WMA 单尾更新，包含输出数组复制 | — | 0.007 ms |

同环境 100,000 根、周期 200 的复测：WMA 126.834 → 0.703 ms，BOLL 1385.146 → 2.074 ms，WMA 单尾更新（含复制）0.142 ms。大样本尾部时间也体现了数组复制的成本。

WMA 和 BOLL 的前后 checksum 分别一致。具体数值依赖机器、优化器和负载，仅作为这组数据的计算微基准。没有测量真机帧率、GPU、总内存峰值或网络吞吐，因此不能由这些数字推出 UI 帧率提高的倍数。

## 算法范围

| 路径 | 计算成本 | 说明 |
| --- | --- | --- |
| 有序历史合并 | O(n + m) | 无序输入额外排序；重复时间戳不会崩溃 |
| 实时尾部定位 | O(1) 比较 | 数组写入可能触发 CoW |
| 中间 tick 定位 | O(log n) 比较 | 数组中间插入移动仍为 O(n) |
| MA / WMA / BOLL 全量 | O(n) | BOLL 每周期重建统计量以限制误差 |
| MA / WMA / BOLL 后缀 | O(period + changedCount) | 不含结果数组复制 |
| EMA / VOL 后缀 | O(changedCount) | 不含结果数组复制 |
| RSI / MACD / SAR | O(n) | 目前全量回退；MACD 使用常量额外工作状态 |
| 普通绘制 | O(visibleCount × seriesCount) | 数据刷新不创建新 descriptor |

内存中保留原始数据、当前渲染快照、指标输出和正在计算的任务快照。它们通常共享 Array 存储，但更新时可能复制。该设计优先保证一致性和插件兼容，未宣称整个实时管线达到 O(1)。

## 正确性保障

- 滚动 WMA / BOLL 与独立窗口公式比较，覆盖周期 1、2、5、20、100、240。
- 大价格小价差的 BOLL 验证，避免使用 `E[x²] - E[x]²` 的严重消减误差。
- 多次尾部修改、追加和历史中间修订：局部重算与全量计算逐项对比。
- 计数模型记录 close 访问次数，验证 WMA / BOLL 访问量随输入长度线性增长；单尾 WMA 更新只读取一个窗口。
- 模拟器测试验证连续 tick 后结果、renderer 实例复用、分时图中间修订和旧任务结果失效。

后续可用 Time Profiler、Allocations 和真机交互录制进一步衡量 UI 热点；本轮未添加每根蜡烛一个 UIView 或每帧重建的图层。
