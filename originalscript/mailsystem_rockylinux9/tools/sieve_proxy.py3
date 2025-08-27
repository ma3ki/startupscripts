#!/usr/bin/python3

import asyncio
import ldap
import sys
import base64
import logging
import os

# --- プロキシ設定 ---
PROXY_HOST = os.environ.get('PROXY_HOST', '127.0.0.1')
PROXY_PORT = int(os.environ.get('PROXY_PORT', 14190))

# --- LDAP設定 ---
LDAP_SERVER = os.environ.get('LDAP_SERVER', 'ldap://127.0.0.1')
SIF_SERVER_ATTR = os.environ.get('SIF_SERVER_ATTR', 'mailHost')

# --- ロギング設定 ---
LOG_FORMAT = '%(asctime)s - %(levelname)s - %(message)s'
LOG_FILE = os.environ.get('LOG_FILE', '/var/log/sieve-proxy.log')

file_handler = logging.FileHandler(LOG_FILE)
file_handler.setFormatter(logging.Formatter(LOG_FORMAT))
file_handler.setLevel(logging.INFO)

stream_handler = logging.StreamHandler(sys.stdout)
stream_handler.setFormatter(logging.Formatter(LOG_FORMAT))
stream_handler.setLevel(logging.INFO)

logger = logging.getLogger()
logger.setLevel(logging.INFO)
logger.addHandler(file_handler)
logger.addHandler(stream_handler)

# --- Sieveプロトコルの初期応答 ---
SIEVE_GREETING = """
"IMPLEMENTATION" "Sieve Proxy"
"SIEVE" "fileinto reject envelope encoded-character vacation subaddress comparator-i;ascii-numeric relational regex imap4flags copy include variables body enotify environment mailbox date index ihave duplicate mime foreverypart extracttext vacation-seconds editheader imapflags notify"
"SASL" "PLAIN LOGIN"
"VERSION" "1.0"
OK "Sieve Proxy ready."
"""
SIEVE_GREETING_BYTES = SIEVE_GREETING.strip().replace('\n', '\r\n').encode('utf-8') + b'\r\n'

async def read_response_lines(reader):
    """複数行にわたるサーバーの応答を、OKまたはNOが来るまで読み込む"""
    lines = []
    while True:
        line = await reader.readuntil(b'\r\n')
        lines.append(line)
        if line.startswith(b'OK') or line.startswith(b'NO'):
            break
    return b"".join(lines)

async def forward_data(reader, writer):
    """通信を一方的に中継するヘルパー関数"""
    try:
        while True:
            data = await reader.read(4096)
            if not data:
                break
            writer.write(data)
            await writer.drain()
    except asyncio.CancelledError:
        pass
    except Exception as e:
        logger.error(f"Communication error: {e}", exc_info=True)
    finally:
        writer.close()

async def handle_sieve_proxy(client_reader, client_writer):
    addr = client_writer.get_extra_info('peername')
    username = None

    try:
        logger.info(f"Client connection initiated from {addr}.")
        
        client_writer.write(SIEVE_GREETING_BYTES)
        await client_writer.drain()
        logger.debug("Sieve greeting sent to client.")

        full_auth_command = await client_reader.readuntil(b'\r\n')
        logger.debug(f"Received full command from client: {full_auth_command!r}")

        if full_auth_command.startswith(b'AUTHENTICATE "PLAIN"'):
            parts = full_auth_command.strip().split(b'"')
            if len(parts) >= 4:
                base64_auth = parts[3]
                logger.debug(f"Isolated Base64 data from client: {base64_auth!r}")
                
                decoded_auth = base64.b64decode(base64_auth).decode()
                credentials_parts = decoded_auth.split('\x00')
                username = credentials_parts[1]
                
                logger.debug(f"Parsed username: {username}")
                
                password = credentials_parts[2]
                username_part, domain_part = username.split('@', 1)
                domain_components = ','.join([f"dc={dc}" for dc in domain_part.split('.')])
                user_dn = f"uid={username_part},ou=People,{domain_components}"
                logger.debug(f"LDAP DN constructed for authentication: {user_dn}")
                
                ldap_conn = ldap.initialize(LDAP_SERVER)
                try:
                    ldap_conn.simple_bind_s(user_dn, password)
                    logger.debug(f"LDAP authentication successful for {username}.")
                except ldap.INVALID_CREDENTIALS:
                    logger.warning(f"LDAP authentication failed for {username}: Invalid credentials.")
                    client_writer.write(b'NO Authentication failed\r\n')
                    await client_writer.drain()
                    return
                except Exception as e:
                    logger.error(f"Unexpected LDAP error during authentication for {username}: {e}", exc_info=True)
                    client_writer.write(b'NO Internal error\r\n')
                    await client_writer.drain()
                    return

                result = ldap_conn.search_s(
                    user_dn, 
                    ldap.SCOPE_BASE,
                    f"(objectClass=*)",
                    [SIF_SERVER_ATTR]
                )
                
                if not result or not result[0][1].get(SIF_SERVER_ATTR):
                    logger.warning(f"Sieve server information not found for {username}.")
                    client_writer.write(b'NO Sieve server not found\r\n')
                    await client_writer.drain()
                    return
                    
                sieve_server = result[0][1][SIF_SERVER_ATTR][0].decode()
                sieve_port = 4190
                logger.debug(f"Retrieved Sieve server info: {sieve_server}:{sieve_port}")

                server_reader, server_writer = await asyncio.open_connection(sieve_server, sieve_port)
                # このログを削除
                # logger.info(f"Connection to backend Sieve server established for {username}.")

                initial_server_response = await read_response_lines(server_reader)
                logger.debug(f"Received backend Sieve greeting: {initial_server_response!r}")

                server_writer.write(full_auth_command)
                await server_writer.drain()
                logger.debug(f"Authentication command forwarded for {username}.")

                auth_response_line = await read_response_lines(server_reader)
                logger.debug(f"Received final OK response from backend: {auth_response_line!r}")
                
                client_writer.write(auth_response_line)
                await client_writer.drain()
                logger.info(f"Sieve proxy established for {username} to {sieve_server}:{sieve_port}.")

                await asyncio.gather(
                    forward_data(client_reader, server_writer),
                    forward_data(server_reader, client_writer)
                )
            else:
                logger.warning(f"Authentication command parsing failed for {username}.")
                client_writer.write(b'NO "Authentication command parsing failed"\r\n')
                await client_writer.drain()
        else:
            logger.warning(f"Unsupported command received: {full_auth_command!r}")
            client_writer.write(b'NO "Unsupported command"\r\n')
            await client_writer.drain()

    except asyncio.CancelledError:
        logger.info("Task cancelled.")
    except Exception as e:
        logger.error(f"An unhandled error occurred: {e}", exc_info=True)
    finally:
        logger.info(f"Connection from {addr} terminated for {username}.")
        if client_writer:
            client_writer.close()
        if server_writer:
            server_writer.close()

async def main():
    try:
        server = await asyncio.start_server(
            handle_sieve_proxy, PROXY_HOST, PROXY_PORT
        )
        addr = server.sockets[0].getsockname()
        logger.info(f"Sieve proxy started and listening on {addr}.")

        async with server:
            await server.serve_forever()
    except Exception as e:
        logger.error(f"Failed to start proxy server: {e}", exc_info=True)

if __name__ == "__main__":
    asyncio.run(main())
