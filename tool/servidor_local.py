"""Servidor local da versão web compilada (build/web).

Diferente do `python -m http.server`, manda `Cache-Control: no-cache` em todos
os arquivos — assim um F5 comum já carrega a compilação nova (antes o
navegador reaproveitava o main.dart.js antigo) — e devolve o index.html para
as rotas do app (ex.: /acompanhamento/pedidos/<id>).

Uso:  .venv\\Scripts\\python.exe tool\\servidor_local.py [porta]   (padrão 8765)
"""
import functools
import http.server
import os
import sys

PORTA = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
RAIZ = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                    'build', 'web')


class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        super().end_headers()

    def send_head(self):
        # Rota do app (não é arquivo) → entrega o index.html
        if not os.path.exists(self.translate_path(self.path)):
            self.path = '/index.html'
        return super().send_head()


if __name__ == '__main__':
    print(f'Servindo {RAIZ} em http://localhost:{PORTA} (sem cache)')
    http.server.ThreadingHTTPServer(
        ('localhost', PORTA), functools.partial(Handler, directory=RAIZ)
    ).serve_forever()
