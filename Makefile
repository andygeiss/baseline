# Repository tooling, not a project Makefile — stack/makefile.md governs
# projects; this repo has no code to build. These targets wire the baseline
# into the current user's Claude Code as a personal skill.

SKILL_DIR = $(HOME)/.claude/skills/engineering-baseline

.PHONY: install uninstall

# Symlink, not copy: the repo stays the single source of truth and
# `git pull` is the update mechanism. If something other than a symlink
# already occupies the path, `rm -f` refuses and the install stops.
install:
	mkdir -p $(HOME)/.claude/skills
	rm -f $(SKILL_DIR)
	ln -s $(CURDIR) $(SKILL_DIR)

uninstall:
	rm -f $(SKILL_DIR)
