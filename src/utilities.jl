# utilities for building and working with GeoTiles
# use X and Y to be consistent with Rasters.jl
const world = Extent(Y=(-90, 90), X = (-180, 180))


"""
    _extent(y, x, width)

Internal that returns extents of geotile given center x (e.g. longitude), y (e.g. latitude) and geotile width

# Example
```julia-repl
julia> ext = GeoTiles._extent(80,80,2)
Extent(X = (79.0, 81.0), Y = (79.0, 81.0))
```
"""
function _extent(x, y, width; alwaysxy=true)

    if !alwaysxy
        (x,y) = (y,x)
    end
     
    halfwidth = width / 2;
    extent = Extent(X=((x - halfwidth), (x + halfwidth)), Y=((y - halfwidth), (y + halfwidth)))
    
    return extent 
end


"""
    _polygon(y, lon, width)

Internal that returns polygon geometreis of geotile given center yitude, longitude and 
geotile width

# Example
```julia-repl
julia> ext = GeoTiles._extent(80,80,2)
Extent(X = (79.0, 81.0), Y = (79.0, 81.0))
```
"""
function _polygon(x, y, width; crs = GFT.EPSG(4326), alwaysxy = true)

    if !alwaysxy 
        (x,y) = (y,x)
    end

    hw = width / 2
    ring = GI.LinearRing([(x - hw, y - hw), (x - hw, y + hw), (x + hw, y + hw), (x + hw, y - hw)])
    polygon = GI.Polygon([ring]; crs)

    return polygon
end

"""
    extent(id)

Returns the geotile extent given a geotile `id`
"""
function extent(id::String)

    a = @scanf id "lat[%d%d]lon[%d%d]" Float64 Float64 Float64 Float64
    extent = Extent(X=(a[4], a[5]), Y=(a[2], a[3]))

    return extent
end


"""
    within(x, y, extent::Extent)

True if a point falls within extent
# Example
```julia-repl
julia> ext = GeoTiles._extent(80,80,2)
Extent(X = (79.0, 81.0), Y = (79.0, 81.0))
julia> ind = GeoTiles.within(80., 80.1, ext)
true
julia> ind = GeoTiles.within(80., 81.1, ext)
false
```
"""
function within(x, y, extent::Extent; alwaysxy=true)
    if !alwaysxy
        (x,y) = (y,x)
    end
    
    in = (y > extent.Y[1]) && 
        (y <= extent.Y[2]) && 
        (x > extent.X[1]) && 
        (x <= extent.X[2])

    return in
end


"""
    crop!(gt::DataFrame, extent)

Crop geotile dataframe to only include data that falls within extent
"""
function crop!(gt::DataFrame, extent)

    ind = .!within.(gt.longitude, gt.latitude, Ref(extent))
    if any(ind)
        gt = deleteat!(gt,ind)
    end

    return gt
end


"""
    isgeotile(df::DataFrame)

Check if `DataFrame` is GeoTile compliant. 
All that is required is "latitude" and "longitude" column names and geotile_id 
in the metadata
"""
function isgeotile(df)
    has_latitude = any(names(df) .== "latitude")
    has_longitude = any(names(df) .== "longitude") 
    has_id = "geotile_id" in metadatakeys(df)

    tf = has_latitude && has_longitude && has_id
    return tf
end


# Defining a special GeoTile type is likely more effort than needed
# struct GeoTile
#    df::DataFrame
#    GeoTile(df) = !isgeotile(df) ? error("GeotTile required columns of latitude and 
# longitude and Extent in the metadata") : new(df)
# end


"""
    define(width; extent=nothing)

Returns a geotiles, a DataFrame with geotile ids and extents

# Example
```julia-repl
julia> GeoTiles.define(2)
16200×2 DataFrame
   Row │ id                        extent                            
       │ String                    Extent…                           
───────┼─────────────────────────────────────────────────────────────
     1 │ lat[-90-88]lon[-180-178]  Extent{(:X, :Y), Tuple{Tuple…
   ⋮   │            ⋮                              ⋮
 16200 │ lat[+88+90]lon[+178+180]  Extent{(:X, :Y), Tuple{Tuple…
                                                   16198 rows omitted
```
"""
function define(width::Number; extent=nothing)

    if mod(180, width) != 0
        error("a geotile width of $width does not divide evenly into 180")
    end
    
    # geotile package uses fixed extents for consistancy, once defined a supset 
    # of tiles can be selected
    halfwidth = width/2;
    centerlat = (world.Y[1] + halfwidth):width:(world.Y[2] - halfwidth)
    centerlon = (world.X[1] + halfwidth):width:(world.X[2] - halfwidth)

    extent0 = vec([_extent(lon, lat, width) for lon in (centerlon), lat in (centerlat)])
    polygon0 = vec([_polygon(lon, lat, width) for lon in (centerlon), lat in (centerlat)])

    # trim to user supplied extent    
    if !isnothing(extent)
        ind = Extents.intersects.(Ref(extent), extent0)
        extent0 = extent0[ind]
        polygon0 = polygon0[ind]
    end
    
    id = _id.(extent0)
    
    geotiles = DataFrame(id=id, extent=extent0, geometry=polygon0)
    return geotiles
end


"""
    _id(extent)

Internal that returns the geotile id given a geotile `extent`
"""
function _id(extent::Extent; alwaysxy=false)

    # determine minimum number of decimals for the id
    halfwidth = (extent.Y[2] .- extent.Y[1]) / 2
    ~, n = Base.Ryu.reduce_shortest(halfwidth)
    n < 0 ? n = -n : n =0

    txt = "lat[%+03.$(n)f%+03.$(n)f]lon[%+04.$(n)f%+04.$(n)f]"
    f = Printf.Format(txt)
    id = Printf.format(f, extent.Y[1], extent.Y[2], extent.X[1], extent.X[2])
 
    return id
end


"""
    utm!(gt::DataFrame)

add x and y coodinates for local utm or polar stereo zone to a geotile DataFrame
"""
function utm!(gt::DataFrame)
    extent = GeoTiles.extent(metadata(gt, "geotile_id"))
    epsg = utm_epsg(extent)
    # add epsg to metadata
    metadata!(gt, "XY_epsg", epsg, style=:note)

    if isempty(gt)
        gt[!, :X] = []
        gt[!, :Y] = []
    else
        trans = FGP.Transformation(GFT.EPSG(4326), epsg)
        gt[!, :X], gt[!, :Y] = trans(gt.latitude, gt.longitude)
    end
    
    return gt
end


"""
    read(path2file)
Read in Arrow file as a GeoTile DataFrame by adding geotile_id to the metadata
"""
function read(path2file; filetype = :arrow)

    if filetype == :arrow
        gt = DataFrame(Arrow.Table(path2file))
    else
        error("$filetype is not a supported file type")
    end

    # add geotile_id to metadata
    geotile_id = idfromfilename(path2file)
    metadata!(gt, "geotile_id", geotile_id, style=:note)

    return gt
end


"""
   idfromfilename(filename)
Returns GeoTile id given a file name or filepath

# Example
```julia-repl
julia> GeoTiles.idfromfilename("/Users/gardnera/data/height_change/2000_2022/lat[+60+62]lon[-146-144].cop30_v2")
"lat[+60+62]lon[-146-144]"
```
"""
function idfromfilename(filename)
    ~, fn = splitdir(filename)
    ind = findall(']', fn)
    if isempty(ind) || (length(ind) < 2)
        error("$filename is not a valid GeoTile file name")
    end

    id = fn[1:ind[2]]
    return id
end


"""
    extentfromfilename(filename)
Returns GeoTile `Extent` given a file name or file path

# Example
```julia-repl
julia> GeoTiles.extentfromfilename("/Users/gardnera/data/height_change/2000_2022/lat[+60+62]lon[-146-144].cop30_v2")
Extent(Y = (60.0, 62.0), X = (-146.0, -144.0))
```
"""
function extentfromfilename(filename)
    id = extentfromfilename(filename)
    ext = extent(id)
    return ext
end


"""
    utm_epsg(lat::Real, lon::Real, always_xy=false)

returns the EPSG code for the intersecting universal transverse Mercator (UTM) zone -OR- 
the relevant polar stereographic projection if outside of UTM limits.

modified from: https://github.com/JuliaGeo/Geodesy.jl/blob/master/src/utm.jl    
"""
function utm_epsg(lon::Real, lat::Real; alwaysxy=true)
    if !alwaysxy
        (lat,lon) = (lon,lat)
    end
|
    if lat > 84
        # NSIDC Sea Ice Polar Stereographic North
        epsg = 3413
    elseif lat < -80
        # Antarctic Polar Stereographic
        epsg = 3031
    end

    # make sure lon is from -180 to 180
    lon = lon - floor((lon+180) / (360)) * 360

    # int versions
    ilat = floor(Int64, lat)
    ilon = floor(Int64, lon)

    # get the latitude band
    band = max(-10, min(9,  fld((ilat + 80), 8) - 10))

    # and check for weird ones
    zone = fld((ilon + 186), 6)
    if ((band == 7) && (zone == 31) && (ilon >= 3)) # Norway
        zone = 32
    elseif ((band == 9) && (ilon >= 0) && (ilon < 42)) # Svalbard
        zone = 2 * fld((ilon + 183), 12) + 1
    end

    if lat >= 0
        epsg = 32600 + zone
    else
        epsg = 32700 + zone
    end

    # convert to GeoFormatType
    epsg = GFT.EPSG(epsg)
    return epsg
end

function utm_epsg(extent::Extent)
    cntr = _center(extent)
    epsg = utm_epsg(cntr.Y,  cntr.X)
    return epsg
end

"""
    _center(extent::Extent
Internal that returns the center Y and X of an Extent
"""
function _center(extent::Extent)
    lat = (extent.Y[1] + extent.Y[2])/2
    lon = (extent.X[1] + extent.X[2])/2
    return (Y = lat, X = lon)
end


"""
    subset(geotiles, extent::Extent)
Returns the subset of geotiles that intersect extent
"""
function subset(geotiles, extent::Extent)
    ind = .!isnothing.(Extents.intersect.(Ref(extent), geotiles.extent));
    geotiles = geotiles[ind,:];
    return geotiles
end


"""
    subset!(geotiles, extent::Extent)
Returns the subset of geotiles that intersect extent
"""
function subset!(geotiles, extent::Extent)
    ind = .!isnothing.(Extents.intersect.(Ref(extent), geotiles.extent))
    geotiles = deleteat!(geotiles, ind)
    return geotiles
end

"""
    allfiles(rootdir; subfolders=false, fn_startswith=nothing, fn_endswith=nothing, 
        fn_contains=nothing, and_or=&, topdown=true, follow_symlinks=false, onerror=throw)

Returns a vector list of file paths that meet the user defined criteria.\n 
# Arguments
- rootdir: directory from which to begin search
- subfolders [false]: include or exclude subfolders in file search
- fn_startswith: include files that startswith
- fn_endswith: include files that startswith
- fn_contains: include files that contain
- and_or [`&`]: only include if all criteria are met (`&`) or include if any criteria 
  are met (`|`)
- topdown, follow_symlinks, onerror: see walkdir documentation
"""
function allfiles(
    rootdir;
    subfolders=false,
    fn_startswith=nothing,
    fn_endswith=nothing,
    fn_contains=nothing,
    and_or=&,
    topdown=true,
    follow_symlinks=false,
    onerror=throw
)

    filelist = String[]

    if subfolders == false
        files = readdir(rootdir)
        for file in files
            endswith_tf = true
            startswith_tf = true
            containsin_tf = true

            if !isnothing(fn_endswith)
                endswith_tf = any(endswith.(file, fn_endswith))
            end

            if !isnothing(fn_startswith)
                startswith_tf = any(startswith.(file, fn_startswith))
            end

            if !isnothing(fn_contains)
                containsin_tf = any(contains.(file, fn_contains))
            end

            tf = and_or(and_or(endswith_tf, startswith_tf), containsin_tf)

            if tf
                push!(filelist, joinpath(rootdir, file))
            end
        end
    else
        # walk dir is very slow so use readdir when you can
        for (root, _, files) in walkdir(
            rootdir, 
            topdown=topdown, 
            follow_symlinks=follow_symlinks, 
            onerror=onerror
            )

            for file in files
                endswith_tf = true
                startswith_tf = true
                containsin_tf = true

                if !isnothing(fn_endswith)
                    endswith_tf = any(endswith.(file, fn_endswith))
                end

                if !isnothing(fn_startswith)
                    startswith_tf = any(startswith.(file, fn_startswith))
                end

                if !isnothing(fn_contains)
                    containsin_tf = any(contains.(file, fn_contains))
                end

                tf = and_or(and_or(endswith_tf, startswith_tf), containsin_tf)

                if tf
                    push!(filelist, joinpath(root, file))
                end
            end
        end
    end

    return filelist
end


"""
    readall(path2dir; suffix = nothing, extent = nothing, filetype=:arrow)

load all geotiles from path2dir. If suffix is provided then only those files with 
matching suffix will be read in. If extent is provided all geotiles that intersect the 
extent will be loaded.
"""
function readall(path2dir; suffix=nothing, extent=nothing, filetype=:arrow)

    df = listtiles(path2dir; suffix, extent)

    gt = DataFrame[]
    for fn in df.path2file
        gt = push!(gt, GeoTiles.read(fn, filetype=:arrow))
    end 
    
    return gt
end


"""
    group(df, geotiles)

Return dataframes seperated by 'geotiles' extents. Unique geotile id is added as metadata 
to each dataframe.
"""
function group(df,geotiles)
    df[!, :gtidx] .= Int64(0)
    for r in eachrow(df)
         foo = findfirst(GeoTiles.within.(r.latitude, r.longitude, geotiles.extent))
         if !isnothing(foo) 
            r.gtidx = foo
         end
    end
    df = groupby(df, :gtidx)

    gts = DataFrame[]
    for df0 in df
        gtidx = df0.gtidx[1]
        if gtidx == 0
            @warn("not all data contained within provided GeoTiles")
            continue
        end
        id = geotiles[gtidx, :id]
        df0 = select(df0, Not(:gtidx))
        push!(gts, metadata!(df0, "geotile_id", id, style=:note))
    end
    return gts
end

function path2tile(folder, id, suffix)
    suffix = suffixcheck(suffix)
    return joinpath(folder, id*suffix)
end


"""
    save(folder, suffix, gt; filetype = :arrow)
Save geotile compliant dataframe to disk. 
"""
function save(folder, suffix, gt; filetype = :arrow)
    id = metadata(gt, "geotile_id")
    path2file = path2tile(folder, id, suffix)

    if filetype == :arrow
        Arrow.write(path2file, gt)
    else
        error("$filetype is not a supported file type")
    end
end


"""
    listtiles(path2dir; suffix = nothing, extent = nothing)

return a DataFrame of tile ids and extents. If suffix is provided then only those files with 
matching suffix will be listed. If extent is provided all geotiles that intersect the 
extent will be listed.
"""
function listtiles(path2dir; suffix = nothing, extent = nothing)
    suffix = suffixcheck(suffix)
    fns = GeoTiles.allfiles(path2dir; fn_startswith="lat[", fn_endswith=suffix)
    ids = GeoTiles.idfromfilename.(fns)
    fns_extents = GeoTiles.extent.(ids)

    if !isnothing(extent)
        ind = Extents.intersects.(Ref(extent), fns_extents)
        fns = fns[ind]
        ids = ids[ind]
        fns_extents = fns_extents[ind]
    end

    df = DataFrame(:id => ids, :extent => fns_extents, :path2file => fns)
    return df
end

"""
    suffixcheck(suffix)

returns a standardized file suffix sting with a leading period
"""
function suffixcheck(suffix::String)

    # add leading period if missing
    if suffix[1] != "."
        suffix = "."*suffix
    end

    return suffix
end

function suffixcheck(suffix::Symbol)
    suffix = suffixcheck(string(suffix))
    return suffix
end

function suffixcheck(suffix::Nothing)
    return suffix
end


"""
    listtiles_intersecting(path2dir, suffixes; extent = nothing)

return a DataFrame of tile ids, extents, and paths to each file suffix for which ALL suffixes 
files exist.  If extent is provided all geotiles that intersect the extent will be listed.
"""
function listtiles_intersecting(path2dir, suffixes; extent=nothing)

    # find requested geotiles within region
    gtfilelist = [GeoTiles.listtiles.(Ref(path2dir); suffix, extent) for suffix in suffixes]

    # ensure geotiles that exisit for all suffix
    if length(suffixes) > 1
        ids = intersect([gt.id for gt in gtfilelist]...)

        # only include files with intersecting geotiles            
        for gt in gtfilelist
            filter!(row -> row.id in ids, gt)
        end
    end

    df = gtfilelist[1][:, [:id, :extent]]
    insertcols!(df, (suffixes .=> [gt.path2file for gt in gtfilelist])...)

    return df
end
