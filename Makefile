
# PL/Proxy version
PLPROXY_VERSION = 2.3

# set to 1 to disallow functions containing SELECT
NO_SELECT = 0

# libpq config
PG_CONFIG = pg_config
PQINC = $(shell $(PG_CONFIG) --includedir)
PQLIB = $(shell $(PG_CONFIG) --libdir)

# PostgreSQL version
PGVER = $(shell $(PG_CONFIG) --version | sed 's/PostgreSQL //')
SQLMED = $(shell test $(PGVER) "<" "8.4" && echo "false" || echo "true")

# module setup
MODULE_big = plproxy
SRCS = src/cluster.c src/execute.c src/function.c src/main.c \
       src/query.c src/result.c src/type.c src/poll_compat.c
OBJS = src/scanner.o src/parser.tab.o $(SRCS:.c=.o)
DATA_built = plproxy.sql
EXTRA_CLEAN = src/scanner.[ch] src/parser.tab.[ch] plproxy.sql.in
PG_CPPFLAGS = -I$(PQINC) -DNO_SELECT=$(NO_SELECT)
SHLIB_LINK = -L$(PQLIB) -lpq

TARNAME = plproxy-$(PLPROXY_VERSION)
DIST_DIRS = src sql expected config doc debian
DIST_FILES = Makefile src/plproxy.h src/rowstamp.h src/scanner.l src/parser.y \
			 $(foreach t,$(REGRESS),sql/$(t).sql expected/$(t).out) \
			 config/simple.config.sql src/poll_compat.h \
			 doc/Makefile doc/config.txt doc/faq.txt \
			 doc/syntax.txt doc/todo.txt doc/tutorial.txt \
			 AUTHORS COPYRIGHT README plproxy_lang.sql plproxy_fdw.sql NEWS \
			 debian/packages.in debian/changelog

# regression testing setup
REGRESS = plproxy_init plproxy_test plproxy_select plproxy_many \
	  plproxy_errors plproxy_clustermap plproxy_dynamic_record \
	  plproxy_encoding plproxy_split plproxy_target

# SQL files
PLPROXY_SQL = plproxy_lang.sql

# SQL/MED available, add foreign data wrapper and regression tests
ifeq ($(SQLMED), true)
REGRESS += plproxy_sqlmed
PLPROXY_SQL += plproxy_fdw.sql
endif


REGRESS_OPTS = --dbname=regression

# pg9.1 ignores --dbname
override CONTRIB_TESTDB := regression

# load PGXS makefile
PGXS = $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

ifeq ($(PORTNAME), win32)
SHLIB_LINK += -lws2_32 -lpgport
endif

# PGXS may define them as empty
FLEX := $(if $(FLEX),$(FLEX),flex)
BISON := $(if $(BISON),$(BISON),bison)

# parser rules
src/scanner.o: src/parser.tab.h
src/parser.tab.h: src/parser.tab.c

src/parser.tab.c: src/parser.y
	cd src; $(BISON) -d parser.y

src/scanner.c: src/scanner.l
	cd src; $(FLEX) -oscanner.c scanner.l

plproxy.sql.in: $(PLPROXY_SQL)
	cat $^ > $@

# dependencies
$(OBJS): src/plproxy.h src/rowstamp.h
src/execute.o: src/poll_compat.h
src/poll_compat.o: src/poll_compat.h

# utility rules

tags:
	cscope -I src -b -f .cscope.out src/*.c

oldtgz:
	rm -rf $(TARNAME)
	mkdir -p $(TARNAME)
	tar c $(DIST_FILES) $(SRCS) | tar xp -C $(TARNAME)
	tar czf $(TARNAME).tgz $(TARNAME)

tgz:
	git archive -o $(TARNAME).tar.gz --prefix=$(TARNAME)/ HEAD

clean: tgzclean doc-clean

doc-clean:
	$(MAKE) -C doc clean

tgzclean:
	rm -rf $(TARNAME) $(TARNAME).tar.gz

test: install
	$(MAKE) installcheck || { less regression.diffs; exit 1; }

ack:
	cp results/*.out expected/

maintainer-clean: clean
	rm -f src/scanner.[ch] src/parser.tab.[ch]
	rm -rf debian/control debian/rules debian/packages debian/packages-tmp*

deb82:
	sed -e s/PGVER/8.2/g < debian/packages.in > debian/packages
	yada rebuild
	debuild -uc -us -b

deb83:
	sed -e s/PGVER/8.3/g < debian/packages.in > debian/packages
	yada rebuild
	debuild -uc -us -b

deb84:
	sed -e s/PGVER/8.4/g < debian/packages.in > debian/packages
	yada rebuild
	debuild -uc -us -b

deb90:
	sed -e s/PGVER/9.0/g < debian/packages.in > debian/packages
	yada rebuild
	debuild -uc -us -b

deb91:
	sed -e s/PGVER/9.1/g < debian/packages.in > debian/packages
	yada rebuild
	debuild -uc -us -b

