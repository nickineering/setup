.PHONY: dev lint test setup fix check update-formatters update-actions

dev: lint test

lint: fix shellcheck

test:
	bats tests/

setup:
	./util/setup.sh

fix:
	shellharden --replace **/*.sh
	dprint fmt

check:
	shellcheck -S warning **/*.sh
	dprint check

update-formatters:
	dprint config update

update-actions:
	@echo "Checking for GitHub Action updates..."
	@latest=$$(curl -s https://api.github.com/repos/actions/checkout/tags | grep -m1 '"name"' | cut -d'"' -f4); \
		sed -i '' "s|actions/checkout@v[0-9]*|actions/checkout@$$latest|g" .github/workflows/*.yml; \
		echo "actions/checkout -> $$latest"
	@latest=$$(curl -s https://api.github.com/repos/ludeeus/action-shellcheck/tags | grep -m1 '"name"' | cut -d'"' -f4); \
		sed -i '' "s|ludeeus/action-shellcheck@[0-9.]*|ludeeus/action-shellcheck@$$latest|g" .github/workflows/*.yml; \
		echo "ludeeus/action-shellcheck -> $$latest"
	@latest=$$(curl -s https://api.github.com/repos/mfinelli/setup-shfmt/tags | grep -m1 '"name"' | cut -d'"' -f4); \
		sed -i '' "s|mfinelli/setup-shfmt@v[0-9.]*|mfinelli/setup-shfmt@$$latest|g" .github/workflows/*.yml; \
		echo "mfinelli/setup-shfmt -> $$latest"
	@latest=$$(curl -s https://api.github.com/repos/dprint/check/tags | grep -m1 '"name"' | cut -d'"' -f4); \
		sed -i '' "s|dprint/check@v[0-9.]*|dprint/check@$$latest|g" .github/workflows/*.yml; \
		echo "dprint/check -> $$latest"
