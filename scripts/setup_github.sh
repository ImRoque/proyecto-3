#!/usr/bin/env bash
# =============================================================================
# setup_github.sh — Configuración inicial del repositorio del equipo en GitHub.
#
# Se ejecuta UNA SOLA VEZ, desde la raíz del proyecto, antes de cualquier commit.
# Crea el repositorio, sube main y develop, configura develop como rama
# predeterminada, aplica protecciones, crea etiquetas e invita colaboradores.
# =============================================================================
set -euo pipefail

uso() {
  cat <<'EOF'
Uso:
  ./scripts/setup_github.sh <owner> <repo> <public|private> <colab1> <colab2> <colab3> <colab4>

Argumentos (todos obligatorios):
  owner           Tu usuario de GitHub o la organización dueña del repositorio.
  repo            Nombre del repositorio nuevo (letras, números, ".", "-", "_").
  public|private  Visibilidad. OBLIGATORIA, no hay valor por defecto.
  colab1..colab4  Usuarios de GitHub de tus 4 compañeros (equipo de 5 integrantes).
                  Reciben una invitación con permiso de escritura (push).

Ejemplo:
  ./scripts/setup_github.sh miusuario proyecto-3 private ana-dev luisr mariag pedro99

Requisitos previos:
  1. git y GitHub CLI (gh) instalados.
  2. Sesión iniciada en gh con la cuenta dueña:  gh auth login
  3. git config --global user.name  y  user.email  configurados.
    4. CODEOWNERS no es obligatorio; el equipo utiliza revisiones generales.
  5. Ejecutar desde la raíz del proyecto, sin historial de git previo.
  
Nota: en cuentas gratuitas, GitHub solo permite proteger ramas en repositorios
públicos. Para repositorios privados hace falta GitHub Pro, Team o Education.
EOF
}

error() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }
info()  { printf '\n==> %s\n' "$*"; }
ok()    { printf '    ✓ %s\n' "$*"; }

FALLOS=()
fallo() { FALLOS+=("$1"); printf '    ✗ %s\n' "$1" >&2; }

# ----------------------------------------------------------------- argumentos
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then uso; exit 0; fi
if [[ $# -ne 7 ]]; then
  uso
  error "se requieren exactamente 7 argumentos: owner, repo, visibilidad y los 4 colaboradores (recibidos: $#)."
fi

OWNER="$1"; REPO="$2"; VIS="$3"; shift 3
COLABS=("$@")
FULL="$OWNER/$REPO"
RE_USUARIO='^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?$'
RE_REPO='^[A-Za-z0-9._-]{1,100}$'

[[ "$VIS" == "public" || "$VIS" == "private" ]] \
  || error "la visibilidad debe ser exactamente 'public' o 'private' (recibido: '$VIS')."
[[ "$OWNER" =~ $RE_USUARIO ]] || error "owner inválido: '$OWNER'."
[[ "$REPO" =~ $RE_REPO && "$REPO" != "." && "$REPO" != ".." ]] || error "nombre de repositorio inválido: '$REPO'."

minus() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
VISTOS=" $(minus "$OWNER") "
for u in "${COLABS[@]}"; do
  [[ "$u" =~ $RE_USUARIO ]] || error "usuario de colaborador inválido: '$u'."
  lu="$(minus "$u")"
  [[ "$VISTOS" != *" $lu "* ]] || error "usuario repetido o igual al owner: '$u'."
  VISTOS="$VISTOS$lu "
done

# ----------------------------------------------------------------- raíz
DIR_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
RAIZ="$(dirname "$DIR_SCRIPT")"
[[ "$(pwd -P)" == "$RAIZ" ]] \
  || error "ejecuta el script desde la raíz del proyecto:  cd \"$RAIZ\" && ./scripts/setup_github.sh ..."
for archivo in README.md CONTRIBUTING.md .gitignore .editorconfig \
               .github/pull_request_template.md .github/ISSUE_TEMPLATE/tarea.md \
               .github/ISSUE_TEMPLATE/bug.md; do
  [[ -f "$archivo" ]] || error "no se encontró '$archivo'. ¿Estás en la raíz del proyecto?"
done

# ----------------------------------------------------------------- herramientas
command -v git >/dev/null 2>&1 || error "git no está instalado."
command -v gh  >/dev/null 2>&1 || error "GitHub CLI (gh) no está instalado: https://cli.github.com"
gh auth status >/dev/null 2>&1 || error "no hay sesión en gh. Ejecuta: gh auth login"
git config user.name  >/dev/null || error "falta configurar: git config --global user.name \"Tu Nombre\""
git config user.email >/dev/null || error "falta configurar: git config --global user.email \"tu@correo\""

# ----------------------------------------------------------------- una sola vez
if [[ -e .git ]]; then
  if git rev-parse --verify -q HEAD >/dev/null 2>&1; then
    error "este directorio ya tiene historial de git. El script es solo para la configuración inicial."
  fi
  if git remote get-url origin >/dev/null 2>&1; then
    error "este directorio ya tiene un remoto 'origin'. El script es solo para la configuración inicial."
  fi
fi
if gh repo view "$FULL" >/dev/null 2>&1; then
  error "el repositorio $FULL ya existe en GitHub. No se modificará nada."
fi

# ----------------------------------------------------------------- confirmación
info "Resumen"
echo "    Repositorio:    https://github.com/$FULL ($VIS)"
echo "    Ramas:          main (estable) y develop (integración, predeterminada)"
echo "    Colaboradores:  ${COLABS[*]}"
if [[ "$VIS" == "private" ]]; then
  echo "    AVISO: si tu cuenta es gratuita, GitHub rechazará la protección de ramas en un repo privado."
fi
read -r -p $'\n¿Continuar? Escribe "si" para confirmar: ' RESP
[[ "$RESP" == "si" || "$RESP" == "sí" ]] || error "operación cancelada. No se hizo ningún cambio."

# ----------------------------------------------------------------- 1. git local
info "1. Commit inicial"
if [[ ! -e .git ]]; then
  git init -q
fi
git symbolic-ref HEAD refs/heads/main
git add -A
if git diff --cached --quiet; then
  error "no hay archivos para el commit inicial."
fi
git commit -q -m "chore(repo): estructura inicial del monorepo"
ok "commit creado en main"
git branch develop
ok "rama develop creada"

# ----------------------------------------------------------------- 2. GitHub
info "2. Crear repositorio $FULL"
gh repo create "$FULL" "--$VIS" \
  --description "Proyecto 3 — Tópicos Web y Móvil: integración, aplicación web y móvil" \
  >/dev/null || error "GitHub no creó el repositorio. No se subió nada."
ok "repositorio creado"
trap 'printf "\nERROR: el repositorio %s ya existe pero la configuración no terminó.\nRevisa el mensaje anterior. Para empezar de nuevo: gh repo delete %s y borra la carpeta .git\n" "$FULL" "$FULL" >&2' ERR

gh auth setup-git >/dev/null 2>&1 || true
git remote add origin "https://github.com/$FULL.git"
git push -q -u origin main
git push -q -u origin develop
trap - ERR
ok "main y develop subidas"

# ----------------------------------------------------------------- 3. ajustes
info "3. Rama predeterminada y método de fusión"
if salida=$(gh api -X PATCH "repos/$FULL" \
      -f default_branch=develop \
      -F allow_squash_merge=true \
      -F allow_merge_commit=false \
      -F allow_rebase_merge=false \
      -F delete_branch_on_merge=true \
      -f squash_merge_commit_title=PR_TITLE \
      -f squash_merge_commit_message=PR_BODY 2>&1); then
  ok "develop como predeterminada, solo Squash and Merge y borrado automático de ramas"
else
  echo "$salida" >&2
  fallo "no se aplicó la configuración de rama predeterminada o fusión"
fi

# ----------------------------------------------------------------- 4. protecciones
info "4. Protección de main y develop"
PROTECCION="$(mktemp)"
cat > "$PROTECCION" <<'JSON'
{
  "required_status_checks": null,
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false
  },
  "restrictions": null,
  "required_linear_history": true,
  "required_conversation_resolution": true,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON

ESPERADO=$'true\t1\tfalse\ttrue\ttrue\ttrue\tfalse\tfalse'
for rama in main develop; do
  if ! salida=$(gh api -X PUT "repos/$FULL/branches/$rama/protection" --input "$PROTECCION" 2>&1); then
    echo "$salida" >&2
    fallo "GitHub rechazó la protección de '$rama'"
    continue
  fi
  real=$(gh api "repos/$FULL/branches/$rama/protection" --jq '[
      .enforce_admins.enabled,
      .required_pull_request_reviews.required_approving_review_count,
      .required_pull_request_reviews.require_code_owner_reviews,
      .required_pull_request_reviews.dismiss_stale_reviews,
      .required_linear_history.enabled,
      .required_conversation_resolution.enabled,
      .allow_force_pushes.enabled,
      .allow_deletions.enabled] | @tsv' 2>&1) || real="(error al verificar: $real)"
  if [[ "$real" == "$ESPERADO" ]]; then
    ok "'$rama' protegida y verificada"
  else
    echo "    Esperado: $ESPERADO" >&2
    echo "    Obtenido: $real" >&2
    fallo "la protección de '$rama' no coincide con la esperada"
  fi
done
rm -f "$PROTECCION"

# ----------------------------------------------------------------- 5. etiquetas
info "5. Etiquetas"
ETIQUETAS=(
  "tarea|0E8A16|Tarea del plan de trabajo"
  "bug|D73A4A|Algo no funciona como se esperaba"
)
for e in "${ETIQUETAS[@]}"; do
  IFS='|' read -r nombre color desc <<< "$e"
  if salida=$(gh label create "$nombre" --color "$color" --description "$desc" --force -R "$FULL" 2>&1); then
    ok "$nombre"
  else
    echo "$salida" >&2
    fallo "no se creó la etiqueta '$nombre'"
  fi
done

# ----------------------------------------------------------------- 6. invitaciones
info "6. Invitaciones (permiso de escritura)"
for u in "${COLABS[@]}"; do
  if salida=$(gh api -X PUT "repos/$FULL/collaborators/$u" -f permission=push 2>&1); then
    ok "invitación enviada a $u"
  else
    echo "$salida" >&2
    fallo "no se pudo invitar a '$u'"
  fi
done

# ----------------------------------------------------------------- resumen
echo
if [[ ${#FALLOS[@]} -gt 0 ]]; then
  echo "=================================================================="
  echo " CONFIGURACIÓN INCOMPLETA en https://github.com/$FULL"
  echo "=================================================================="
  for x in "${FALLOS[@]}"; do echo "  - $x"; done
  echo
  echo " Corrige lo anterior desde la web de GitHub (Settings). No vuelvas a"
  echo " ejecutar este script: el repositorio ya existe."
  exit 1
fi

git checkout -q develop
echo "=================================================================="
echo " Repositorio configurado: https://github.com/$FULL"
echo " Rama local activa: $(git rev-parse --abbrev-ref HEAD)"
echo "=================================================================="
echo " Pendiente (manual):"
echo "  - Checks de CI obligatorios: NO configurados. Cuando exista un workflow"
echo "    que se haya ejecutado con éxito, agrégalo en Settings → Branches →"
echo "    main / develop → Require status checks to pass."
echo "  - Pide a tus compañeros que acepten la invitación (correo o"
echo "    https://github.com/$FULL/invitations)."