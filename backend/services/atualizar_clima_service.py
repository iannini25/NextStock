import json
import os
import urllib.error
import urllib.parse
import urllib.request
from datetime import date

from repositories.clima_repository import ClimaRepository
from services.utils import virar_data


class AtualizarClimaService:

    URL = "https://api.open-meteo.com/v1/forecast"

    def __init__(self):
        self.repo = ClimaRepository()

    def cidade(self):
        return os.getenv("WEATHER_CITY", "São Paulo")

    def executar(self, forcar=False):
        if not forcar and self._cache_ok():
            return
        try:
            self._buscar_e_salvar()
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError, ValueError, KeyError):
            return

    def _cache_ok(self):
        row = self.repo.buscar_por_data(date.today())
        if not row or not row.atualizado_em:
            return False
        return row.atualizado_em.date() == date.today()

    def _buscar_e_salvar(self):
        lat = os.getenv("WEATHER_LAT", "-23.5505")
        lon = os.getenv("WEATHER_LON", "-46.6333")
        tz = os.getenv("WEATHER_TZ", "America/Sao_Paulo")
        query = urllib.parse.urlencode({
            "latitude": lat,
            "longitude": lon,
            "daily": "temperature_2m_max,precipitation_sum",
            "timezone": tz,
            "past_days": 30,
            "forecast_days": 16,
        })
        url = self.URL + "?" + query
        req = urllib.request.Request(url, headers={"User-Agent": "NextStock/1.0"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            dados = json.loads(resp.read().decode())

        daily = dados["daily"]
        datas = daily["time"]
        temps = daily.get("temperature_2m_max") or []
        chuvas = daily.get("precipitation_sum") or []

        registros = []
        for i, texto_data in enumerate(datas):
            dia = virar_data(texto_data)
            temp = temps[i] if i < len(temps) else None
            chuva = chuvas[i] if i < len(chuvas) else None
            registros.append({
                "data": dia,
                "temperatura": temp,
                "chuva_mm": chuva,
                "condicao": self.classificar(temp, chuva),
            })
        if registros:
            self.repo.salvar_varios(registros)

    def classificar(self, temperatura, chuva_mm):
        chuva = chuva_mm if chuva_mm is not None else 0
        if chuva >= 10:
            return "chuva_forte"
        if chuva >= 2:
            return "chuva"
        if temperatura is None:
            return "normal"
        if temperatura >= 29:
            return "calor"
        if temperatura <= 17:
            return "frio"
        return "normal"
