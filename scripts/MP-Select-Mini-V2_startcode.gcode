M140 S{material_bed_temperature}
M105
M190 S{material_bed_temperature}
M104 S{material_print_temperature}
M105
M109 S{material_print_temperature}
M190 S{material_bed_temperature}
G21;(metric values)
G90;(absolute positioning)
M82;(set extruder to absolute mode)
G28;(Home the printer)
G92 E0;(Reset the extruder to 0)
G0 Z5 E5 F500;(Move up and prime the nozzle)
G0 X-1 Z0;(Move outside the printable area)
G1 Y60 E8 F500;(Draw a priming/wiping line to the rear)
G1 X-1;(Move a little closer to the print area)
G1 Y10 E16 F500;(draw more priming/wiping)
G1 E15 F250;(Small retract)
G92 E0;(Zero the extruder)
