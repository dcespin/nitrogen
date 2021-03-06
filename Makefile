
NITROGEN_VERSION=2.1.0

help:
	@echo 
	@echo "Usage: "
	@echo "       make {compile|clean}"        
	@echo
	@echo "       make {rel_cowboy|package_cowboy}"
	@echo "       make {rel_inets|package_inets}"  
	@echo "       make {rel_mochiweb|package_mochiweb}"
	@echo "       make {rel_webmachine|package_webmachine}"
	@echo "       make {rel_yaws|package_yaws}"
	@echo
	@echo "Windows Users:"
	@echo "       make rel_inets_win"
	@echo "       make rel_mochiweb_win"
	@echo "       make rel_cowboy_win"
	@echo 
	@echo "To install the helper script on linux/unix machines:"
	@echo "       make install-helper-script" 

all: get-deps compile

distribute-rebar:
	@(cp rebar rel/rebar; cp rebar rel/overlay/common;)

get-deps: distribute-rebar
	./rebar get-deps

update-deps:
	./rebar update-deps

compile: get-deps
	./rebar compile

clean:
	./rebar clean

install-helper-script:
	@(cd support/helper_script;./install.sh)

## Produce a list of contributors from the main repo and the dependent repos
thanks: get-deps
	perl support/list_thanks/list_thanks.pl

# COWBOY

rel_cowboy: compile
	@rm -rf rel/nitrogen
	@rm -rf rel/reltool.config
	@ln rel/reltool_cowboy.config rel/reltool.config
	@(make rel_inner)
	@echo Generated a self-contained Nitrogen project
	@echo in 'rel/nitrogen', configured to run on Cowboy.

rel_cowboy_win: compile
	@rm -rf rel/nitrogen
	@rm -rf rel/reltool.config
	@ln rel/reltool_cowboy_win.config rel/reltool.config
	@(make rel_inner_win)
	@echo Generated a self-contained Nitrogen project
	@echo in 'rel/nitrogen', configured to run on Cowboy.

package_cowboy: rel_cowboy
	mkdir -p ./builds
	make link_docs
	tar -C rel -c nitrogen | gzip --best > ./builds/nitrogen-${NITROGEN_VERSION}-cowboy.tar.gz

package_cowboy_win: rel_cowboy_win copy_docs
	mkdir -p ./builds
	make copy_docs
	7za a -r -tzip ./builds/nitrogen-${NITROGEN_VERSION}-cowboy-win.zip ./rel/nitrogen/
	rm -fr ./rel/nitrogen

# INETS

rel_inets: compile
	@rm -rf rel/nitrogen
	@rm -rf rel/reltool.config
	@ln rel/reltool_inets.config rel/reltool.config
	@(make rel_inner)
	@echo Generated a self-contained Nitrogen project
	@echo in 'rel/nitrogen', configured to run on Inets.

rel_inets_win: compile
	@rm -rf rel/nitrogen
	@rm -rf rel/reltool.config
	@ln rel/reltool_inets_win.config rel/reltool.config
	@(make rel_inner_win)
	@echo Generated a self-contained Nitrogen project
	@echo in 'rel/nitrogen', configured to run on Inets.

package_inets: rel_inets
	mkdir -p ./builds
	make link_docs
	tar -C rel -c nitrogen | gzip --best > ./builds/nitrogen-${NITROGEN_VERSION}-inets.tar.gz

package_inets_win: rel_inets_win copy_docs
	mkdir -p ./builds
	make copy_docs
	7za a -r -tzip ./builds/nitrogen-${NITROGEN_VERSION}-inets-win.zip ./rel/nitrogen/
	rm -fr ./rel/nitrogen



# MOCHIWEB

rel_mochiweb: compile
	@rm -rf rel/nitrogen
	@rm -rf rel/reltool.config
	@ln rel/reltool_mochiweb.config rel/reltool.config
	@(make rel_inner)
	@echo Generated a self-contained Nitrogen project
	@echo in 'rel/nitrogen', configured to run on Mochiweb.

rel_mochiweb_win: compile
	@rm -rf rel/nitrogen
	@rm -rf rel/reltool.config
	@ln rel/reltool_mochiweb_win.config rel/reltool.config
	@(make rel_inner_win)
	@echo Generated a self-contained Nitrogen project
	@echo in 'rel/nitrogen', configured to run on Mochiweb.

package_mochiweb: rel_mochiweb
	mkdir -p ./builds
	make link_docs
	tar -C rel -c nitrogen | gzip --best > ./builds/nitrogen-${NITROGEN_VERSION}-mochiweb.tar.gz

package_mochiweb_win: rel_mochiweb_win copy_docs
	mkdir -p ./builds
	make copy_docs
	7za a -r -tzip ./builds/nitrogen-${NITROGEN_VERSION}-mochiweb-win.zip ./rel/nitrogen/
	rm -fr ./rel/nitrogen

# WEBMACHINE

rel_webmachine: compile
	@rm -rf rel/nitrogen
	@rm -rf rel/reltool.config
	@ln rel/reltool_webmachine.config rel/reltool.config
	@(make rel_inner)
	@echo Generated a self-contained Nitrogen project
	@echo in 'rel/nitrogen', configured to run on Webmachine.

package_webmachine: rel_webmachine
	mkdir -p ./builds
	make link_docs
	tar -C rel -c nitrogen | gzip --best > ./builds/nitrogen-${NITROGEN_VERSION}-webmachine.tar.gz


# YAWS

rel_yaws: compile
	@rm -rf rel/nitrogen
	@rm -rf rel/reltool.config
	@ln rel/reltool_yaws.config rel/reltool.config
	@(make rel_inner)
	@echo Generated a self-contained Nitrogen project
	@echo in 'rel/nitrogen', configured to run on Yaws.

package_yaws: rel_yaws
	mkdir -p ./builds
	make link_docs
	tar -C rel -c nitrogen | gzip --best > ./builds/nitrogen-${NITROGEN_VERSION}-yaws.tar.gz

# MASS PACKAGING - Produce packages for all servers

package_all: clean update-deps package_inets package_mochiweb package_cowboy package_yaws package_webmachine

package_all_win: clean update-deps package_inets_win package_mochiweb_win package_cowboy_win

clean_docs:
	@(cd rel/nitrogen; rm -fr doc)

copy_docs: clean_docs
	@(echo "Copying Documentation to the release")
	@(cd rel/nitrogen; cp -r lib/nitrogen_core/doc .; cd doc; rm *.pl *.html)

link_docs: clean_docs
	@(echo "Linking Documentation in the release")
	@(cd rel/nitrogen; ln -s lib/nitrogen_core/doc doc)

ERLANG_MAJOR_VERSION_CHECK := erl -eval "erlang:display(erlang:system_info(otp_release)), halt()."  -noshell | grep -o 'R[0-9]\{2\}'
ERLANG_MAJOR_VERSION = $(shell $(ERLANG_MAJOR_VERSION_CHECK))

# This is primarily for Travis build testing, as each build instruction will overwrite the previous
travis:
	@echo Building Nitrogen for Travis for OTP $(ERLANG_MAJOR_VERSION)
ifeq ($(ERLANG_MAJOR_VERSION), R14)
	@(make travis-r14)
else
	@(make travis-r15plus)
endif
	
	
travis-r15plus: rel_cowboy rel_inets rel_yaws rel_mochiweb rel_webmachine

travis-r14: rel_inets rel_yaws rel_mochiweb rel_webmachine

# SHARED


rel_inner:
	@(cd rel; ./rebar generate)
	@(cd rel; escript copy_erl_interface.escript)
	@(cd rel/nitrogen; make; make cookie)
	@printf "Nitrogen Version:\n${NITROGEN_VERSION}\n\n" > rel/nitrogen/BuildInfo.txt
	@echo "Built On (uname -v):" >> rel/nitrogen/BuildInfo.txt
	@uname -v >> rel/nitrogen/BuildInfo.txt
	@cp -r ./deps/nitrogen_core/www rel/nitrogen/site/static/nitrogen
	@rm -rf rel/reltool.config	

rel_inner_win:
	@(cd rel; ./rebar generate)
	@(cd rel; escript copy_erl_interface.escript)
	@(cd rel/nitrogen; cp releases/${NITROGEN_VERSION}/start_clean.boot bin/)
	@(cd rel/nitrogen; make; make cookie)
	@(cd rel/nitrogen; ./make_start_cmd.sh)
	@printf "Nitrogen Version:\n${NITROGEN_VERSION}\n\n" > rel/nitrogen/BuildInfo.txt
	@echo "Built On (uname -v):" >> rel/nitrogen/BuildInfo.txt
	@uname -v >> rel/nitrogen/BuildInfo.txt
	@cp -r ./deps/nitrogen_core/www rel/nitrogen/site/static/nitrogen
	@rm -rf rel/reltool.config rel/nitrogen/make_start_cmd.sh rel/nitrogen/start.cmd.src

rel_copy_quickstart:
	cp -R ../NitrogenProject.com/src/* rel/nitrogen/site/src
	cp -R ../NitrogenProject.com/static/* rel/nitrogen/site/static
	cp -R ../NitrogenProject.com/templates/* rel/nitrogen/site/templates
	rm -rf rel/nitrogen/site/src/nitrogen_website.app.src
	(cd rel/nitrogen; ln -s site/static static)
	(cd rel/nitrogen; ln -s site/templates templates)

rellink:  
	$(foreach app,$(wildcard deps/*), rm -rf rel/nitrogen/lib/$(shell basename $(app))* && ln -sf $(abspath $(app)) rel/nitrogen/lib;)


