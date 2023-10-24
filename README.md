# GeoTiles.jl

GeoTiles provides tooling to handle table compatible data that is separated into geographic 
tiles to support global workflows.

Global scale processing of large datasets often requires implementing some form of 
geographic tiling schema to facilitate efficient data access and processing. GeoTiles.jl 
provides some basic tooling to help create and manage such tiling schemes.  

GeoTiles.jl relies on a defined file-suffix naming convention to avoid needing a separate 
file catalogue or database. GeoTiles.jl current only supports reading of Arrow files but is
trivial to modify for other DataFrame supported file formats.