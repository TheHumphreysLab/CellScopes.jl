function read_10x(tenx_dir::String; 
    version::String="v2", 
    min_gene::Real = 0.0, 
    min_cell::Real = 0.0
)
    if version === "v2"
        counts = MatrixMarket.mmread(tenx_dir * "/matrix.mtx")
        cells = CSV.File(tenx_dir * "/barcodes.tsv", header = false) |> DataFrame
        genes = CSV.File(tenx_dir * "/genes.tsv", header = false) |> DataFrame
    elseif version === "v3"
        gene_file = tenx_dir * "/features.tsv.gz"
        cell_file = tenx_dir * "/barcodes.tsv.gz"
        count_file = tenx_dir * "/matrix.mtx.gz"
        genes = DataFrame(load(File(format"TSV", gene_file); header_exists=false))
        cells = DataFrame(load(File(format"TSV", cell_file); header_exists=false))
        counts = MatrixMarket.mmread(gunzip(count_file))
    else
        error("version can only be v2 or v3!")
    end
    cells = string.(cells.Column1)
    genes = string.(genes.Column2)
    gene_kept = (vec ∘ collect)(rowSum(counts).> min_cell)
    genes = genes[gene_kept]
    cell_kept = (vec ∘ collect)(colSum(counts) .> min_gene)
    cells = cells[cell_kept]
    counts = counts[gene_kept, cell_kept]
    gene_kept, gene_removed = check_duplicates(genes)
    gene_removed = collect(values(gene_removed))
    counts = counts[Not(gene_removed), :]
    rawcount = RawCountObject(counts, cells, gene_kept)
    return rawcount
end

function save(sc_obj::AbstractCellScope; filename::String = "cs_obj.jld2")
    JLD2.save(filename, "key", sc_obj)
end

function load(;filename::String = "cs_obj.jld2")
    cs = JLD2.load(filename)
    cs = cs["key"]
    return cs
end

function read_visium(visium_dir::String; 
    min_gene::Real = 0.0, 
    min_cell::Real = 0.0
)
    # locate all files
    highres_image_file = visium_dir * "/spatial/tissue_hires_image.png"
    lowres_image_file = visium_dir * "/spatial/tissue_lowres_image.png"
    detected_tissue = visium_dir * "/spatial/detected_tissue_image.jpg"
    aligned_image_file = visium_dir * "/spatial/aligned_fiducials.jpg"
    position_file = visium_dir * "/spatial/tissue_positions_list.csv"
    json_file = visium_dir * "/spatial/scalefactors_json.json"
    gene_file = visium_dir * "/filtered_feature_bc_matrix/features.tsv.gz"
    cell_file = visium_dir * "/filtered_feature_bc_matrix/barcodes.tsv.gz"
    count_file = visium_dir * "/filtered_feature_bc_matrix/matrix.mtx.gz"
    # prepare counts
    genes = DataFrame(CSVFiles.load(CSVFiles.File(format"TSV", gene_file); header_exists=false))
    genes = string.(genes.Column2)
    cells = DataFrame(CSVFiles.load(CSVFiles.File(format"TSV", cell_file); header_exists=false))
    cells = string.(cells.Column1)
    counts = MatrixMarket.mmread(gunzip(count_file))
    gene_kept = (vec ∘ collect)(rowSum(counts).> min_cell)
    genes = genes[gene_kept]
    cell_kept = (vec ∘ collect)(colSum(counts) .> min_gene)
    cells = cells[cell_kept]
    counts = counts[gene_kept, cell_kept]
    gene_kept, gene_removed = check_duplicates(genes)
    gene_removed = collect(values(gene_removed))
    counts = counts[Not(gene_removed), :]
    rawcount = RawCountObject(counts, cells, gene_kept)
    # prepare spatial info
    positions = DataFrame(CSV.File(position_file, header=false))
    rename!(positions, ["barcode","in_tissue","array_row","array_col","pxl_row_in_fullres","pxl_col_in_fullres"])
    positions.barcode = string.(positions.barcode)
    high_img = load(highres_image_file)
    low_img = load(lowres_image_file)
    tissue_img = load(detected_tissue)
    aligned_img = load(aligned_image_file)
    json_data = JSON.parsefile(json_file)
    image_obj = VisiumImgObject(high_img, low_img, tissue_img, aligned_img, json_data)
    # create visiumobject
    vsm_obj = VisiumObject(rawcount)
    vsm_obj.spmetaData = positions
    vsm_obj.imageData = image_obj
    return vsm_obj
end