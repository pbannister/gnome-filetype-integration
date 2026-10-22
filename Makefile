#
#	Makefile for the project skeleton.
#
#	This Makefile is the human-facing driver.
#	Each rule calls the appropriate tool instead of reimplementing work:
#		all:    the project's primary artifact (a cheap no-op when current)
#		build:  sh scripts/site-build.sh
#		site:   sh scripts/site-build.sh + sh scripts/site-condense.sh
#		        (the standard page set; see prompts/features/02-project-pages.md)
#		state:  sh scripts/site-state-fetch.sh (refresh the live state file;
#		        run on the owning host)
#		check:  validate generated output (the leak gate over site.out/);
#		        a pipeline project extends this with its own validation mode
#		release: sh scripts/release-package.sh (the files a release publishes)
#		clean:  rm -rf generated output (keeps .gitkeep placeholders)
#		test:   npm test
#		deploy: RETIRED - all publishing to labs.bannister.us goes through
#		        the homelab project (homelab-publish; see the homelab's
#		        documents/09-project-pages-conventions.md). This target
#		        only reminds you of that; use the homelab's make deploy.
#		install: reserved; not yet defined.
#
#	A data pipeline names each rule for the file it produces, adds an `all`
#	target that is a cheap no-op when current, keeps work products unless
#	`--refresh` is asked for, and preserves raw caches; see
#	prompts/03-conventions.md 6.3.
#

all: build

build:
	sh scripts/site-build.sh

site:
	sh scripts/site-build.sh
	sh scripts/site-condense.sh

state:
	sh scripts/site-state-fetch.sh

status:
	sh scripts/status.sh

maturity:
	sh scripts/prompt-maturity.sh

context:
	sh scripts/context-budget.sh

check:
	@if [ -d site.out ]; then sh scripts/leak-gate.sh site.out; else echo '==== nothing to check: site.out/ is not built (run make site)'; fi

release:
	sh scripts/release-package.sh

clean:
	rm -rf dataflow.out/* site.out/* logs/*

test:
	npm test

deploy:
	@echo '==== RETIRED: publishing goes through the homelab project (homelab-publish).'
	@echo '==== Build the pages here (make site / make state), then run the homelab''s "make deploy"'
	@echo '==== to publish (see homelab documents/09-project-pages-conventions.md).'

install:
	@echo '==== No install yet defined'

.PHONY: all build site state status maturity context check release clean test deploy install
