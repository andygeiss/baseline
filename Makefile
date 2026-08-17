# Repository tooling, not a project Makefile — stack/makefile.md governs
# projects; this repo has no code to build. These targets wire the baseline
# into the current user's Claude Code as a personal skill. `install` is the
# first target: a bare `make` installs.

SKILL_DIR = $(HOME)/.claude/skills/engineering-baseline

# Size budgets from README.md *Size budgets*. A token is estimated as four
# bytes: the real count varies by tokenizer, and a budget only has to catch
# growth, not price it. DOC_BUDGET counts the whole document, prose and fenced
# code alike, because a reader pays for both and a split budget only measures
# which side of the fence an author put the answer on. The split is still
# printed, as a diagnosis: prose grows by arguing, code by spelling out what
# the reader can already write. Every other budget is a read path.
DOC_BUDGET       = 3800
CHECKLIST_BUDGET = 4300
FLOOR_BUDGET     = 19500
CHANGE_BUDGET    = 7000

# Every document a checklist can send an agent to. The checklists name their
# documents as bare repository-root paths, so this is the reach path with no
# second list to keep in sync. Expects $$check to name the checklist.
REACHED = grep -ohE '`(patterns|stack|operations)/[a-z0-9.-]+\.md`|`STYLE\.md`' \
	"$$check" | tr -d '`' | sort -u

# The Required reading list, as repository-root paths. Expects $$base to name
# the project-type document.
REQUIRED = sed -n '/^\#\# Required reading/,/^\#\# Open when/p' "$$base" \
	| sed -n 's/^[0-9][0-9]*\. \[[^]]*\](\.\.\/\([^)\#]*\)).*/\1/p'

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

# What the corpus costs an agent to READ — never what it costs to store. The
# repository total is vanity: VERIFICATION.md is a twelfth of it and sits on no
# read path, while the floor every project pays is the number that hurts. Each
# budget below is a path somebody actually walks. Exits non-zero when one is
# blown, so a review run can call it as a gate rather than read it as a report.
tokens:
	@fail=0; \
	echo "== one document =="; \
	echo "each patterns/ or stack/ document, prose and code together: $(DOC_BUDGET)"; \
	over=0; \
	for f in patterns/*.md stack/*.md; do \
		t=$$(( $$(wc -c < "$$f") / 4 )); \
		p=$$(( $$(awk '/^```/{c=!c;next} !c' "$$f" | wc -c) / 4 )); \
		if [ $$t -gt $(DOC_BUDGET) ]; then over=$$((over + 1)); \
			printf "  OVER %5d  (%d prose + %d code)  %s\n" \
				$$t $$p $$(( t - p )) "$$f"; fi; \
	done; \
	if [ $$over -eq 0 ]; then echo "  all within budget"; else \
		echo "  $$over over budget"; fail=1; fi; \
	echo "checklists/*.md: $(CHECKLIST_BUDGET)"; \
	for f in checklists/*.md; do \
		t=$$(( $$(wc -c < "$$f") / 4 )); \
		if [ $$t -gt $(CHECKLIST_BUDGET) ]; then printf "  OVER %6d  %s\n" $$t "$$f"; \
			fail=1; else printf "       %6d  %s\n" $$t "$$f"; fi; \
	done; \
	echo; \
	echo "== one read path =="; \
	echo "floor  $(FLOOR_BUDGET)  before the first line of code"; \
	echo "change $(CHANGE_BUDGET)  an ordinary change to a project that already conforms"; \
	echo "reach  (report)  every document the type can reach — no build fires every row"; \
	printf "\n  %6s %6s %6s  %s\n" floor change reach project-type; \
	for base in project-types/*.md; do \
		name=$${base#project-types/}; name=$${name%.md}; \
		check="checklists/$$name.md"; \
		floor=$$(( $$(cat SKILL.md VERSIONS.md "$$base" "$$check" | wc -c) / 4 )); \
		for d in $$($(REQUIRED)); do \
			floor=$$(( floor + $$(wc -c < "$$d") / 4 )); \
		done; \
		change=$$(( $$(cat SKILL.md VERSIONS.md "$$check" | wc -c) / 4 )); \
		reach=$$floor; \
		req=" $$($(REQUIRED) | tr '\n' ' ') "; \
		for d in $$($(REACHED)); do \
			case "$$req" in *" $$d "*) continue;; esac; \
			reach=$$(( reach + $$(wc -c < "$$d") / 4 )); \
		done; \
		mark=" "; \
		if [ $$floor -gt $(FLOOR_BUDGET) ] || [ $$change -gt $(CHANGE_BUDGET) ]; then \
			mark="!"; fail=1; fi; \
		printf "%s %6d %6d %6d  %s\n" "$$mark" $$floor $$change $$reach "$$name"; \
	done; \
	echo; \
	echo "== where the mass is (report only) =="; \
	echo "  the heaviest documents on each reach path, and whether every project of"; \
	echo "  that type pays them. Frequency is the maintainer's judgement; this ranks"; \
	echo "  what that judgement is worth applying to."; \
	for base in project-types/*.md; do \
		name=$${base#project-types/}; name=$${name%.md}; \
		check="checklists/$$name.md"; \
		echo; echo "  $$name"; \
		req=" $$($(REQUIRED) | tr '\n' ' ') "; \
		for d in $$( { $(REQUIRED); $(REACHED); } | sort -u ); do \
			when="trigger"; \
			case "$$req" in *" $$d "*) when="always ";; esac; \
			printf "  %6d  %s  %s\n" $$(( $$(wc -c < "$$d") / 4 )) "$$when" "$$d"; \
		done | sort -rn | head -8; \
	done; \
	echo; \
	echo "== the repository (report only, never a budget) =="; \
	hot=0; cold=0; \
	for f in $$(find . -name '*.md' -not -path './.git/*'); do \
		n=$$(( $$(wc -c < "$$f") / 4 )); \
		case "$$f" in ./README.md|./VERIFICATION.md) cold=$$((cold + n));; \
			*) hot=$$((hot + n));; esac; \
	done; \
	printf "  hot  %6d  reachable by a building agent\n" $$hot; \
	printf "  cold %6d  README + VERIFICATION: maintainers only, on no read path\n" $$cold; \
	printf "  %d files\n" $$(find . -name '*.md' -not -path './.git/*' | wc -l); \
	exit $$fail
