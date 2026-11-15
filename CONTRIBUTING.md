# Guía de contribución

## 1. Ramas

| Rama | Tipo | Uso |
|---|---|---|
| `main` | Permanente, **estable** | Versión revisada que se entrega y se demuestra. Solo recibe PR desde `develop`. |
| `develop` | Permanente, **integración** | Rama predeterminada. Recibe todos los PR de trabajo. |
| `feature/<area>-<descripcion>` | Temporal | Nueva funcionalidad o tarea |
| `fix/<area>-<descripcion>` | Temporal | Corrección de errores |
| `docs/<descripcion>` | Temporal | Documentación e informes |

- Las ramas temporales salen de `develop` actualizado y **se eliminan al fusionarse**.
- No hay ramas personales permanentes.
- Nombres en minúsculas, con guiones y sin acentos: `feature/pedidos-registro-folio`,
  `fix/gateway-cors`, `docs/informe-patrones`.

## 2. Flujo de trabajo

```bash
git checkout develop
git pull origin develop
git checkout -b feature/<area>-<descripcion>
# ... cambios ...
git add <archivos>
git commit -m "feat(<area>): descripción breve"
git push -u origin feature/<area>-<descripcion>
```

Después abre un Pull Request **hacia `develop`** en GitHub.

Para entregar: un integrante abre un PR `develop → main`, que se revisa con las mismas reglas.

## 3. Reglas de Pull Request

1. **PR obligatorio:** nadie hace push directo a `main` ni a `develop`, tampoco los administradores.
2. **Destino:** todo PR de trabajo va hacia `develop`. Solo `develop` entra a `main`.
3. **Aprobaciones:** mínimo una aprobación de otro integrante con permisos de escritura.
4. **Conversaciones resueltas:** todos los comentarios de revisión deben quedar resueltos antes de fusionar.
5. **Squash and Merge:** es el único método de fusión permitido. El título del PR se convierte en el commit final, así que debe seguir Conventional Commits.
6. **Eliminación de ramas:** la rama se elimina automáticamente al fusionar.
7. **Un PR, una tarea:** enlaza el Issue con `Closes #N`.
8. **Cambios nuevos invalidan aprobaciones:** si subes commits después de una aprobación, pide revisión otra vez.
9. **Prohibido:** force push a `main` o `develop`, subir secretos, `.env`, bases de datos locales o builds.

## 4. Conventional Commits

Formato: `tipo(alcance): descripción en minúsculas y en presente`

| Tipo | Uso |
|---|---|
| `feat` | Nueva funcionalidad |
| `fix` | Corrección de error |
| `docs` | Documentación |
| `refactor` | Cambio interno sin alterar comportamiento |
| `test` | Pruebas |
| `chore` | Mantenimiento, configuración |
| `ci` | Integración continua |
| `build` | Dependencias o empaquetado |

Alcances sugeridos: `catalogo`, `pedidos`, `recomendar`, `asistente`, `gateway`,
`flutter`, `infra`, `docs`, `repo`.

Ejemplos:

```
feat(pedidos): agrega registro de pedido
fix(flutter): corrige url base en android
docs(api): propone contrato de recomendación
chore(repo): actualiza codeowners
```

Cambio incompatible: agrega `!` (`feat(api)!: ...`) y explícalo en la descripción del PR.

## 5. Revisión

- Revisa en un máximo de 48 horas los PR donde te asignen.
- Comenta de forma concreta: qué cambiar y por qué.
- Usa *Request changes* solo para problemas que bloquean. Las sugerencias menores van como comentario.

