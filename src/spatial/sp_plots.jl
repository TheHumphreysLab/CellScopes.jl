
function sp_dot_plot(sp::get_object_group("Spatial"), genes::Union{Vector, String},
    cluster::Union{Symbol, String};expr_cutoff::Union{Float64, Int64}=0, split_by::Union{String, Nothing}=nothing,
    x_title="Gene",y_title="Cell type", use_imputed= false, imp_type = "SpaGE", cell_order::Union{Vector, String, Nothing}=nothing,
    fontsize::Int64=12, color_scheme::String="yelloworangered",reverse_color::Bool=false,
    height::Union{String, Int64}=400, width::Union{String, Int64}=400)
    if use_imputed
        if !isdefined(sp, :imputeData)
            error("Please impute the data first!")
        end
        if isa(imp_type, Nothing)
            imp_type = "SpaGE"
        end
        if imp_type === "tangram"
            norm_counts = sp.imputeData.tgCount
        elseif imp_type === "SpaGE"
            norm_counts = sp.imputeData.spageCount
        elseif imp_type === "gimVI"
            norm_counts = sp.imputeData.gimviCount
        else
            error("imp_type can only be \"tangram\", \"SpaGE\" and \"gimVI\"")
        end
    else
        if isdefined(sp, :normCount)
            norm_counts=sp.normCount
        else
            error("Please normalize the data first!")
        end
    end
    if isa(split_by, Nothing)
        all_df=DataFrame()
        for (i, gene) in enumerate(genes)
            gene_expr = subset_count(norm_counts; genes = [gene])
            gene_expr = (vec ∘ collect)(gene_expr.count_mtx)
            df = DataFrame()
            df.gene=gene_expr
            df.celltype=string.(sp.spmetaData.cell[!, cluster])
            avg_expr=DataFrames.combine(groupby(df, :celltype), :gene => mean => :avg_exp);
            perc_expr=DataFrames.combine(groupby(df, :celltype), :gene => function(x) countmap(x.>expr_cutoff)[:1]*100/length(x) end => :perc_exp)
            df_plt=innerjoin(avg_expr, perc_expr, on = :celltype)
            df_plt.gene.=gene
            all_df=[all_df; df_plt]
        end
        p=all_df |> @vlplot(:circle,
            x={"gene:o", title="Gene", scale={
                    domain=genes
                }, axis={labelFontSize=fontsize,titleFontSize=fontsize}},
            y={"celltype:o", title="Cell type",
            scale={
                    domain=cell_order
                }, axis={labelFontSize=fontsize,titleFontSize=fontsize}},
            color={"avg_exp:q",
                    scale={scheme=color_scheme,reverse=reverse_color}},
            size={"perc_exp:q", legend={symbolFillColor="transparent"}},
            height= height, width=width
            )
    else
        all_df=DataFrame()
        for (i, gene) in enumerate(genes)
            gene_expr = subset_count(norm_counts; genes = [gene])
            gene_expr = (vec ∘ collect)(gene_expr.count_mtx)
            df = DataFrame()
            df.gene=gene_expr
            df.celltype=string.(sp.spmetaData.cell[!, cluster])
            df.split_by = string.(sp.spmetaData.cell[!, split_by])
            avg_expr=DataFrames.combine(groupby(df, [:celltype, :split_by]), :gene => mean => :avg_exp)
            perc_expr=DataFrames.combine(groupby(df, [:celltype,:split_by]), :gene => function(x) countmap(x.>expr_cutoff)[:1]*100/length(x) end => :perc_exp)
            df_plt=innerjoin(avg_expr, perc_expr, on = [:celltype,:split_by])
            df_plt.gene.=gene
            all_df=[all_df; df_plt]
        end
        p=all_df |> @vlplot(:circle,
            x={"gene:o", title="Gene", scale={
                    domain=genes
                }, axis={labelFontSize=fontsize,titleFontSize=fontsize}},
            y={"celltype:o", title="Cell type",
            scale={
                    domain=cell_order
                }, axis={labelFontSize=fontsize,titleFontSize=fontsize}},
            color={"avg_exp:q",
                    scale={scheme=color_scheme,reverse=reverse_color}},
            size={"perc_exp:q", legend={symbolFillColor="transparent"}},
            column={:split_by, header={labelFontSize=16, title=nothing}},
            height= height, width=width
            )        
    end
    return p
end

function sp_feature_plot(sp::get_object_group("Spatial2"), gene_list::Union{String, Vector{String}, Tuple{String}}; layer::String = "cells", x_col::Union{String, Symbol}="x",
    y_col::Union{String, Symbol}="y", cell_col = "cell", x_lims=nothing, y_lims=nothing, marker_size=2, order::Bool=true, scale::Bool = false,titlesize::Int64=24, 
    height::Real = 500, width::Real = 500, combine = true, img_res::String = "low",  adjust_contrast::Real = 1.0, adjust_brightness::Real = 0.3, use_imputed=false, imp_type::Union{String, Nothing} = nothing,
    color_keys=["gray94","orange","red3"], gene_colors = nothing, alpha = [1.0,1.0], clip = 0, legend_fontsize = 10, do_legend=false, legend_size = 10, bg_color = "white",
    custom_img=false, adjust_coord_to_img="auto")
    if isa(gene_list, String)
        gene_list = [gene_list]
    end
    n_rows = Int(ceil(length(gene_list) / 3))
    if length(gene_list) < 4
        n_cols = length(gene_list)
    else
        n_cols = 3
    end
    if layer === "cells"
        coord_limits = spatial_range(sp)
        if isa(sp, VisiumObject)
            coord_cell = deepcopy(sp.spmetaData)
            x_col = Symbol(x_col)
            y_col = Symbol(y_col)
            rename!(coord_cell, [:barcode, :pxl_row_in_fullres, :pxl_col_in_fullres] .=> [:cell, x_col, y_col])
            coord_cell[!, x_col] = Float64.(coord_cell[!, x_col])
            coord_cell[!, y_col] = Float64.(coord_cell[!, y_col])
            scale_factor = get_vs_sf(sp; img_res = img_res)
            coord_cell[!, x_col] =  coord_cell[!, x_col] .* scale_factor
            coord_cell[!, y_col] =  coord_cell[!, y_col] .* scale_factor
            coord_limits[1] = round.(Int, coord_limits[1] .* scale_factor)
            coord_limits[2] = round.(Int, coord_limits[2] .* scale_factor)
        elseif isa(sp, SlideseqObject)
            coord_cell=deepcopy(sp.spmetaData)
        else
            coord_cell=deepcopy(sp.spmetaData.cell)
        end
        if use_imputed
            if !isdefined(sp, :imputeData)
                error("Please impute the data first!")
            end
            if isa(imp_type, Nothing)
                imp_type = "SpaGE"
            end
            if imp_type === "tangram"
                norm_counts = sp.imputeData.tgCount
            elseif imp_type === "SpaGE"
                norm_counts = sp.imputeData.spageCount
            elseif imp_type === "gimVI"
                norm_counts = sp.imputeData.gimviCount
            else
                error("imp_type can only be \"tangram\", \"SpaGE\" and \"gimVI\"")
            end
        else
            if isdefined(sp, :normCount)
                norm_counts=sp.normCount
            else
                error("Please normalize the data first!")
            end
        end
        
        if isa(x_lims, Nothing)
            if isa(sp, VisiumObject)
                x_lims=coord_limits[1]
            else
                x_lims1=(minimum(coord_cell[!, x_col])-0.05*maximum(coord_cell[!, x_col]),1.05*maximum(coord_cell[!, x_col]))
            end
        else 
            if isa(sp, VisiumObject)
                x_lims = x_lims .* scale_factor
            else
                x_lims = x_lims
            end
        end
        if isa(y_lims, Nothing)
            if isa(sp, VisiumObject)
                y_lims=coord_limits[2]
            else
                y_lims1=(minimum(coord_cell[!, y_col])-0.05*maximum(coord_cell[!, y_col]),1.05*maximum(coord_cell[!, y_col]))
            end
        else
            if isa(sp, VisiumObject)
                y_lims = y_lims .* scale_factor
            else
                y_lims = y_lims
            end
        end
        c_map = ColorSchemes.ColorScheme([parse(Colorant, color_keys[1]),parse(Colorant, color_keys[2]),parse(Colorant, color_keys[3])])
        fig = MK.Figure(size = (width * n_cols, height * n_rows))
        for (i, gene) in enumerate(gene_list)
            gene_expr = subset_count(norm_counts; genes = [gene])
            gene_expr = (vec ∘ collect)(gene_expr.count_mtx)
            if scale
                gene_expr = unit_range_scale(gene_expr)
            end
            df = DataFrame()
            df.gene_expr = gene_expr
            coord_cell[!, cell_col] = string.(coord_cell[!, cell_col])
            df[!, cell_col] = string.(coord_cell[!, cell_col])
            df_plt = innerjoin(df, coord_cell, on = cell_col)
            df_plt.gene .= gene
            if sum(gene_expr) > 0.0
                colors = get(c_map, gene_expr, :extrema)
                plt_color = "#" .* hex.(colors)
                total_col = length(plt_color)
                alpha_new = [x > clip ? alpha[2] : alpha[1] for x in gene_expr]
                plt_color = [(i, j) for (i,j) in zip(plt_color, alpha_new)]
                df_plt.plt_color = plt_color
                if order
                    df_plt = sort(df_plt,:gene_expr)
                end
            else
                plt_color = repeat([color_keys[1]], length(gene_expr))
                df_plt.plt_color = plt_color
            end
            n_row = Int(ceil(i/3))
            if i < 4
                n_col1 = 2i-1
                n_col2 = 2i
            else
                n_col1 = 2*(i-3*(n_row-1))-1
                n_col2 = 2*(i-3*(n_row-1))
            end
            ax1 = MK.Axis(fig[n_row,n_col1]; backgroundcolor = bg_color, xticklabelsize = 12, yticklabelsize = 12, xticksvisible = false, 
            xticklabelsvisible = false, yticksvisible = false, yticklabelsvisible = false,
            xgridvisible = false, ygridvisible = false,yreversed=false, title = gene_list[i], 
            titlesize = titlesize, xlabel = "", ylabel = "", 
            xlabelsize = titlesize -4, ylabelsize = titlesize -4)
            if isa(sp, VisiumObject)
                if img_res == "high"
                    img = deepcopy(sp.imageData.highresImage)
                elseif img_res == "low"
                    img = deepcopy(sp.imageData.lowresImage)
                else
                    img = deepcopy(sp.imageData.fullresImage)
                end
                if !isa(x_lims, Nothing) && !isa(y_lims, Nothing)
                    img = img[round(Int,x_lims[1]):round(Int, x_lims[2]), round(Int, y_lims[1]):round(Int, y_lims[2])]
                end
                img2 = augment(img, ColorJitter(adjust_contrast, adjust_brightness))
                MK.image!(ax1, img2)
            end
            if custom_img
                if isa(sp, XeniumObject)
                    img = deepcopy(sp.imageData)
                    scale_factor = get_xn_sf(sp; adjust_coord_to_img=adjust_coord_to_img)
                    scale_x = scale_factor[1]
                    scale_y = scale_factor[2]
                    df_plt[!, x_col] = df_plt[!, x_col] ./ scale_x
                    df_plt[!, y_col] = df_plt[!, y_col] ./ scale_y
                    if i == 1
                        if isa(x_lims, Nothing)
                            x_lims1 = x_lims1 ./ scale_x
                        else
                            x_lims = x_lims ./ scale_x
                        end
                        if isa(y_lims, Nothing)
                            y_lims1 = y_lims1 ./ scale_y
                        else
                            y_lims = y_lims ./ scale_y
                        end
                    end
                end                            
                if !isa(x_lims, Nothing) && !isa(y_lims, Nothing)
                    img = img[round(Int, x_lims[1]):round(Int, x_lims[2]), round(Int, y_lims[1]):round(Int, y_lims[2])]
                end
                img2 = augment(img, ColorJitter(adjust_contrast, adjust_brightness))
                MK.image!(ax1, img2)
            end
            if !isa(x_lims, Nothing) && !isa(y_lims, Nothing)
                df_plt=filter([x_col, y_col] => (x,y) -> x_lims[1] < x < x_lims[2] && y_lims[1] < y < y_lims[2], df_plt)
                df_plt[!, x_col] = df_plt[!, x_col] .- x_lims[1]
                df_plt[!, y_col] = df_plt[!, y_col] .- y_lims[1]
            else
                if isa(x_lims, Nothing)
                    MK.xlims!(MK.current_axis(), x_lims1)
                else
                    MK.xlims!(MK.current_axis(), x_lims)
                end
                if isa(y_lims, Nothing)
                    MK.ylims!(MK.current_axis(), y_lims1)
                else
                    MK.ylims!(MK.current_axis(), y_lims)
                end                    
            end
            MK.scatter!(ax1, df_plt[!, x_col], df_plt[!, y_col]; color = df_plt.plt_color, strokewidth = 0, markersize = marker_size)
            MK.Colorbar(fig[n_row,n_col2], label = "", colormap = c_map, width=10, limits = (0, maximum(gene_expr)))
        end
        return fig

    elseif layer === "transcripts"
            if isa(sp, Union{VisiumObject, SlideseqObject})
                error("Visium or SlideSeq object doesn't support transcript plot.")
            end
            coord_molecules=deepcopy(sp.spmetaData.molecule)
            coord_molecules.gene = String.(coord_molecules.gene)
            if isa(x_lims, Nothing)
                x_lims=(minimum(coord_molecules[!, x_col])-0.05*maximum(coord_molecules[!, x_col]),1.05*maximum(coord_molecules[!, x_col]))
            end
            if isa(y_lims, Nothing)
                y_lims=(minimum(coord_molecules[!, y_col])-0.05*maximum(coord_molecules[!, y_col]),1.05*maximum(coord_molecules[!, y_col]))
            end
            if combine
                if isa(gene_colors, Nothing)
                    c_map=Colors.distinguishable_colors(length(gene_list), Colors.colorant"#007a10", lchoices=range(20, stop=70, length=15))
                    c_map = "#" .* hex.(c_map)
                else
                    c_map = gene_colors
                end
                gene_color=Dict(gene_list .=> c_map)
                gene_color["others"] = color_keys[1]
                from = collect(keys(gene_color))
                to = collect(values(gene_color))
                df_plt=DataFrames.transform(coord_molecules, :gene => ByRow(name -> name ∈ gene_list ? name : "others") => :new_gene)
                df_plt = map_values(df_plt, :new_gene, :forcolor, from, to)
                df_plt.new_gene = string.(df_plt.new_gene)
                df_plt.forcolor = [(i, alpha) for i in df_plt.forcolor]
                fig = MK.Figure(size = (width, height))
                ax1 = MK.Axis(fig[1,1]; backgroundcolor = bg_color, xticklabelsize = 12, yticklabelsize = 12, xticksvisible = false, 
                    xticklabelsvisible = false, yticksvisible = false, yticklabelsvisible = false,
                    xgridvisible = false, ygridvisible = false,yreversed=false, 
                    titlesize = titlesize, xlabel = "", ylabel = "", 
                    xlabelsize = titlesize -4, ylabelsize = titlesize -4)
                ax2 = MK.Axis(fig[1,1]; backgroundcolor = bg_color, xticklabelsize = 12, yticklabelsize = 12, xticksvisible = false, 
                    xticklabelsvisible = false, yticksvisible = false, yticklabelsvisible = false,
                    xgridvisible = false, ygridvisible = false,yreversed=false, 
                    titlesize = titlesize, xlabel = "", ylabel = "", 
                    xlabelsize = titlesize -4, ylabelsize = titlesize -4)
                all_genes = ["others"; from[from .!= "others"]]
                all_colors = [color_keys[1]; to[to .!= color_keys[1]]]
                if custom_img
                    if isa(sp, XeniumObject)
                        img = deepcopy(sp.imageData)
                        all_genes = from[from .!= "others"]
                        all_colors = to[to .!= color_keys[1]]
                        scale_factor = get_xn_sf(sp; adjust_coord_to_img=adjust_coord_to_img)
                        scale_x = scale_factor[1]
                        scale_y = scale_factor[2]
                        df_plt[!, x_col] = df_plt[!, x_col] ./ scale_x
                        df_plt[!, y_col] = df_plt[!, y_col] ./ scale_y
                        x_lims = x_lims ./ scale_x
                        y_lims = y_lims ./ scale_y
                    end                            
                    if !isa(x_lims, Nothing) && !isa(y_lims, Nothing)
                        img = img[round(Int, x_lims[1]):round(Int, x_lims[2]), round(Int, y_lims[1]):round(Int, y_lims[2])]
                    end
                    img2 = augment(img, ColorJitter(adjust_contrast, adjust_brightness))
                    MK.image!(ax1, img2)
                end
                df_plt=filter([x_col, y_col] => (x,y) -> x_lims[1] < x < x_lims[2] && y_lims[1] < y < y_lims[2], df_plt)
                df_plt[!, x_col] = df_plt[!, x_col] .- x_lims[1]
                df_plt[!, y_col] = df_plt[!, y_col] .- y_lims[1]
                for (gene, ann_color) in zip(all_genes, all_colors)
                    x_ax = df_plt[!, x_col][df_plt.new_gene .== gene]
                    y_ax = df_plt[!, y_col][df_plt.new_gene .== gene]
                    if do_legend
                        MK.scatter!(ax2, x_ax , y_ax;  visible=false,
                                        color=ann_color, strokewidth=0, markersize=2*legend_size, label=gene)
                        MK.scatter!(ax1, x_ax , y_ax; color = ann_color, strokewidth = 0, markersize = marker_size)
                    else
                        MK.scatter!(ax1, x_ax , y_ax; color = ann_color, strokewidth = 0, markersize = marker_size)
                    end
                end
                if do_legend
                    MK.Legend(fig[1, 2], ax2, framecolor=:white, labelsize=legend_fontsize)
                end
                
                return fig
            else
                fig = MK.Figure(size = (width * n_cols, height * n_rows))
                for (i, gene) in enumerate(gene_list)
                    n_row = Int(ceil(i/3))
                    if i < 4
                        n_col = i
                    else
                        n_col = i-3*(n_row-1)
                    end
                    gene_list2 = ["others", gene]
                    c_map = [gene_colors[1], gene_colors[2]]
                    gene_color=Dict(gene_list2 .=> c_map)
                    from = collect(keys(gene_color))
                    to = collect(values(gene_color))
                    df_plt=DataFrames.transform(coord_molecules, :gene => ByRow(name -> name == gene ? name : "others") => :new_gene)
                    df_plt = map_values(df_plt, :new_gene, :forcolor, from, to)
                    df_plt.new_gene = String.(df_plt.new_gene)
                    df_plt.forcolor = [(i, alpha) for i in df_plt.forcolor]
                    ax1 = MK.Axis(fig[n_row,n_col]; backgroundcolor = bg_color, xticklabelsize = 12, yticklabelsize = 12, xticksvisible = false, 
                    xticklabelsvisible = false, yticksvisible = false, yticklabelsvisible = false,
                    xgridvisible = false, ygridvisible = false,yreversed=false, title = gene, 
                    titlesize = titlesize, xlabel = "", ylabel = "", 
                    xlabelsize = titlesize -4, ylabelsize = titlesize -4)
                    if custom_img
                        if isa(sp, XeniumObject)
                            img = deepcopy(sp.imageData)
                            scale_factor = get_xn_sf(sp; adjust_coord_to_img=adjust_coord_to_img)
                            scale_x = scale_factor[1]
                            scale_y = scale_factor[2]
                            df_plt[!, x_col] = df_plt[!, x_col] ./ scale_x
                            df_plt[!, y_col] = df_plt[!, y_col] ./ scale_y
                            if i == 1
                                x_lims = x_lims ./ scale_x
                                y_lims = y_lims ./ scale_y
                            end
                        end                            
                        if !isa(x_lims, Nothing) && !isa(y_lims, Nothing)
                            img = img[round(Int, x_lims[1]):round(Int, x_lims[2]), round(Int, y_lims[1]):round(Int, y_lims[2])]
                        end
                        img2 = augment(img, ColorJitter(adjust_contrast, adjust_brightness))
                        MK.image!(ax1, img2)
                    end
                    df_plt=filter([x_col, y_col] => (x,y) -> x_lims[1] < x < x_lims[2] && y_lims[1] < y < y_lims[2], df_plt)
                    df_plt[!, x_col] = df_plt[!, x_col] .- x_lims[1]
                    df_plt[!, y_col] = df_plt[!, y_col] .- y_lims[1]
                    df_plt1 = deepcopy(df_plt)
                    df_plt1=filter(:new_gene => ==("others"), df_plt1)
                    df_plt2 = deepcopy(df_plt)
                    df_plt2=filter(:new_gene => ==(gene), df_plt2)
                    if custom_img
                        MK.scatter!(ax1, df_plt2[!, x_col], df_plt2[!, y_col]; color = df_plt2.forcolor, strokewidth = 0, markersize = marker_size)
                    else
                        if order
                            MK.scatter!(ax1, df_plt1[!, x_col], df_plt1[!, y_col]; color = df_plt1.forcolor, strokewidth = 0, markersize = marker_size)
                            MK.scatter!(ax1, df_plt2[!, x_col], df_plt2[!, y_col]; color = df_plt2.forcolor, strokewidth = 0, markersize = marker_size)
                        else
                            MK.scatter!(ax1, df_plt[!, x_col], df_plt[!, y_col]; color = df_plt.forcolor, strokewidth = 0, markersize = marker_size)
                        end
                    end
                end
                return fig
            end
    else
        error("Layer must be \"cells\" or \"transcripts\"")
    end
end

function plot_gene_polygons(sp::get_object_group("Imaging"), gene_list::Union{String, Vector{String}, Tuple{String}};
    color_keys::Union{Vector{String}, Tuple{String,String,String}}=["gray94","lemonchiffon","orange","red3"],
    x_lims=nothing, y_lims=nothing,width=900,height=1000,stroke_width=0,stroke_color="black",
    titlesize::Int64=24, scale::Bool = false, bg_color = "white"
    )
    if isa(gene_list, String)
        gene_list = [gene_list]
    end
    n_rows = Int(ceil(length(gene_list) / 3))
    if length(gene_list) < 4
        n_cols = length(gene_list)
    else
        n_cols = 3
    end
    norm_count=sp.polynormCount
    polygons=sp.polygonData
    if isa(x_lims, Nothing)
        x_lims=(minimum(sp.spmetaData.cell.x)-0.05*maximum(sp.spmetaData.cell.x),1.05*maximum(sp.spmetaData.cell.x))
    end
    if isa(y_lims, Nothing)
        y_lims=(minimum(sp.spmetaData.cell.y)-0.05*maximum(sp.spmetaData.cell.y),1.05*maximum(sp.spmetaData.cell.y))
    end
    select_fov = deepcopy(sp.spmetaData.cell)
    select_fov=filter([:x, :y] => (x, y) -> x_lims[1] < x < x_lims[2] && y_lims[1] < y < y_lims[2], select_fov)
    cell_set = Set(select_fov.cell)
    subset_poly = deepcopy(sp.spmetaData.polygon)
    subset_poly=filter(:mapped_cell => ∈(cell_set), subset_poly)
    polygon_num = subset_poly.polygon_number
    polygons = polygons[polygon_num]
    c_map = ColorSchemes.ColorScheme([parse(Colorant, color_keys[1]),parse(Colorant, color_keys[2]),parse(Colorant, color_keys[3]),parse(Colorant, color_keys[4])])
    fig = MK.Figure(size = (width * n_cols, height * n_rows))
    for (i, gene) in enumerate(gene_list)
        gene_expr = subset_count(norm_count; genes = [gene])
        gene_expr = (vec ∘ collect)(gene_expr.count_mtx)
        if scale
            gene_expr = unit_range_scale(gene_expr)
        end
        colors = get(c_map, gene_expr, :extrema)
        plt_color="#" .* hex.(colors)
        plt_color = plt_color[polygon_num]
        n_row = Int(ceil(i/3))
        if i < 4
            n_col1 = 2i-1
            n_col2 = 2i
        else
            n_col1 = 2*(i-3*(n_row-1))-1
            n_col2 = 2*(i-3*(n_row-1))
        end
        ax1 = MK.Axis(fig[n_row,n_col1]; backgroundcolor = bg_color, xticklabelsize = 12, yticklabelsize = 12, xticksvisible = false, 
        xticklabelsvisible = false, yticksvisible = false, yticklabelsvisible = false,
        xgridvisible = false, ygridvisible = false,yreversed=false, title = gene_list[i], 
        titlesize = titlesize, xlabel = "", ylabel = "", 
        xlabelsize = titlesize -4, ylabelsize = titlesize -4)
        MK.poly!(ax1, [MK.Point2.(eachrow(p)) for p in polygons]; strokecolor=stroke_color, color=plt_color, strokewidth=stroke_width,label="")
        MK.xlims!(MK.current_axis(), x_lims)
        MK.ylims!(MK.current_axis(), y_lims)
        MK.Colorbar(fig[n_row,n_col2], label = "", colormap = c_map, width=10, limits = (0, maximum(gene_expr)))
    end
        return fig
end

function plot_cell_polygons(sp::Union{ImagingSpatialObject, CartanaObject,XeniumObject,MerfishObject, STARmapObject, seqFishObject, StereoSeqObject}, anno;
    cell_types::Union{String, Int64, Vector, Tuple, Nothing}=nothing, cell_colors::Union{Nothing, String, Vector, Tuple} = nothing,
    pt_bg_color = "gray90", x_lims=nothing, y_lims=nothing,width = 500, height = 500,stroke_width=0, stroke_color="black",
    legend_fontsize = 10, do_legend=false, legend_size = 10 , bg_color = "white"
    )
    if isa(x_lims, Nothing)
        x_lims=(minimum(sp.spmetaData.cell.x)-0.05*maximum(sp.spmetaData.cell.x),1.05*maximum(sp.spmetaData.cell.x))
    end
    if isa(y_lims, Nothing)
        y_lims=(minimum(sp.spmetaData.cell.y)-0.05*maximum(sp.spmetaData.cell.y),1.05*maximum(sp.spmetaData.cell.y))
    end
    if isa(cell_types, String)
        cell_types = [cell_types]
    end
    if isa(cell_colors, String)
        cell_colors = [cell_colors]
    end
    anno_df=deepcopy(sp.spmetaData.polygon)
    polygons=deepcopy(sp.polygonData)
    if isa(anno, String)
        anno=Symbol(anno)
    end
    all_celltypes = unique(anno_df[!,anno])
    if isa(cell_types, Nothing)
        cell_types = all_celltypes
    end
    other_cells = setdiff(all_celltypes, cell_types)
    other_color = Dict(other_cells .=> repeat([pt_bg_color], length(other_cells)))
    if isa(cell_colors, Nothing)
        c_map= Colors.distinguishable_colors(length(cell_types), Colors.colorant"#007a10", lchoices=range(20, stop=70, length=15))
        c_map = "#" .* hex.(c_map)
        cell_color=Dict(cell_types .=> c_map)
        anno_color = merge(cell_color, other_color)
    else
        if length(cell_types) !== length(cell_colors)
            error("The number of colors must equal to the number of cell types!")
        end
        cell_color=Dict(cell_types .=> cell_colors)
        anno_color = merge(cell_color, other_color)
    end
    anno_df = DataFrames.transform(anno_df, anno => ByRow(x -> anno_color[x]) => :new_color)
    plt_color = anno_df.new_color
    select_fov = deepcopy(sp.spmetaData.cell)
    select_fov=filter([:x, :y] => (x, y) -> x_lims[1] < x < x_lims[2] && y_lims[1] < y < y_lims[2], select_fov)
    subset_poly = deepcopy(sp.spmetaData.polygon)
    subset_poly=filter(:mapped_cell => ∈(Set(select_fov.cell)), subset_poly)
    polygon_num = subset_poly.polygon_number
    polygons = polygons[polygon_num]
    plt_color = plt_color[polygon_num]
    fig = MK.Figure(size=(width, height))
    ax1 = MK.Axis(fig[1,1]; backgroundcolor = bg_color, xticklabelsize=12, yticklabelsize=12, xticksvisible=false, 
        xticklabelsvisible=false, yticksvisible=false, yticklabelsvisible=false,
        xgridvisible = false,ygridvisible = false)
        if do_legend
            cells = string.(collect(keys(cell_color)))
            colors = collect(values(cell_color))
            for (cell1, color1) in zip(cells, colors)
                select_fov1 = filter(anno => ==(cell1), select_fov)
                MK.scatter!(ax1, select_fov1.x , select_fov1.y; color = color1, strokewidth = 0.5,strokecolor=stroke_color, markersize = legend_size, label = cell1)
            end
            MK.Legend(fig[1, 2], ax1, framecolor=:white, labelsize=legend_fontsize)
        end
        MK.poly!(ax1, [MK.Point2.(eachrow(p)) for p in polygons]; strokecolor=stroke_color, color=plt_color, strokewidth=stroke_width)
        MK.xlims!(ax1, x_lims)
        MK.ylims!(ax1, y_lims)
    return fig
end

function plot_transcript_polygons(sp::get_object_group("Imaging"); 
    gene_list::Union{Vector, Symbol, String, Nothing}=nothing, 
    gene_colors::Union{Vector, Symbol, String, Nothing}=nothing, 
    pt_bg_color::Union{Vector, Symbol, String}="gray95",
    stroke_color::Union{Vector, Symbol, String}="black",
    marker_size = 2, stroke_width=0.1, bg_color="white",
    width = 900,
    height = 1000,
    x_lims=nothing, y_lims=nothing, 
    anno::Union{Symbol, String, Nothing}=nothing,
    ann_colors::Union{Nothing, Dict}=nothing
)
    if isa(gene_list, Nothing)
        error("Please enter a gene or a list of gene. \"gene_list\" can not be empty.")
    end
    if isa(gene_colors, Nothing)
        error("Please define the colors to label the genes. \"gene_colors\" can not be empty.")
    end
    df_spatial=sp.spmetaData.molecule
    polygons=sp.polygonData
    df_spatial[!, anno] = string.(df_spatial[!, anno])
    other_genes=unique(df_spatial.gene[Not(in.(df_spatial.gene, [Set(gene_list)]))])
    other_colors=repeat([(pt_bg_color,0.1)],length(other_genes))
    all_genes=[gene_list; other_genes]
    all_colors=[gene_colors; other_colors]
    map_color=Dict(all_genes .=> all_colors)
    df_spatial=DataFrames.transform(df_spatial, :gene => ByRow(x -> map_color[x]) => :new_color)
    if isa(x_lims, Nothing)
        x_lims=(minimum(df_spatial.x)-0.05*maximum(df_spatial.x),1.05*maximum(df_spatial.x))
    end
    if isa(y_lims, Nothing)
        y_lims=(minimum(df_spatial.y)-0.05*maximum(df_spatial.y),1.05*maximum(df_spatial.y))
    end 
    if isa(anno, Nothing)
        error("Please define the cell type annotation column. \"anno\" can not be empty.")
    end
    if isa(anno, String)
        anno = Symbol(anno)
    end
    select_fov = deepcopy(sp.spmetaData.cell)
    select_fov=filter([:x, :y] => (x, y) -> x_lims[1] < x < x_lims[2] && y_lims[1] < y < y_lims[2], select_fov)
    cell_set = Set(select_fov.cell)
    anno_df = deepcopy(sp.spmetaData.polygon)
    anno_df=filter(:mapped_cell => ∈(cell_set), anno_df)
    polygon_num = anno_df.polygon_number
    polygons = sp.polygonData
    polygons = polygons[polygon_num]
    df_spatial = filter(:cell => ∈(cell_set), df_spatial)
    if isa(ann_colors, Nothing)
        cell_anno=unique(anno_df[!,anno])
        c_map=Colors.distinguishable_colors(length(cell_anno), parse(Colors.Colorant, pt_bg_color), lchoices=range(20, stop=70, length=15))
        c_map = "#" .* hex.(c_map)
        ann_colors=Dict(cell_anno .=> c_map)
    end
    anno_df[!, anno] = string.(anno_df[!, anno])
    anno_df=DataFrames.transform(anno_df, anno => ByRow(x -> ann_colors[x]) => :new_color)
    df_spatial1 = deepcopy(df_spatial)
    df_spatial1=filter(:gene => ∈(Set(other_genes)), df_spatial1)
    colors1 = df_spatial1[!,:new_color]
    df_spatial2 = deepcopy(df_spatial)
    df_spatial2=filter(:gene => ∈(Set(gene_list)), df_spatial2)
    colors2 = df_spatial2[!,:new_color]
    fig = MK.Figure(size=(width, height))
    fig[1, 1] = MK.Axis(fig; backgroundcolor = bg_color, xticklabelsize=12, yticklabelsize=12, 
        xticksvisible=false, xticklabelsvisible=false, yticksvisible=false, 
        yticklabelsvisible=false, xgridvisible = false, ygridvisible = false)
    MK.poly!([MK.Point2.(eachrow(p)) for p in polygons]; 
        strokecolor=stroke_color, color=anno_df.new_color, strokewidth=stroke_width,label="")
    MK.scatter!(df_spatial1.x, df_spatial1.y; color=colors1,
            strokewidth=0, markersize=marker_size*0.25)
    MK.scatter!(df_spatial2.x, df_spatial2.y; color=colors2,
            strokewidth=0, markersize=marker_size)
    MK.xlims!(MK.current_axis(), x_lims)
    MK.ylims!(MK.current_axis(), y_lims)
    return fig
end

function sp_dim_plot(sp::get_object_group("Spatial2"), anno::Union{Symbol, String}; 
    anno_color::Union{Nothing, Dict} = nothing, x_col::String = "x", y_col::String = "y", cell_order::Union{Vector{String}, Nothing}=nothing, cell_highlight::Union{String, Nothing}=nothing,
    x_lims=nothing, y_lims=nothing,width=900, height=1000,stroke_width=0.5,stroke_color=:transparent,  bg_color=:white,
        marker_size=2, label_size=50, label_color="black", label_offset=(0,0), do_label=false, do_legend=true, alpha::Real = 1,
        legend_size = 10, legend_fontsize = 16, legend_ncol = 1,img_res::String = "low", custom_img=false, adjust_coord_to_img="auto",
        adjust_contrast::Real = 1.0, adjust_brightness::Real = 0.3
    )
    coord_limits = spatial_range(sp)
    if isa(sp, VisiumObject)
        anno_df = deepcopy(sp.spmetaData)
        anno_df[!, anno] = sp.metaData[!, anno]
        x_col = Symbol(x_col)
        y_col = Symbol(y_col)
        rename!(anno_df, [:barcode, :pxl_row_in_fullres, :pxl_col_in_fullres] .=> [:cell, x_col, y_col])
        if isa(anno_df[!, x_col], Vector{String})
            anno_df[!, x_col] = Float64.(anno_df[!, x_col])
        end
        if isa(anno_df[!, y_col], Vector{String})
            anno_df[!, y_col] = Float64.(anno_df[!, y_col])
        end
        scale_factor = get_vs_sf(sp; img_res = img_res)
        anno_df[!, x_col] =  anno_df[!, x_col] .* scale_factor
        anno_df[!, y_col] =  anno_df[!, y_col] .* scale_factor
        coord_limits[1] = round.(Int, coord_limits[1] .* scale_factor)
        coord_limits[2] = round.(Int, coord_limits[2] .* scale_factor)
    elseif isa(sp, SlideseqObject)
        anno_df = deepcopy(sp.spmetaData)
        anno_df[!, anno] = string.(sp.metaData[!, anno])
    else
        anno_df=deepcopy(sp.spmetaData.cell)
        anno_df[!, anno] = string.(anno_df[!, anno])
    end
    if isa(x_lims, Nothing)
        if isa(sp, VisiumObject)
            x_lims = coord_limits[1]
        else
            x_lims=(minimum(anno_df[!,x_col])-0.05*maximum(anno_df[!,x_col]),1.05*maximum(anno_df[!,x_col]))
        end
    else 
        if isa(sp, VisiumObject)
            x_lims = x_lims .* scale_factor
        else
            x_lims = x_lims
        end
    end
    if isa(y_lims, Nothing)
        if isa(sp, VisiumObject)
            y_lims = coord_limits[2]
        else
            y_lims=(minimum(anno_df[!,y_col])-0.05*maximum(anno_df[!,y_col]),1.05*maximum(anno_df[!,y_col]))
        end
    else 
        if isa(sp, VisiumObject)
            y_lims = y_lims .* scale_factor
        else
            y_lims = y_lims
        end
    end
    if isa(anno, String)
        anno=Symbol(anno)
    end
    if isa(anno_color, Nothing)
        cell_anno=unique(anno_df[!,anno])
        c_map=Colors.distinguishable_colors(length(cell_anno), Colors.colorant"#007a10", lchoices=range(20, stop=70, length=15))
        c_map = "#" .* hex.(c_map)
        anno_color=Dict(cell_anno .=> c_map)
    end
    anno_df=DataFrames.transform(anno_df, anno => ByRow(x -> anno_color[x]) => :new_color)
    anno_df.new_color = [(i, alpha) for i in anno_df.new_color]
    fig = MK.Figure(size=(width, height))
    ax1 = MK.Axis(fig[1,1]; backgroundcolor = bg_color, xticklabelsize=12, yticklabelsize=12, xticksvisible=false, 
        xticklabelsvisible=false, yticksvisible=false, yticklabelsvisible=false,
        xgridvisible = false,ygridvisible = false);
    ax2 = MK.Axis(fig[1,1]; backgroundcolor = bg_color, xticklabelsize=12, yticklabelsize=12, xticksvisible=false, 
        xticklabelsvisible=false, yticksvisible=false, yticklabelsvisible=false,
        xgridvisible = false,ygridvisible = false);
    if isa(sp, VisiumObject)
        if img_res == "high"
            img = deepcopy(sp.imageData.highresImage)
        elseif img_res == "low"
            img = deepcopy(sp.imageData.lowresImage)
        else
            img = deepcopy(sp.imageData.fullresImage)
        end
        if !isa(x_lims, Nothing) && !isa(y_lims, Nothing)
            img = img[round(Int,x_lims[1]):round(Int, x_lims[2]), round(Int, y_lims[1]):round(Int, y_lims[2])]
        end
        img2 = augment(img, ColorJitter(adjust_contrast, adjust_brightness))
        MK.image!(ax1, img2)
    end
    if custom_img
        if isa(sp, XeniumObject)
            img = deepcopy(sp.imageData)   
            scale_factor = get_xn_sf(sp; adjust_coord_to_img=adjust_coord_to_img)
            scale_x = scale_factor[1]
            scale_y = scale_factor[2]
            anno_df[!, x_col] = anno_df[!, x_col] ./ scale_x
            anno_df[!, y_col] = anno_df[!, y_col] ./ scale_y
            x_lims = x_lims ./ scale_x
            y_lims = y_lims ./ scale_y
            if !isa(x_lims, Nothing) && !isa(y_lims, Nothing)
                img = img[round(Int,x_lims[1]):round(Int, x_lims[2]), round(Int, y_lims[1]):round(Int, y_lims[2])]
            end
            img2 = augment(img, ColorJitter(adjust_contrast, adjust_brightness))
            MK.image!(ax1, img2)
        end
    end
    anno_df=filter([x_col, y_col] => (x,y) -> x_lims[1] < x < x_lims[2] && y_lims[1] < y < y_lims[2], anno_df)
    anno_df[!, x_col] = anno_df[!, x_col] .- x_lims[1]
    anno_df[!, y_col] = anno_df[!, y_col] .- y_lims[1]
    if !isa(cell_highlight, Nothing)
        anno_df2 = deepcopy(anno_df)
        anno_df2=filter(anno => ==(cell_highlight), anno_df2)
        x_ax = anno_df2[!, x_col]
        y_ax = anno_df2[!, y_col]
        colors = unique(anno_df2.new_color)
        if do_legend
            MK.scatter!(ax2, x_ax , y_ax; strokecolor=stroke_color, visible=false,
                color=colors[1], strokewidth=0, markersize=2*legend_size, label=cell_highlight)
            MK.scatter!(ax1, x_ax , y_ax; strokecolor=stroke_color, 
                color=colors[1], strokewidth=0, markersize=marker_size, label=cell_highlight)
        else
            MK.scatter!(ax1, x_ax , y_ax; strokecolor=stroke_color, 
                color=colors[1], strokewidth=0, markersize=marker_size)
        end
    else
        if isa(cell_order, Nothing)
            cell_anno=unique(anno_df[!,anno])
        else
            cell_anno=cell_order
        end
        for i in cell_anno
            anno_df2=filter(anno => ==(i), anno_df)
            x_ax = anno_df2[!, x_col]
            y_ax = anno_df2[!, y_col]
            colors = unique(anno_df2.new_color)
            if do_legend
                MK.scatter!(ax2, x_ax , y_ax; strokecolor=stroke_color, visible=false,
                    color=colors[1], strokewidth=0, markersize=2*legend_size, label=i)
                MK.scatter!(ax1, x_ax , y_ax; strokecolor=stroke_color, 
                    color=colors[1], strokewidth=0, markersize=marker_size, label=i)
            else
                MK.scatter!(ax1, x_ax , y_ax; strokecolor=stroke_color, 
                    color=colors[1], strokewidth=0, markersize=marker_size)
            end
        end
    end
    if do_legend
        MK.Legend(fig[1, 2], ax2, framecolor=:white, labelsize=legend_fontsize, nbanks=legend_ncol)
    end
    if do_label
        for i in cell_anno
            anno_df2 = filter(anno => ==(i), anno_df)
            x_ax = anno_df2[!, x_col]
            y_ax = anno_df2[!, y_col]
            MK.text!(i, position = (mean(x_ax) - label_offset[1], mean(y_ax) - label_offset[2]),align = (:center, :center),font = "Noto Sans Regular",fontsize = label_size,color = label_color)
        end
    end
    return fig
end

function sp_highlight_cells(sp::get_object_group("Imaging"), cell_hightlight::String, anno::Union{String,Symbol};
    canvas_size=(900,1000),stroke_width::Float64=0.1, stroke_color="black", cell_color::String="red",
    marker_size=2,x_lims=nothing, y_lims=nothing, bg_color = "white")
    coord_cells=deepcopy(sp.spmetaData.cell)
    if isa(x_lims, Nothing)
        x_lims=(minimum(sp.spmetaData.cell.x)-0.05*maximum(sp.spmetaData.cell.x),1.05*maximum(sp.spmetaData.cell.x))
    end
    if isa(y_lims, Nothing)
        y_lims=(minimum(sp.spmetaData.cell.y)-0.05*maximum(sp.spmetaData.cell.y),1.05*maximum(sp.spmetaData.cell.y))
    end
    coord_cells[!,anno]=string.(coord_cells[!,anno])
    coord_cells=DataFrames.transform(coord_cells, anno => ByRow(name -> name == cell_hightlight ? name : "others") => :newcell)
    coord_cells=DataFrames.transform(coord_cells, :newcell => ByRow(name -> name =="others" ? "gray90" : cell_color) => :newcolor)
    fig = MK.Figure(size=canvas_size)
    fig[1, 1] = MK.Axis(fig; backgroundcolor = bg_color, xticklabelsize=12, yticklabelsize=12, 
                xticksvisible=false, xticklabelsvisible=false, 
                yticksvisible=false, yticklabelsvisible=false,
                xgridvisible = false,ygridvisible = false)
    MK.scatter!(coord_cells.x, coord_cells.y; color=coord_cells.newcolor, strokewidth=stroke_width, markersize=marker_size,strokecolor=stroke_color)
    MK.xlims!(MK.current_axis(), x_lims)
    MK.ylims!(MK.current_axis(), y_lims)
    return fig
end

function sp_gene_rank(sp::get_object_group("Imaging"), celltype::String, cluster::String; num_gene::Int64=20)
    gene_list=unique(sp.spmetaData.molecule.gene)
    all_df=DataFrame()
    for (i, gene) in enumerate(gene_list)
        norm_counts = sp.normCount
        gene_expr = subset_count(norm_counts; genes = [gene])
        gene_expr = (vec ∘ collect)(gene_expr.count_mtx)
        df = DataFrame()
        df.gene=gene_expr
        df.celltype=string.(sp.spmetaData.cell[!, cluster])
        avg_expr=DataFrames.combine(groupby(df, :celltype), :gene => mean => :avg_exp);
        avg_expr.gene .= gene
        all_df=[all_df; avg_expr]
    end
    gene_mean=DataFrame(gene=sp.rawCount.gene_name,all_mean=vec(mean(sp.rawCount.count_mtx, dims=2)))
    clustern=innerjoin(all_df, gene_mean, on = :gene)
    clustern=filter(:celltype => ==(celltype), clustern)
    clustern.rank=clustern.avg_exp .^ 2 ./ clustern.all_mean
    clustern=sort(clustern, :rank, rev=true)
    clustern=clustern[1:num_gene,:]
    clustern |> @vlplot(:circle, 
        x={:gene,scale={domain=clustern.gene},axis={title="Gene", grid=false}}, 
        y={:rank,axis={title="Ranking", grid=false}})
end

function sp_feature_plot_group(sp_list::Union{ Vector{ImagingSpatialObject}, Vector{VisiumHDObject}, Vector{CartanaObject}, Vector{XeniumObject}, Vector{VisiumObject}, Vector{MerfishObject}, Vector{SlideseqObject}, Vector{seqFishObject}, Vector{STARmapObject}, Vector{StereoSeqObject}, Vector{CosMxObject}}, genes::Vector{String};
    x_col::Union{String, Symbol}="x",y_col::Union{String, Symbol}="y", alpha = [1.0,1.0], clip = 0,
    marker_size = 2, order=false, use_imputed = false,  imp_type::Union{String, Nothing}=nothing,
    height::Real = 500, width::Real = 500, titlesize::Int64 = 24, labels=nothing, img_res="low",
    adjust_contrast::Real = 1.0, adjust_brightness::Real = 0.3, scale = false,x_lims=nothing, y_lims=nothing, 
    color_keys=["gray94","orange","red3"], bg_color=:white)
    c_map = ColorSchemes.ColorScheme([parse(Colorant, color_keys[1]),parse(Colorant, color_keys[2]),parse(Colorant, color_keys[3])])
    if isa(labels, Nothing)
        labels = "Group" .* string.(collect(1:length(sp_list)))
    else
        if length(labels) !== length(sp_list)
            error("Labels must have same length as length(sp_list)")
        end
    end
    fig = MK.Figure(size=(width * length(genes), height * length(sp_list)))
    for m in 1:length(genes)
        gene=genes[m]
        all_expr=[]
        for i in 1:length(sp_list)
            if use_imputed
                if !isdefined(sp_list[i], :imputeData)
                    error("Please impute the data first!")
                end
                if isa(imp_type, Nothing)
                    imp_type = "SpaGE"
                end
                if imp_type === "tangram"
                    impute_data = sp_list[i].imputeData.tgCount
                elseif imp_type === "SpaGE"
                    impute_data = sp_list[i].imputeData.spageCount
                elseif imp_type === "gimVI"
                    impute_data = sp_list[i].imputeData.gimviCount
                else
                    error("imp_type can only be \"tangram\", \"SpaGE\" and \"gimVI\"")
                end
                gene_expr= subset_count(impute_data; genes = [gene])
                gene_expr = (vec ∘ collect)(gene_expr.count_mtx)
            else
                if isdefined(sp_list[i], :normCount)
                    gene_expr=subset_count(sp_list[i].normCount; genes = [gene])
                    gene_expr = (vec ∘ collect)(gene_expr.count_mtx)
                else
                    error("Please normalize the data first!")
                end
            end
            all_expr=[all_expr;gene_expr]
            all_expr=Float64.(all_expr)
            if scale
                all_expr = unit_range_scale(all_expr)
            end
        end
        colors = get(c_map, all_expr, :extrema)
        plt_color = "#" .* hex.(colors)
        total_col = length(plt_color)
        alpha_new = []
        for i in all_expr
            if i > maximum(all_expr) * clip
                alpha_new = [alpha_new; alpha[2]]
            else
                alpha_new = [alpha_new; alpha[1]]
            end
        end
        plt_color = [(i, j) for (i,j) in zip(plt_color, alpha_new)]
        segments=[size(sp_list[i].normCount.count_mtx)[2] for i in 1:length(sp_list)]
        segments=cumsum(segments)
        seg_all=[]
        for i in 1:length(segments)
            if i == 1
             seg_all=[seg_all; [1:segments[i]]]
            else
             seg_all=[seg_all; [(segments[i-1]+1):(segments[i])]]
            end
        end
        for i in 1:length(sp_list)
            if isa(sp_list[i], Union{VisiumObject, VisiumHDObject})
                coord_cell = deepcopy(sp_list[i].spmetaData)
                x_col = Symbol(x_col)
                y_col = Symbol(y_col)
                rename!(coord_cell, [:barcode, :pxl_row_in_fullres, :pxl_col_in_fullres] .=> [:cell, x_col, y_col])
                coord_cell[!, x_col] = Float64.(coord_cell[!, x_col])
                coord_cell[!, y_col] = Float64.(coord_cell[!, y_col])
                if img_res == "high"
                    scale_factor = sp_list[i].imageData.jsonParameters["tissue_hires_scalef"]
                elseif img_res == "low"
                    scale_factor = sp_list[i].imageData.jsonParameters["tissue_lowres_scalef"]
                elseif img_res == "full"
                    dim_full = size(sp_list[i].imageData.fullresImage)
                    dim_high = size(sp_list[i].imageData.highresImage)
                    x_ratio = dim_full[1]/dim_high[1]
                    y_ratio = dim_full[2]/dim_high[2]
                    scale_factor = sp_list[i].imageData.jsonParameters["tissue_hires_scalef"]
                    scale_factor = scale_factor * (x_ratio + y_ratio)/2    
                else
                    error("img_res can only be \"high\", \"low\" or \"full\"!")
                end
                coord_cell[!, x_col] =  coord_cell[!, x_col] .* scale_factor
                coord_cell[!, y_col] =  coord_cell[!, y_col] .* scale_factor
                data_plt = coord_cell
            else
                data_plt = deepcopy(sp_list[i].spmetaData.cell)
            end
            data_plt.color = plt_color[seg_all[i]]
            data_plt.gene_expr = all_expr[seg_all[i]]
            if isa(x_lims, Nothing)
                x_lims=(minimum(data_plt[!, x_col])-0.05*maximum(data_plt[!, x_col]),1.05*maximum(data_plt[!, x_col]))
            end
            if isa(y_lims, Nothing)
                y_lims=(minimum(data_plt[!, y_col])-0.05*maximum(data_plt[!, y_col]),1.05*maximum(data_plt[!, y_col]))
            end
            if order
                sort!(data_plt, :gene_expr)
            end
            if i == 1
                y_label = gene
            else
                y_label = ""
            end
            if m == 1
                title_name = labels[i]
            else
                title_name = ""
            end
            ax = MK.Axis(fig[m, i]; backgroundcolor = bg_color, xticklabelsize = 12, yticklabelsize = 12, xticksvisible = false, 
                            xticklabelsvisible = false, yticksvisible = false, yticklabelsvisible = false,
                            xgridvisible = false, ygridvisible = false,yreversed=false, title = title_name, 
                            titlesize = titlesize , xlabel = "", ylabel = y_label, ylabelsize = titlesize)
            if isa(sp_list[i], Union{VisiumObject, VisiumHDObject})
                if img_res == "high"
                    img = deepcopy(sp_list[i].imageData.highresImage)
                elseif img_res == "low"
                    img = deepcopy(sp_list[i].imageData.lowresImage)
                else
                    img = deepcopy(sp_list[i].imageData.fullresImage)
                end
                img2 = augment(img, ColorJitter(adjust_contrast, adjust_brightness))
                MK.image!(ax, img2)
            end
            MK.xlims!(MK.current_axis(), x_lims)
            MK.ylims!(MK.current_axis(), y_lims)
            MK.scatter!(ax, data_plt[!, x_col], data_plt[!, y_col]; 
                color=data_plt.color, strokewidth=0,markersize=marker_size)
            if i == length(sp_list)
                MK.Colorbar(fig[m,length(sp_list)+1], label = "", 
                    colormap = c_map, width=10, limits = (0, maximum(data_plt.gene_expr)))
            end
        end
    end
    return fig
end

function plot_fov(sp::get_object_group("Spatial"), n_fields_x::Int64, n_fields_y::Int64; 
    x_col::Union{String, Symbol}="x", y_col::Union{String, Symbol}="y", group_label::Union{Nothing, String}=nothing, alpha = 1, adjust_coord_to_img = "auto",
    custom_img=false, width=4000, height=4000, cell_highlight::Union{Nothing, String, Number}=nothing, shield::Bool= false, marker_size::Union{Int64, Float64, Nothing}=nothing)
    coord_limits = spatial_range(sp)
    if isa(sp, VisiumObject)
        df = deepcopy(sp.spmetaData)
        if !isa(group_label, Nothing)
            meta = deepcopy(sp.metaData)
            df[!,group_label] = meta[!, group_label]
        end
        rename!(df, [:barcode, :pxl_row_in_fullres, :pxl_col_in_fullres] .=> [:cell, Symbol(x_col), Symbol(y_col)])
        scale_factor = sp.imageData.jsonParameters["tissue_hires_scalef"]
        df[!, x_col] =  df[!, x_col] .* scale_factor
        df[!, y_col] =  df[!, y_col] .* scale_factor
        coord_limits[1] = round.(Int, coord_limits[1] .* scale_factor)
        coord_limits[2] = round.(Int, coord_limits[2] .* scale_factor)
    elseif isa(sp, VisiumHDObject)
        if isa(sp.alterImgData, Nothing)
            df = deepcopy(sp.spmetaData)
            rename!(df, [:barcode, :pxl_row_in_fullres, :pxl_col_in_fullres] .=> [:cell, Symbol(x_col), Symbol(y_col)])
        else
            df = deepcopy(sp.alterImgData.posData.positions["high_pos"])
        end
        if !isa(group_label, Nothing)
            meta = deepcopy(sp.metaData)
            df[!,group_label] = meta[!, group_label]
        end
        scale_factor = sp.imageData.jsonParameters["tissue_hires_scalef"]
        df[!, x_col] =  df[!, x_col] .* scale_factor
        df[!, y_col] =  df[!, y_col] .* scale_factor
    else
        df = deepcopy(sp.spmetaData.cell)
    end
    if isa(sp, XeniumObject)
        if custom_img
            scale_factor = get_xn_sf(sp; adjust_coord_to_img=adjust_coord_to_img)
            scale_x = scale_factor[1]
            scale_y = scale_factor[2]
            df[!, x_col] = df[!, x_col] ./ scale_x
            df[!, y_col] = df[!, y_col] ./ scale_y
        end
    end
    pts, centroids=split_field(df, n_fields_x, n_fields_y)
    centroids=convert.(Tuple{Float64, Float64},centroids)
    if isa(sp, VisiumObject)
        x_lims = coord_limits[1]
    else
        x_lims=(minimum(df[!, x_col])-0.05*maximum(df[!, x_col]),1.05*maximum(df[!, x_col]))
    end
    if isa(sp, VisiumObject)
        y_lims = coord_limits[2]
    else
        y_lims=(minimum(df[!, y_col])-0.05*maximum(df[!, y_col]),1.05*maximum(df[!, y_col]))
    end
    label_size= 800 * 16/length(centroids)
    if label_size < 35
       label_size = 35
    elseif label_size > 1600
        label_size = 1600
    end
    fig = MK.Figure(size=(width, height))
    fig[1, 1] = MK.Axis(fig; xticklabelsize=12, yticklabelsize=12, xticksvisible=false, 
                xticklabelsvisible=false, yticksvisible=false, yticklabelsvisible=false,
                xgridvisible = false,ygridvisible = false)
    if isa(sp, VisiumObject)
        img = deepcopy(sp.imageData.highresImage)
        MK.image!(img)
    end
    if isa(sp, VisiumHDObject)
        if isa(sp.alterImgData, Nothing)
            img = deepcopy(sp.imageData.highresImage)
        else
            img = deepcopy(sp.alterImgData.imgData.imgs["high"])
        end
        max_w = minimum([size(img)[1], Int(round(maximum(df[!, x_col])))])
        max_h = minimum([size(img)[2], Int(round(maximum(df[!, y_col])))])
        x_lims=[1,max_w]
        y_lims=[1,max_h]
        img = img[x_lims[1]:x_lims[2], y_lims[1]:y_lims[2]]
        df = filter([:x, :y] => (x, y) -> x_lims[1] < x < x_lims[2] && y_lims[1] < y < y_lims[2], df)
        MK.image!(img)
    end
    if custom_img
        if isa(sp, XeniumObject)
            img = deepcopy(sp.imageData)
            MK.image!(img)
        end
    end

    if isa(marker_size, Nothing)
        if isa(sp, XeniumObject)
            marker_size = 8
        elseif isa(sp, VisiumHDObject)
            marker_size = 5
        elseif isa(sp, VisiumObject)
            marker_size = 50
        else
            marker_size = 10
        end
    end

    if isa(group_label, Nothing) && isa(cell_highlight, Nothing)
        MK.scatter!(df[!,x_col],df[!, y_col]; strokecolor="black", color=(:gray98, alpha), strokewidth=0.5,label="", markersize=marker_size)
    elseif isa(group_label, Nothing) && isa(cell_highlight, String)
        error("Please indicate the group name that contains cell type info!")
    elseif isa(group_label, String) && isa(cell_highlight, Nothing)
        error("Please indicate the cell type name to be highlighted!")
    else
        df[!,group_label]=string.(df[!,group_label])
        df=DataFrames.transform(df, group_label => ByRow(name -> name == cell_highlight ? name : "others") => :newcell)
        df=DataFrames.transform(df, :newcell => ByRow(name -> name =="others" ? "gray98" : "black") => :newcolor)
        df.newcolor = [(i, alpha) for i in df.newcolor]
        if marker_size > 0
            MK.scatter!(df[!, x_col],df[!, y_col]; strokecolor="black", color=df.newcolor, strokewidth=0.5,label="", markersize=marker_size)
        end
    end
    if shield
        label_color=:yellow1
        bg_color=(:blue, 0.3)
        font_style="Noto Sans Bold"
    else
        label_color= cgrad(:darkrainbow)[LinRange(0, 1, length(centroids))]
        bg_color=:transparent
        font_style="Noto Sans Regular"
    end
    MK.poly!([p for p in pts]; color = bg_color, strokecolor = :black, strokewidth = 3)
    MK.text!(string.(1:length(centroids)),position = centroids,align = (:center, :center),font = font_style,fontsize = label_size,color = label_color)
    if isa(sp, VisiumHDObject)
        MK.xlims!(MK.current_axis(), x_lims .- x_lims[1] .+ 1)
        MK.ylims!(MK.current_axis(), y_lims .- y_lims[1] .+ 1)
    else
        MK.xlims!(MK.current_axis(), x_lims)
        MK.ylims!(MK.current_axis(), y_lims)
    end
    return fig
end

function plot_point(sp::get_object_group("Imaging"), pt::Vector{Float64}; 
    canvas_size=(4000,4000),marker_size=60, text_size=100, 
    pt_color="red", text_color="blue", label="point")
    df = sp.spmetaData.cell
    pt2=MK.Point2f0(pt[1], pt[2])
    x_lims=(minimum(df.x)-0.05*maximum(df.x),1.05*maximum(df.x))
    y_lims=(minimum(df.y)-0.05*maximum(df.y),1.05*maximum(df.y))
    fig = MK.Figure(size=canvas_size)
    fig[1, 1] = MK.Axis(fig; xticklabelsize=12, yticklabelsize=12, xticksvisible=false, 
                xticklabelsvisible=false, yticksvisible=false, yticklabelsvisible=false,
                xgridvisible = false,ygridvisible = false);
    MK.scatter!(df.x,df.y; strokecolor="black", color=:gray98, strokewidth=0.5,label="")
    MK.scatter!([pt[1]],[pt[2]]; strokecolor="black", color=pt_color, strokewidth=0.5,label="",markersize=marker_size)    
    MK.text!(label,position = pt2,align = (:center, :bottom),fontsize = text_size,color = text_color)
    MK.xlims!(MK.current_axis(), x_lims)
    MK.ylims!(MK.current_axis(), y_lims)
    return fig
end

function plot_depth(sp::get_object_group("Spatial"); celltype::Union{String, Symbol} = :celltype,
    cmap=nothing, cell_select=nothing, fontsize=16, scale=0.8, markers=nothing)
        cells=sp.spmetaData.cell
        celltypes=cell_select
        if isa(celltypes, Nothing)
            cell_order= DataFrames.combine(groupby(cells, celltype),:depth=>mean=>:mean)
            sort!(cell_order, :mean)
            celltypes=cell_order[!, celltype]
            celltypes=reverse(celltypes)
        end
        sort!(cells, :depth)
        if isa(cmap, Nothing)
            cell_colors = [cgrad(:thermal, [0.0, 1.0])[z] for z in cells.depth]
        else
            cell_colors = [cgrad(cmap, [0.0, 1.0])[z] for z in cells.depth]
        end
        fig = MK.Figure(size=(1200,600))
        ax1=MK.Axis(fig[1, 1]; xticklabelsize=(fontsize-4), yticklabelsize=fontsize, xticksvisible=false, xticklabelsvisible=false, yticksvisible=false, yticklabelsvisible=false,xgridvisible = false,ygridvisible = false,title = "Cells colored by kidney depth",titlesize = fontsize)
        ax2=MK.Axis(fig[1,2]; xticklabelsize=(fontsize-4) ,yticklabelsize=fontsize, xticksvisible=true, xticklabelsvisible=true, yticksvisible=true, yticklabelsvisible=true,xgridvisible = false,ygridvisible = false, title = "Cell distribution from cortex to papilla",titlesize = fontsize,yticks = ((1:length(celltypes)) ./ scale,  celltypes))
        MK.scatter!(ax1, cells.x, cells.y; color = cell_colors, markersize = 2)
        for i in length(celltypes):-1:1
            cell_density=filter(:celltype => ==(celltypes[i]), cells)
            cell_density=float.(cell_density.depth)
            d = MK.density!(ax2, cell_density,npoints=200, offset = i / scale,
                color = :x, colormap = cell_colors, colorrange = (0, 1),
                strokewidth = 1, strokecolor = :black)
            MK.translate!(d, 0, 0, -0.05i)
        end
        if markers !== nothing
        molecules=sp.spmetaData.molecule
        cell2=sp.spmetaData.cell.cell
        molecules = filter(:cell=> ∈(Set(cell2)), molecules)
        from=cell2
        to=cells.depth
        molecules2=map_values(molecules, :cell, :depth, from, to)
        markers=markers
        ax3=MK.Axis(fig[1, 3]; xticklabelsize=(fontsize-4) ,yticklabelsize=fontsize, 
            xticksvisible=true, xticklabelsvisible=true, yticksvisible=true, 
            yticklabelsvisible=true,xgridvisible = false,ygridvisible = false, 
            title = "Transcript distribution from cortex to papilla",
            titlesize = fontsize,yticks = ((1:length(markers)) ./ scale,  markers))
            for j in length(markers):-1:1
                cell_density2=filter(:gene => ==(markers[j]), molecules2)
                cell_density2=float.(cell_density2.depth)
                f = MK.density!(ax3, cell_density2,npoints=200, offset = j / scale,
                        color = :x, colormap = cell_colors, colorrange = (0, 1),
                        strokewidth = 1, strokecolor = :black)
                MK.translate!(f, 0, 0, -0.05j)
            end
        end
        return fig
end

function plot_depth_animation(sp::get_object_group("Spatial"), celltypes::Vector{String}, markers::Vector{String}; 
    group_label="celltype",gene_label="gene", bg_color="gray94",fontsize=16, scale=0.8, width=1800,height=600, file_name="animation.gif", framerate=30,
    titles = ["Cells colored by kidney depth","Cell distribution from cortex to papilla","Transcript distribution from cortex to papilla"])
    cells = sp.spmetaData.cell
    cells = filter(group_label => ∈(Set(celltypes)), cells)
    molecules = sp.spmetaData.molecule
    molecules = filter(gene_label => ∈(Set(markers)), molecules)
    fig = MK.Figure(size = (width, height))
    ax1 = MK.Axis(fig[1, 1]; xticklabelsize = (fontsize-4), yticklabelsize=fontsize, xticksvisible=false, xticklabelsvisible=false, yticksvisible=false, yticklabelsvisible=false,xgridvisible = false,ygridvisible = false,title = titles[1],titlesize = fontsize)
    ax2 = MK.Axis(fig[1, 3]; xticklabelsize = (fontsize-4) ,yticklabelsize=fontsize, xticksvisible=true, xticklabelsvisible=true, yticksvisible=true, yticklabelsvisible=true,xgridvisible = false,ygridvisible = false, title = titles[2],titlesize = fontsize,yticks = ((1:length(celltypes)) ./ scale,  celltypes))
    ax3 = MK.Axis(fig[1, 2]; xticklabelsize = (fontsize-4) ,yticklabelsize=fontsize, xticksvisible=true, xticklabelsvisible=true, yticksvisible=true, yticklabelsvisible=true,xgridvisible = false,ygridvisible = false, title = titles[3],titlesize = fontsize,yticks = ((1:length(markers)) ./ scale,  markers))
    MK.scatter!(ax1, cells.x, cells.y; color = bg_color, markersize = 2)
    for i in length(celltypes):-1:1
        celltype = celltypes[i]
        cell_density0 = filter(:celltype => ==(celltype), cells)
        cell_density0 = float.(cell_density0.depth)
        d0 = MK.density!(ax2, cell_density0, npoints = 200, offset = i / scale, 
            color = bg_color, strokewidth = 1, strokecolor = :black)
        MK.translate!(d0, 0, 0, -0.05i)
    end
    for j in length(markers):-1:1
        mol_density0 = filter(gene_label => ==(markers[j]), molecules)
        mol_density0 = float.(mol_density0.depth)
        f0 = MK.density!(ax3, mol_density0,npoints=200, offset = j / scale,
                color = bg_color, strokewidth = 1, strokecolor = :black)
        MK.translate!(f0, 0, 0, -0.05j)
    end
    timestamps = range(0.01, 1, length = framerate)
    MK.record(fig, file_name, timestamps; framerate = framerate) do t
            cells_t = filter(:depth => <(t), cells)
            cell_stats_t = countmap(cells_t.celltype)
            depth_val = cells_t.depth
            depth_val = float.(depth_val)
            cs = ColorSchemes.ColorScheme([colorant"#0d2232",colorant"#1b326e",colorant"#473899",colorant"#6e4b8e",colorant"#935c87",colorant"#a6606c",colorant"#dc7f60",colorant"#eea152",colorant"#f2cd5d", colorant"#ecf975"])
            colors = get(cs, depth_val, :extrema)
            cell_colors = "#" .* hex.(colors)
            MK.scatter!(ax1, cells_t.x, cells_t.y; color = cell_colors, markersize = 2)
            for i in length(celltypes):-1:1
                cell_density = filter(:celltype => ==(celltypes[i]), cells)
                cell_density = float.(cell_density.depth)
                cs = ColorSchemes.ColorScheme([colorant"#0d2232",colorant"#1b326e",colorant"#473899",colorant"#6e4b8e",colorant"#935c87",colorant"#a6606c",colorant"#dc7f60",colorant"#eea152",colorant"#f2cd5d", colorant"#ecf975", parse(Colorant, bg_color)])
                sort!(depth_val)
                colors = get(cs, depth_val, :extrema)
                cell_colors="#" .* hex.(colors)
                d = MK.density!(ax2, cell_density,npoints = 200, offset = i / scale, 
                    color = :x, colormap = cell_colors, colorrange = (0, t),
                    strokewidth = 1, strokecolor = :black)
                MK.translate!(d, 0, 0, -0.05i)
            end
            molecule_t = filter(:depth => <(t), molecules)
            for j in length(markers):-1:1
                mol_density = filter(gene_label => ==(markers[j]), molecules)
                mol_density = float.(mol_density.depth)
                cs = ColorSchemes.ColorScheme([colorant"#0d2232",colorant"#1b326e",colorant"#473899",colorant"#6e4b8e",colorant"#935c87",colorant"#a6606c",colorant"#dc7f60",colorant"#eea152",colorant"#f2cd5d", colorant"#ecf975", parse(Colorant, bg_color)])
                depth_val = molecule_t.depth
                sort!(depth_val)
                colors = get(cs, depth_val, :extrema)
                mol_colors="#" .* hex.(colors)
                f = MK.density!(ax3, mol_density, npoints = 200, offset = j / scale,
                        color = :x, colormap = mol_colors, colorrange = (0, t),
                        strokewidth = 1, strokecolor = :black)
                MK.translate!(f, 0, 0, -0.05j)
            end
        end
end

function plot_gene_depth(sp::get_object_group("Spatial"), gene::String;
    c_map::Union{String, Symbol, Nothing}=nothing, cell_col="cell",
    canvas_size =(1200,300),marker_size=4,
    stroke_width=0.5,stroke_color="gray94",
    expr_cutoff=0.25,n_bins=50
)
    coord_cell=sp.spmetaData.cell
    norm_counts=sp.normCount
    gene_expr = subset_count(norm_counts; genes = [gene])
    gene_expr = (vec ∘ collect)(gene_expr.count_mtx)
    df = DataFrame()
    df.gene_expr=gene_expr
    coord_cell[!, cell_col]=string.(coord_cell[!, cell_col])
    df.cell=string.(coord_cell[!, cell_col])
    df_plt=innerjoin(df, coord_cell, on = cell_col)
    df_plt.gene.=gene
    df_plt.depth=float.(df_plt.depth)
    df_plt.gene_expr=float.(df_plt.gene_expr)
    if isa(c_map, Nothing)
        c_map=:gist_heat
    end
    fig = MK.Figure(size=canvas_size)
    fig[1, 1] = MK.Axis(fig; xticklabelsize=16, yticklabelsize=16, 
                xticksvisible=false, xticklabelsvisible=false, 
                yticksvisible=false, yticklabelsvisible=false,
                xgridvisible = false,ygridvisible = false, 
                ylabel = "Expression", xlabel = "Kidney depth")
    df_plt = filter(:gene_expr => >(expr_cutoff), df_plt)
    x_hist = StatsBase.fit(Histogram, tuple(df_plt.depth, df_plt.gene_expr), nbins=n_bins) 
    MK.contour!(x_hist,levels = 3,fillrange = true, colormap=c_map)
    MK.ylims!(MK.current_axis(), (0.25, 0.75))
    return fig
end

function PlotInteractive(sp::get_object_group("Spatial"); layer::String = "cells", marker_color::Union{Symbol, String}="black", marker_size=3, plot_mode="markers")
    if layer === "cells"
        cells=sp.spmetaData.cell
        plyjs.plot(plyjs.scatter(x=cells.x, y=cells.y, mode=plot_mode, marker=plyjs.attr(size=marker_size, color=marker_color)))
    elseif layer === "molecules"
        molecules = sp.spmetaData.molecule
        plyjs.plot(plyjs.scatter(x=molecules.x, y=molecules.y, mode=plot_mode, marker=plyjs.attr(size=marker_size, color=marker_color)))
    else
        println("Layer must be \"cells\" or \"molecules\"")
    end
end

function plot_transcript_dapi(sp::get_object_group("Imaging"), fov::Int64, n_fields_x::Int64, 
    n_fields_y::Int64; noise_ann=nothing,annotation=:cell,
    is_noise=nothing, draw_poly=false, marker_size=3)
    selected_view = subset_fov(sp, fov, n_fields_x, n_fields_y)
    xmin = trunc(Int64,minimum(selected_view.x))
    xmax = trunc(Int64,maximum(selected_view.x))
    ymin = trunc(Int64,minimum(selected_view.y))
    ymax = trunc(Int64, maximum(selected_view.y))
    polygons = sp.polygonData
    df_spatial = sp.spmetaData.molecule
    img = sp.imageData
    df_spatial = filter([:x, :y]=> (x,y) -> xmin < x < xmax && ymin < y < ymax, df_spatial)
    df_spatial = filter(:is_noise => ==(0), df_spatial)
    poly = sp.imageData.polygon
    cells = df_spatial.cell
    poly.mapped_cell = Int.(poly.mapped_cell)
    poly = filter(:mapped_cell => ∈(Set(cells)), poly)
    polygons = polygons[poly.polygon_number]
    img2 = img[ymin:ymax,xmin:xmax]'
    plt_x = df_spatial.x .- xmin
    plt_y = df_spatial.y .- ymin
    fig = MK.Figure(size=(500,500))
    fig[1, 1] = MK.Axis(fig; xticklabelsize=12, yticklabelsize=12, 
        xticksvisible = false, xticklabelsvisible=false, backgroundcolor = :black,
        yticksvisible = false, yticklabelsvisible=false, xgridvisible = false,ygridvisible = false )
    annotation = df_spatial[!,annotation]
    ann_vals = annotation[annotation .!= noise_ann] |> unique |> sort
    c_map = Colors.distinguishable_colors(length(ann_vals), 
        Colors.colorant"#007a10", lchoices=range(20, stop=70, length=15))
    MK.image!(img2)
    for (color, ann) in zip(c_map, ann_vals)
            MK.scatter!(df_spatial.x[annotation .== ann] .- xmin, df_spatial.y[annotation .== ann] .- ymin;
            strokewidth=0, markersize=marker_size, label=ann, color=(color,1))
    end
    if draw_poly
        MK.poly!([MK.Point2.(eachrow(p .- [xmin ymin])) for p in polygons]; strokecolor=("cyan",0.7), color="transparent", strokewidth=2,label="")
    end
    MK.xlims!(MK.current_axis(), (minimum(plt_x), maximum(plt_x)))
    MK.ylims!(MK.current_axis(), (minimum(plt_y), maximum(plt_y)))
    return fig
end

function compare_gene_imputation(sp1::Union{ImagingSpatialObject, CartanaObject,XeniumObject, MerfishObject, STARmapObject, seqFishObject, StereoSeqObject, CosMxObject},sp2::Union{CartanaObject,XeniumObject,MerfishObject, STARmapObject, seqFishObject, StereoSeqObject, CosMxObject}, gene_list::Union{Vector, String},
    cluster::Union{Symbol, String}; sp1_name::String ="sp1", sp2_name::String="sp2",
    assay_use::String="measured",expr_cutoff::Union{Float64, Int64}=0, legend_min::Union{Float64, Int64}=0, legend_max::Union{Float64, Int64}=1, 
    x_title="Gene",y_title="Cell type", cell_order::Union{Vector, String, Nothing}=nothing,
    fontsize::Int64=12, color_range::Vector=["white", "ivory","gold","orange","tomato","red"],
    fig_height::Union{String, Int64}=400, fig_width::Union{String, Int64}=400)
    all_df=DataFrame()
    if assay_use === "measured"
        ct_mtx1 = deepcopy(sp1.normCount)
        ct_mtx2 = deepcopy(sp2.normCount)
    elseif assay_use === "predicted"
            if imp_type === "tangram"
                ct_mtx1 = sp1.imputeData.tgCount
                ct_mtx2 = sp2.imputeData.tgCount
            elseif imp_type === "SpaGE"
                ct_mtx1 = sp1.imputeData.spageCount
                ct_mtx2 = sp2.imputeData.spageCount
            elseif imp_type === "gimVI"
                ct_mtx1 = sp1.imputeData.gimviCount
                ct_mtx2 = sp2.imputeData.gimviCount
            else
                error("imp_type can only be \"tangram\", \"SpaGE\" and \"gimVI\"")
            end
    else
        error("assay_use can only be \"measured\" or \"predicted\"")
    end
        all_df=DataFrame()
        for (i, gene) in enumerate(gene_list)
            gene_expr= subset_count(ct_mtx1; genes = [gene])
            gene_expr = (vec ∘ collect)(gene_expr.count_mtx)
            df = DataFrame()
            df.gene=gene_expr
            df.celltype=string.(sp1.spmetaData.cell[!, cluster])
            avg_expr1=DataFrames.combine(groupby(df, :celltype), :gene => mean => :avg_exp)
            avg_expr1.group .= sp1_name
            gene_expr= subset_count(ct_mtx2; genes = [gene])
            gene_expr = (vec ∘ collect)(Float64.(gene_expr.count_mtx))
            df = DataFrame()
            df.gene=gene_expr
            df.celltype=string.(sp2.spmetaData.cell[!, cluster])
            avg_expr2=DataFrames.combine(groupby(df, :celltype), :gene => mean => :avg_exp)
            avg_expr2.group .= sp2_name
            avg_expr = [avg_expr1; avg_expr2]
            if scale
                avg_expr.avg_exp= unit_range_scale(avg_expr.avg_exp)
            end
            perc_expr=DataFrames.combine(groupby(df, :celltype), :gene => function(x) countmap(x.>expr_cutoff)[:1]*100/length(x) end => :perc_exp)
            df_plt=innerjoin(avg_expr, perc_expr, on = :celltype)
            df_plt.gene.=gene
            all_df=[all_df; df_plt]
        end
        p=all_df |> @vlplot(:rect,
            y={"gene:o", title="Gene", scale={
                    domain=gene_list
                }, axis={labelFontSize=fontsize,titleFontSize=fontsize}},
            x={"celltype:o", title="Cell type",
               scale={
                    domain=cell_order
                }, axis={labelFontSize=fontsize,titleFontSize=fontsize}},
            color={"avg_exp:q",
                    scale={domainMin=legend_min, domainMax=legend_max, range=color_range}},
            column={:group, header={labelFontSize=16, title=nothing}},
            height= fig_height, width=fig_width
            )
        return p
end

function plot_heatmap(sp::get_object_group("Imaging"), gene_list::Union{Vector, String},
    cluster::Union{Symbol, String};assay_use::String="measured",expr_cutoff::Union{Float64, Int64}=0, split_by::Union{String, Nothing}=nothing,
    x_title="Gene",y_title="Cell type", cell_order::Union{Vector, String, Nothing}=nothing,imp_type="SpaGE",
    fontsize::Int64=12, color_keys=["white", "ivory","gold","orange","tomato","red"],reverse_color::Bool=false,scale::Bool=false,
    height::Union{String, Int64}=400, width::Union{String, Int64}=400)
    all_df=DataFrame()
    if assay_use === "measured"
        ct_mtx = deepcopy(sp.normCount)
    elseif assay_use === "predicted"
        if imp_type === "tangram"
            ct_mtx = sp.imputeData.tgCount
        elseif imp_type === "SpaGE"
            ct_mtx = sp.imputeData.spageCount
        elseif imp_type === "gimVI"
            ct_mtx = sp.imputeData.gimviCount
        else
            error("imp_type can only be \"tangram\", \"SpaGE\" and \"gimVI\"")
        end
    else
        error("assay_use can only be \"measured\" or \"predicted\"")
    end
    if isa(split_by, Nothing)
        all_df=DataFrame()
        for (i, gene) in enumerate(gene_list)
            gene_expr= subset_count(ct_mtx; genes = [gene])
            gene_expr = (vec ∘ collect)(gene_expr.count_mtx)
            df = DataFrame()
            df.gene=gene_expr
            df.celltype=string.(sp.spmetaData.cell[!, cluster])
            avg_expr=DataFrames.combine(groupby(df, :celltype), :gene => mean => :avg_exp)
            if scale
                avg_expr.avg_exp= unit_range_scale(avg_expr.avg_exp)
            end
            perc_expr=DataFrames.combine(groupby(df, :celltype), :gene => function(x) countmap(x.>expr_cutoff)[:1]*100/length(x) end => :perc_exp)
            df_plt=innerjoin(avg_expr, perc_expr, on = :celltype)
            df_plt.gene.=gene
            all_df=[all_df; df_plt]
        end
        p=all_df |> @vlplot(:rect,
            y={"gene:o", title="Gene", scale={
                    domain=gene_list
                }, axis={labelFontSize=fontsize,titleFontSize=fontsize}},
            x={"celltype:o", title="Cell type",
               scale={
                    domain=cell_order
                }, axis={labelFontSize=fontsize,titleFontSize=fontsize}},
            color={"avg_exp:q",
            scale={domainMin = 0, domainMax = maximum(all_df.avg_exp), range=color_keys}},
            height= height, width=width
            )
    else
        all_df=DataFrame()
        for (i, gene) in enumerate(gene_list)
            gene_expr= subset_count(ct_mtx; genes = [gene])
            gene_expr = (vec ∘ collect)(gene_expr.count_mtx)
            df = DataFrame()
            if scale
                gene_expr =unit_range_scale(gene_expr)
            end
            df.gene = gene_expr
            df.celltype=string.(sp.spmetaData.cell[!, cluster])
            df.split_by = string.(sp.spmetaData.cell[!, split_by])
            avg_expr=DataFrames.combine(groupby(df, [:celltype, :split_by]), :gene => mean => :avg_exp)
            perc_expr=DataFrames.combine(groupby(df, [:celltype,:split_by]), :gene => function(x) countmap(x.>expr_cutoff)[:1]*100/length(x) end => :perc_exp)
            df_plt=innerjoin(avg_expr, perc_expr, on = [:celltype,:split_by])
            df_plt.gene.=gene
            all_df=[all_df; df_plt]
        end
        p=all_df |> @vlplot(:rect,
            y={"gene:o", title="Gene", scale={
                    domain=gene_list
                }, axis={labelFontSize=fontsize,titleFontSize=fontsize}},
            x={"celltype:o", title="Cell type",
               scale={
                    domain=cell_order
                }, axis={labelFontSize=fontsize,titleFontSize=fontsize}},
            color={"avg_exp:q",
            scale={domainMin = 0, domainMax = maximum(all_df.avg_exp), range=color_keys}},
            column={:split_by, header={labelFontSize=16, title=nothing}},
            height= height, width=width
            )        
    end
        return p
end

function overlay_visium_cartana(vs::Union{VisiumObject, SlideseqObject, VisiumHDObject}, sp::Union{ImagingSpatialObject, CartanaObject,XeniumObject,MerfishObject, STARmapObject, seqFishObject, StereoSeqObject, CosMxObject}; vs_x = "new_x", vs_y = "new_y", 
    sp_x = "new_x", sp_y = "new_y", vs_color=:red, sp_color=:blue, vs_markersize=7, 
    sp_markersize=2, vs_title="Visium", sp_title="Cartana")
    cartana_df = deepcopy(sp.spmetaData.cell)
    visium_df = deepcopy(vs.spmetaData.cell)
    fig = MK.Figure(size=(1800,500))
    ax1 = MK.Axis(fig[1, 1]; xticklabelsize=12, yticklabelsize=12, xticksvisible=false, 
                            xticklabelsvisible=false, yticksvisible=false, yticklabelsvisible=false,
                            xgridvisible = false, ygridvisible = false,yreversed=false, title = sp_title, titlesize=26)
    ax2 = MK.Axis(fig[1, 2]; xticklabelsize=12, yticklabelsize=12, xticksvisible=false, 
                            xticklabelsvisible=false, yticksvisible=false, yticklabelsvisible=false,
                            xgridvisible = false, ygridvisible = false,yreversed=false, title = vs_title, titlesize=26)
    ax3 = MK.Axis(fig[1, 3]; xticklabelsize=12, yticklabelsize=12, xticksvisible=false, 
                            xticklabelsvisible=false, yticksvisible=false, yticklabelsvisible=false,
                            xgridvisible = false, ygridvisible = false,yreversed=false, title = sp_title * "+" * vs_title, titlesize=26)
    MK.scatter!(ax1, unit_range_scale(cartana_df[!, sp_x]), unit_range_scale(cartana_df[!, sp_y]); color=(sp_color,0.5),strokewidth=0, markersize=sp_markersize)
    MK.scatter!(ax2, unit_range_scale(visium_df[!, vs_x]), unit_range_scale(visium_df[!, vs_y]); color=(vs_color,0.8),strokewidth=0, markersize=vs_markersize)
    MK.scatter!(ax3, unit_range_scale(cartana_df[!, sp_x]), unit_range_scale(cartana_df[!, sp_y]); color=(sp_color,0.5),strokewidth=0, markersize=sp_markersize)
    MK.scatter!(ax3, unit_range_scale(visium_df[!, vs_x]), unit_range_scale(visium_df[!, vs_y]); color=(vs_color,0.8),strokewidth=0, markersize=vs_markersize)
    return fig
end

function overlay_visium_cartana_gene(vs::Union{VisiumObject, SlideseqObject, VisiumHDObject}, sp::Union{ImagingSpatialObject, CartanaObject,XeniumObject, MerfishObject, STARmapObject, seqFishObject, StereoSeqObject, CosMxObject}, gene; vs_x="new_x", vs_y="new_y", sp_x="new_x", sp_y="new_y",
    vs_color=:red, sp_color=:blue, vs_markersize=7, canvas_size=(1800,500),x_lims=nothing, y_lims=nothing,
    sp_markersize=2, vs_title="Visium", sp_title="Cartana", order=true, scale = true)
    vs_count=deepcopy(vs.normCount)
    sp_count=deepcopy(sp.normCount)
    gene_expr= subset_count(vs_count; genes = [gene])
    gene_expr = (vec ∘ collect)(gene_expr.count_mtx)
    if scale
        gene_expr=unit_range_scale(gene_expr)
    end
    df1=DataFrame()
    df1.gene_expr = gene_expr
    c_map = ColorSchemes.ColorScheme([colorant"gray96",colorant"red",colorant"red3"])
    colors = get.(Ref(c_map), (gene_expr .- minimum(gene_expr)) ./ maximum(gene_expr))
    plt_color1="#" .* hex.(colors)
    df1.color1=plt_color1
    plt_color2=[(x, 0.5) for x in plt_color1]
    df1.color2=plt_color2
    df1.x = vs.spmetaData.cell[!, vs_x]
    df1.y = vs.spmetaData.cells[!, vs_y]
    gene_expr= subset_count(sp_count; genes = [gene])
    gene_expr = (vec ∘ collect)(gene_expr.count_mtx)
    if scale
        gene_expr=unit_range_scale(gene_expr)
    end
    df2=DataFrame()
    df2.gene_expr = gene_expr
    c_map = ColorSchemes.ColorScheme([colorant"gray96",colorant"blue",colorant"blue3"])
    colors = get.(Ref(c_map), (gene_expr .- minimum(gene_expr)) ./ maximum(gene_expr))
    plt_color3="#" .* hex.(colors)
    df2.color3=plt_color3
    plt_color4=[(x, 0.5) for x in plt_color3]
    df2.color4=plt_color4
    df2.x = sp.spmetaData.cell[!, sp_x]
    df2.y = sp.spmetaData.cell[!, sp_y]
    if order
        df2 = sort(df2,:gene_expr)        
    end
    if isa(x_lims, Nothing)
        x_lims=(minimum(sp.spmetaData.cell[!, sp_x])-0.1,maximum(sp.spmetaData.cell[!, sp_x])+0.1)
    end
    if isa(y_lims, Nothing)
        y_lims=(minimum(sp.spmetaData.cell[!, sp_y])-0.1,maximum(sp.spmetaData.cell[!, sp_y])+0.1)
    end
    fig = MK.Figure(size=canvas_size)
    ax3 = MK.Axis(fig[1,3]; xticklabelsize=12, yticklabelsize=12, xticksvisible=false, 
                            xticklabelsvisible=false, yticksvisible=false, yticklabelsvisible=false,
                            xgridvisible = false, ygridvisible = false, title = vs_title * "+" * sp_title, titlesize=26)
    MK.xlims!(MK.current_axis(), x_lims)
    MK.ylims!(MK.current_axis(), y_lims)
    ax1 = MK.Axis(fig[1,1]; xticklabelsize=12, yticklabelsize=12, xticksvisible=false,
                            xticklabelsvisible=false, yticksvisible=false, yticklabelsvisible=false,ylabel=gene,ylabelsize=26,
                            xgridvisible = false, ygridvisible = false, title = sp_title, titlesize=26)
    MK.xlims!(MK.current_axis(), x_lims)
    MK.ylims!(MK.current_axis(), y_lims)
    ax2 = MK.Axis(fig[1,2]; xticklabelsize=12, yticklabelsize=12, xticksvisible=false, 
                            xticklabelsvisible=false, yticksvisible=false, yticklabelsvisible=false,
                            xgridvisible = false, ygridvisible = false, title = vs_title, titlesize=26)
    MK.xlims!(MK.current_axis(), x_lims)
    MK.ylims!(MK.current_axis(), y_lims)
    MK.scatter!(ax1, df2.x, df2.y; color=df2.color3, strokewidth=0, markersize=sp_markersize)
    MK.scatter!(ax2, df1.x, df1.y; color = df1.color1, strokewidth=0, markersize=vs_markersize)
    MK.scatter!(ax3, df2.x, df2.y; color=df2.color4, strokewidth=0, markersize=sp_markersize)
    MK.scatter!(ax3, df1.x, df1.y; color=df1.color2, strokewidth=0, markersize=vs_markersize)
    return fig
end

function plot_gene_group_spatial(sp_list::Union{Vector{ImagingSpatialObject}, Vector{VisiumHDObject}, Vector{CartanaObject},Vector{XeniumObject}, Vector{MerfishObject}, Vector{SlideseqObject}, Vector{seqFishObject}, Vector{STARmapObject}, Vector{StereoSeqObject}, Vector{CosMxObject}}, n_bin, gene_list; group_names::Union{Vector, String, Nothing}=nothing,
    color_range::Vector=["white", "ivory","gold","orange","tomato","red"],legend_min::Union{Float64, Int64}=0, 
    legend_max::Union{Float64, Int64}=1, assay_use = "measured", imp_type = "SpaGE")
    n_obj = length(sp_list)
    all_genes = DataFrame()
    for i in 1:n_obj
        plt_df = bin_gene_spatial(sp_list[i], n_bin; assay_use=assay_use, imp_type = imp_type, genes = gene_list)
        plt_df = filter(:gene => ∈(Set(gene_list)), plt_df)
        if isa(group_names, Nothing)
            plt_df.group .= "group" * string(i)
        else
            plt_df.group .= group_names[i]
        end
        all_genes = [all_genes; plt_df]
    end
    plt_df = DataFrame()
    for i in 1:length(gene_list)
        gene1 = filter(:gene => ==(gene_list[i]), all_genes)
        gene1.avg_exp = unit_range_scale(gene1.avg_exp)
        plt_df = [plt_df; gene1]
    end
    plt_df.bin = round.(plt_df.bin; digits= 2)
    p = plt_df |> @vlplot(:rect,
        y={"group:o", title="",scale={domain=group_names}, axis={labelFontSize=16,titleFontSize=16}},
        x={"bin:o", title="C --------------------- > P", axis={labelFontSize=0,titleFontSize=16}},
        color={"avg_exp:q",scale={domainMin=legend_min, domainMax=legend_max, range=color_range}},
        column={:gene,sort=gene_list, header={labelFontSize=16, title=nothing}},
        height= 200, width=180
        )
    return p
end