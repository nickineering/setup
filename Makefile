.PHONY: dev lint test setup fix check update-formatters update-actions

dev: lint test

lint: fix check

test:
	bats tests/

setup:
	./run.sh

fix:
	shellharden --replace **/*.sh
	dprint fmt

check:
	shellcheck -S warning **/*.sh
	dprint check

update-formatters:
	dprint config update

update-actions:
	lib/update_actions.sh
