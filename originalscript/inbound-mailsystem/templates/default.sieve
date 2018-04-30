require ["copy", "fileinto", "envelope", "vnd.dovecot.pipe", "foreverypart", "mime", "variables"];

if envelope :matches "from" "*" {
 	set "efrom" "${1}" ;
}

if envelope :matches "to" "*" {
 	set "eto" "${1}" ;
}

if header :matches "message-id" "*" {
	set "mid" "${1}" ;
}

# destination mail box
if true
{
	set "dmbox" "DRAFT" ;
}

if true
{
	pipe :copy :try "mailmove.sh" [ "${eto}", "${mid}", "${efrom}", "${dmbox}" ];
}

if true
{
	pipe :copy :try "mailsend.sh" [ "${efrom}", "${eto}" ];
}
