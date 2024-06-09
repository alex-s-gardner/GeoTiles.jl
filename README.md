# GeoTiles.jl

GeoTiles provides tooling to handle table compatible data that is separated into geographic 
tiles to support global-scale workflows.

Global scale processing of large datasets often requires implementing some form of 
geographic tiling schema to facilitate efficient data access and processing. GeoTiles.jl 
provides tooling to help create and manage such tiling schemes.  

GeoTiles.jl relies on a defined file-prefix naming convention to avoid needing a separate 
file catalogue or database. GeoTiles.jl current only supports reading of Arrow files but it 
would be trivial to modify for other DataFrame supported file formats.


# Example
load packages
```julia-repl
julia> using GeoTiles;
julia> using DataFrames;
julia> using Extents;
```

Define a global 2-degree GeoTile grid
```julia-repl
julia> geotiles = GeoTiles.define(2.)
16200×3 DataFrame
   Row │ id                        extent                             geometry   ⋯
       │ String                    Extent…                            Polygon…   ⋯
───────┼──────────────────────────────────────────────────────────────────────────
     1 │ lat[-90-88]lon[-180-178]  Extent{(:X, :Y), Tuple{Tuple{Flo…  Polygon{fa ⋯
     2 │ lat[-90-88]lon[-178-176]  Extent{(:X, :Y), Tuple{Tuple{Flo…  Polygon{fa
     3 │ lat[-90-88]lon[-176-174]  Extent{(:X, :Y), Tuple{Tuple{Flo…  Polygon{fa
   ⋮   │            ⋮                              ⋮                             ⋱
 16198 │ lat[+88+90]lon[+174+176]  Extent{(:X, :Y), Tuple{Tuple{Flo…  Polygon{fa
 16199 │ lat[+88+90]lon[+176+178]  Extent{(:X, :Y), Tuple{Tuple{Flo…  Polygon{fa ⋯
 16200 │ lat[+88+90]lon[+178+180]  Extent{(:X, :Y), Tuple{Tuple{Flo…  Polygon{fa
                                                   1 column and 16194 rows omitted
```


Make a DataFrame with columns of latitude and longitude and some data
```julia-repl
julia> df = DataFrame(latitude = [70.2, 71.4, 80.], longitude = [50.1, 50.5, 30.], data = [4.5, 8.1, 20.])
3×3 DataFrame
 Row │ latitude  longitude  data    
     │ Float64   Float64    Float64 
─────┼──────────────────────────────
   1 │     70.2       50.1      4.5
   2 │     71.4       50.5      8.1
   3 │     80.0       30.0     20.0
```

Group data into geotiles
```julia-repl
julia> gts = GeoTiles.group(df, geotiles)
2-element Vector{DataFrame}:
 2×3 DataFrame
 Row │ latitude  longitude  data    
     │ Float64   Float64    Float64 
─────┼──────────────────────────────
   1 │     70.2       50.1      4.5
   2 │     71.4       50.5      8.1
 1×3 DataFrame
 Row │ latitude  longitude  data    
     │ Float64   Float64    Float64 
─────┼──────────────────────────────
   1 │     80.0       30.0     20.0
```

Check that returned dataframes are geotile compliant to be compliant the dataframe must 
have latitude & longitude columns and contain geotile_id in metadata
```julia-repl
julia> GeoTiles.isgeotile.(gts)
2-element BitVector:
 1
 1
```

Save geotiles to disk
```julia-repl
julia> folder = "/Users/gardnera/Downloads/Test";
julia> suffix = "_test.arrow";
julia> GeoTiles.save.(Ref(folder), Ref(suffix), gts)
2-element Vector{String}:
 "/Users/gardnera/Downloads/Test/lat[+70+72]lon[+050+052]_test.arrow"
 "/Users/gardnera/Downloads/Test/lat[+78+80]lon[+028+030]_test.arrow"
```

Load only geotiles that intersect extent
```julia-repl
julia> extent = Extent(Lat=(70.,71.), Lon=(50.,51.));
julia> GeoTiles.readall(folder; extent=extent)
1-element Vector{DataFrame}:
 2×3 DataFrame
 Row │ latitude  longitude  data    
     │ Float64   Float64    Float64 
─────┼──────────────────────────────
   1 │     70.2       50.1      4.5
   2 │     71.4       50.5      8.1
```