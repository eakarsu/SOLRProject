.PHONY: build test audit clean

build:
	python3 -m compileall -q discovery tests
	python3 -c "import _build_backend; print(_build_backend.build_wheel('dist'))"

test:
	python3 -m unittest discover -v

audit:
	python3 scripts/audit_repository.py

clean:
	find discovery tests -type d -name __pycache__ -prune -exec rm -r {} +
