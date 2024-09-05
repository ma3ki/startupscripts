# 概要
- メールシステム
  - さくらのクラウドのスタートアップスクリプト機能で単体のメールサーバをセットアップします。
  - セットアップにはサーバの作成から20分程度、お時間がかかります。
# 提供機能
- メール送信(SMTPサーバ)
  - SMTP Submission(587/tcp)
  - SMTP over TLS(465/tcp)
  - SMTP-AUTH
  - STARTTLS
  - Virus Check (パスワード付きZIPファイルは送信拒否)
  - 各種メール認証技術
    - SPF, DKIM, DMARC, ARC 署名
- メール受信
  - SMTP(25/tcp)
  - STARTTLS
  - Virus Check (パスワード付きZIPファイルは受信拒否)
  - Spam Check
  - 各種メール認証技術
    - SPF, DKIM, DMARC, ARC 認証
- メール参照(POP/IMAPサーバ)
  - POP over TLS(995/tcp)
  - IMAP over TLS(993/tcp)
- Webmail
  - Roundcube
    - フィルタリング/転送設定
    - パスワード変更
- アカウント管理
  - phpldapadmin
    - メールアドレス追加/削除/停止
    - パスワード変更
- 他
  - Thunderbird の autoconfig 対応
  - メールアーカイブ
  - マルチドメイン
  - エイリアスアドレス
  - グループアドレス
# セットアップ手順
## 1. APIキーの登録
- アクセスレベルが 作成・削除 のAPIキーを用意
## 2. メールアドレス用ドメインの追加
- グローバルリソースの DNS に ゾーンを追加し利用できるようにする
## 3. スタートアップスクリプトの登録
- mailsystem.sh の内容をスタートアップスクリプトに登録
## 4. サーバの作成
```
下記は example.com をドメインとした場合の例です
```
- "アーカイブ選択" で 対応OS のアーカイブを選択
- "ホスト名" はドメインを省いたものを入力する (例: mail と入力した場合、 mail.example.com というホスト名になります)
- "スタートアップアクリプト" で shell を選択
- "配置するスタートアップスクリプト"で 3で作成したスタートアップスクリプト を選択
- "作成するメールアドレスのリスト" に初期セットアップ時に作成するメールアドレスを1行に1つ入力
- "APIキー" を選択 (DNSのレコード登録に使用します)
- "メールアーカイブを有効にする" 場合は チェックしてください
- "セットアップ完了メールを送信する宛先" に、メールを受信できるアドレスを入力
- "usacloudをインストールする" のチェックをはずす
- 必要な項目を入力したら作成
## 5. セットアップ完了メール の確認
- セットアップ完了後に、セットアップ情報を記述したメールが届きます
- メールが届かない場合は、サーバにログインしインストールログを確認してください

```
-- Mail Server Domain --
smtp server : example.com
pop  server : example.com
imap server : example.com

-- Rspamd Webui --
LOGIN URL : https://example.com/rspamd
PASSWORD  : ***********

-- phpLDAPadmin --
LOGIN URL : https://example.com/phpldapadmin
LOGIN_DN  : cn=********
PASSWORD  : ***********

-- Roundcube Webmail --
LOGIN URL : https://example.com/roundcube

-- Application Version --
os: Rocky Linux release 9.4 (Blue Onyx)
389ds: 2.4.5
dovecot: 2.3.16
clamd: 1.0.6
rspamd: 3.9.1
redis: 6.2.7
postfix: 3.5.9
mysql: 8.0.36
php-fpm: 8.0.30
nginx: 1.20.1
roundcube: 1.6.9
phpldapadmin: 1.2.6.6

-- Process Check --
OK: ns-slapd
OK: dovecot
OK: clamd
OK: rspamd
OK: redis-server
OK: postfix
OK: mysqld
OK: php-fpm
OK: nginx

-- example.com DNS Check --
OK: example.com A XX.XX.XX.XX
OK: example.com MX 10 example.com.
OK: example.com TXT "v=spf1 +ip4:XX.XX.XX.XX -all"
OK: mail.example.com A XX.XX.XX.XX
OK: autoconfig.example.com A XX.XX.XX.XX
OK: _dmarc.example.com TXT "v=DMARC1\; p=reject\; rua=mailto:admin@example.com"
OK: sacloud._domainkey.example.com TXT "v=DKIM1\; k=rsa\; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDkviwuC8KvC6OP7HwUPQEZDA+ZnY1mRzZrCJcM4sMRhhVse7Cwy/VOldbIxGTAnsRSaLmmxcz96aiCftvctue7mzIvFscCDRm35PtAS5mvlWXRP1f2brHROLoc0rv7upliPdwNXmc7UhZ2b8/gJhSDw76nFiOiOG7/x5GkLCZLCQIDAQAB"

-- example.com TLS Check --
Validity:
 Not Before: Sep  3 15:41:34 2024 GMT
 Not After : Dec  2 15:41:33 2024 GMT
Subject Alternative Name:
 DNS:*.example.com, DNS:example.com

-- Mail Address and Password --
admin@example.com: ***********
user01@example.com: ***********
user02@example.com: ***********
user03@example.com: ***********
```
# インストールアプリケーションと主な用途
- usacloud
  - さくらのクラウドDNSへのレコード登録
    - A レコード (メールドメイン用、ホスト名用)
    - MX レコード
    - TXT レコード (SPF, DKIM, DMARC)
    - CNAME レコード (Thunderbird の autoconfig用)
    - PTR レコード
- 389 directory server
  - LDAPサーバ
  - メールアドレスの管理
- dovecot
  - LMTP,POP,IMAP,ManageSieveサーバ
  - メール保存 (LMTP)
  - メール参照 (POP/IMAP)
  - メールフィルタリング (Sieve)
  - メール転送 (Sieve)
- rspamd + redis
  - 送信メールの DKIM, ARC 署名
  - 受信メールの SPF, DKIM, DMARC, ARC 検証
  - 受信メールの Spam Check
  - 送受信メールの Virus Scan (clamav と連携)
- clamav
  - ウィルススキャンサーバ
- postfix, postfix-inbound (multi-instance)
  - メール送信サーバ(postfix)
  - メール受信サーバ(postfix-inbound)
- nginx, php-fpm
  - Webサーバ(HTTPS)
  - メールプロキシサーバ(SMTP Submission,SMTPS,POPS,IMAPS)
  - メールプロキシ用認証サーバ(HTTP)
- mysql
  - roundcube用データベース
- roundcube
  - Webメール
  - パスワード変更
  - メールフィルタ設定
  - メール転送設定
- phpldapadmin
  - ldapの管理
- certbot
  - TLS対応(Lets Encrypt)
- Thunderbird の autoconfig設定
## 補足
- 1通のメールサイズは最大20MBで、MBOXのサイズは4GBでquotaをかけている
- 転送設定の最大転送先アドレスは32アドレス
- adminアドレスはエイリアス設定をしている (下記のアドレス宛のメールは admin 宛に配送される)
  - admin, root, postmaster, abuse, nobody, dmarc-report
- ウィルス検知時の挙動
  - clamavで ウィルス を検知したメールは、送受信を拒否する(reject)
- rspamd が正常に動作していない場合、postfixは tempfail を応答する
- メールアーカイブ機能
  - メールアーカイブを有効にすると、全てのユーザの送信/受信メールがarchive用のアドレスに複製配送(bcc)される
  - archive用のメールボックスのみ 受信日時から1年経過したメールが cron で削除される
- マルチドメイン設定方法
  - さくらのクラウドDNSに複数ゾーンを追加し、サーバ作成時に複数のドメインのメールアドレスを入力する
- メールアドレスの無効化
  - ldap の ou 属性を People から Termed に変更することで メールアドレスを無効にできる
- 各種OSSの設定、操作方法についてはOSSの公式のドキュメントをご参照ください

## コマンドでの操作
```
・メールアドレス追加 (作成したメールアドレスのパスワードが出力されます)
# /root/.sacloud-api/notes/cloud-startupscripts/originalscript/mailsystem/tools/389ds_create_mailaddress.sh adduser@example.com

・外部向けメールキューの確認
# mailq

・内部向けメールキューの確認
# postqueue -p -c /etc/postfix-inbound/
```
