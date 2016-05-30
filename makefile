
SHELL := /bin/bash

-include .profile

APPLICATION ?= nidata
PYVERSION ?= python3
VIRTUAL_ENV ?= $(abspath .pyenv)
PGHOST ?= localhost
PGPORT ?= 5432
PGUSER ?= $(APPLICATION)
PGDATABASE ?= $(APPLICATION)
PGPASSFILE ?= $(abspath .pgpass)
SCRIPTS := $(abspath bin)
PSQL := psql
PYTHON := $(VIRTUAL_ENV)/bin/python
PIP := $(VIRTUAL_ENV)/bin/pip
GENPASS := tr -dc 'a-zA-Z0-9!$%^&*()-+=~.?' < /dev/urandom | fold -w 64 | head -n 1
DATAPATH ?= $(abspath var)
BELFAST_TREES_CSV := $(DATAPATH)/trees.csv

export VIRTUAL_ENV
export PGHOST
export PGPORT
export PGUSER
export PGDATABASE
export PGPASSFILE


#########################################################################################
# Utility.
#########################################################################################
.PHONY: pgpass data.update

pgpass:
	@if [ -e $(PGPASSFILE) ]; then \
		echo "PGPASSFILE exists ($(PGPASSFILE))."; \
	else \
		echo "Creating PGPASSFILE ($(PGPASSFILE))."; \
		echo "$(PGHOST):$(PGPORT):$(PGDATABASE):$(PGUSER):$$($(GENPASS))" > $(PGPASSFILE) ; \
	fi
	@chmod 0600 $(PGPASSFILE)

data.update:
	@mkdir -p $(DATAPATH)
	@$(PYTHON) $(SCRIPTS)/download_belfast_trees_csv.py $(BELFAST_TREES_CSV)


#########################################################################################
# Initial setup
#########################################################################################
.PHONY: init.pgpass init.data init.requirements init

init.pgpass: pgpass

init.data: data.update

init.requirements:
	@if [ ! -e $(VIRTUAL_ENV) ]; then virtualenv --python=$(PYVERSION) $(VIRTUAL_ENV) && $(PIP) install -U pip; fi
	@$(PIP) install -r requirements.txt

init: init.pgpass init.requirements init.data

#########################################################################################
# SQL.
#########################################################################################
.PHONY: sql.createdb sql.dropdb

sql.createdb:
	@if [ ! -e $(PGPASSFILE) ]; then echo "PGPASSFILE not found. Run 'make pgpass' to create it."; exit 1;fi
	@echo "CREATE ROLE \"$(PGUSER)\" LOGIN PASSWORD '$$(awk -F : '{ print $$5 }' $(PGPASSFILE))' INHERIT CREATEDB;"
	@echo "CREATE DATABASE \"$(PGDATABASE)\" WITH OWNER \"$(PGUSER)\" ENCODING 'utf8';"
	@echo "\connect $(PGDATABASE);"
	@echo "CREATE EXTENSION file_fdw;"
	@echo "CREATE EXTENSION cube;"
	@echo "CREATE EXTENSION earthdistance;"
	@echo "CREATE SERVER nidata_ext FOREIGN DATA WRAPPER file_fdw;"
	@echo "CREATE TYPE tree_condition AS ENUM ('N/A', 'Dead', 'Dying', 'Very Poor', 'Poor', 'Fair', 'Good');"
	@echo "CREATE TYPE tree_age AS ENUM ('Juvenile', 'Young', 'Young Mature', 'Semi-Mature', 'Mature', 'Fully Mature');"
	@echo "CREATE TYPE tree_vigour AS ENUM ('N/A', 'Low', 'Normal');"
	@echo "CREATE FOREIGN TABLE belfast_trees ("
	@echo "    typeoftree VARCHAR(50), speciestype VARCHAR(30), species VARCHAR(80),"
	@echo "    age tree_age, description VARCHAR(140), treesurround VARCHAR(80),"
	@echo "    vigour tree_vigour, condition tree_condition, diameter REAL,"
	@echo "    spreadradius REAL, longitude REAL, latitude REAL, treetag INTEGER,"
	@echo "    treeheight REAL)"
	@echo "SERVER nidata_ext"
	@echo "OPTIONS (format 'csv', header 'true', filename '$(BELFAST_TREES_CSV)', delimiter ',', null '');"

sql.dropdb:
	@echo "DROP DATABASE \"$(PGDATABASE)\";"
	@echo "DROP ROLE \"$(PGUSER)\""



