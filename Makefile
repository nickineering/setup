.PHONY: dev lint test setup fix check update-formatters update-actions

dev: lint test

lint: fix check

test:
	bats tests/

setup:
	./run.sh

# git ls-files rather than **/*.sh: make runs these under sh, where ** is not
# recursive, so a plain glob reached 40 of the 52 shell files and silently
# skipped every nested one.
fix:
	git ls-files -z '*.sh' '*.bats' | xargs -0 shellharden --replace
	git ls-files -z '*.py' | xargs -0 ruff format
	dprint fmt

check:
	git ls-files -z '*.sh' '*.bats' | xargs -0 shellcheck -S warning
	git ls-files -z '*.py' | xargs -0 ruff format --check
	git ls-files -z '*.py' | xargs -0 ruff check
	dprint check

update-formatters:
	dprint config update

update-actions:
	lib/update_actions.sh
