---
layout: default
title: 1.3.e-Optimization
parent: 1.3-EIGRP
grand_parent: 1-Network-Infrastructure
nav_order: 1
---

# 1.3.e-Optimization

## 📘 概要
EIGRP の最適化では、収束高速化、SIA 防止、サマリ、Stub、Stub-Site、  
Split Horizon、フィルタリング、Offset List などを用いて  
大規模ネットワークの安定性と効率を向上させます。

## 🔑 要点
- Failure Detection（Hello/Hold）
- Convergence（FS → Successor）
- Active 状態と Query Boundary
- SIA（90秒 / 180秒）
- サマリ（Null0, summary-metric）
- Stub / Stub-Site
- Split Horizon（DMVPN）
- Route Filtering（ACL / Prefix / Route-map）
- Offset List（Delay 操作）

## 🎯 試験対策
- SIA のタイミングは暗記レベル
- Stub と Stub-Site の違い（Named Mode 限定）
- Split Horizon の有効/無効化（DMVPN）
- サマリ Null0（AD=5）はブラックホールの原因

## 🛠 設定例
```text
interface Gi0/4
 ip summary-address eigrp 100 172.16.0.0 255.255.0.0
!
router eigrp 100
 eigrp stub connected summary

```

## 📝 補足
- 補足情報をここに追加してください。

