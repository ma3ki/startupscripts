<?php
  $LoginName = "";
  $raw = file_get_contents('php://input');
  $matches = array();
  preg_match('/<EMailAddress>(.*)<\/EMailAddress>/', $raw, $matches);
  if (isset($matches[1])) {
    $LoginName = "<LoginName>".$matches[1]."</LoginName>";
  }
  $domain = preg_replace('/^autodiscover\./','',$_SERVER['HTTP_HOST']);
  header('Content-Type: application/xml');
?>
<?xml version="1.0" encoding="utf-8" ?>
<Autodiscover xmlns="http://schemas.microsoft.com/exchange/autodiscover/responseschema/2006">
  <Response xmlns="http://schemas.microsoft.com/exchange/autodiscover/outlook/responseschema/2006a">
    <User>
      <DisplayName><?php echo $matches[1]; ?></DisplayName>
    </User>
    <Account>
      <AccountType>email</AccountType>
      <Action>settings</Action>
      <Protocol>
        <Type>IMAP</Type>
        <Server><?php echo $domain; ?></Server>
        <Port>993</Port>
        <SPA>off</SPA>
        <SSL>on</SSL>
        <AuthRequired>on</AuthRequired>
        <DomainRequired>on</DomainRequired>
        <DomainName><?php echo $domain; ?></DomainName>
        <?php echo $LoginName; ?>
      </Protocol>
      <Protocol>
        <Type>POP3</Type>
        <Server><?php echo $domain; ?></Server>
        <Port>995</Port>
        <SPA>off</SPA>
        <SSL>on</SSL>
        <AuthRequired>on</AuthRequired>
        <DomainRequired>on</DomainRequired>
        <?php echo $LoginName; ?>
      </Protocol>
      <Protocol>
        <Type>SMTP</Type>
        <Server><?php echo $domain; ?></Server>
        <Port>465</Port>
        <SPA>off</SPA>
        <SSL>on</SSL>
        <AuthRequired>on</AuthRequired>
        <DomainRequired>on</DomainRequired>
        <DomainName><?php echo $domain; ?></DomainName>
        <?php echo $LoginName; ?>
      </Protocol>
    </Account>
  </Response>
</Autodiscover>
