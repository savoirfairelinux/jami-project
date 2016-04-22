.PHONY: docs
docs: env
	make -C docs html

env:
	virtualenv env
	env/bin/pip install Sphinx==1.4.1 sphinx-rtd-theme==0.1.9

clean:
	rm -rf env
	make -C docs clean
