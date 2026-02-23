VIVADO ?= vivado24

generate_project: generate_project.tcl
	$(VIVADO) -mode batch -source generate_project.tcl

clean:
	rm -rf *.log *.jou *.xpr *.cache *.hw *.ip_user_files .Xil *.sim *.runs *.srcs *.gen *.str
