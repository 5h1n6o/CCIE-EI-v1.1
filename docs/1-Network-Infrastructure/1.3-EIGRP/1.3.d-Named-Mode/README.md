---
layout: default
title: 1.3.d-Named-Mode
parent: 1.3-EIGRP
grand_parent: 1-Network-Infrastructure
nav_order: 1
---

# 1.3.d-Named-Mode

## 📘 概要
Named Mode は Classic Mode の課題を解消し、  
階層構造（Address-Family / Interface / Topology）で  
設定の一元管理と Wide Metrics を提供します。

## 🔑 要点
- Classic → Named の進化（階層構造）
- Address-Family（IPv4/IPv6）
- af-interface（Hello/Hold/認証）
- topology base（Active Timer / Variance / Redistribution）
- Wide Metrics（K6）
- 認証（MD5 / SHA256）

## 📘 EIGRP Classic vs Named Mode ― 完全比較表

### 🧩 全体構造の違い

| 項目 | Classic Mode | Named Mode |
|------|--------------|------------|
| 導入目的 | 旧来の EIGRP。設定が分散しやすい | Classic の課題を解消。設定を階層化 |
| 設定場所 | router eigrp と各インターフェイスに分散 | router eigrp → address-family → af-interface → topology |
| 可読性 | 低い | 高い（設定が一元化） |
| VRF対応 | 非対応 | 対応（address-family vrf） |

---

### 🔧 設定コマンド体系

| 項目 | Classic Mode | Named Mode |
|------|--------------|------------|
| プロセス開始 | `router eigrp <ASN>` | `router eigrp <name>` |
| ASN指定 | `router eigrp 100` | `address-family ipv4 unicast autonomous-system 100` |
| ネットワーク有効化 | `network <ip> <wildcard>` | address-family 内で network |
| インターフェイス固有設定 | インターフェイス下で設定 | `af-interface <id>` または `af-interface default` |
| topology設定 | なし | `topology base`（AD、redistribute、max-paths、variance など） |

---

### 🔐 認証（Authentication）

| 項目 | Classic Mode | Named Mode |
|------|--------------|------------|
| 方式 | MD5 のみ | MD5 / HMAC-SHA-256 |
| 設定場所 | インターフェイス下 | af-interface 下 |
| コマンド例 | `ip authentication mode eigrp 100 md5` | `authentication mode md5` / `authentication mode hmac-sha-256 password` |

---

### 📡 Passive Interface

| 項目 | Classic Mode | Named Mode |
|------|--------------|------------|
| 設定場所 | `passive-interface` | `af-interface default` または `af-interface <id>` |
| 動作 | Hello を送受信しないが connected は広告 | 同じ |

---

### 📏 Metric（Classic vs Wide）

| 項目 | Classic Mode | Named Mode |
|------|--------------|------------|
| 使用メトリック | Classic metric（BW/Delay） | Wide metric（Latency＝ps、K6追加） |
| K値 | K1〜K5 | K1〜K6 |
| 高帯域リンクの精度 | 10Gbps 以上は差が出ない | 655 Tbps まで精密に扱える |
| 互換性 | Classic 同士のみ | Classic と adjacency 可能（K6=0） |

---

### 🔍 show コマンドの違い

| 項目 | Classic Mode | Named Mode |
|------|--------------|------------|
| show run | router eigrp の下に network が並ぶ | 階層構造で表示 |
| show ip protocols | K1〜K5 | K1〜K6（wide metric） |

---

### 🚦 運用・トラブルシューティング

| 項目 | Classic Mode | Named Mode |
|------|--------------|------------|
| 設定の散らばり | 多い | 少ない |
| 大規模ネットワーク向け | 不向き | 向いている（VRF、階層、wide metric） |
| 試験での問われ方 | Classic の network/passive/auth が頻出 | Named の階層構造と wide metric が頻出 |

---


## 🎯 試験対策
- Classic の network / passive / auth はコマンド暗記必須  
- Named は階層構造（address-family → af-interface → topology）を「3階建て」として覚える  
- 設定が Classic か Named かを読み取る問題が多い
- Classic と Named の混在はメトリック不一致の原因

## 🛠 設定例
```text
router eigrp EIGRP-NAMED
 address-family ipv4 unicast autonomous-system 100
  af-interface default
   hello-interval 3
   hold-time 15
  topology base
   timers active-time 2
```

## 📝 補足
- 補足情報をここに追加してください。

