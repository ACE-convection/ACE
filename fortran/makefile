# makefile of ACE model
FC = ifort
CHECK = -CB -g -traceback -check all,noarg_temp_created -debug all
FCFLAGS = -r8 -O3 -free -mcmodel=large -heap-arrays 10 -shared-intel -fp-model precise
ifdef DEBUG
  FCFLAGS += $(CHECK)
endif
FINCLUDE = -I/opt/libs-intel-oneapi/netcdf-4.7.4/include
LDLIBS = -L/opt/libs-intel-oneapi/netcdf-4.7.4/lib -lnetcdff 


# code paths
VPATH = src

# objects

LIST = test.F ace_module.F ace_input.F ace_interpolation.F microphy_p3.F
ace_model.exe: test.o ace_module.o ace_input.o ace_interpolation.o microphy_p3.o
test.o: test.F ace_module.o ace_input.o
ace_module.o: ace_module.F microphy_p3.o ace_input.o ace_interpolation.o
microphy_p3.o: microphy_p3.F
ace_input.o: ace_input.F
ace_interpolation.o: ace_interpolation.F

LIST_o = $(LIST:.F=.o)
target = ace_model.exe


all: $(target)

$(LIST_o): %.o: %.F
	$(FC) $(FCFLAGS) $(FINCLUDE) -c $<

$(target) : $(LIST_o)
	$(FC) $(FCFLAGS) $(FINCLUDE) $^ -o $@ $(LDLIBS)

clean:
	rm -rf *.o *.mod ace_model.exe


