.PHONY: lint fix check update-formatters

lint: fix shellcheck

fix:
	shellharden --replace **/*.sh
	dprint fmt

check:
	shellcheck -S warning **/*.sh
	dprint check

update-formatters:
	dprint config update
