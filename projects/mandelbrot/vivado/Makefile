VIVADO ?= vivado

export PRJ_DIR = $(abspath ../)
export TOP_DIR = $(abspath ../../../)

generate_project: generate_project.tcl
	mkdir -p project/
	cd project/ && $(VIVADO) -mode batch -source ../generate_project.tcl

clean:
	rm -rf project/
