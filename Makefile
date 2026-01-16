.PHONY: test
test:
	helm lint --strict charts/helm-common
	helm template charts/helm-common > /dev/null
