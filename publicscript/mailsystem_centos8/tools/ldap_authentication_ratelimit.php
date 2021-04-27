<?php
error_reporting(0);

// write syslog
function _writelog($message) {
  openlog("nginx-mail-proxy", LOG_PID, LOG_MAIL);
  syslog(LOG_INFO, "$message");
  closelog();
}

// ldap authentication
function _ldapauth($server,$port,$dn,$passwd) {
  $conn = ldap_connect($server, $port);
  if ($conn) {
    ldap_set_option($conn, LDAP_OPT_PROTOCOL_VERSION, 3);
    $bind = ldap_bind($conn, $dn, $passwd);
    if ($bind) {
      ldap_close($conn);
      return true;
    } else {
      ldap_close($conn);
      return false;
    }
  } else {
    return false;
  }
}

function _mail_proxy($server,$port,$base,$filter,$attribute,$proxyport) {
  $message = "" ;
  $proxyhost = _ldapsearch($server, $port, $base, $filter, $attribute);

  if ($proxyhost === '' ) {
    // proxyhost is not found
    $message = "proxy=failure" ;
    header('Content-type: text/html');
    header('Auth-Status: Invalid login');
  } else {
    // proxyhost is found
    $proxyip = gethostbyname($proxyhost);

    $message = sprintf('proxy=%s:%s', $proxyhost, $proxyport);
    header('Content-type: text/html');
    header('Auth-Status: OK');
    header("Auth-Server: $proxyip");
    header("Auth-Port: $proxyport");
  }
  return $message ;
}

// ldap search
function _ldapsearch($server,$port,$base,$filter,$attribute) {
  $conn = ldap_connect($server, $port);
  if ($conn) {
    ldap_set_option($conn, LDAP_OPT_PROTOCOL_VERSION, 3);
    $sresult = ldap_search($conn, $base, $filter, array($attribute));
    $info = ldap_get_entries($conn, $sresult);
    if ($info[0][$attribute][0] != "" ) {
      return $info[0][$attribute][0];
    }
  }
  return "" ;
}

// set $env from nginx
$env['meth']    = getenv('HTTP_AUTH_METHOD');
$env['user']    = getenv('HTTP_AUTH_USER');
$env['passwd']  = getenv('HTTP_AUTH_PASS');
$env['salt']    = getenv('HTTP_AUTH_SALT');
$env['proto']   = getenv('HTTP_AUTH_PROTOCOL');
$env['attempt'] = getenv('HTTP_AUTH_LOGIN_ATTEMPT');
$env['client']  = getenv('HTTP_CLIENT_IP');
$env['host']    = getenv('HTTP_CLIENT_HOST');
$env['port']    = getenv('HTTP_PORT');

$log = "" ;

// protocol port map
$portmap = array(
  "smtp" => 25,
  "pop3" => 110,
  "imap" => 143,
);

// port searvice name map
$protomap = array(
  "995" => "pops",
  "993" => "imaps",
  "110" => "pop",
  "143" => "imap",
  "587" => "smtp",
  "465" => "smtps",
);

// ldap setting , attribute は全て小文字で記述すること
$ldap = array(
  "host" => "127.0.0.1",
  "port" => 389,
  "basedn" => "",
  "filter" => "(mailRoutingAddress=" . $env['user'] . ")",
  "attribute" => "mailmessagestore",
  "dn" => "",
  "passwd" => "",
);

// split uid and domain
$spmra = preg_split('/\@/', $env['user']);

// make dn
foreach (preg_split("/\./", $spmra[1]) as $value) {
  $ldap['dn'] = $ldap['dn'] . 'dc=' . $value . ',' ;
}
$tmpdn = preg_split('/,$/',$ldap['dn']);
$ldap['basedn'] = $tmpdn[0];
$ldap['dn'] = 'uid=' . $spmra[0] . ',ou=People,' . $ldap['basedn'];

// set search attribute
if ($env['proto'] === 'smtp' ) {
  $ldap['attribute'] = 'mailhost' ;
}

// set log
$log = sprintf('meth=%s, user=%s, client=%s, proto=%s', $env['meth'], $env['user'], $env['client'], $protomap[$env['port']]);

// set password
$ldap['passwd'] = urldecode($env['passwd']);

// set ratelimit
$max_failcnt = 3 ;
$max_rejectcnt = 3 ;
$expire_time = 120 ;
$reject_time = 600 ;
$max_reject_time = 86400 ;

$whitelist = [
  "127.0.0.1",
  "#IPV4"
];

// check whitelist
if ( ! preg_grep("/^$clientip$/", $whitelist) ) {
  $redis = new Redis();
  try {
    $redis->connect('127.0.0.1', 6379);

    $key = $protomap[$env['port']] . ":" . $env['client'] ;
    $clientip = $env['client'] ;
    $failcnt = $redis->Get($key);
    $ttl = $redis->ttl($key);
    $rejectcnt = $redis->hGet('blacklist', $key);

    if ($failcnt >= $max_failcnt && $ttl > 0 ) {
      // $log = sprintf('auth=reject, %s, failcnt=%s, rejectcnt=%s, ttl=%s',$log,$failcnt,$rejectcnt,$ttl);
      $log = sprintf('auth=reject, %s, passwd=%s, failcnt=%s, rejectcnt=%s, ttl=%s',$log,$ldap['passwd'],$failcnt,$rejectcnt,$ttl);
      header('Content-type: text/html');
      header('Auth-Status: Invalid login');
      _writelog($log);
      exit;
    }
  }
  catch(Exception $e) {
  }
  $redis->close();
}

// ldap authentication
if (_ldapauth($ldap['host'], $ldap['port'], $ldap['dn'], $ldap['passwd'])) {
  // authentication successful
  $log = sprintf('auth=successful, %s', $log);
  $proxyport = $portmap[$env['proto']];
  $result = _mail_proxy($ldap['host'], $ldap['port'], $ldap['basedn'], $ldap['filter'], $ldap['attribute'], $proxyport);
  $log = sprintf('%s, %s', $log, $result);
} else {
  // authentication failure
  // $log = sprintf('auth=failure, %s', $log);
  $log = sprintf('auth=failure, %s, passwd=%s', $log, $ldap['passwd']);

  // check whitelist
  if ( ! preg_grep("/^$clientip$/", $whitelist) ) {
    // set failcnt to redis
    $redis = new Redis();
    try {
      $redis->connect('127.0.0.1', 6379);

      $key = $protomap[$env['port']] . ":" . $env['client'] ;
      $ttl = $redis->ttl($key);
      $failcnt = $redis->Get($key) + 1;
      $rejectcnt = $redis->hGet('blacklist', $key);

      if ( $failcnt > $max_failcnt ) {
        $failcnt = 1 ;
      }

      if ( $failcnt < $max_failcnt ) {
        $redis->Set($key,$failcnt,$expire_time + $ttl);
        if ( empty($rejectcnt) ) {
          $rejectcnt = 0;
          $redis->hSet('blacklist', $key, $rejectcnt);
        }
      } else {
        $rejectcnt += 1;
        $redis->hSet('blacklist', $key, $rejectcnt);
        if ( $rejectcnt >= $max_rejectcnt ) {
          $reject_time = $max_reject_time ;
          $redis->hSet('blacklist', $key, 0);
        }
        $redis->Set($key, $failcnt, $reject_time);
      }

      $ttl = $redis->ttl($key);
      $log = sprintf('%s, failcnt=%s, rejectcnt=%s, ttl=%s',$log,$failcnt,$rejectcnt,$ttl);

    }
    catch(Exception $e) {
    }
    $redis->close();
  }
  header('Content-type: text/html');
  header('Auth-Status: Invalid login');
}

_writelog($log);
exit;
?>
