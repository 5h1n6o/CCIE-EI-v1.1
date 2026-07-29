# 1.3.c-Operations

## 概要
EIGRP の動作は DUAL によるループフリーな経路選択、  
パケット交換、トポロジーテーブル管理、収束プロセスによって構成されます。

## 要点
- 5 種類のパケット（Hello / Update / Query / Reply / ACK）
- トポロジーテーブルに FD/RD を保持
- Successor / FS の選出
- Active 状態 → Query → Reply → Passive
- Query Boundary による収束高速化
- RTP による信頼性制御（Update/Query/Reply は ACK 必須）

## 試験対策
- Active 状態の流れ（最重要）
- Query は Delay=Infinity
- show ip eigrp topology active の読み解き
- SIA（90秒 / 180秒）のタイミング

## 設定例
```text
router eigrp 100
 timers active-time 2
