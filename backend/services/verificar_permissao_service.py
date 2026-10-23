class VerificarPermissaoService:
    def executar(self, usuario):
        return usuario is not None and usuario.perfil == "admin"
