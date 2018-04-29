require ["copy", "fileinto", "envelope", "vnd.dovecot.pipe", "foreverypart", "mime", "variables"];

if envelope :matches "from" "*" {
 	set "from" "${1}" ;
}

if envelope :matches "to" "*" {
 	set "to" "${1}" ;
}

if header :matches "message-id" "*" {
	set "mid" "${1}" ;
}

if header :mime :param "filename" :matches "Content-Type" "*" {
	#execute :output "result" "attachments.sh" [ "${from}", "${to}", "INBOX", "${mid}" ] ;
	pipe :copy :try "attachments.sh" [ "${from}", "${to}", "INBOX", "${mid}" ];
} else {
	pipe :copy :try "noattachments.sh" [ "${from}", "${to}", "INBOX", "${mid}" ] ;
}

fileinto "INBOX";
