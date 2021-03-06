# Makefile

PROJECTDIR = ./
SRC 	= env.d init.d gui/*.d   manip.d cell/*.d  command/*.d  text/*.d shape/*.d util/*.d data/*.d
FLAGS	= -L-L/usr/local/lib -L-lgtk-3 -L-lgtkd-2   -L-lpthread -L-lfreetype  -L-lcairo -version=CairoHasPngFunctions -unittest -g
OUT		= exe

.PHONY : all
all : 
	@dmd -of$(OUT) $(SRC) $(FLAGS) 

.d.o :
	dmd -c $<

.PHONY : run
run :
	@./$(OUT)
.PHONY : clean
clean :
	@rm *.o
