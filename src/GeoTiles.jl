module GeoTiles

    # a geotile is nothing more than DataFrame that includes longitude and latitude columns and a programitically assigned file name

    # Write your package code here.
    using Extents
    using DataFrames
    using Printf
    using Scanf
    using Arrow
    import FastGeoProjections as FGP
    import GeoFormatTypes as GFT
    import GeoInterface as GI

    include("utilities.jl")
end
