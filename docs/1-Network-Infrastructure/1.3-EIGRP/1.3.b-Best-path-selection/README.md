---
layout: default
title: 1.3.b-Best-path-selection
parent: 1.3-EIGRP
grand_parent: 1-Network-Infrastructure
nav_order: 1
---

# 1.3.b-Best-path-selection

## 📘 概要
EIGRP の経路選択は DUAL によって行われ、  
帯域幅と遅延を中心としたメトリック計算に基づいて  
Successor（最適経路）と Feasible Successor（バックアップ経路）が選出されます。

## 🔑 要点
- メトリック：帯域幅（最小リンク速度）＋遅延（合計）
- Classic Metrics（256 スケール）と Wide Metrics（65536 スケール）
- K値（K1=BW, K3=Delay）
- Feasibility Condition（RD < FD）
- Successor / Feasible Successor（FS）
- Variance による不等コスト負荷分散

## 🎯 試験対策
- Feasibility Condition は暗記レベル
- Wide Metrics は高速リンクで精度向上（Named Mode）
- Classic と Wide の混在は危険（経路選択が狂う）
- Variance の計算式（FD_FS / FD_Successor）

## 🛠 設定例
```text
router eigrp 100
 variance 2

```

## 📝 補足
- 補足情報をここに追加してください。

