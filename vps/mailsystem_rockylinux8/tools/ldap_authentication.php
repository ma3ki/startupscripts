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

function _mail_proxy($server,$port,$base,$filter,$attribute,$proxyport,$user) {
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
    header("Auth-User: $user");
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
  "filter" => "(mailAlternateAddress=" . $env['user'] . ")",
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

// mailAlternateAddress で認証する場合のコード
$spmra[0] = _ldapsearch($ldap['host'], $ldap['port'], $ldap['basedn'], $ldap['filter'], "uid");
$authuser = $spmra[0] . '@' . $spmra[1];

$ldap['dn'] = 'uid=' . $spmra[0] . ',ou=People,' . $tmpdn[0];

// set search attribute
if ($env['proto'] === 'smtp' ) {
  $ldap['attribute'] = 'mailhost' ;
}

// set log
if ($env['user'] === $authuser or $spmra[0] === '' ) {
  $log = sprintf('meth=%s, user=%s, client=%s, proto=%s', $env['meth'], $env['user'], $env['client'], $protomap[$env['port']]);
} else {
  $log = sprintf('meth=%s, user=%s, alias=%s, client=%s, proto=%s', $env['meth'], $authuser, $env['user'], $env['client'], $protomap[$env['port']]);
}

// set password
$ldap['passwd'] = urldecode($env['passwd']);

// ldap authentication
if (_ldapauth($ldap['host'], $ldap['port'], $ldap['dn'], $ldap['passwd'])) {
  // authentication successful
  $log = sprintf('auth=successful, %s', $log);
  $proxyport = $portmap[$env['proto']];
  $result = _mail_proxy($ldap['host'], $ldap['port'], $ldap['basedn'], $ldap['filter'], $ldap['attribute'], $proxyport, $authuser);
  $log = sprintf('%s, %s', $log, $result);
} else {
  // authentication failure
  // $log = sprintf('auth=failure, %s', $log);
  $log = sprintf('auth=failure, %s, passwd=%s', $log, $ldap['passwd']);
  header('Content-type: text/html');
  header('Auth-Status: Invalid login');
}

_writelog($log);
exit;
?>
