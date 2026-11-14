#!/usr/bin/env bats
# The agent skill (ADR 0019) describes the installed system to a coding agent,
# so it must not drift from the system: every command, path, theme and bundle
# it names has to exist in this repository.

setup() {
  repo="$BATS_TEST_DIRNAME/.."
}

# named PATTERN: every match of PATTERN in the skills, one per line, unique.
named() {
  grep -rhoE -- "$1" "$repo"/skills | sort -u
}

@test "every skill has frontmatter agents accept: its directory as the name, and a description" {
  for dir in "$repo"/skills/*/; do
    name="$(basename -- "$dir")"
    file="$dir/SKILL.md"
    [[ "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ && ${#name} -le 64 ]] || { echo "bad skill name: $name"; return 1; }
    [ "$(sed -n 1p "$file")" = "---" ] || { echo "no frontmatter: $file"; return 1; }
    front="$(sed -n '2,/^---$/p' "$file")"
    grep -qx "name: $name" <<<"$front" || { echo "name is not $name: $file"; return 1; }
    # The description is a folded block: the indented lines after its key.
    desc="$(sed -n '/^description: *>$/,$p' <<<"$front" | sed -n 's/^  //p' | tr '\n' ' ')"
    [ -n "$desc" ] || { echo "no description: $file"; return 1; }
    [ "${#desc}" -le 1024 ] || { echo "description is ${#desc} characters, over 1024: $file"; return 1; }
  done
}

@test "the skill names every pyre command" {
  for file in "$repo"/src/cli/commands/*; do
    cmd="$(basename -- "$file")"
    grep -rqE -- "pyre $cmd\b" "$repo/skills/pyre" || { echo "the skill never names: pyre $cmd"; return 1; }
  done
}

@test "every pyre command the skill names exists" {
  # In code: after a backtick, or at the start of a line in a code block.
  found=0
  while IFS= read -r cmd; do
    [ -f "$repo/src/cli/commands/$cmd" ] || { echo "no such command: pyre $cmd"; return 1; }
    found=$((found + 1))
  done < <(named '(`|^)pyre [a-z][a-z-]*' | sed -E 's/^`?pyre //' | sort -u)
  [ "$found" -ge 5 ]
}

@test "every theme and bundle the skill names exists" {
  found=0
  while IFS= read -r theme; do
    [ -f "$repo/themes/$theme/theme.toml" ] || { echo "no such theme: $theme"; return 1; }
    found=$((found + 1))
  done < <(named 'pyre theme set [a-z]+' | sed 's/.* //')
  [ "$found" -ge 1 ]
  found=0
  while IFS= read -r bundle; do
    [ -f "$repo/packages/pyre-bundle-$bundle/PKGBUILD" ] || { echo "no such bundle: $bundle"; return 1; }
    found=$((found + 1))
  done < <(named 'pyre (install|remove) [a-z]+' | sed 's/.* //')
  [ "$found" -ge 1 ]
}

@test "every installed path the skill names comes from a file in this repository" {
  # Installed prefix, then where the package takes it from (the PKGBUILDs).
  found=0
  while read -r prefix source; do
    while IFS= read -r path; do
      rel="${path#"$prefix"}"
      rel="${rel%.}"
      [ -e "$repo/$source$rel" ] || { echo "$path: no $source$rel in the repository"; return 1; }
      found=$((found + 1))
    done < <(named "$prefix[A-Za-z0-9._/-]*")
  done <<'PATHS'
/usr/share/pyre/defaults/ defaults/
/usr/share/pyre/themes/ themes/
/usr/share/pyre/skills/ skills/
/usr/lib/pyre/commands/ src/cli/commands/
/etc/skel/ skel/
/usr/share/doc/pyre/guide/ docs/guide/
PATHS
  [ "$found" -ge 10 ]
  # Guide pages named without their folder.
  while IFS= read -r page; do
    [ -f "$repo/docs/guide/$page" ] || { echo "no guide page: $page"; return 1; }
  done < <(named '\b0[0-9]-[a-z-]+\.md')
}

@test "SKILL.md links every topic file" {
  for file in "$repo"/skills/pyre/*.md; do
    name="$(basename -- "$file")"
    [ "$name" = SKILL.md ] || grep -qF "($name)" "$repo/skills/pyre/SKILL.md" || { echo "SKILL.md does not link $name"; return 1; }
  done
}
