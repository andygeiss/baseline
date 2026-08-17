# Repository tooling, not a project Makefile — stack/makefile.md governs
# projects; this repo has no code to build. These targets wire the baseline
# into the current user's Claude Code as a personal skill. `install` is the
# first target: a bare `make` installs.

SKILL_DIR = $(HOME)/.claude/skills/engineering-baseline

# Size budgets from README.md *Size budgets*. A token is estimated as four
# bytes: the real count varies by tokenizer, and a budget only has to catch
# growth, not price it. DOC_BUDGET counts prose only — fenced code is the
# payload an agent copies, and capping it would delete the answer.
DOC_BUDGET   = 2500
FLOOR_BUDGET = 19000

.PHONY: install uninstall tokens

# Symlink, not copy: the repo stays the single source of truth and
# `git pull` is the update mechanism. Neither target ever removes anything
# but a symlink: if something else occupies the path, install refuses and
# stops, and uninstall leaves it alone.
install:
	test -f "$(CURDIR)/SKILL.md" || \
		{ echo "run make from the baseline repo root, not via -f" >&2; exit 1; }
	mkdir -p "$(HOME)/.claude/skills"
	if [ -e "$(SKILL_DIR)" ] && [ ! -L "$(SKILL_DIR)" ]; then \
		echo "refusing to replace $(SKILL_DIR): not a symlink" >&2; exit 1; fi
	rm -f "$(SKILL_DIR)"
	ln -s "$(CURDIR)" "$(SKILL_DIR)"

uninstall:
	if [ -L "$(SKILL_DIR)" ]; then rm "$(SKILL_DIR)"; fi

# What the corpus costs to read. Exits non-zero when a budget is blown, so a
# review run can call it as a gate rather than read it as a report.
tokens:
	@fail=0; \
	echo "per-document prose budget: $(DOC_BUDGET) tokens (code excluded)"; \
	over=0; \
	for f in patterns/*.md stack/*.md; do \
		t=$$(( $$(awk '/^```/{c=!c;next} !c' "$$f" | wc -c) / 4 )); \
		if [ $$t -gt $(DOC_BUDGET) ]; then \
			over=$$((over + 1)); printf "  OVER %6d  %s\n" $$t "$$f"; fi; \
	done; \
	if [ $$over -eq 0 ]; then echo "  all within budget"; else \
		echo "  $$over over budget"; fail=1; fi; \
	echo; \
	echo "required-reading floor budget: $(FLOOR_BUDGET) tokens"; \
	for pt in project-types/*.md; do \
		t=$$(( $$(cat SKILL.md VERSIONS.md "$$pt" | wc -c) / 4 )); \
		for d in $$(sed -n '/^## Required reading/,/^## Open when/p' "$$pt" \
				| sed -n 's/^[0-9][0-9]*\. \[[^]]*\](\([^)#]*\)).*/\1/p'); do \
			t=$$(( t + $$(wc -c < "project-types/$$d") / 4 )); \
		done; \
		if [ $$t -gt $(FLOOR_BUDGET) ]; then \
			printf "  OVER %6d  %s\n" $$t "$$pt"; fail=1; \
		else printf "       %6d  %s\n" $$t "$$pt"; fi; \
	done; \
	echo; \
	printf "corpus total: %d tokens in %d files\n" \
		$$(( $$(cat $$(find . -name '*.md' -not -path './.git/*') | wc -c) / 4 )) \
		$$(find . -name '*.md' -not -path './.git/*' | wc -l); \
	exit $$fail
