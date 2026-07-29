# 1.3.a-Adjacencies

# 1.3.a EIGRP Adjacencies

## 概要
EIGRP の隣接形成は Hello パケットを基盤として行われ、  
AS 番号・K値・サブネット・認証・MTU が一致している必要があります。  
隣接形成が正しく行われることで、DUAL によるループフリーな経路選択が可能になります。

## 要点
- Hello / Hold Timer（高速リンク 5/15秒、低速リンク 60/180秒）
- 隣接形成条件：AS / K値 / サブネット / 認証 / MTU
- Hello はマルチキャスト 224.0.0.10（IPv4）/ FF02::A（IPv6）
- 認証（MD5 / SHA）不一致は隣接形成不可
- Passive Interface は隣接形成しないが prefix は広告される
- IPv6 はリンクローカルアドレスで隣接形成

## 試験対策
- MTU 不一致は隣接形成不可（頻出）
- Hello < Hold が隣接維持の条件
- IPv6 は network コマンドを使わずインターフェース単位で有効化
- Router-ID 未設定は EIGRPv6 の隣接形成不可

## 設定例
```text
interface Gi0/1
 ip hello-interval eigrp 100 3
 ip hold-time eigrp 100 15

