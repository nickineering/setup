.PHONY: lint fix shellcheck format format-check

lint: fix shellcheck

fix:
	shellharden --replace **/*.sh
	shfmt -w .

shellcheck:
	shellcheck -S warning **/*.sh

format:
	shfmt -w .

format-check:
	shfmt -d .
