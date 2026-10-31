---
layout: default
title: 5.3.b-DNAC-API
parent: 5.3-Programmability
grand_parent: 5-Infrastructure-Automation-and-Programmability
nav_order: 2
---

# 5.3.b Interaction with Cisco DNA Center API using HTTP requests (GET, PUT, POST) via Python requests library and Postman

---

## 📘 概要

Cisco DNA Center（現 Catalyst Center）Intent API は、エンタープライズ ネットワーク ファブリック（SD-Access）および従来型 Cisco IOS XE / Catalyst ネットワークインフラに対する自動化、情報取得、ポリシー配置、およびモニタリングを RESTful HTTP インターフェイス経由で実現するプログラマビリティ基盤である。

CCIE Enterprise Infrastructure v1.1 Blueprint において、**5.3.b Interaction with Cisco DNA Center API using HTTP requests (GET, PUT, POST) via Python requests library and Postman** は、ネットワーク自動化エンジニアが外部スクリプト（Python `requests`）や API 開発環境（Postman）を用いて、Catalyst Center に対する認証、ネットワークインベントリ取得（GET）、サイトや構成の作成・変更（POST/PUT）、および非同期タスク処理（Task API）を正確にコントロールするスキルを検証する核心項目である。

### 主な利用目的と適用シーン

1. **トークンベース認証の自動化 (Authentication)**
   HTTP Basic 認証（`/dna/system/api/v1/auth/token`）を用いて短命な認証トークン（Token）を取得し、以降のリクエストヘッダー `X-Auth-Token` に透過的にバインドしてセッションを管理する。

2. **ネットワーク情報・ヘルスの視覚的可視化 (GET API)**
   Catalyst Center に管理されている全スイッチ、ルータ、AP、WLC のインベントリ、シリアル番号、IP アドレス、IOS XE バージョン、クライアントヘルス、トポロジーマップを自動収集・解析する。

3. **意図ベースの構成配置とサイト管理 (POST / PUT API)**
   エリア・ビル・フロア等の階層型サイト構造の動的作成、Network Profile の割り当て、CLI テンプレート（Template Programmer）の適用、ならびにデバイス属性の更新を実施する。

4. **非同期タスクの実行とポーリング (Task API)**
   POST/PUT リクエストの多くが非同期処理（`HTTP 202 Accepted`）として即座に `taskId` を返却するアーキテクチャを理解し、Task API エンドポイント（`/dna/intent/api/v1/task/{taskId}`）を自動ポーリングして完了状態（`SUCCESS` / `FAILURE`）を確定させる。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **対象プロトコル / トランスポート** | HTTPS (HTTP/1.1 over TLS 1.2/1.3, TCP Port 443) |
| **データエンコーディング** | JSON (`application/json`) |
| **主要認証方式** | HTTP Basic Auth ➔ `Token` 発行 ➔ Header `X-Auth-Token: <token>` |
| **トークン有効期限** | デフォルト **1 時間 (60分)**（有効期限切れ時は `HTTP 401 Unauthorized`） |
| **主要 HTTP メソッド** | `GET` (取得), `POST` (新規作成/認証/リクエスト送信), `PUT` (更新/置換), `DELETE` (削除) |
| **非同期レスポンス形式** | `HTTP 202 Accepted` + レスポンス Body 内の `taskId` 及び `url` |
| **推奨 Python ライブラリ** | `requests`, `urllib3` (`disable_warnings`), `json`, `time` |
| **制限事項・注意点** | セルフサイン証明書による `SSLError` 回避 (`verify=False`), 非同期処理完了待ち (Polling) 必須 |

---

## 🏗 動作原理

Cisco DNA Center Intent API との対話は、**「認証フェーズ」**、**「同期 / 非同期 API 実行フェーズ」**、および **「非同期タスク完了追跡フェーズ」** の 3 つのステップから構成される。

```
[ External Client / Python / Postman ]
        │
        │ 1. POST /dna/system/api/v1/auth/token
        │    Header: Authorization: Basic <Base64(user:pass)>
        ▼
┌────────────────────────────────────────────────────────┐
│ Cisco DNA Center (Catalyst Center)                     │
│ └─ Authenticates User via AAA / Local DB               │
└────────────────────────────────────────────────────────┘
        │
        │ 2. Return HTTP 200 OK
        │    Body: { "Token": "eyJhbGciOi..." }
        ▼
[ Store Token in Variable / Header ]
        │
        │ 3. GET/POST/PUT /dna/intent/api/v1/...
        │    Header: X-Auth-Token: eyJhbGciOi...
        │    Header: Content-Type: application/json
        ▼
┌────────────────────────────────────────────────────────┐
│ Cisco DNA Center API Gateway / Intent Engine           │
│ ├─ GET: Direct Synchronous Response (HTTP 200 OK)       │
│ └─ POST/PUT: Asynchronous Task Created (HTTP 202)     │
└────────────────────────────────────────────────────────┘
        │
        │ 4. If Asynchronous: Return Body { "response": { "taskId": "xxx-yyy" } }
        ▼
[ Poll Task Status Loop ]
        │
        │ 5. GET /dna/intent/api/v1/task/{taskId}
        │    Header: X-Auth-Token: eyJhbGciOi...
        ▼
┌────────────────────────────────────────────────────────┐
│ Task Execution Engine                                  │
│ └─ Check Status (progress: "SUCCESS" / isError: false) │
└────────────────────────────────────────────────────────┘
```

---

## ⚙ 動作シーケンス

1. **認証トークン要求 (Authentication Request):**
   * クライアントは POST `/dna/system/api/v1/auth/token` へリクエストを送信する。
   * ヘッダーに `Authorization: Basic Base64(username:password)` を付与する。
   * レスポンス JSON の `"Token"` キーから長文の JWT スタイルトークン文字列を抽出する。

2. **API リクエスト実行 (API Request Execution):**
   * 以降のすべての Intent API リクエストにおいて、HTTP Header に **`X-Auth-Token: <Token>`** および **`Content-Type: application/json`**（POST/PUT の場合）をセットする。

3. **同期処理 (Synchronous API Execution):**
   * デバイス一覧取得（`GET /dna/intent/api/v1/network-device`）等の参照系リクエストは、即座に `HTTP 200 OK` とデータ本体の JSON 配列が返却される。

4. **非同期処理およびタスク生成 (Asynchronous Task Creation):**
   * サイト作成やテンプレート配置等の書き込み系リクエスト（POST/PUT/DELETE）は、即座に `HTTP 202 Accepted` を返却する。
   * レスポンス JSON には `"taskId"`（例: `"a1b2c3d4-5678-90ab-cdef-1234567890ab"`）が含まれる。

5. **タスク結果の追跡 (Task Polling Loop):**
   * クライアントは一定間隔（例: 2〜5秒）で `GET /dna/intent/api/v1/task/{taskId}` を繰り返し実行する。
   * レスポンス内の `"isError": false` かつ `"progress"` または `"endTime"` の値を確認し、処理完了（`SUCCESS`）または失敗（`FAILURE`）を検出する。


## 🎯 試験対策（CCIEラボ試験）

CCIE Enterprise Infrastructure v1.1 ラボ試験において、Cisco DNA Center API のプログラマビリティ課題が出題された場合、短時間かつ確実に得点するために以下のポイントを完全にマスターしておく必要がある。

### Blueprintで重要なポイント

1. **二段階認証プロセスの完全理解**
   * `/dna/system/api/v1/auth/token` に対する Basic 認証 POST 送信。
   * 返却された Token を変数に保持し、`X-Auth-Token` ヘッダーにセットする手順。

2. **JSON Payload の正確なパースと構築**
   * `GET /dna/intent/api/v1/network-device` から特定デバイスの `id`, `managementIpAddress`, `platformId` を抽出する処理。
   * 抽出した `id` を後続の API URL（例: `/dna/intent/api/v1/interface/network-device/{device_id}`）に埋め込んで呼び出す連鎖リクエスト（Chained API Requests）。

3. **Task API による非同期処理のポーリング実装**
   * POST/PUT リクエスト後に返却される `taskId` を抽出し、`while` ループと `time.sleep()` を用いてタスク完了を待機するロジックを自力でコード化できること。

4. **Postman での環境変数（Environment Variables）と自動化スクリプト**
   * Postman の **Pre-request Script** または **Tests** タブで、`pm.environment.set("dna_token", responseData.Token);` を記述し、コレクション全体で `{{dna_token}}` を利用可能にする設定。

---

## 🛠 設定方法

### 1. Postman での認証および環境変数自動セット

Postman を用いて Catalyst Center API と対話する場合、コレクションの Tests スクリプトでトークンを自動抽出し、環境変数 `dna_token` に保存するのが標準的な手法である。

#### 【トークン取得リクエスト設定】
* **Method:** `POST`
* **URL:** `https://{{dnac_host}}/dna/system/api/v1/auth/token`
* **Authorization:** `Basic Auth` (Username: `admin`, Password: `<password>`)
* **Headers:** `Content-Type: application/json`

#### 【Postman Tests スクリプト (JavaScript)】
```javascript
// レスポンス JSON のパース
var responseData = pm.response.json();

// Token を環境変数 "dna_token" に保存
if (responseData.Token) {
    pm.environment.set("dna_token", responseData.Token);
    console.log("DNA Center Token successfully saved to environment: " + responseData.Token);
} else {
    console.error("Failed to retrieve Token from response.");
}
```

#### 【後続リクエスト（GET/POST）の共通設定】
* **Headers:**
  * `X-Auth-Token`: `{{dna_token}}`
  * `Content-Type`: `application/json`

---

### 2. Python `requests` による認証 ＆ セッション管理基本コード

```python
import requests
import json
import urllib3

# 証明書検証警告の抑制
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# DNAC 接続情報
DNAC_HOST = "10.1.1.100"
DNAC_USER = "admin"
DNAC_PASS = "Cisco123!"

class DNACenterAPI:
    def __init__(self, host, username, password):
        self.base_url = f"https://{host}"
        self.username = username
        self.password = password
        self.session = requests.Session()
        self.session.verify = False  # 自己署名証明書無効化
        self.token = None

    def get_token(self):
        url = f"{self.base_url}/dna/system/api/v1/auth/token"
        try:
            response = self.session.post(
                url,
                auth=(self.username, self.password),
                headers={"Content-Type": "application/json"}
            )
            response.raise_for_status()
            token_data = response.json()
            self.token = token_data.get("Token")
            # 以降のリクエスト用に X-Auth-Token をセッションヘッダーにセット
            self.session.headers.update({
                "X-Auth-Token": self.token,
                "Content-Type": "application/json"
            })
            print(f"[+] Token successfully retrieved: {self.token[:15]}...")
            return self.token
        except requests.exceptions.RequestException as e:
            print(f"[-] Authentication Failed: {e}")
            raise

    def get_network_devices(self):
        url = f"{self.base_url}/dna/intent/api/v1/network-device"
        response = self.session.get(url)
        response.raise_for_status()
        return response.json().get("response", [])

if __name__ == "__main__":
    dnac = DNACenterAPI(DNAC_HOST, DNAC_USER, DNAC_PASS)
    dnac.get_token()
    devices = dnac.get_network_devices()
    for dev in devices:
        print(f"Device: {dev.get('hostname')} | IP: {dev.get('managementIpAddress')} | Platform: {dev.get('platformId')}")
```

---

## 🔍 検証コマンド

### HTTP レスポンスコード ＆ 検証コマンド一覧

| 目的 | HTTP メソッド / コマンド | 期待されるステータス |
| :--- | :--- | :--- |
| **認証トークン取得** | `POST /dna/system/api/v1/auth/token` | `200 OK` (JSON 内に `"Token"` 保持) |
| **デバイス一覧取得** | `GET /dna/intent/api/v1/network-device` | `200 OK` (JSON 内の `"response"` 配列) |
| **特定デバイスインターフェイス取得** | `GET /dna/intent/api/v1/interface/network-device/{id}` | `200 OK` |
| **サイト構造作成 (新規)** | `POST /dna/intent/api/v1/site` | `202 Accepted` (JSON 内に `"taskId"`) |
| **タスク状態確認 (Polling)** | `GET /dna/intent/api/v1/task/{taskId}` | `200 OK` (`"progress": "SUCCESS"`) |
| **cURL 認証動作確認** | <code>curl -k -X POST -u admin:pass https://.../auth/token</code> | `200 OK` |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド / ログ | 対処方法 |
| :--- | :--- | :--- | :--- |
| **`401 Unauthorized`** | 1. 認証パスワード間違い<br>2. トークン有効期限（1時間）切れ<br>3. ヘッダー `X-Auth-Token` 命名ミス | `print(response.status_code)`<br>`print(response.text)` | ・`/auth/token` でトークン再取得<br>・ヘッダー名が `X-Auth-Token` であるか確認 |
| **`400 Bad Request`** | JSON Payload の構文ミス、または必須フィールドの欠落 | `print(response.json())` | API リファレンスを参照し Payload JSON の型・必須属性を確認 |
| **`422 Unprocessable Entity`** | 送信パラメータの論理エラー（既存サイト名の重複登録等） | `response.json()["message"]` | 既存リソースの有無を確認し、重複しないパラメータを指定 |
| **`SSLError / CertificateVerifyFailed`** | 自己署名証明書の検証失敗 | Python traceback | `requests.get(..., verify=False)` または `session.verify = False` |
| **`Task Failed (isError: true)`** | 非同期タスク実行中の Catalyst Center 内部エラー | `GET /dna/intent/api/v1/task/{taskId}` | 返却された `"failureReason"` フィールドを読み取り原因特定 |

---

## ⚠ 制限事項

1. **トークンの有効期限 (Token Expiration)**
   Catalyst Center の認証トークンは発行から **1 時間 (60分)** で無効化される。長時間実行されるバッチ処理スクリプトでは、定期的なトークン再取得（リフレッシュ）ロジックを実装する必要がある。

2. **レート制限 (API Rate Limiting)**
   Catalyst Center は過剰な API リクエストに対して `HTTP 429 Too Many Requests` を返却する場合がある。スクリプト側で `time.sleep()` を挟む等のリクエスト間隔調整が推奨される。

3. **バージョン間の API エンドポイント変更**
   Catalyst Center 2.2.x ➔ 2.3.x ➔ 3.x へのバージョンアップに伴い、一部のレガシーエンドポイント（例: `/dna/intent/api/v1/topology/...`）が推奨非表示（Deprecated）となり、新しいエンドポイントに置き換わる場合がある。

---

## 🔄 他技術との関連

* **Python `requests` & `json`:** API レスポンスのパース、辞書オブジェクト処理、Jinja2 テンプレート連動。
* **Cisco SD-Access (SDA):** Fabric 構成、Host Onboarding、Virtual Network (VN) 割り当て、Scalable Group Tag (SGT) の割り当てを Catalyst Center API 経由でプログラマブルに制御。
* **Ansible (`cisco.dnac` コレクション):** Catalyst Center API を抽象化した Ansible モジュール群による Infrastructure as Code (IaC) 実装。

---

## 🧩 比較表

| 項目 | Cisco DNA Center (Catalyst Center) Intent API | Cisco SD-WAN vManage REST API |
| :--- | :--- | :--- |
| **主要認証方式** | HTTP Basic ➔ `X-Auth-Token` ヘッダー | POST `/j_security_check` (Cookie) ➔ GET `/dataservice/client/token` (`X-XSRF-TOKEN`) |
| **トークン保持形式** | HTTP Header (`X-Auth-Token: <token>`) | Header (`X-XSRF-TOKEN`) + Cookie (`JSESSIONID`) の両方 |
| **非同期タスク管理** | `GET /dna/intent/api/v1/task/{taskId}` | `GET /dataservice/device/action/status/{taskId}` |
| **標準データ形式** | JSON (`application/json`) | JSON (`application/json`) |

---

## 💡 ベストプラクティス

1. **`requests.Session()` の徹底活用**
   リクエストごとに HTTP 接続を再確立するのではなく、`Session` オブジェクトを使い回すことで TLS ハンドシェイクのオーバーヘッドを削減し、ヘッダー（`X-Auth-Token`）を一元管理する。

2. **堅牢な Task Polling 関数コンポーネント化**
   非同期処理のタスク追跡を行う専用関数を作成し、最大タイムアウト（Timeout）と試行回数を設定して無限ループを防止する。

3. **例外処理 (`try-except-raise_for_status`) の実装**
   ネットワーク障害や API エラー発生時にスクリプトがクラッシュしないよう、`response.raise_for_status()` と `HTTPError` のキャッチを明示的に行う。


## 📝 ラボ学習・設定サンプル例

### ラボ 1: 認証トークン取得 ＆ セッション管理実装

#### 【問題】
Python `requests` ライブラリを用いて Catalyst Center への認証を行い、トークンを取得してセッションを初期化せよ。

#### 【要件】
1. `/dna/system/api/v1/auth/token` へ Basic 認証で POST 送信する。
2. 取得した `Token` をセッションのデフォルトヘッダー `X-Auth-Token` にセットする。
3. セルフサイン証明書エラーを無視する設定（`verify=False`）を入れる。

#### 【設定例】
```python
import requests
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

def create_dnac_session(host, username, password):
    session = requests.Session()
    session.verify = False
    
    url = f"https://{host}/dna/system/api/v1/auth/token"
    response = session.post(
        url,
        auth=(username, password),
        headers={"Content-Type": "application/json"}
    )
    response.raise_for_status()
    
    token = response.json().get("Token")
    session.headers.update({
        "X-Auth-Token": token,
        "Content-Type": "application/json"
    })
    print(f"[SUCCESS] Authenticated to {host}. Token: {token[:20]}...")
    return session

if __name__ == "__main__":
    sess = create_dnac_session("10.1.1.100", "admin", "my_password")
```

#### 【検証方法】
スクリプトを実行し、`[SUCCESS]` メッセージとトークン文字列が出力されることを確認する。


### ラボ 2: ネットワーク機器一覧取得と条件抽出

#### 【問題】
Catalyst Center から機器情報を取得し、指定の型番（例: C9300）かつ到達可能な機器を抽出せよ。

#### 【要件】
1. エンドポイント `GET /dna/intent/api/v1/network-device` を呼び出す。
2. レスポンス内の `"response"` リストをループ処理する。
3. `platformId` および `reachabilityStatus` フィールドで条件判定を行う。

#### 【設定例】
```python
def filter_network_devices(session, base_url, target_platform="C9300"):
    url = f"{base_url}/dna/intent/api/v1/network-device"
    res = session.get(url)
    res.raise_for_status()
    
    device_list = res.json().get("response", [])
    matched = []
    
    for device in device_list:
        p_id = device.get("platformId", "")
        status = device.get("reachabilityStatus", "")
        if p_id.startswith(target_platform) and status == "Reachable":
            matched.append({
                "hostname": device.get("hostname"),
                "mgmt_ip": device.get("managementIpAddress")
            })
            
    return matched

if __name__ == "__main__":
    # session は事前認証済みオブジェクトを使用
    devices = filter_network_devices(sess, "https://dnac.example.com")
    for dev in devices:
        print(f"Device: {dev['hostname']} ({dev['mgmt_ip']})")
```

#### 【検証方法】
条件に一致した機器のみがリストアップされることを確認する。

---

### ラボ 3: 連鎖リクエスト (Chained Requests) - デバイス ID からのポート状態取得

#### 【問題】
特定ホスト名の機器 ID を取得し、その機器のインターフェイス一覧から admin 状態が UP で oper 状態が DOWN なポートを抽出せよ。

#### 【要件】
1. `GET /dna/intent/api/v1/network-device?hostname={hostname}` で ID を検索。
2. `GET /dna/intent/api/v1/interface/network-device/{device_id}` でポート一覧を取得。
3. `adminStatus` が "UP" かつ `status` が "down" のポート名をリスト化。

#### 【設定例】
```python
def get_down_ports_by_hostname(session, base_url, hostname):
    dev_url = f"{base_url}/dna/intent/api/v1/network-device?hostname={hostname}"
    res_dev = session.get(dev_url)
    res_dev.raise_for_status()
    dev_data = res_dev.json().get("response", [])
    
    if not dev_data:
        print(f"Device {hostname} not found.")
        return []
        
    dev_id = dev_data[0].get("id")
    
    intf_url = f"{base_url}/dna/intent/api/v1/interface/network-device/{dev_id}"
    res_intf = session.get(intf_url)
    res_intf.raise_for_status()
    port_list = res_intf.json().get("response", [])
    
    target_ports = []
    for port in port_list:
        if port.get("adminStatus") == "UP" and port.get("status") == "down":
            target_ports.append(port.get("portName"))
            
    return target_ports

if __name__ == "__main__":
    ports = get_down_ports_by_hostname(sess, "https://dnac.example.com", "SW-CORE-01")
    print(f"Inactive Ports: {ports}")
```

#### 【検証方法】
ホスト名指定による Device ID の取得とインターフェイス一覧取得が正常に行われることを確認する。


### ラボ 4: クライアントヘルス情報取得 (Assurance API)

#### 【問題】
Catalyst Center Assurance API を使用し、クライアント全体のヘルススコア概要を取得せよ。

#### 【要件】
1. エンドポイント `GET /dna/intent/api/v1/client-health` を呼び出す。
2. レスポンス内のスコア詳細（`scoreDetail`）から健全性％を読み取る。

#### 【設定例】
```python
def get_client_health_summary(session, base_url):
    url = f"{base_url}/dna/intent/api/v1/client-health"
    res = session.get(url)
    res.raise_for_status()
    
    health_list = res.json().get("response", [])
    for item in health_list:
        site = item.get("siteId", "Global")
        details = item.get("scoreDetail", [])
        print(f"Site/Category: {site}")
        for d in details:
            cat_name = d.get("scoreCategory", {}).get("value")
            val = d.get("scoreValue")
            count = d.get("clientCount")
            print(f"  - {cat_name}: {val}% (Clients: {count})")

if __name__ == "__main__":
    get_client_health_summary(sess, "https://dnac.example.com")
```

#### 【検証方法】
有線/無線クライアントのカテゴリ別ヘルススコアが表示されることを確認する。

---

### ラボ 5: エリアサイトの新規作成 (POST) ＆ Task ID ポーリング

#### 【問題】
Catalyst Center にエリア（Area）サイトを新規作成し、非同期 Task ID を自動送信・追跡して完了を確認せよ。

#### 【要件】
1. `POST /dna/intent/api/v1/site` を実行。
2. レスポンスの `HTTP 202 Accepted` 内から `taskId` を抽出。
3. `GET /dna/intent/api/v1/task/{taskId}` を繰り返し実行（ポーリング）し成功を判定。

#### 【設定例】
```python
import time

def poll_task_until_complete(session, base_url, task_id, timeout=60):
    url = f"{base_url}/dna/intent/api/v1/task/{task_id}"
    start = time.time()
    
    while time.time() - start < timeout:
        res = session.get(url)
        res.raise_for_status()
        data = res.json().get("response", {})
        
        if data.get("isError"):
            reason = data.get("failureReason", "Task Error")
            raise RuntimeError(f"Task Failed: {reason}")
            
        progress = data.get("progress", "")
        if "SUCCESS" in progress.upper() or data.get("endTime"):
            print(f"[+] Task {task_id} Completed: {progress}")
            return data
            
        time.sleep(3)
        
    raise TimeoutError(f"Task {task_id} polling timed out.")

def create_area(session, base_url, area_name, parent_name="Global"):
    url = f"{base_url}/dna/intent/api/v1/site"
    payload = {
        "type": "area",
        "site": {
            "area": {
                "name": area_name,
                "parentName": parent_name
            }
        }
    }
    res = session.post(url, json=payload)
    res.raise_for_status()
    
    task_id = res.json().get("response", {}).get("taskId")
    print(f"[+] Task Created. Task ID: {task_id}")
    return poll_task_until_complete(session, base_url, task_id)

if __name__ == "__main__":
    create_area(sess, "https://dnac.example.com", "Tokyo", "Global/Japan")
```

#### 【検証方法】
サイト作成リクエスト完了後に Task ポーリングが正常に追跡され SUCCESS と表示されることを確認する。

---

### ラボ 6: サイト構造への Network Profile 割り当て (POST)

#### 【問題】
作成済みの ネットワークプロファイル（Network Profile）を特定サイト ID に対して割り当てるリクエストを送信せよ。

#### 【要件】
1. `POST /dna/intent/api/v1/site/{siteId}/network-profile/{networkProfileId}` を使用。
2. 処理完了を Task API ポーリングで検証する。

#### 【設定例】
```python
def attach_network_profile_to_site(session, base_url, site_id, profile_id):
    url = f"{base_url}/dna/intent/api/v1/site/{site_id}/network-profile/{profile_id}"
    res = session.post(url)
    res.raise_for_status()
    
    task_id = res.json().get("response", {}).get("taskId")
    print(f"[+] Attaching Profile {profile_id} to Site {site_id}. Task ID: {task_id}")
    return poll_task_until_complete(session, base_url, task_id)

if __name__ == "__main__":
    attach_network_profile_to_site(sess, "https://dnac.example.com", "site-12345", "prof-67890")
```

#### 【検証方法】
プロファイル割り当てタスクが SUCCESS で完了することを確認する。

---

### ラボ 7: CLI テンプレート (Template Programmer) 一覧取得 ＆ プロジェクト別フィルタリング

#### 【問題】
Template Programmer 内に登録されている全 CLI テンプレートプロジェクトを取得し、特定プロジェクト名（例: "Branch-Templates"）配下のテンプレート一覧とテンプレート ID を抽出せよ。

#### 【要件】
1. `GET /dna/intent/api/v1/template-programmer/template` を呼び出す。
2. 各テンプレートの `projectName` を比較し、目的のプロジェクトのテンプレート名と ID を取得する。

#### 【設定例】
```python
def get_templates_by_project(session, base_url, target_project):
    url = f"{base_url}/dna/intent/api/v1/template-programmer/template"
    res = session.get(url)
    res.raise_for_status()
    
    templates = res.json()
    matched = []
    
    for t in templates:
        if t.get("projectName") == target_project:
            matched.append({
                "template_name": t.get("name"),
                "template_id": t.get("id"),
                "version": t.get("version")
            })
            
    return matched

if __name__ == "__main__":
    tmpl_list = get_templates_by_project(sess, "https://dnac.example.com", "Branch-Templates")
    for tmpl in tmpl_list:
        print(f"Template: {tmpl['template_name']} | ID: {tmpl['template_id']} (v{tmpl['version']})")
```

#### 【検証方法】
指定したプロジェクト名の CLI テンプレート一覧と ID が取得できることを確認する。


### ラボ 8: CLI テンプレートの特定機器へのデプロイ適用 (POST)

#### 【問題】
特定機器に対して CLI テンプレートをバインド・適用（Deploy）する API リクエストを発行せよ。

#### 【要件】
1. `POST /dna/intent/api/v1/template-programmer/template/deploy` を使用。
2. Payload 内に `templateId` 及び対象機器の `targetInfo` (IP/ID) を指定。
3. 非同期 Task ポーリングで適用完了を検証する。

#### 【設定例】
```python
def deploy_template_to_device(session, base_url, template_id, device_id, params={}):
    url = f"{base_url}/dna/intent/api/v1/template-programmer/template/deploy"
    payload = {
        "templateId": template_id,
        "targetInfo": [
            {
                "id": device_id,
                "type": "MANAGED_DEVICE_UUID",
                "params": params
            }
        ]
    }
    
    res = session.post(url, json=payload)
    res.raise_for_status()
    
    task_id = res.json().get("response", {}).get("taskId")
    print(f"[+] Deploying Template {template_id} to Device {device_id}. Task ID: {task_id}")
    return poll_task_until_complete(session, base_url, task_id)

if __name__ == "__main__":
    deploy_template_to_device(
        sess, 
        "https://dnac.example.com", 
        "tmpl-uuid-1111", 
        "dev-uuid-2222", 
        params={"vlan_id": "100", "vlan_name": "GUEST_NET"}
    )
```

#### 【検証方法】
テンプレート適用タスクが成功（SUCCESS）で完了することを確認する。

---

### ラボ 9: デバイス属性の更新 (PUT) - ロケーション情報・属性値更新

#### 【問題】
管理対象デバイスの属性（Location や Description）を PUT メソッドを用いて更新せよ。

#### 【要件】
1. `PUT /dna/intent/api/v1/network-device` を使用。
2. Payload にデバイス ID および更新対象の属性値を指定。

#### 【設定例】
```python
def update_device_location(session, base_url, device_id, new_location):
    url = f"{base_url}/dna/intent/api/v1/network-device"
    payload = [
        {
            "id": device_id,
            "location": new_location
        }
    ]
    
    res = session.put(url, json=payload)
    res.raise_for_status()
    
    task_id = res.json().get("response", {}).get("taskId")
    print(f"[+] Updating Location for Device {device_id}. Task ID: {task_id}")
    return poll_task_until_complete(session, base_url, task_id)

if __name__ == "__main__":
    update_device_location(sess, "https://dnac.example.com", "dev-uuid-2222", "Tokyo Building A Floor 2")
```

#### 【検証方法】
PUT リクエスト後の Task ポーリングが SUCCESS で完了し、`GET /network-device` で属性が反映されていることを確認する。

---

### ラボ 10: 物理トポロジー (Physical Topology) の取得と隣接リンク解析

#### 【問題】
Catalyst Center から物理ネットワークトポロジー情報を取得し、全リンクの送信元機器・ポートおよび宛先機器・ポートの一覧を表示せよ。

#### 【要件】
1. `GET /dna/intent/api/v1/topology/physical-topology` を実行。
2. レスポンス内の `"links"` 配列をループし、`source` 及び `target` 情報を抽出する。

#### 【設定例】
```python
def print_physical_topology_links(session, base_url):
    url = f"{base_url}/dna/intent/api/v1/topology/physical-topology"
    res = session.get(url)
    res.raise_for_status()
    
    topology = res.json().get("response", {})
    links = topology.get("links", [])
    
    print(f"=== Physical Topology Links ({len(links)} Links Found) ===")
    for link in links:
        src = link.get("source", "")
        dst = link.get("target", "")
        src_port = link.get("startPortName", "")
        dst_port = link.get("endPortName", "")
        print(f"Link: {src} [{src_port}] <---> {dst} [{dst_port}]")

if __name__ == "__main__":
    print_physical_topology_links(sess, "https://dnac.example.com")
```

#### 【検証方法】
Catalyst Center で認識されている物理トポロジーの全リンク接続関係が出力されることを確認する。


## ❓ 想定試験問題

### 問 1 (コンフィグ読解・ヘッダー指定)
以下の Python スクリプトを実行したところ、Catalyst Center から HTTP 401 が返却された。不具合の原因として最も適切なものを1つ選べ。

```python
import requests

url = "https://dnac.example.com/dna/intent/api/v1/network-device"
headers = {
    "Auth-Header": "TOKEN_STRING",
    "Content-Type": "application/json"
}
response = requests.get(url, headers=headers, verify=False)
```

1. GET メソッドの代わりに POST メソッドを使用する必要があるため。
2. 認証トークン指定のヘッダー名が異なっており、Catalyst Center Intent API では X-Auth-Token ヘッダーに直接トークン文字列を設定する必要があるため。
3. verify=False を指定したことで SSL 検証がスキップされ、API サーバー側で接続拒否されたため。
4. Content-Type に application/yang-data+json を指定する必要があるため。

**【正解】** 2
**【解説】**
Cisco DNA Center Intent API では、トークンを X-Auth-Token というカスタム HTTP ヘッダーとして指定する必要がある。


---

### 問 2 (トラブルシューティング・非同期処理)
POST リクエストでサイトを作成した後、直ちに GET リクエストで照会したところ、サイトが含まれなかった。原因と修正方法を説明せよ。

**【正解と解説】**
* **原因:** サイト作成は非同期処理（HTTP 202 Accepted）であり、完了していないため。
* **修正方法:** レスポンス内の taskId を抽出し、GET /dna/intent/api/v1/task/{taskId} をポーリングして SUCCESS を確認してから照会する。


---

### 問 3 (Design・認証トークン運用)
多数の機器に対して夜間に順次 API 経由で設定変更および状態チェックを行う処理（所要時間約 2 時間）を設計している。トークン管理に関する注意点として正しいものを選べ。

1. 認証トークンは永続的に有効であるため、1回だけ取得すればよい。
2. 認証トークンの有効期限は発行から 1 時間（60分）であるため、実行中に期限切れ（HTTP 401）が発生するリスクがある。定期的または 401 エラー検出時にトークンを再取得するロジックを実装すべきである。
3. トークン有効期限を延長するため、リクエストヘッダーで期限延長パラメータを指定すべきである。
4. トークン再取得を回避するため、すべてのリクエストでユーザー名とパスワードを付与すべきである。

**【正解】** 2
**【解説】**
Catalyst Center の認証トークンは有効期限が 1 時間（60分）に固定されている。長時間の自動化処理では、トークンの有効期限切れが発生するため、定期的または 401 エラー捕捉時にトークン取得用エンドポイントを再呼び出ししてトークンを更新する設計が必須である。


---

### 問 4 (実装・Postman 環境変数)
Postman を用いて Catalyst Center API のリクエストコレクションを作成する際、認証トークン取得レスポンスから自動的にトークンを抽出し、後続リクエストの X-Auth-Token ヘッダーで利用可能にするための Postman Tests スクリプトを作成せよ。

**【正解】**
```javascript
var responseJson = pm.response.json();
if (responseJson.Token) {
    pm.environment.set("dna_token", responseJson.Token);
    console.log("Token stored in dna_token");
} else {
    console.error("Token key not found");
}
```


---

### 問 5 (トラブルシューティング・HTTP Status Code)
POST リクエストでリソース作成を試みたところ、HTTP 422 Unprocessable Entity が返却された。理由と対処手順を説明せよ。

**【正解と解説】**
* **理由:** 送信した JSON Payload の構文自体は正しく解析できた（HTTP 400 Bad Request ではない）が、ビジネスロジック上の制約違反（例: 既に存在する親サイト名との不一致、既存サイト名の重複登録等）が発生したため。
* **対処手順:** レスポンス Body の JSON 内に含まれる message や errorReason 属性を読み取り、論理エラーの原因（重複または存在しないID等）を特定して再送信する。


---

## 🔗 参考リソース

* Cisco Catalyst Center Developer Guide
* Cisco DNA Center Intent API Reference
* Cisco Live On-Demand Library - Automating Cisco Catalyst Center
* Postman Documentation - Variables and Scripting

---

## 📝 **補足（Notes）**

### API 呼び出しフロー
```text
Client                      Catalyst Center API Gateway
  │                                     │
  ├─── 1. POST /auth/token ─────────────┼───► Validate Credentials
  │                                     │
  │◄── 2. HTTP 200 OK { Token: "..." } ┼───◄ Return Token
  │                                     │
  ├─── 3. POST /intent/api/v1/site ────┼───► Validate X-Auth-Token
  │       Header: X-Auth-Token          │     Create Async Task
  │                                     │
  │◄── 4. HTTP 202 Accepted {taskId} ──┼───◄ Task Queued
  │                                     │
  ├─── 5. GET /task/{taskId} ──────────┼───► Check Task Status
  │                                     │
  │◄── 6. HTTP 200 OK {progress: "..."}┼───◄ Return Progress
  │    (Loop until "SUCCESS")           │
```

### 注意点・チェックリスト
* [ ] 認証ヘッダー名が `X-Auth-Token` であること
* [ ] 自己署名証明書環境での `verify=False` (Python) 及び SSL 設定確認 (Postman)
* [ ] 書き込み系 API（POST/PUT/DELETE）のレスポンスに対する Task API ポーリング処理の組み込み
* [ ] トークン有効期限（60分）超過に対する再取得ロジック



