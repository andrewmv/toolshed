G0 X0 Y120;(Stick out the part)
M190 S0;(Turn off heat bed, don't wait.)
G92 E10;(Set extruder to 10)
G1 E7 F200;(retract 3mm)
M104 S0;(Turn off nozzle, don't wait)
M107;(Turn off part fan)
M84;(Turn off stepper motors.)
