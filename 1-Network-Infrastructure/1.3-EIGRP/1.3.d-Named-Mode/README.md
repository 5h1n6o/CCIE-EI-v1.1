# 1.3.d-Named-Mode

## 概要
Named Mode は Classic Mode の課題を解消し、  
階層構造（Address-Family / Interface / Topology）で  
設定の一元管理と Wide Metrics を提供します。

## 要点
- Classic → Named の進化（階層構造）
- Address-Family（IPv4/IPv6）
- af-interface（Hello/Hold/認証）
- topology base（Active Timer / Variance / Redistribution）
- Wide Metrics（K6）
- 認証（MD5 / SHA256）

## 試験対策
- Named Mode の階層構造は暗記レベル
- Wide Metrics は Named Mode のみ
- Classic と Named の混在はメトリック不一致の原因

## 設定例
```text
router eigrp EIGRP-NAMED
 address-family ipv4 unicast autonomous-system 100
  af-interface default
   hello-interval 3
   hold-time 15
  topology base
   timers active-time 2
