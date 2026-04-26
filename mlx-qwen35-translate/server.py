#!/usr/bin/env python3
import json
import os
import signal
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from threading import Lock
from urllib.parse import parse_qs, urlparse

from mlx_lm import load, generate

HOST = os.environ.get('MLX_TRANSLATE_HOST', '127.0.0.1')
PORT = int(os.environ.get('MLX_TRANSLATE_PORT', '5010'))
MODEL_ID = os.environ.get('MLX_TRANSLATE_MODEL', 'mlx-community/Qwen3.5-0.8B-4bit')
MAX_TOKENS = int(os.environ.get('MLX_TRANSLATE_MAX_TOKENS', '512'))

LANGUAGES = [
    {"code": "en", "name": "English"},
    {"code": "zh", "name": "Chinese"},
    {"code": "ja", "name": "Japanese"},
    {"code": "es", "name": "Spanish"},
    {"code": "fr", "name": "French"},
    {"code": "de", "name": "German"},
    {"code": "ko", "name": "Korean"},
    {"code": "ru", "name": "Russian"},
]
LANGUAGE_NAMES = {item['code']: item['name'] for item in LANGUAGES}
LANGUAGE_NAMES.update({
    'zh-CN': 'Simplified Chinese',
    'zh-TW': 'Traditional Chinese',
    'pt': 'Portuguese',
    'it': 'Italian',
    'id': 'Indonesian',
    'vi': 'Vietnamese',
    'th': 'Thai',
})

print(f'Loading model: {MODEL_ID}', flush=True)
MODEL, TOKENIZER = load(MODEL_ID)
print('Model loaded.', flush=True)
MODEL_LOCK = Lock()


def language_name(code: str | None) -> str:
    if not code:
        return 'Auto-detected language'
    return LANGUAGE_NAMES.get(code, code)


def build_prompt(text: str, source: str | None, target: str) -> str:
    source_name = language_name(source) if source and source != 'auto' else 'the source language'
    target_name = language_name(target)
    messages = [
        {
            'role': 'system',
            'content': 'You are a translation engine. Return only the translation. Preserve line breaks, links, mentions, and emojis. Do not explain.'
        },
        {
            'role': 'user',
            'content': f'Translate the following text from {source_name} to {target_name}. Output only the translation.\n\n{text}'
        }
    ]
    return TOKENIZER.apply_chat_template(
        messages,
        tokenize=False,
        add_generation_prompt=True,
        enable_thinking=False,
    )


def translate_text(text: str, source: str | None, target: str) -> str:
    prompt = build_prompt(text, source, target)
    with MODEL_LOCK:
        output = generate(MODEL, TOKENIZER, prompt=prompt, max_tokens=MAX_TOKENS, verbose=False)
    return output.strip()


class Handler(BaseHTTPRequestHandler):
    server_version = 'MLXTranslateAPI/0.1'

    def _send_json(self, code: int, payload: dict | list):
        body = json.dumps(payload, ensure_ascii=False).encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _read_json(self):
        length = int(self.headers.get('Content-Length', '0'))
        raw = self.rfile.read(length) if length else b'{}'
        content_type = (self.headers.get('Content-Type') or '').lower()
        text = raw.decode('utf-8') if raw else ''
        print(f'Request content-type={content_type} body={text[:1000]}', flush=True)
        if 'application/json' in content_type or text.strip().startswith('{'):
            return json.loads(text or '{}')
        if 'application/x-www-form-urlencoded' in content_type:
            parsed = {k: v[-1] if isinstance(v, list) and v else v for k, v in parse_qs(text, keep_blank_values=True).items()}
            return parsed
        try:
            return json.loads(text or '{}')
        except json.JSONDecodeError:
            return {k: v[-1] if isinstance(v, list) and v else v for k, v in parse_qs(text, keep_blank_values=True).items()}

    def log_message(self, fmt, *args):
        sys.stdout.write('%s - - [%s] %s\n' % (self.address_string(), self.log_date_time_string(), fmt % args))
        sys.stdout.flush()

    def do_GET(self):
        path = urlparse(self.path).path
        if path == '/health':
            self._send_json(200, {'ok': True, 'model': MODEL_ID})
            return
        if path == '/languages':
            self._send_json(200, LANGUAGES)
            return
        self._send_json(404, {'error': 'Not found'})

    def do_POST(self):
        path = urlparse(self.path).path
        if path != '/translate':
            self._send_json(404, {'error': 'Not found'})
            return
        try:
            data = self._read_json()
            text = (data.get('q') or '').strip()
            source = data.get('source') or 'auto'
            target = data.get('target')
            if not text:
                self._send_json(400, {'error': 'Missing q'})
                return
            if not target:
                self._send_json(400, {'error': 'Missing target'})
                return
            translated = translate_text(text, source, target)
            payload = {
                'translatedText': translated,
                'detectedLanguage': {
                    'language': source if source != 'auto' else 'auto'
                }
            }
            self._send_json(200, payload)
        except Exception as exc:
            self._send_json(500, {'error': str(exc)})


def main():
    httpd = ThreadingHTTPServer((HOST, PORT), Handler)
    def shutdown(*_args):
        print('Shutting down...', flush=True)
        httpd.shutdown()
    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)
    print(f'Serving on http://{HOST}:{PORT}', flush=True)
    httpd.serve_forever()


if __name__ == '__main__':
    main()
