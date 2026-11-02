# A minimal MQTT 3.1.1 broker over WebSocket, for testing online co-op without the internet:
# CONNECT, SUBSCRIBE, PUBLISH (QoS 0, exact topic match), PINGREQ, DISCONNECT. Needs `websockets`.
#   python3 tools/mqtt_ws_broker.py 8899
#   then start the games with --signal=ws://127.0.0.1:8899/mqtt
import asyncio
import sys

import websockets

subs = {}   # websocket -> set of topics


def remaining_length(buf, i=1):
    mult, length = 1, 0
    while i < len(buf) and i <= 4:
        b = buf[i]
        length += (b & 0x7F) * mult
        mult *= 128
        i += 1
        if not b & 0x80:
            return length, i
    return None, None


async def handler(ws):
    subs[ws] = set()
    buf = b''
    try:
        async for msg in ws:
            buf += msg if isinstance(msg, bytes) else msg.encode()
            while len(buf) >= 2:
                length, start = remaining_length(buf)
                if length is None or len(buf) < start + length:
                    break
                kind, body, raw = buf[0] >> 4, buf[start:start + length], buf[:start + length]
                buf = buf[start + length:]
                if kind == 1:                                   # CONNECT
                    await ws.send(bytes([0x20, 2, 0, 0]))
                elif kind == 8:                                 # SUBSCRIBE
                    pid, j = body[:2], 2
                    codes = []
                    while j < len(body):
                        tl = (body[j] << 8) | body[j + 1]
                        subs[ws].add(body[j + 2:j + 2 + tl].decode())
                        j += 2 + tl + 1
                        codes.append(0)
                    await ws.send(bytes([0x90, 2 + len(codes)]) + pid + bytes(codes))
                elif kind == 3:                                 # PUBLISH
                    tl = (body[0] << 8) | body[1]
                    topic = body[2:2 + tl].decode()
                    for other, topics in list(subs.items()):
                        if topic in topics:
                            try:
                                await other.send(raw)
                            except websockets.ConnectionClosed:
                                pass
                elif kind == 12:                                # PINGREQ
                    await ws.send(bytes([0xD0, 0]))
                elif kind == 14:                                # DISCONNECT
                    await ws.close()
    except websockets.ConnectionClosed:
        pass
    finally:
        subs.pop(ws, None)


async def main(port):
    async with websockets.serve(handler, '127.0.0.1', port, subprotocols=['mqtt']):
        print('mqtt-over-websocket broker on', port, flush=True)
        await asyncio.Future()


if __name__ == '__main__':
    asyncio.run(main(int(sys.argv[1]) if len(sys.argv) > 1 else 8899))
