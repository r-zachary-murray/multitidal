Simulation += Simulation_data.o orbit.o poly2.o read_table.o Multitidal_interface.o Multitidal_findExtrema.o
Driver += nr.o nrutil.o 
MagneticResistivity += Multitidal_interface.o

nrutil.o : nrtype.o
Simulation_init.o : Simulation_data.o 
Simulation_initBlock.o : Simulation_data.o
