# shellcheck shell=sh
# PyreOS: commands installed into your home are found (ADR 0022). Tools that
# install themselves per user, such as uv, pipx and vendor installers, put
# their commands in ~/.local/bin.
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) PATH="$HOME/.local/bin:$PATH" ;;
esac
export PATH
