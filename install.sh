#!/usr/bin/env bash
# Установка claude-team-kit в проект. Ничего не перезаписывает без --force,
# CLAUDE.md и .gitignore дополняет, .claude/settings.json объединяет (если есть jq).
#
#   ./install.sh /путь/к/проекту [--owner ЛОГИН] [--dry-run] [--force]
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TPL="$KIT_DIR/template"
TARGET=""; OWNER=""; DRY=0; FORCE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --owner) OWNER="${2:-}"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help) sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) [ -z "$TARGET" ] && TARGET="$1" || { echo "Лишний аргумент: $1" >&2; exit 1; }; shift ;;
  esac
done
[ -n "$TARGET" ] || { echo "Укажите папку проекта: ./install.sh /путь/к/проекту" >&2; exit 1; }
[ -d "$TARGET/.git" ] || { echo "$TARGET — не корень git-репозитория." >&2; exit 1; }
TARGET="$(cd "$TARGET" && pwd)"

say()  { printf '%s\n' "$*"; }
act()  { if [ "$DRY" = 1 ]; then say "  [dry-run] $*"; else say "  $*"; fi; }

# Владелец: флаг → gh → владелец origin
if [ -z "$OWNER" ] && command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  OWNER="$(gh api user --jq .login 2>/dev/null || true)"
fi
if [ -z "$OWNER" ]; then
  url="$(git -C "$TARGET" remote get-url origin 2>/dev/null || true)"
  if [[ "$url" =~ github\.com[:/]([^/]+)/ ]]; then OWNER="${BASH_REMATCH[1]}"; fi
fi
[ -n "$OWNER" ] || { echo "Не удалось определить владельца, укажите --owner ЛОГИН" >&2; exit 1; }

# Команда проверок по package.json
CHECK=""
if [ -f "$TARGET/package.json" ] && command -v node >/dev/null; then
  CHECK="$(node -e '
    const s=(require(process.argv[1]).scripts)||{};
    console.log(["lint","typecheck","test"].filter(k=>s[k]).map(k=>k==="test"?"npm test":"npm run "+k).join(" && "));
  ' "$TARGET/package.json" 2>/dev/null || true)"
fi

say "claude-team-kit → $TARGET"
say "Владелец: @$OWNER${CHECK:+, проверки: $CHECK}"
say ""

write_file() {  # write_file <исходник> <цель> — с подстановкой владельца и проверок
  local src="$1" dst="$2"
  if [ "$DRY" = 1 ]; then return 0; fi
  mkdir -p "$(dirname "$dst")"
  case "$(basename "$dst")" in
    team.conf|CODEOWNERS) sed -e "s/@OWNER/@$OWNER/g" -e "s/your-github-login/$OWNER/g" "$src" > "$dst" ;;
    *) cp "$src" "$dst" ;;
  esac
  if [ "$(basename "$dst")" = "team.conf" ] && [ -n "$CHECK" ]; then
    local tmp; tmp="$(mktemp)"
    awk -v c="$CHECK" '/^CHECK_CMD=/{print "CHECK_CMD=" c; next} {print}' "$dst" > "$tmp" && mv "$tmp" "$dst"
  fi
  case "$dst" in *.sh) chmod +x "$dst" ;; esac
}

added=0; skipped=0; merged=0
while IFS= read -r -d '' src; do
  rel="${src#"$TPL"/}"; dst="$TARGET/$rel"
  if [ ! -e "$dst" ]; then
    act "+ $rel"; write_file "$src" "$dst"; added=$((added+1)); continue
  fi
  case "$rel" in
    CLAUDE.md)
      if grep -q 'claude-team-kit:start' "$dst"; then
        say "  = $rel (блок набора уже есть)"; skipped=$((skipped+1))
      else
        act "~ $rel (правила команды дописаны в конец)"
        [ "$DRY" = 1 ] || { printf '\n' >> "$dst"; cat "$src" >> "$dst"; }
        merged=$((merged+1))
      fi ;;
    .claude/settings.json)
      if command -v jq >/dev/null; then
        tmp="$(mktemp)"
        jq -s '.[0] * {permissions: ((.[0].permissions // {}) + {
                 deny:  ((.[0].permissions.deny  // []) + .[1].permissions.deny  | unique),
                 allow: ((.[0].permissions.allow // []) + .[1].permissions.allow | unique)})}' \
           "$dst" "$src" > "$tmp"
        if jq -e --slurpfile a "$dst" --slurpfile b "$tmp" -n '$a[0] == $b[0]' >/dev/null; then
          say "  = $rel (разрешения уже есть)"; skipped=$((skipped+1)); rm -f "$tmp"
        else
          act "~ $rel (разрешения объединены)"
          if [ "$DRY" = 0 ]; then mv "$tmp" "$dst"; else rm -f "$tmp"; fi
          merged=$((merged+1))
        fi
      else
        say "  ! $rel уже есть, а jq не установлен — перенесите permissions вручную из $src"; skipped=$((skipped+1))
      fi ;;
    *)
      if [ "$FORCE" = 1 ]; then act "! $rel (перезаписан, --force)"; write_file "$src" "$dst"; added=$((added+1))
      else say "  = $rel уже есть, пропущен (--force чтобы заменить)"; skipped=$((skipped+1)); fi ;;
  esac
done < <(find "$TPL" -type f -print0 | sort -z)

# .gitignore: ключи никогда не попадают в репозиторий
gi="$TARGET/.gitignore"
for line in '.env' '.env.*' '!.env.example'; do
  if ! grep -qxF -- "$line" "$gi" 2>/dev/null; then
    act "~ .gitignore += $line"; [ "$DRY" = 1 ] || printf '%s\n' "$line" >> "$gi"; merged=$((merged+1))
  fi
done

say ""
say "Добавлено: $added, дополнено: $merged, пропущено: $skipped."
cat <<EOF

Дальше (владелец):
  1. Впишите участников в .github/team.conf, зоны — в .github/CODEOWNERS и docs/team/ROLES.md,
     раздел «Проект» — в CLAUDE.md.
  2. Закоммитьте набор в main через PR, затем: scripts/team.sh setup
  3. Пригласите участников (Settings → Collaborators, роль Write).
Дальше (каждый участник): gh auth login, клон репозитория, scripts/team.sh doctor,
первый промпт из docs/team/PROMPTS.md.
EOF
