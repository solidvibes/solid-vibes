# solidvibes install         link the skills into ~/.agents/skills/ for Codex and other agents
# solidvibes install nono    link the sandbox profile into nono's user profiles folder
#
# Skills: every skills/<name>/ of sv, and of sv-pro when found ($SOLIDVIBES_PRO_ROOT,
# else a solid-vibes-pro folder next to this one). Claude Code gets them from the plugin instead.
# Harness: sv-pro's bin/sv-harness → ~/.local/bin/sv-harness, for other agents, `solidvibes run`
# and humans.
# nono: profiles/solidvibes.json → ${XDG_CONFIG_HOME:-~/.config}/nono/profiles/solidvibes.json,
# so `nono run --profile solidvibes` finds it. `solidvibes run` passes the profile by path and
# does not need this.
#
# Only our own links are ever replaced: a link into sv or sv-pro (any version). A real file or
# folder, or a link elsewhere, is left alone and reported; nothing is ever deleted. A link of ours
# whose skill or sv-harness is gone is reported as dangling, and stays.

INSTALL_KEPT=0

# True when <link> is a symlink into one of our trees: its target, or the target's folder two
# levels up, holds a .claude-plugin/plugin.json named sv or sv-pro.
install_own_link() {
  local target dir
  [ -L "$1" ] || return 1
  target="$(readlink "$1")"
  case "$target" in /*) ;; *) target="$(dirname "$1")/$target" ;; esac
  for dir in "$(dirname "$target")/.." "$(dirname "$target")/../.."; do
    [ -f "$dir/.claude-plugin/plugin.json" ] || continue
    grep -qE '"name"[[:space:]]*:[[:space:]]*"sv(-pro)?"' "$dir/.claude-plugin/plugin.json" && return 0
  done
  return 1
}

# install_link <source> <link>
install_link() {
  local src="$1" dst="$2"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    echo "ok        $dst"
  elif [ -L "$dst" ] && install_own_link "$dst"; then
    rm "$dst"
    ln -s "$src" "$dst"
    echo "updated   $dst"
  elif [ -e "$dst" ] || [ -L "$dst" ]; then
    echo "left alone $dst: not a Solid Vibes link" >&2
    INSTALL_KEPT=$((INSTALL_KEPT + 1))
  else
    ln -s "$src" "$dst"
    echo "linked    $dst"
  fi
}

install_skills() {
  local dest="$HOME/.agents/skills" harness="$HOME/.local/bin/sv-harness" pro root skill
  pro="${SOLIDVIBES_PRO_ROOT:-$(dirname "$SOLIDVIBES_ROOT")/solid-vibes-pro}"
  mkdir -p "$dest"
  for root in "$SOLIDVIBES_ROOT" "$pro"; do
    [ -d "$root/skills" ] || continue
    root="$(cd "$root" && pwd -P)"
    for skill in "$root"/skills/*/; do
      [ -f "$skill/SKILL.md" ] || continue
      skill="${skill%/}"
      install_link "$skill" "$dest/$(basename "$skill")"
    done
  done
  for skill in "$dest"/*; do
    if [ -L "$skill" ] && [ ! -e "$skill" ] && install_own_link "$skill"; then
      echo "dangling  $skill: its skill is gone; remove the link if nothing else needs it"
    fi
  done
  if [ -f "$pro/bin/sv-harness" ]; then
    pro="$(cd "$pro" && pwd -P)"
    mkdir -p "$HOME/.local/bin"
    install_link "$pro/bin/sv-harness" "$harness"
    case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) echo "note: $HOME/.local/bin is not on your PATH; add it so sv-harness is found" ;; esac
  elif [ -L "$harness" ] && [ ! -e "$harness" ] && install_own_link "$harness"; then
    echo "dangling  $harness: its target is gone; remove the link if nothing else needs it"
  elif [ -d "$pro" ]; then
    echo "skipped   $harness: sv-pro has no bin/sv-harness yet"
  fi
}

install_nono() {
  local dest="${XDG_CONFIG_HOME:-$HOME/.config}/nono/profiles"
  mkdir -p "$dest"
  install_link "$SOLIDVIBES_ROOT/profiles/solidvibes.json" "$dest/solidvibes.json"
  command -v nono >/dev/null 2>&1 || echo "note: nono is not installed yet (https://nono.sh); the profile is ready for it"
}

cli_install() {
  case "${1:-}" in
    "") install_skills ;;
    nono) install_nono ;;
    *) echo "usage: solidvibes install [nono]" >&2; return 1 ;;
  esac
  if [ "$INSTALL_KEPT" -gt 0 ]; then
    echo "install: $INSTALL_KEPT path(s) left alone; move them away and run again to link them" >&2
    return 1
  fi
}
