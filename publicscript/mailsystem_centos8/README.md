# 概要
- メールシステム
  - このスクリプトは単体のメールサーバをセットアップします。
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
- Spam Filter Systemp
  - Rspamd 
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
  - メールアーカイブ機能
  - MTA-STS に対応
  - マルチドメイン対応
# セットアップ手順
## 1. APIキーの登録
## 2. メールアドレス用ドメインの追加
- グローバル DNS に ゾーンを追加
## 3. サーバの作成
```
下記は example.com をドメインとした場合の例です
```
- "アーカイブ選択" で RHEL 8互換のアーカイブを選択 (CentOS 8.x 又は CentOS Stream 8 など)
- "ホスト名" はドメインを省いたものを入力してください (例: mail と入力した場合、 mail.example.com というホスト名になります)
- "スタートアップアクリプト" で shell を選択
- "配置するスタートアップスクリプト"で MailSystem を選択
- "作成するメールアドレスのリスト" に初期セットアップ時に作成するメールアドレスを1行に1つ入力
![create02](https://user-images.githubusercontent.com/7104966/30677401-8a5291a2-9ec6-11e7-8219-dfec28f7bf90.png)
- "APIキー" を選択 (DNSのレコード登録に使用します)
- "メールアーカイブを有効にする" 場合は チェックしてください
- "cockpitを有効にする" 場合は チェックしてください (389-dsのcockpit pluginもインストールします)
- "セットアップ完了メールを送信する宛先" に、メールを受信できるアドレスを入力
![create03](https://user-images.githubusercontent.com/7104966/30677427-a4594988-9ec6-11e7-9f40-506e31c2e707.png)
- 必要な項目を入力したら作成
## 4. セットアップ完了メール の確認
- セットアップ完了後に、セットアップ情報を記述したメールが届きます
- メールが届かない場合は、サーバにログインしインストールログを確認してください

```
SETUP START : Tue Sep 12 01:34:13 JST 2017
SETUP END   : Tue Sep 12 01:50:08 JST 2017

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

-- Cockpit --
LOGIN URL : https://example.com/cockpit

-- Application Version --
os: CentOS Stream release 8
389ds: 1.4.3.17
dovecot: 2.3.8
clamd: 0.103.0
rspamd: 2.7
redis: 5.0.3
postfix: 3.5.9
mysql: 8.0.21
php-fpm: 7.2.24
nginx: 1.14.1
roundcube: 1.4.11
phpldapadmin: 1.2.3

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
OK: _adsp._domainkey.example.com TXT "dkim=discardable"
OK: default._domainkey.example.com TXT "v=DKIM1\; k=rsa\; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDkviwuC8KvC6OP7HwUPQEZDA+ZnY1mRzZrCJcM4sMRhhVse7Cwy/VOldbIxGTAnsRSaLmmxcz96aiCftvctue7mzIvFscCDRm35PtAS5mvlWXRP1f2brHROLoc0rv7upliPdwNXmc7UhZ2b8/gJhSDw76nFiOiOG7/x5GkLCZLCQIDAQAB"
OK: _mta-sts.example.com TXT "v=STSv1; id=20210225090207;"
OK: _smtp._tls.example.com TXT "v=TLSRPTv1; rua=mailto:sts-report@example.com"

-- example.com TLS Check --
Validity:
 Not Before: Feb 24 23:04:05 2021 GMT
 Not After : May 25 23:04:05 2021 GMT
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
    - TXT レコード (SPF, DKIM, DKIM-ADSP, DMARC, MTA-STS)
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
- rspamd
  - 送信メールの DKIM, ARC 署名
  - 受信メールの SPF, DKIM, DMARC, ARC 検証
  - 受信メールの Spam Check
  - 送受信メールの Virus Scan (clamav と連携)
- clamav
  - 送受信メールの ウィルススキャンサーバ
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
  - メールアカウント管理
- certbot
  - TLS対応(Lets Encrypt)
- cockpit
  - サーバ管理
- Thunderbird の autoconfig設定
## phpldapadminのログイン
- ログイン後、メールアドレスの追加/削除/無効化/パスワード変更などができる
  - メールアドレスの追加は、既存のユーザのレコードをコピーし、固有なIDのみ変更すること

![phpldapadmin](https://user-images.githubusercontent.com/7104966/30680400-580b6066-9eda-11e7-9c0d-d4c721fefb64.png)

## ThunderBirdへのアカウント追加
- autoconfigによりメールアドレスとパスワードの入力だけで設定が完了する

![thunderbird](https://user-images.githubusercontent.com/7104966/30680317-d9df3d70-9ed9-11e7-8168-fffb5fa4aa9d.png)

## 補足
- 1通のメールサイズは20MBまで、MBOXのサイズ、保存通数に制限は設定していない
- 転送設定の最大転送先アドレスは32アドレス
- adminアドレスはエイリアス設定をしている (下記のアドレス宛のメールは admin 宛に配送される)
    - admin, root, postmaster, abuse, nobody, dmarc-report, sts-report
- virus メールについて
    - clamavで Virus と判定したメールは、送受信を拒否する(reject)
- rspamd が正常に動作していない場合、postfixは tempfail を応答する
- メールアーカイブ機能
    - メールアーカイブを有効にすると、全てのユーザの送信/受信メールがarchive用のアドレスに複製配送(bcc)される
    - archive用のメールボックスのみ cron で 受信日時から1年経過したメールを自動で削除する
- マルチドメイン設定方法
    - さくらのクラウドDNSに複数ゾーンを追加し、サーバ作成時に複数のドメインのメールアドレスを入力する
    - MTA-STSの対応は1つ目のドメインのみ
- 各種OSSの設定、操作方法についてはOSSの公式のドキュメントをご参照ください

## コマンドでのメールアドレスの管理

```
・メールアドレスの確認
# ldapsearch -x mailroutingaddress=admin@example.com
objectClass: mailRecipient
objectClass: top
mailMessageStore: 127.0.0.1
mailHost: 127.0.0.1
mailAccessDomain: example.com
mailRoutingAddress: admin@example.com
mailAlternateAddress: admin@example.com
mailAlternateAddress: root@example.com
mailAlternateAddress: postmaster@example.com
mailAlternateAddress: abuse@example.com
mailAlternateAddress: nobody@example.com
mailAlternateAddress: dmarc-report@example.com
mailAlternateAddress: sts-report@example.com
uid: admin

※)mailAlternateAddress 宛のメールが mailRoutingAddress のMBOXに配送される
※)nginx は mailHost に SMTP を Proxy する
※)nginx は mailMessageStore に POP/IMAP を Proxy する
※)postfix-inbound は mailMessageStore に LMTP で配送をする

・パスワード変更: archive@example.com のパスワードを xxxxxx に変更する(******は ROOT_DNのパスワード)
# ldappasswd -x -D "cn=manager" -w ****** -s xxxxxx "uid=archive,ou=People,dc=example,dc=com"

・メールアドレス無効化: foobar@example.com の ou を People から Termed に変更する
ldapmodify -D cn=manager -W
dn: uid=foobar,ou=People,dc=example,dc=com
changetype: modrdn
newrdn: uid=foobar
deleteoldrdn: 0
newsuperior: ou=Termed,dc=example,dc=com

・メールアドレス追加 (作成したメールアドレスのパスワードが出力されます)
# /root/.sacloud-api/notes/cloud-startupscripts/publicscript/mailsystem/tools/389ds_create_mailaddress.sh adduser@example.com

```
