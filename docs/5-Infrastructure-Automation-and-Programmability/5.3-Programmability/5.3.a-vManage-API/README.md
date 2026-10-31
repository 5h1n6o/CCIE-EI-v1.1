---
layout: default
title: 5.3.a-vManage-API
parent: 5.3-Programmability
grand_parent: 5-Infrastructure-Automation-and-Programmability
nav_order: 1
---

# 5.3.a Interaction with vManage API

## 📘 概要

Cisco SD-WAN (Viptela) ソリューションの中核である Cisco SD-WAN Manager (旧 vManage) は、全コンフィグレーション、モニタリング、トラブルシューティング機能を提供する集中管理システムです。vManage のすべての GUI 操作は内部的に RESTful API エンドポイント (`/dataservice/...`) を呼んでおり、外部の自動化ツールやスクリプトから vManage API を直接操作することで、大規模 SD-WAN ファブリックのゼロタッチプロビジョニング (ZTP)、テンプレート自動適用、リアルタイム監視、ネットワーク障害の自己修復をプログラムから実行可能になります。

CCIE Enterprise Infrastructure (EI) v1.1 試験において、vManage API との相互作用（Interaction with vManage API）はネットワーク自動化・オーケストレーション領域の極めて重要なトピックです。特に、Python `requests` ライブラリを用いた 2 段階認証（Session Cookie 及び CSRF トークン処理）、モニタリングエンドポイント（デバイス状態・OMP/BFD ピア・アラーム等）からのデータ抽出、ならびにコンフィグレーションエンドポイント（Feature/Device Template の取得・編集・アタッチ・非同期タスク完了待ち）の実装スキルが厳しく問われます。

---

## 🔑 要点

| 項目 | 内容 |
| --- | --- |
| **対象プロトコル** | HTTPS (HTTP over TLS/SSL), ポート 443 |
| **データエンコーディング** | JSON (`Content-Type: application/json`, `Accept: application/json`) |
| **認証メカニズム** | 2 段階認証: (1) `/j_security_check` への POST (ユーザー名/パスワード) ➔ Cookie (`JSESSIONID`) 取得 <br> (2) GET `/dataservice/client/token` ➔ CSRF トークン (`X-XSRF-TOKEN`) 取得 |
| **状態変化リクエスト制御** | POST, PUT, DELETE などの State-Changing リクエストには、Cookie に加えて `X-XSRF-TOKEN` ヘッダーを添付必須 |
| **モニタリング API** | `/dataservice/device/*` (BFD, OMP, Interface), `/dataservice/monitoring/*`, `/dataservice/system/device/*` |
| **コンフィグレーション API** | `/dataservice/template/device/*`, `/dataservice/template/feature/*`, `/dataservice/template/device/config/attachfeature` |
| **非同期処理 (Asynchronous Task)** | Template Attach や Device Reboot などの処理は非同期で実行され、返却された `taskId` を `/dataservice/device/action/status/{taskId}` でポーリングして完了判定を実施 |
| **クライアントツール** | Python (`requests.Session`), Postman (Environment/Pre-request Scripts/Tests) |

---

## 🏗 動作原理

vManage API アーキテクチャは、Web アプリケーション型のセッションベース認証と RESTful 原則に基づいています。

```
[ Python Script / Postman ]
          │
          │ 1. POST /j_security_check (j_username & j_password)
          ├───────────────────────────────────────────────────────► [ vManage ]
          │◄───────────────────────────────────────────────────────┤
          │ 2. Return HTTP 200 OK & Set-Cookie: JSESSIONID=...
          │
          │ 3. GET /dataservice/client/token (with JSESSIONID)
          ├───────────────────────────────────────────────────────► [ vManage ]
          │◄───────────────────────────────────────────────────────┤
          │ 4. Return CSRF Token String (e.g. "a1b2c3d4...")
          │
          │ 5. GET /dataservice/device/bfd/sessions (Read-only)
          ├───────────────────────────────────────────────────────► [ vManage ]
          │    (Headers: Cookie: JSESSIONID=...)                   │
          │◄───────────────────────────────────────────────────────┤
          │ 6. Return BFD Session Status JSON                      │
          │
          │ 7. POST /dataservice/template/device/config/attachfeature (Write)
          ├───────────────────────────────────────────────────────► [ vManage ]
          │    (Headers: Cookie: JSESSIONID=..., X-XSRF-TOKEN: ...)│
          │◄───────────────────────────────────────────────────────┤
          │ 8. Return Task ID JSON (e.g. {"id": "process-12345"})  │
          │
          │ 9. GET /dataservice/device/action/status/process-12345
          ├───────────────────────────────────────────────────────► [ vManage ]
          │◄───────────────────────────────────────────────────────┤
          │ 10. Return Task Status ("status": "Success")           │
```

---

## ⚙ 動作シーケンス

1. **認証セッションの確立 (Authentication):**
   * クライアントは `https://<vmanage-ip>/j_security_check` に対し、`application/x-www-form-urlencoded` 形式で `j_username` および `j_password` を POST 送信します。
   * vManage は資格情報を検証後、レスポンスヘッダー `Set-Cookie` にてセッション ID (`JSESSIONID`) を返却します。

2. **CSRF トークンの取得 (Cross-Site Request Forgery Protection):**
   * vManage 19.2 以降、Web セッション脆弱性（CSRF 攻撃）を防御するため、データ書き込み系 API（POST/PUT/DELETE）の実行には `X-XSRF-TOKEN` の提示が義務付けられました。
   * クライアントはセッション Cookie を保持した状態で `https://<vmanage-ip>/dataservice/client/token` へ GET リクエストを発行し、プレーンテキスト形式で返却されるトークン文字列を取得します。

3. **モニタリング API (GET リクエスト) の実行:**
   * 参照系エンドポイント（例: `/dataservice/device/bfd/sessions`）への GET リクエストでは、Cookie (`JSESSIONID`) のみが提示されていれば成功（HTTP 200 OK）します。

4. **コンフィグレーション API (POST/PUT/DELETE) の実行:**
   * 設定更新・アタッチなどの変更系エンドポイントへのリクエストでは、HTTP ヘッダーに `Cookie: JSESSIONID=...` と `X-XSRF-TOKEN: <token>` の双方が設定されている必要があります。トークンが欠落している場合、vManage は `403 Forbidden` エラーを返却します。

5. **非同期タスクのトラッキング (Asynchronous Task Tracking):**
   * デバイスへのテンプレートアタッチなどの処理要求を送信すると、vManage はレスポンスとして `{"id": "push_feature_template_configuration-xxx"}` という `taskId` を即座に返却します。
   * クライアントは `/dataservice/device/action/status/{taskId}` を一定間隔（例: 5 秒）で繰り返し呼び出し、`summary.status` が `Success` になるか `Failure` になるかを追跡します。

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI ラボ試験における vManage API 関連の主な評価ポイントと対策は以下の通りです。

### 1. 重点評価ポイント
* **Python `requests.Session()` の活用:**  
  単発の `requests.post()` や `requests.get()` ではなく、`requests.Session()` オブジェクトを使用して Cookie 状態を維持し、`session.headers.update({'X-XSRF-TOKEN': token})` でトークンを一括管理するコードの実装能力。
* **SSL 証明書検証の無効化 (`verify=False`):**  
  ラボ環境の vManage は自己署名証明書（Self-signed Certificate）を使用していることが多いため、`verify=False` オプションと `urllib3.disable_warnings()` の使用が不可欠です。
* **モニタリングデータからの条件抽出:**  
  `/dataservice/device/bfd/sessions` や `/dataservice/device/omp/synced/peers` のレスポンス JSON から、特定の `system-ip` や `state` (`up`/`down`) を Python のリスト内包表記や辞書操作で絞り込む問題。
* **Device Template アタッチと Payload 構成:**  
  `/dataservice/template/device/config/attachfeature` に対し、正しい構造の Payload (Device Template ID、Device CLI/CSV 変数マッピング) を含めて POST し、発行された `taskId` の完了を確認するエンドツーエンド自動化。

### 2. よくある設定・実装ミス
* **`X-XSRF-TOKEN` の欠落による 403 Forbidden:**  
  POST リクエスト時に `JSESSIONID` だけを送信し、`X-XSRF-TOKEN` をセットし忘れる。
* **`/j_security_check` の `Content-Type` 誤り:**  
  `json={'j_username': ..., 'j_password': ...}` として POST してしまう（正しくは `data={'j_username': ..., 'j_password': ...}`）。
* **CSRF トークン取得 API の HTTP メソッド誤り:**  
  `/dataservice/client/token` に対し POST でアクセスしてしまう（正しくは GET）。
* **非同期タスクの完了待ち（Polling）の考慮漏れ:**  
  Template Attach API を呼んだ直後に処理完了とみなしてスクリプトを終了させてしまい、エラー検出や後続処理の依存関係が壊れる。

---

## 🛠 設定方法

### 1. Postman での vManage API 認証コレクション設定

Postman を用いて vManage API を検証する場合、コレクション変数と Pre-request Script / Tests スクリプトを利用して認証とトークン維持を自動化するのがベストプラクティスです。

#### (1) 環境変数の設定 (Environment Variables)
* `vmanage_ip`: `10.1.1.1` (または vManage の FQDN)
* `vmanage_user`: `admin`
* `vmanage_password`: `Cisco123!`
* `jsessionid`: (空欄。認証成功時に自動更新)
* `token`: (空欄。トークン取得時に自動更新)

#### (2) 認証リクエスト 1: POST /j_security_check
* **URL:** `https://{{vmanage_ip}}/j_security_check`
* **Method:** `POST`
* **Headers:** `Content-Type: application/x-www-form-urlencoded`
* **Body (x-www-form-urlencoded):**
  * `j_username`: `{{vmanage_user}}`
  * `j_password`: `{{vmanage_password}}`
* **Tests スクリプト (JS):**
  ```javascript
  // Set-Cookie ヘッダーから JSESSIONID を抽出して環境変数に保存
  var cookie = pm.response.headers.get("Set-Cookie");
  if (cookie) {
      var match = cookie.match(/JSESSIONID=([^;]+)/);
      if (match) {
          pm.environment.set("jsessionid", match[1]);
          console.log("JSESSIONID captured: " + match[1]);
      }
  }
  ```

#### (3) 認証リクエスト 2: GET /dataservice/client/token
* **URL:** `https://{{vmanage_ip}}/dataservice/client/token`
* **Method:** `GET`
* **Headers:**
  * `Cookie`: `JSESSIONID={{jsessionid}}`
* **Tests スクリプト (JS):**
  ```javascript
  // プレーンテキストレスポンスを token 変数に保存
  var token = pm.response.text();
  pm.environment.set("token", token);
  console.log("X-XSRF-TOKEN captured: " + token);
  ```

#### (4) データ変更リクエスト例: POST /dataservice/template/device/config/attachfeature
* **URL:** `https://{{vmanage_ip}}/dataservice/template/device/config/attachfeature`
* **Method:** `POST`
* **Headers:**
  * `Content-Type`: `application/json`
  * `Cookie`: `JSESSIONID={{jsessionid}}`
  * `X-XSRF-TOKEN`: `{{token}}`
* **Body (raw JSON):** Device Template Attach 用の JSON Payload

---

### 2. Python `requests` を用いた vManage API クライアント基本構造

Python で vManage API を実装する際は、`requests.Session()` を使用してセッション状態とトークンを一括管理します。

```python
import requests
import json
import time
import urllib3

# SSL 自己署名証明書の警告を抑制
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

class vManageClient:
    def __init__(self, host, user, password):
        self.base_url = f"https://{host}"
        self.user = user
        self.password = password
        self.session = requests.Session()
        self.session.verify = False  # 自己署名証明書を許可

    def login(self):
        # 1. /j_security_check への POST によるログイン
        login_url = f"{self.base_url}/j_security_check"
        payload = {
            'j_username': self.user,
            'j_password': self.password
        }
        
        response = self.session.post(login_url, data=payload)
        
        # 認証成功時、HTML リダイレクトまたは 200 OK が返る
        if response.status_code != 200 or "login" in response.text.lower():
            raise Exception("Authentication Failed: Check credentials or IP")
            
        print("[+] Logged in successfully. JSESSIONID obtained.")

        # 2. /dataservice/client/token への GET による CSRF トークン取得
        token_url = f"{self.base_url}/dataservice/client/token"
        token_res = self.session.get(token_url)
        
        if token_res.status_code == 200:
            token = token_res.text.strip()
            # 以降のすべての POST/PUT/DELETE にヘッダーを適用
            self.session.headers.update({'X-XSRF-TOKEN': token})
            print(f"[+] CSRF Token obtained: {token[:10]}...")
        else:
            print("[!] Warning: Could not obtain CSRF Token (vManage < 19.2 or Error)")

    def get_data(self, endpoint):
        # モニタリング API (GET) 呼び出し
        url = f"{self.base_url}{endpoint}"
        response = self.session.get(url)
        response.raise_for_status()
        return response.json()

    def post_data(self, endpoint, payload):
        # コンフィグレーション API (POST) 呼び出し
        url = f"{self.base_url}{endpoint}"
        self.session.headers.update({'Content-Type': 'application/json'})
        response = self.session.post(url, json=payload)
        response.raise_for_status()
        return response.json()

    def wait_for_task(self, task_id, timeout=300, interval=5):
        # 非同期タスク完了待ち (Polling)
        status_endpoint = f"/dataservice/device/action/status/{task_id}"
        start_time = time.time()
        
        print(f"[*] Waiting for Task ID: {task_id} ...")
        while time.time() - start_time < timeout:
            res = self.get_data(status_endpoint)
            status = res.get('summary', {}).get('status', 'Validation')
            print(f"    Current Status: {status}")
            
            if status == 'Success':
                print("[+] Task Completed Successfully!")
                return True
            elif status in ['Failure', 'Validation error']:
                print(f"[!] Task Failed! Details: {res}")
                return False
                
            time.sleep(interval)
            
        raise Exception(f"[-] Task timed out after {timeout} seconds.")
```

---

## 🔍 検証コマンド

vManage API の主要エンドポイントと検証方法を以下の表に示します。

| カテゴリ | エンドポイント (Endpoint) | HTTP Method | 説明・利用目的 |
| --- | --- | --- | --- |
| **認証 (Auth)** | `/j_security_check` | POST | ユーザー名/パスワードによるセッション認証 |
| **認証 (Auth)** | `/dataservice/client/token` | GET | CSRF 防御用 `X-XSRF-TOKEN` 取得 |
| **デバイス (Device)** | `/dataservice/system/device/controllers` | GET | ファブリック内の Controller (vManage, vSmart, vBond) 一覧取得 |
| **デバイス (Device)** | `/dataservice/system/device/vedges` | GET | ファブリック内の WAN Edge (cEdge/vEdge) インベントリ一覧取得 |
| **モニタリング (Mon)** | `/dataservice/device/bfd/sessions` | GET | 全デバイスの BFD セッション状態 (Up/Down, Jitter, Loss) 取得 |
| **モニタリング (Mon)** | `/dataservice/device/omp/synced/peers` | GET | OMP ピアの確立状態及び同期情報取得 |
| **モニタリング (Mon)** | `/dataservice/device/interface` | GET | 物理/論理インターフェイスのステータス及び IP 情報取得 |
| **テンプレート (Config)**| `/dataservice/template/device` | GET | 定義済み Device Template の一覧及び ID 取得 |
| **テンプレート (Config)**| `/dataservice/template/feature` | GET | 定義済み Feature Template の一覧取得 |
| **アタッチ (Config)** | `/dataservice/template/device/config/attachfeature` | POST | デバイスに対する Device Template のアタッチ実行 (Task ID 発行) |
| **アクション (Task)** | `/dataservice/device/action/status/{taskId}` | GET | 非同期タスクの進捗状況 (Success/Failure) 照会 |

---

## 🚨 トラブルシュート

vManage API 運用における代表的なトラブル症状、原因、及び解決手順です。

| 症状 | 原因 | 確認コマンド / 方法 | 対処方法 |
| --- | --- | --- | --- |
| **`403 Forbidden` エラーが POST/PUT リクエストで発生する** | `X-XSRF-TOKEN` ヘッダーが送られていない、またはトークン期限切れ | API レスポンスボディの確認 (`"error": {"message": "CSRF token validation failed"}`) | POST 前に GET `/dataservice/client/token` を呼び出し、得られた文字列を `X-XSRF-TOKEN` ヘッダーに設定 |
| **ログイン失敗 (`401` または ログイン画面 HTML 返却)** | パスワード誤り、または `/j_security_check` への送信形式誤り | `response.text` を確認。ログインフォームの HTML が返っていないか点検 | リクエスト Body を JSON (`json=`) ではなく `application/x-www-form-urlencoded` (`data=`) で送信 |
| **`SSLError` (Certificate verify failed)** | vManage が自己署名証明書を使用しており Python の SSL 検証が失敗 | Python のスタック・トレース (`requests.exceptions.SSLError`) | `requests.get(..., verify=False)` をセットし `urllib3.disable_warnings()` を呼び出す |
| **Template Attach が途中で止まる / `Validation error`** | Payload JSON 内のデバイス変数マッピング (CSV/CLI 変数名) 不正 | GET `/dataservice/device/action/status/{taskId}` のレスポンス詳細情報 | `attachfeature` に送信する Payload 内の `csv-status` や変数名キー（`vlan_id`, `system_ip` 等）のタイポを修正 |
| **`JSESSIONID` が次回リクエストで認識されない** | 単発の `requests.get()` を使っており Cookie が引き継がれていない | `session.cookies.get_dict()` の出力を印刷確認 | `requests.Session()` を使用してログインからデータ取得まで同一セッションオブジェクトを保持 |

---

## ⚠ 制限事項

* **API レート制限 (Rate Limiting):**  
  大量の API リクエストを短時間に送信すると vManage の CPU 高騰を防止するため HTTP `429 Too Many Requests` や接続拒否が発生します。
* **セッションタイムアウト:**  
  デフォルトで vManage の Web セッションは一定時間無通信が続くと破棄されます。長時間のバックグラウンド監視スクリプトでは再ログイン処理（自動トークン更新）を組み込む必要があります。
* **クラスタ環境での IP 指定:**  
  vManage がクラスタ構成の場合、ロードバランサまたは特定 vManage ノードの IP 宛てにリクエストを送信します。セッション維持（Sticky Session）が必要です。

---

## 🔄 他技術との関連

* **Cisco SD-WAN Architecture (2.2):**  
  vManage API は vSmart へのポリシープッシュや vEdge/cEdge へのテンプレートアタッチを透過的に制御します。
* **Data Encoding Formats (5.1):**  
  vManage API はすべてのデータ交換に JSON を使用します。Python の `json` モジュールや `dict` 処理が不可欠です。
* **Automation and Scripting (5.2):**  
  Python `requests` ライブラリを用いた標準的な REST API クライアント作成パターンと 100% 共通します。

---

## 🧩 比較表

| 項目 | vManage API (SD-WAN) | Catalyst Center Intent API | RESTCONF (IOS XE) |
| --- | --- | --- | --- |
| **標準ポート** | HTTPS (443) | HTTPS (443) | HTTPS (443) |
| **認証方式** | Session Cookie (`JSESSIONID`) ＋ CSRF (`X-XSRF-TOKEN`) | OAuth2 Bearer Token (`X-Auth-Token`) | HTTP Basic Auth または Token |
| **ログイン URL** | `/j_security_check` | `/dna/system/api/v1/auth/token` | 設定不要 (リクエスト毎に認証ヘッダー) |
| **データ形式** | JSON 限定 | JSON 限定 | JSON 及び XML |
| **書き込み制御** | CSRF トークン必須 | Bearer トークンのみで可 | HTTP Header のみで可 |
| **非同期処理** | Task ID ポーリング (`/dataservice/device/action/status/...`) | Task ID ポーリング (`/dna/intent/api/v1/task/...`) | 原則同期処理 |

---

## 💡 ベストプラクティス

1. **`requests.Session()` の徹底活用:**  
   ログインからトークン取得、モニタリング、設定アタッチまでを単一の `Session` インスタンスで実行し、Cookie と Header の引き継ぎミスを根本排除します。
2. **自己署名証明書警告の抑制:**  
   試験環境でのノイズを減らすため、必ず `urllib3.disable_warnings()` をスクリプト冒頭に記述します。
3. **堅牢な非同期タスク待ち（Polling Loop）:**  
   Task ID による完了判定は無限ループを避け、必ず `timeout` と `time.sleep(5)` を設定してループ脱出ロジックを実装します。

---

## 📝 ラボ学習・設定サンプル例

CCIE EI ラボ試験レベルを意識した 10 個の実践的な演習サンプルです。

---

### ラボ 1: vManage 2 段階認証（Session Cookie ＋ CSRF トークン）完全ログイン実装

#### 要件
* Python `requests.Session()` を使用して `10.1.1.1` の vManage へアクセスする。
* `/j_security_check` への POST で `JSESSIONID` を取得する。
* `/dataservice/client/token` への GET で CSRF トークンを取得し、以降のリクエストヘッダー `X-XSRF-TOKEN` にセットする。

#### 実装コード
```python
import requests
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

def vmanage_login(vmanage_ip, username, password):
    session = requests.Session()
    session.verify = False
    
    # Step 1: POST /j_security_check
    login_url = f"https://{vmanage_ip}/j_security_check"
    login_data = {
        'j_username': username,
        'j_password': password
    }
    
    res_login = session.post(login_url, data=login_data)
    if res_login.status_code != 200 or "login" in res_login.text.lower():
        print("[-] Login failed. Check credentials.")
        return None
        
    print("[+] Step 1: Successfully authenticated. JSESSIONID Cookie stored.")

    # Step 2: GET /dataservice/client/token
    token_url = f"https://{vmanage_ip}/dataservice/client/token"
    res_token = session.get(token_url)
    
    if res_token.status_code == 200:
        token = res_token.text.strip()
        session.headers.update({'X-XSRF-TOKEN': token})
        print(f"[+] Step 2: CSRF Token obtained: {token[:15]}...")
    else:
        print("[!] Warning: CSRF Token fetch failed.")
        
    return session

if __name__ == "__main__":
    sess = vmanage_login("10.1.1.1", "admin", "Cisco123!")
```

#### 検証方法
スクリプトを実行し、`JSESSIONID Cookie stored` 及び `CSRF Token obtained` が出力されることを確認する。

---

### ラボ 2: モニタリング - WAN Edge インベントリ一覧及び Reachability 取得

#### 要件
* `/dataservice/system/device/vedges` エンドポイントを呼び出す。
* ファブリック内の WAN Edge デバイスの Hostname, System-IP, Device-Type, Reachability (`reachable`/`unreachable`) をテーブル状に出力する。

#### 実装コード
```python
def get_wan_edge_inventory(session, vmanage_ip):
    url = f"https://{vmanage_ip}/dataservice/system/device/vedges"
    res = session.get(url)
    res.raise_for_status()
    
    devices = res.json().get('data', [])
    print(f"| {'Hostname':<15} | {'System-IP':<15} | {'Device Type':<12} | {'Reachability':<12} |")
    print("|" + "-"*17 + "|" + "-"*17 + "|" + "-"*14 + "|" + "-"*14 + "|")
    
    for dev in devices:
        host = dev.get('host-name', 'N/A')
        sys_ip = dev.get('system-ip', 'N/A')
        dev_type = dev.get('device-type', 'N/A')
        reach = dev.get('reachability', 'unknown')
        print(f"| {host:<15} | {sys_ip:<15} | {dev_type:<12} | {reach:<12} |")

# 使用例: get_wan_edge_inventory(sess, "10.1.1.1")
```

#### 検証方法
実行後、全 cEdge / vEdge の Reachability 状態が正常に取得・表示されることを確認する。

---

### ラボ 3: モニタリング - 全デバイス BFD セッション状態抽出 ＆ Down セッション検知

#### 要件
* `/dataservice/device/bfd/sessions` エンドポイントから全 BFD セッション情報を取得する。
* 状態が `up` 以外のセッション（`down` など）が存在する場合、該当する Source IP, Local System IP, Peer System IP, Site ID を警告出力する。

#### 実装コード
```python
def check_bfd_sessions(session, vmanage_ip):
    url = f"https://{vmanage_ip}/dataservice/device/bfd/sessions"
    res = session.get(url)
    res.raise_for_status()
    
    bfd_list = res.json().get('data', [])
    down_sessions = []
    
    for bfd in bfd_list:
        state = bfd.get('state', '').lower()
        if state != 'up':
            down_sessions.append(bfd)
            
    print(f"[i] Total BFD Sessions: {len(bfd_list)}")
    if down_sessions:
        print(f"[!] WARNING: {len(down_sessions)} BFD Session(s) are DOWN!")
        for ds in down_sessions:
            print(f"    - System IP: {ds.get('vdevice-name')} | Peer System IP: {ds.get('dst-ip')} | State: {ds.get('state')}")
    else:
        print("[+] All BFD Sessions are UP and Healthy.")

# 使用例: check_bfd_sessions(sess, "10.1.1.1")
```

#### 検証方法
ファブリック内の全 BFD セッション数が正しく出力され、Down セッションが検知できることを確認する。

---

### ラボ 4: モニタリング - OMP ピア同期状態の検証 ＆ カウント

#### 要件
* `/dataservice/device/omp/synced/peers` を呼び出し、各 WAN Edge と vSmart 間の OMP ピア確立状態を取得する。
* OMP ピア状態が `established` になっていないピアを抽出・表示する。

#### 実装コード
```python
def check_omp_peers(session, vmanage_ip):
    url = f"https://{vmanage_ip}/dataservice/device/omp/synced/peers"
    res = session.get(url)
    res.raise_for_status()
    
    peers = res.json().get('data', [])
    print(f"[i] Checking {len(peers)} OMP Peer records...")
    
    for peer in peers:
        device = peer.get('vdevice-name')
        peer_ip = peer.get('peer')
        state = peer.get('state')
        type_ = peer.get('type')
        
        if state != 'established':
            print(f"[!] Issue detected: Device {device} Peer {peer_ip} ({type_}) State: {state}")
        else:
            print(f"    [OK] Device {device} <-> Peer {peer_ip} ({type_}): Established")

# 使用例: check_omp_peers(sess, "10.1.1.1")
```

#### 検証方法
WAN Edge 機器から vSmart 宛ての OMP ピアが `Established` と判定されることを確認する。

---

### ラボ 5: モニタリング - デバイスの物理・論理インターフェイス IP/ステータス抽出

#### 要件
* 指定した WAN Edge の System IP (`172.16.255.11`) に対し、`/dataservice/device/interface?deviceId=172.16.255.11` を呼び出す。
* インターフェイス名、IP アドレス、Operational Status (`up`/`down`) を取得・表示する。

#### 実装コード
```python
def get_device_interfaces(session, vmanage_ip, system_ip):
    url = f"https://{vmanage_ip}/dataservice/device/interface?deviceId={system_ip}"
    res = session.get(url)
    res.raise_for_status()
    
    ifaces = res.json().get('data', [])
    print(f"=== Interface Status for System-IP: {system_ip} ===")
    for iface in ifaces:
        name = iface.get('ifname')
        ip = iface.get('ip-address', 'N/A')
        status = iface.get('if-oper-status')
        print(f"  Interface: {name:<15} | IP: {ip:<18} | Status: {status}")

# 使用例: get_device_interfaces(sess, "10.1.1.1", "172.16.255.11")
```

#### 検証方法
指定したデバイスの全インターフェイス状態がリスト化されることを確認する。

---

### ラボ 6: コンフィグレーション - 特定 Device Template ID の取得 ＆ 変数名抽出

#### 要件
* `/dataservice/template/device` から指定したテンプレート名（例: `cEdge_Branch_Template`）の ID (`templateId`) を取得する。
* 定義されている変数（CLI/CSV 変数名）を判定して出力する。

#### 実装コード
```python
def get_device_template_id(session, vmanage_ip, template_name):
    url = f"https://{vmanage_ip}/dataservice/template/device"
    res = session.get(url)
    res.raise_for_status()
    
    templates = res.json().get('data', [])
    for tpl in templates:
        if tpl.get('templateName') == template_name:
            t_id = tpl.get('templateId')
            print(f"[+] Found Template '{template_name}' ID: {t_id}")
            return t_id
            
    print(f"[-] Template '{template_name}' not found.")
    return None

# 使用例: t_id = get_device_template_id(sess, "10.1.1.1", "cEdge_Branch_Template")
```

#### 検証方法
テンプレート名から正確な UUID (`templateId`) が取得できることを確認する。

---

### ラボ 7: コンフィグレーション - Device Template アタッチ Payload の動的構築 ＆ POST 送信

#### 要件
* 前ラボで取得した `templateId` に対し、`/dataservice/template/device/config/attachfeature` へアタッチ要求を送信する。
* レスポンスから `taskId` を抽出して返却する。

#### 実装コード
```python
def attach_device_template(session, vmanage_ip, template_id, device_system_ip, device_uuid, variables_dict):
    url = f"https://{vmanage_ip}/dataservice/template/device/config/attachfeature"
    
    # Attach 用の標準 Payload 構造
    payload = {
        "deviceTemplateList": [
            {
                "templateId": template_id,
                "device": [
                    {
                        "csv-status": "complete",
                        "csv-deviceId": device_uuid,
                        "csv-deviceIP": device_system_ip,
                        **variables_dict  # カスタム変数を展開
                    }
                ],
                "isDraft": False,
                "isStrict": False
            }
        ]
    }
    
    res = session.post(url, json=payload)
    res.raise_for_status()
    
    task_id = res.json().get('id')
    print(f"[+] Attach Request Submitted. Generated Task ID: {task_id}")
    return task_id
```

#### 検証方法
POST 送信成功時、`id` フィールドにタスク識別子文字列（例: `push_feature_template_configuration-xxx`）が含まれることを確認する。

---

### ラボ 8: タスク管理 - 非同期 Task ID の自動ポーリング ＆ 完了判定

#### 要件
* `/dataservice/device/action/status/{taskId}` を 5 秒間隔でポーリングする。
* ステータスが `Success` になったら成功として終了、`Failure` の場合は詳細ログを出力して例外を発生させる。

#### 実装コード
```python
import time

def poll_task_status(session, vmanage_ip, task_id, timeout=300):
    url = f"https://{vmanage_ip}/dataservice/device/action/status/{task_id}"
    start_time = time.time()
    
    print(f"[*] Polling Task Status for ID: {task_id}")
    while time.time() - start_time < timeout:
        res = session.get(url)
        res.raise_for_status()
        
        data = res.json()
        summary = data.get('summary', {})
        status = summary.get('status', 'Unknown')
        
        print(f"    [+] Current Status: {status}")
        if status == 'Success':
            print("[+] Template Attach Operation Succeeded!")
            return True
        elif 'Failure' in status or 'Error' in status:
            details = data.get('actionResult', [])
            print(f"[-] Operation Failed. Details: {details}")
            return False
            
        time.sleep(5)
        
    raise TimeoutError(f"[-] Polling timed out for Task ID {task_id}")
```

#### 検証方法
タスク実行進捗が `In-Progress` ➔ `Success` へ遷移するログ出力を確認する。

---

### ラボ 9: モニタリング - アラーム・イベントログの過去条件抽出

#### 要件
* `/dataservice/alarms` から発生した Critical/Major アラームを取得する。
* アラームメッセージ、発生デバイス、タイムスタンプを分析出力する。

#### 実装コード
```python
def get_critical_alarms(session, vmanage_ip):
    url = f"https://{vmanage_ip}/dataservice/alarms"
    res = session.get(url)
    res.raise_for_status()
    
    alarms = res.json().get('data', [])
    critical_alarms = [a for a in alarms if a.get('severity') in ['CRITICAL', 'MAJOR']]
    
    print(f"[i] Found {len(critical_alarms)} Critical/Major Alarm(s):")
    for alarm in critical_alarms:
        rule_name = alarm.get('rule_name_display')
        dev = alarm.get('vdevice-name')
        entry_time = alarm.get('entry_time')
        print(f"  - [{alarm.get('severity')}] Device: {dev} | Alarm: {rule_name} | Time: {entry_time}")

# 使用例: get_critical_alarms(sess, "10.1.1.1")
```

#### 検証方法
ネットワーク内の障害アラームがソートされて表示されることを確認する。

---

### ラボ 10: 統合自動化 - WAN Edge の BFD 障害検出 ➔ アラーム照会 ➔ ヘルスレポート生成

#### 要件
* WAN Edge インベントリ、BFD セッション、アラーム情報を取得して、ファブリック全体の統合ヘルス状態レポートを画面に出力する。

#### 実装コード
```python
def generate_fabric_health_report(vmanage_ip, user, password):
    sess = vmanage_login(vmanage_ip, user, password)
    if not sess:
        return
        
    print("
==========================================")
    print("      SD-WAN FABRIC HEALTH REPORT         ")
    print("==========================================")
    
    # 1. Inventory Check
    edges_res = sess.get(f"https://{vmanage_ip}/dataservice/system/device/vedges").json().get('data', [])
    reachable_edges = [e for e in edges_res if e.get('reachability') == 'reachable']
    print(f"[1] WAN Edge Inventory  : {len(reachable_edges)}/{len(edges_res)} Reachable")
    
    # 2. BFD Sessions Check
    bfd_res = sess.get(f"https://{vmanage_ip}/dataservice/device/bfd/sessions").json().get('data', [])
    up_bfd = [b for b in bfd_res if b.get('state', '').lower() == 'up']
    print(f"[2] BFD Sessions        : {len(up_bfd)}/{len(bfd_res)} UP")
    
    # 3. Critical Alarms Check
    alarm_res = sess.get(f"https://{vmanage_ip}/dataservice/alarms").json().get('data', [])
    crit_alarms = [a for a in alarm_res if a.get('severity') == 'CRITICAL']
    print(f"[3] Critical Alarms     : {len(crit_alarms)} Active")
    
    print("==========================================
")

if __name__ == "__main__":
    generate_fabric_health_report("10.1.1.1", "admin", "Cisco123!")
```

#### 検証方法
スクリプト実行によりファブリック全体の要約ヘルスレポートが健全に出力されることを確認する。

---

## ❓ 想定試験問題

CCIE EI ラボ試験及び筆記試験を想定した実践問題集です。

---

### 問 1 (実装・コンフィグ読解)
**問題:**  
Python `requests` ライブラリを使用して vManage API 経由で Device Template のアタッチリクエスト (POST `/dataservice/template/device/config/attachfeature`) を送信しました。しかし、レスポンスとして `403 Forbidden` (`CSRF token validation failed`) が返却されました。この問題を修正するために必要なコードの追加処理を説明し、正しいコードブロックを示してください。

**解答・解説:**  
**原因:** vManage 19.2 以降では、データ変更操作（POST/PUT/DELETE）時に `JSESSIONID` Cookie に加え、CSRF 防御用の `X-XSRF-TOKEN` ヘッダーが送られていないとリクエストが拒否されます。  
**修正手順:** POST リクエスト送信前に、GET `/dataservice/client/token` を呼び出し、取得したトークン文字列を `session.headers.update({'X-XSRF-TOKEN': token})` で追加します。

```python
# 修正コード例
token_res = session.get(f"https://{vmanage_ip}/dataservice/client/token")
if token_res.status_code == 200:
    token = token_res.text.strip()
    session.headers.update({'X-XSRF-TOKEN': token})

# この後に POST リクエストを発行
res = session.post(attach_url, json=payload)
```

---

### 問 2 (トラブルシューティング)
**問題:**  
ある自動化スクリプトで `/j_security_check` へのログインリクエストを `requests.post(url, json={'j_username': user, 'j_password': pwd})` として送信したところ、HTTP 200 OK が返るものの `JSESSIONID` Cookie が設定されず、後続の API 呼び出しがすべて認証失敗となります。理由と正しい書き方を答えてください。

**解答・解説:**  
**原因:** `/j_security_check` は標準的な HTML フォーム認証エンドポイントであり、`Content-Type: application/json` (`json=`) ではなく `Content-Type: application/x-www-form-urlencoded` 形式のボディデータ (`data=`) を要求します。`json=` パラメータで送ると vManage は引数を解析できずログイン画面の HTML を返します。  
**正しい書き方:**  
`requests.post(url, data={'j_username': user, 'j_password': pwd})`

---

### 問 3 (Design)
**問題:**  
100 台の WAN Edge に対し vManage API を用いて一括で Device Template をアタッチするスクリプトを設計しています。POST `/dataservice/template/device/config/attachfeature` のレスポンスを受け取った直後にスクリプトを終了させた場合、運用上どのような問題が発生するか説明してください。

**解答・解説:**  
`attachfeature` API は非同期処理（Asynchronous Operation）であり、POST 送信成功時に返されるのは処理完了ではなく `taskId`（例: `push_feature_template_configuration-xxx`）です。レスポンス受け取り直後に終了すると、バックグラウンドで発生したコンフィグ構文エラー、デバイスの応答不可、ロールバックなどのエラーを検知できません。正しくは返却された `taskId` を用いて `/dataservice/device/action/status/{taskId}` を完了（`Success` または `Failure`）まで定期ポーリング（Polling）する必要があります。

---

### 問 4 (実装・データ処理)
**問題:**  
GET `/dataservice/device/bfd/sessions` のレスポンス JSON から、特定 Site ID (例: `100`) に所属し、かつステータスが `down` になっている BFD セッションの Peer System IP 一覧を抽出する Python コードを記述してください。

**解答・解説:**
```python
def extract_down_bfd_peers(bfd_json_data, target_site_id=100):
    sessions = bfd_json_data.get('data', [])
    down_peers = [
        s.get('dst-ip') for s in sessions 
        if s.get('site-id') == target_site_id and s.get('state', '').lower() == 'down'
    ]
    return down_peers
```

---

### 問 5 (トラブルシューティング)
**問題:**  
Postman を使用して vManage API のテストを行っています。POST `/j_security_check` の実行後、GET `/dataservice/system/device/vedges` を呼び出すと `401 Unauthorized` が返却されます。Postman 内で認証セッションが維持されていない原因と、自動化するためのテストスクリプト設定を説明してください。

**解答・解説:**  
**原因:** POST `/j_security_check` のレスポンスヘッダー `Set-Cookie` で返された `JSESSIONID` が、GET リクエストの `Cookie` ヘッダーに設定されていないため。  
**設定方法:** POST `/j_security_check` の `Tests` タブに以下の JavaScript を記述し、`Set-Cookie` から `JSESSIONID` を抽出して環境変数 `jsessionid` に自動セットします。以降の GET リクエストでは `Cookie: JSESSIONID={{jsessionid}}` ヘッダーを添付します。

```javascript
var cookie = pm.response.headers.get("Set-Cookie");
if (cookie) {
    var match = cookie.match(/JSESSIONID=([^;]+)/);
    if (match) {
        pm.environment.set("jsessionid", match[1]);
    }
}
```

---

## 🔗 参考リソース

Cisco 公式ドキュメント及び開発者リソースのリンク集です。

* Cisco SD-WAN vManage REST API Getting Started Guide (Cisco DevNet)
* Cisco SD-WAN vManage API Reference Guide (DevNet Portal)
* Cisco SD-WAN Architecture Design Guide (CVD)
* Cisco Live Presentation: Programmability and Automation with Cisco SD-WAN
* Python Requests Official Documentation

---

## 📝 補足（Notes）

### 1. vManage バージョン間の認証差異
* **vManage 19.1 以前:** `/j_security_check` による `JSESSIONID` Cookie のみで POST/PUT リクエストが許可されていました。
* **vManage 19.2 以降:** CSRF 攻撃対策として GET `/dataservice/client/token` から取得する `X-XSRF-TOKEN` が必須化されました。最新の CCIE EI ラボ試験（SD-WAN 20.x ベース）では必ず CSRF トークンの取得とヘッダー適用が必要です。

### 2. SD-WAN Controller と Manager の名称変更
* 従来 **vManage** と呼ばれていたコントローラは、Cisco のリブランディングにより **Cisco SD-WAN Manager** (または Cisco Catalyst SD-WAN Manager) と表記されます。API エンドポイント（`/dataservice/...`）や認証仕様（`/j_security_check`）は従来と完全に互換性があります。

---

