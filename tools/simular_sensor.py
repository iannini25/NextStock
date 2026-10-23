"""Simulador de sensor de temperatura, so pra desenvolvimento e teste do NextStock.

Faz o papel de um termometro ligado na rede: de tempos em tempos manda uma leitura pro NextStock
usando a chave do sensor (header X-Sensor-Key) no lugar do login.
Quase sempre a temperatura fica dentro da faixa, mas de vez em quando ele manda um pico fora dela
pra disparar o alerta.

Antes, uma vez so:
    1. no backend/.env, preencha SENSOR_API_KEY (gere com: python -c "import secrets; print(secrets.token_hex(32))")
    2. reinicie a API
    3. no app, crie o local de armazenamento e veja o numero dele (aparece no detalhe do local: "Local #3")

Como usar (na raiz do projeto, com a API rodando):
    python tools/simular_sensor.py --local 1
    python tools/simular_sensor.py --local 1 --min 0 --max 5 --intervalo 10 --pico-cada 5
    python tools/simular_sensor.py --local 2 --min -25 --max -18 --vezes 3

A chave vem de --chave, ou da variavel de ambiente SENSOR_API_KEY, ou do backend/.env.
Para com Ctrl+C.
"""
import argparse
import json
import os
import random
import time
import urllib.error
import urllib.request

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


# le so a SENSOR_API_KEY do backend/.env (nao mostra nem guarda nada alem dela)
def chave_do_env():
    caminho = os.path.join(RAIZ, "backend", ".env")
    if not os.path.exists(caminho):
        return ""
    with open(caminho, encoding="utf-8") as arquivo:
        for linha in arquivo:
            linha = linha.strip()
            if linha.startswith("SENSOR_API_KEY="):
                return linha.split("=", 1)[1].strip().strip('"').strip("'")
    return ""


def enviar(url, chave, id_local, temperatura, umidade):
    corpo = json.dumps({"temperatura": temperatura, "umidade": umidade}).encode()
    pedido = urllib.request.Request(
        f"{url}/locais-armazenamento/{id_local}/leituras",
        data=corpo,
        method="POST",
        headers={"Content-Type": "application/json", "X-Sensor-Key": chave},
    )
    try:
        with urllib.request.urlopen(pedido, timeout=10) as resposta:
            return resposta.status, json.loads(resposta.read().decode())
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.loads(e.read().decode())
        except ValueError:
            return e.code, {"erro": f"erro {e.code}"}


def main():
    p = argparse.ArgumentParser(description="Manda leituras de temperatura pro NextStock como se fosse um sensor.")
    p.add_argument("--local", type=int, required=True, help="número do local de armazenamento")
    p.add_argument("--url", default="http://127.0.0.1:5000", help="endereço da API (padrão: %(default)s)")
    p.add_argument("--chave", default=None, help="chave do sensor (padrão: SENSOR_API_KEY do ambiente ou do backend/.env)")
    p.add_argument("--min", type=float, default=0.0, help="mínimo da faixa do local (padrão: %(default)s)")
    p.add_argument("--max", type=float, default=5.0, help="máximo da faixa do local (padrão: %(default)s)")
    p.add_argument("--intervalo", type=float, default=5.0, help="segundos entre leituras (padrão: %(default)s)")
    p.add_argument("--pico-cada", type=int, default=6, help="a cada N leituras manda uma fora da faixa (0 = nunca)")
    p.add_argument("--vezes", type=int, default=0, help="quantas leituras mandar (0 = até apertar Ctrl+C)")
    args = p.parse_args()

    if args.min >= args.max:
        p.error("--min tem que ser menor que --max")
    chave = args.chave or os.getenv("SENSOR_API_KEY") or chave_do_env()
    if not chave:
        p.error("sem chave do sensor: preencha SENSOR_API_KEY no backend/.env (e reinicie a API) ou use --chave")

    print(f"sensor do local {args.local} -> {args.url}  (faixa {args.min:.1f} a {args.max:.1f} °C, Ctrl+C para parar)")
    enviadas = 0
    try:
        while args.vezes == 0 or enviadas < args.vezes:
            enviadas += 1
            pico = args.pico_cada > 0 and enviadas % args.pico_cada == 0
            if pico:  # sobe uns graus acima do maximo, como porta aberta ou compressor parado
                temperatura = args.max + random.uniform(2, 6)
            else:
                margem = (args.max - args.min) * 0.15
                temperatura = random.uniform(args.min + margem, args.max - margem)
            temperatura = round(temperatura, 1)
            umidade = round(random.uniform(55, 80), 1)
            try:
                status, resposta = enviar(args.url, chave, args.local, temperatura, umidade)
            except urllib.error.URLError as e:
                print(f"#{enviadas} {temperatura:5.1f} °C  -> sem conexão com {args.url} ({e.reason}). A API está rodando?")
            else:
                if status == 201:
                    situacao = resposta["local"]["nome_status"]
                    print(f"#{enviadas} {temperatura:5.1f} °C  -> gravada  (local: {situacao}){'  << PICO' if pico else ''}")
                else:
                    print(f"#{enviadas} {temperatura:5.1f} °C  -> recusada ({status}): {resposta.get('erro')}")
                    if status in (401, 404):
                        break  # chave errada ou local que nao existe: nao adianta continuar
            if args.vezes == 0 or enviadas < args.vezes:
                time.sleep(args.intervalo)
    except KeyboardInterrupt:
        pass
    print(f"fim: {enviadas} leitura(s) enviada(s)")


if __name__ == "__main__":
    main()
