function run_SpaGCN(sp::AbstractSpaObj, count_path::String, python_path::String; 
            n_cluster::Int64=20, 
            l_val::Union{Float64, Nothing}=nothing, 
            res::Union{Float64, Nothing}=nothing, 
            start_res=1.0, 
            seed_use::Int64=100)
            sc = pyimport("scanpy")
            spg=pyimport("SpaGCN")
            random=pyimport("random")
            np=pyimport("numpy")
            torch=pyimport("torch")
            pd=pyimport("pandas")
            spa_coord = pd.read_csv(coord_path)
            x_pixel=spa_coord["x"].tolist()
            y_pixel=spa_coord["y"].tolist()
            println("Calculating adjacency...")
            adj=spg.calculate_adj_matrix(x=x_pixel,y=y_pixel, histology=false)
            counts=pd.read_csv(count_path,sep="\t", header=0,index_col=0)
            adata = sc.AnnData(counts.transpose())
            adata.var_names_make_unique()
            spg.prefilter_genes(adata,min_cells=1)
            spg.prefilter_specialgenes(adata)
            sc.pp.normalize_per_cell(adata)
            sc.pp.log1p(adata)
            p=0.5
            if isa(l_val, Nothing)
                println("Searching l...")
                l_val=spg.search_l(p, adj, start=0.01; :end=>1000, tol=0.01, max_run=100)
                println(l_val)
            end
            n_clusters=n_cluster
            r_seed=t_seed=n_seed=seed_use
            println("Searching the best resolution for clustering...")
            if isa(res, Nothing)
                res=spg.search_res(adata, adj, l_val, n_clusters, start=start_res, step=0.1, tol=5e-3, lr=0.05, max_epochs=20, r_seed=r_seed, t_seed=t_seed, n_seed=n_seed)
                println(res)
            end
            clf=spg.SpaGCN()
            clf.set_l(l_val)
            random.seed(r_seed)
            torch.manual_seed(t_seed)
            np.random.seed(n_seed)
            println("Training data to obtain the expected clusters...")
            clf.train(adata,adj,init_spa=true,init="louvain",res=res, tol=5e-3, lr=0.05, max_epochs=200)
            (y_pred, prob)=clf.predict()
            adata.obs["pred"]= y_pred
            sp.spmetaData.cell.SpaGCN=y_pred
            refined_pred=spg.refine(sample_id=adata.obs.index.tolist(), pred=adata.obs["pred"].tolist(), dis=adj, shape="square")
            sp.spmetaData.cell.SpaGCNrefined=refined_pred
            println("All done!")
            return sp
end

function run_tangram(sp::Union{CartanaObject, XeniumObject,MerfishObject, STARmapObject, seqFishObject}, data_path::String)
    py"""
    import os
    import numpy as np
    import pandas as pd
    import tangram as tg
    import anndata
    import scipy
    from anndata import AnnData
    import warnings
    warnings.filterwarnings('ignore')
    import glob
    import scanpy as sc
    def Norm_rna(x):
        return np.log(((x/np.sum(x))*1000000)+1)
    def Norm_spatial(x):
            return np.log(((x/np.sum(x))*np.median(cell_count)) + 1)
    print("preparing single cell data...")
    sc_meta = pd.read_csv(glob.glob($data_path + '/' + 'sc_meta*')[0])
    sc_count = sc.read_mtx(glob.glob($data_path + '/' + 'sc_matrix*')[0])
    sc_count = pd.DataFrame.sparse.from_spmatrix(sc_count.X)
    cell_id = pd.read_csv(glob.glob($data_path + '/' + 'sc_barcode*')[0], header = None)
    cell_id = cell_id[0].to_list()
    gene_id1 = pd.read_csv(glob.glob($data_path + '/' + 'sc_gene*')[0], header = None)
    gene_id1 = gene_id1[0].to_list()
    sc_count.columns = cell_id
    sc_count.index = gene_id1
    gene_count = np.sum(sc_count>0, axis=1)
    sc_count = sc_count.loc[gene_count >=10, :]
    sc_count = sc_count.apply(Norm_rna,axis=0)
    sc_count=sc_count.sparse.to_dense()
    print("preparing spatial data...")
    sp_meta = pd.read_csv(glob.glob($data_path + '/' + 'sp_meta*')[0])
    sp_count = sc.read_mtx(glob.glob($data_path + '/' + 'sp_matrix*')[0])
    sp_count = pd.DataFrame.sparse.from_spmatrix(sp_count.X)
    cell_id2 = pd.read_csv(glob.glob($data_path + '/' + 'sp_barcode*')[0], header = None)
    cell_id2 = cell_id2[0].to_list()
    gene_id = pd.read_csv(glob.glob($data_path + '/' + 'sp_gene*')[0], header = None)
    gene_id = gene_id[0].to_list()
    sp_count.columns = cell_id2
    sp_count.index = gene_id
    cell_count = np.sum(sp_count,axis=0)
    sp_count = sp_count.apply(Norm_spatial,axis=0)
    sp_count = sp_count.sparse.to_dense()
    gene_list = sc_count.index.to_list()
    obs = pd.DataFrame()
    obs['x_coord'] = sp_meta.x
    obs['y_coord'] = sp_meta.y
    obs['labels'] = sp_meta.cluster
    spatial_adata =  anndata.AnnData(sp_count.T.values, obs = obs)
    spatial_adata.var_names = sp_count.index.tolist()
    spatial_adata.obs_names = sp_count.columns.tolist()
    rna_adata = anndata.AnnData(sc_count.T)
    rna_adata.obs['cell_subclass'] = sc_meta.name
    rna_adata.var_names = sc_count.index.tolist()
    rna_adata.obs_names = sc_count.columns.tolist()
    overlap_genes = list(set(rna_adata.var_names) & set(spatial_adata.var_names))
    spatial_adata = spatial_adata[:,overlap_genes].copy()
    tg.pp_adatas(rna_adata, spatial_adata, genes=overlap_genes)
    ad_map = tg.map_cells_to_space(rna_adata, spatial_adata, density_prior='uniform',num_epochs=500,device="cpu")
    ad_ge = tg.project_genes(adata_map=ad_map, adata_sc=rna_adata)
    ad_ge.X = scipy.sparse.csc_matrix(ad_ge.X)
    Imp_Genes = pd.DataFrame.sparse.from_spmatrix(ad_ge.X)
    Imp_Genes.columns = rna_adata.var_names.to_list()
    print("done!")
    """
    imp_count = py"Imp_Genes"
    new_df = pd_to_df(imp_count)
    gene_list = names(new_df)
    new_df = convert(SparseMatrixCSC{Float64, Int64},Matrix(new_df)')
    cell_list = py"cell_id2"
    cell_list = string.(cell_list)
    new_counts = SpaCountObj(new_df, cell_list, gene_list)
    if isdefined(sp, :imputeData)
        sp.imputeData = add_impdata(sp.imputeData, "tangram", new_counts)
    else
        sp.imputeData = SpaImputeObj("tangram"; imp_data = new_counts)
    end
    return sp
end

function run_spaGE(sp::Union{CartanaObject, XeniumObject,MerfishObject, STARmapObject, seqFishObject}, 
    sc::scRNAObject, spaGE_path::String; gene_list::Union{String, Vector{String}, Nothing}=nothing, npv::Int64=30)
    if isa(gene_list, String)
        gene_list = [gene_list]
    end
    if isa(gene_list, Nothing)
        gene_list = sc.rawCount.gene_name
    end
    pushfirst!(PyVector(pyimport("sys")."path"), spaGE_path)
    spge = pyimport("SpaGE.main")
    np = pyimport("numpy")
    pd = pyimport("pandas")
    sp_count = deepcopy(sp.rawCount.count_mtx)
    cell_count = sum(sp_count, dims=1)
    median_value = median(cell_count)
    sp_count = hcat([log_norm_spatial(sp_count[:, i], median_value) for i = 1:size(sp_count, 2)]...)
    sc_count = deepcopy(sc.rawCount.count_mtx)
    sc_count = hcat([log_norm_cpm(sc_count[:, i]) for i = 1:size(sc_count, 2)]...)
    sc_cells = sc.rawCount.cell_name
    sc_count = DataFrame(Matrix(sc_count),:auto)
    rename!(sc_count, sc_cells)
    sc_count = pd.DataFrame(Dict(name => sc_count[!, name] for name in names(sc_count)))
    sc_count = sc_count.set_axis(gene_list)
    sp_cells = sp.rawCount.cell_name
    sp_genes = sp.rawCount.gene_name
    sp_count = DataFrame(Matrix(sp_count),:auto)
    rename!(sp_count, sp_cells);
    sp_count = pd.DataFrame(Dict(name => sp_count[!, name] for name in names(sp_count)));
    sp_count = sp_count.set_axis(sp_genes)
    imp_genes = spge.SpaGE(sp_count.T,
        sc_count.T,
        n_pv=npv,
        genes_to_predict = gene_list)
    new_df = pd_to_df(imp_genes)
    gene_ids = names(new_df)
    new_df.cell = sp_count.columns.to_list()
    new_df = new_df[indexin(sp_cells, new_df.cell),:]
    new_df = new_df[!, gene_ids]
    imp_counts = convert(SparseMatrixCSC{Float64, Int64},Matrix(new_df)')
    imp_counts = SpaCountObj(imp_counts, sp_cells, gene_ids)
    if isdefined(sp, :imputeData)
        sp.imputeData = add_impdata(sp.imputeData, "SpaGE", imp_counts)
    else
        sp.imputeData = SpaImputeObj("SpaGE"; imp_data = imp_counts)
    end
    return sp
end

function run_gimVI(sp::Union{CartanaObject, XeniumObject, STARmapObject, seqFishObject, MerfishObject, STARmapObject, seqFishObject}, data_path::String)
    py"""
    import os
    import numpy as np
    import pandas as pd
    from scvi.external import GIMVI
    import anndata
    from anndata import AnnData
    import warnings
    warnings.filterwarnings('ignore')
    import glob
    import scanpy as sc
    def Norm_rna(x):
        return np.log(((x/np.sum(x))*1000000)+1)
    def Norm_spatial(x):
            return np.log(((x/np.sum(x))*np.median(cell_count)) + 1)
    print("preparing single cell data...")
    sc_meta = pd.read_csv(glob.glob($data_path + '/' + 'sc_meta*')[0])
    sc_count = sc.read_mtx(glob.glob($data_path + '/' + 'sc_matrix*')[0])
    sc_count = pd.DataFrame.sparse.from_spmatrix(sc_count.X)
    cell_id = pd.read_csv(glob.glob($data_path + '/' + 'sc_barcode*')[0], header = None)
    cell_id = cell_id[0].to_list()
    gene_id1 = pd.read_csv(glob.glob($data_path + '/' + 'sc_gene*')[0], header = None)
    gene_id1 = gene_id1[0].to_list()
    sc_count.columns = cell_id
    sc_count.index = gene_id1
    gene_count = np.sum(sc_count>0, axis=1)
    sc_count = sc_count.loc[gene_count >=10, :]
    sc_count = sc_count.apply(Norm_rna,axis=0)
    sc_count=sc_count.sparse.to_dense()
    print("preparing spatial data...")
    sp_meta = pd.read_csv(glob.glob($data_path + '/' + 'sp_meta*')[0])
    sp_count = sc.read_mtx(glob.glob($data_path + '/' + 'sp_matrix*')[0])
    sp_count = pd.DataFrame.sparse.from_spmatrix(sp_count.X)
    cell_id2 = pd.read_csv(glob.glob($data_path + '/' + 'sp_barcode*')[0], header = None)
    cell_id2 = cell_id2[0].to_list()
    gene_id = pd.read_csv(glob.glob($data_path + '/' + 'sp_gene*')[0], header = None)
    gene_id = gene_id[0].to_list()
    sp_count.columns = cell_id2
    sp_count.index = gene_id
    cell_count = np.sum(sp_count,axis=0)
    sp_count = sp_count.apply(Norm_spatial,axis=0)
    sp_count = sp_count.sparse.to_dense()
    gene_list = sc_count.index.to_list()
    obs = pd.DataFrame()
    obs['x_coord'] = sp_meta.x
    obs['y_coord'] = sp_meta.y
    obs['labels'] = sp_meta.cluster
    spatial_adata =  anndata.AnnData(sp_count.T.values, obs = obs)
    spatial_adata.var_names = sp_count.index.tolist()
    spatial_adata.obs_names = sp_count.columns.tolist()
    rna_adata = anndata.AnnData(sc_count.T)
    rna_adata.obs['cell_subclass'] = sc_meta.name
    rna_adata.var_names = sc_count.index.tolist()
    rna_adata.obs_names = sc_count.columns.tolist()
    overlap_genes = list(set(rna_adata.var_names) & set(spatial_adata.var_names))
    spatial_adata = spatial_adata[:,overlap_genes].copy()
    GIMVI.setup_anndata(spatial_adata, labels_key='labels')
    GIMVI.setup_anndata(rna_adata)
    model = GIMVI(rna_adata, spatial_adata)
    _, Imp_Genes = model.get_imputed_values(normalized=True)
    Imp_Genes = pd.DataFrame(Imp_Genes, columns=rna_adata.var_names.to_list())
    print("done!")
    """
    imp_count = py"Imp_Genes"
    new_df = pd_to_df(imp_count)
    gene_list = names(new_df)
    new_df = convert(SparseMatrixCSC{Float64, Int64},Matrix(new_df)')
    cell_list = py"cell_id2"
    cell_list = string.(cell_list)
    new_counts = SpaCountObj(new_df, cell_list, gene_list)
    if isdefined(sp, :imputeData)
        sp.imputeData = add_impdata(sp.imputeData, "gimVI", new_counts)
    else
        sp.imputeData = SpaImputeObj("gimVI"; imp_data = new_counts)
    end
    return sp
end

function run_cell_pairing(df::DataFrame, cell_col::Union{Symbol, String}, celltype_col::Union{Symbol, String}; radius::Union{Int64, Float64, Nothing}=nothing)
    cells=df[!,cell_col]
    Sum = 0
    Sum_nonself = 0
    cell_type=unique(df[!, celltype_col])
    PairCounts = zeros(length(cell_type),length(cell_type))
    n=length(cells)-1
    p = Progress(n, dt=0.5, barglyphs=BarGlyphs("[=> ]"), barlen=40, color=:black)
    Threads.@threads for i in 1:(length(cells)-1)
      x1=filter(:cell2 => ==(cells[i]), df).x[1]
      y1=filter(:cell2 => ==(cells[i]), df).y[1]
      cell1=filter(:cell2 => ==(cells[i]), df).cell_index[1]
        for j in (i+1):length(cells)
          x2=filter(:cell2 => ==(cells[j]), df).x[1]
          y2=filter(:cell2 => ==(cells[j]), df).y[1]
          cell2=filter(:cell2 => ==(cells[j]), df).cell_index[1]
          if radius !== nothing
                dist_ab=sqrt((x1-x2)^2+(y1-y2)^2)
                if dist_ab < radius
                    if cell1 !== cell2
                        PairCounts[cell1,cell2] += 1
                        PairCounts[cell2,cell1] += 1
                        Sum_nonself += 1
                    else
                        PairCounts[cell1,cell2] += 1
                    end
                    Sum += 1
                    end
          else
                if cell1 !== cell2
                    PairCounts[cell1,cell2] += 1
                    PairCounts[cell2,cell1] += 1
                    Sum_nonself += 1
                else
                    PairCounts[cell1,cell2] += 1
                end
                Sum += 1
            end
        end
      next!(p)
    end
    return PairCounts, Sum_nonself, Sum
end

function run_seurat(ranger_dir::String; data_type::String="visium", cell_prefix::Union{String, Nothing}=nothing,
    project_name::String="seuratObj",n_var_genes::Int64=1000,n_pca::Int64=20, res::Float64=0.6, min_dist::Float64=0.3)
    if data_type === "scRNA"
        R"""
        library(Seurat)
        seu <- Read10X($ranger_dir)
        seu <- RenameCells(seu, add.cell.id = $cell_prefix)
        seu <- SCTransform(seu,  verbose = F, variable.features.n = $n_var_genes)
        seu <- RunPCA(seu, verbose = F)
        seu <- RunUMAP(seu, dims = 1:$n_pca, verbose = F, min.dist = $min_dist)
        seu <- FindNeighbors(seu, dims = 1:$n_pca, verbose = F)
        seu <- FindClusters(seu, verbose = F, resolution = $res)
        """
        @rget seu
    elseif data_type === "visium"
        R"""
        library(Seurat)
        seu <- Load10X_Spatial($ranger_dir)
        seu <- RenameCells(seu, add.cell.id = $cell_prefix)
        seu <- SCTransform(seu,  assay = "Spatial", verbose = F, variable.features.n = $n_var_genes)
        seu <- RunPCA(seu, assay = "SCT", verbose = FALSE)
        seu <- FindNeighbors(seu, reduction = "pca" , dims = 1:$n_pca)
        seu <- FindClusters(seu, verbose = FALSE, resolution = $res)
        seu <- RunUMAP(seu, dims = 1:$n_pca, verbose = F, min.dist = $min_dist)
        """
        @rget seu
    else
        error("data_type can only be \"visium\" or \"scRNA\"")
    end
end

function retrieve_seurat_data(seu_obj::RObject{S4Sxp}; data_type="visium")
    if data_type === "visium"
        barcodes = rcopy(Vector, R"colnames"(seu_obj))
        cells=rcopy(DataFrame, seu_obj["meta.data"])
        cells.cell=barcodes
        umap=rcopy(Matrix{Float64}, seu_obj["reductions"]["umap"]["cell.embeddings"])
        umap= DataFrame(umap, :auto)
        rename!(umap, [:UMAP_1, :UMAP_2])
        tissue_coord=rcopy(seu_obj["images"]["slice1"]["coordinates"])
        tissue_coord=tissue_coord[!, [:imagecol, :imagerow]]
        rename!(tissue_coord, ["x", "y"])
        cells=[tissue_coord cells umap]
        genes = rcopy(Vector, R"rownames"(seu_obj["assays"]["Spatial"]["counts"]))
        raw_counts=rcopy(Matrix{Float64},R"as.matrix"(seu_obj["assays"]["Spatial"]["counts"]))
        raw_counts=DataFrame(raw_counts, :auto)
        rename!(raw_counts, cells.cell)
        raw_counts=[genes raw_counts]
        rename!(raw_counts, :x1 => :gene)
        return cells, raw_counts
    elseif data_type === "scRNA"
            barcodes = rcopy(Vector, R"colnames"(seu_obj))
            cells=rcopy(DataFrame, seu_obj["meta.data"])
            cells.cell=barcodes
            umap=rcopy(Matrix{Float64}, seu_obj["reductions"]["umap"]["cell.embeddings"])
            umap= DataFrame(umap, :auto)
            rename!(umap, [:UMAP_1, :UMAP_2])
            cells=[cells umap]
            genes = rcopy(Vector, R"rownames"(seu_obj["assays"]["RNA"]["counts"]))
            raw_counts=rcopy(Matrix{Float64},R"as.matrix"(seu_obj["assays"]["RNA"]["counts"]))
            raw_counts=DataFrame(raw_counts, :auto)
            rename!(raw_counts, cells.cell)
            raw_counts=[genes raw_counts]
            rename!(raw_counts, :x1 => :gene)
            norm_counts=rcopy(Matrix{Float64},R"as.matrix"(seu_obj["assays"]["RNA"]["data"]))
            norm_counts=DataFrame(norm_counts, :auto)
            rename!(norm_counts, cells.cell)
            norm_counts=[genes norm_counts]
            rename!(norm_counts, :x1 => :gene)
            return cells, raw_counts, norm_counts
    else
        error("data_type can only be \"visium\" or \"scRNA\"")
    end
end

function run_scanpy(ranger_dir::String; data_type::String="visium",cell_prefix::Union{String, Nothing}=nothing,
    min_cells::Int64=0,n_neighbors::Int64=20, n_pca::Int64=20,n_var_genes::Int64=1000,
    min_dist::Float64=0.3, res::Float64=0.6)
    sc = pyimport("scanpy")
    if data_type === "visium"
        adata=sc.read_visium(ranger_dir, library_id=cell_prefix)
    elseif data_type === "scRNA"
        adata=sc.read_10x_mtx(ranger_dir, prefix=cell_prefix)
    else
        error("data_type can only be \"visium\" or \"scRNA\"")
    end
    sc.pp.filter_genes(adata, min_cells=min_cells)
    sc.pp.calculate_qc_metrics(adata, inplace=true)
    adata.raw=adata
    sc.pp.highly_variable_genes(adata, n_top_genes=n_var_genes, flavor="seurat_v3")
    sc.tl.pca(adata, svd_solver="arpack")
    sc.pp.neighbors(adata, n_neighbors=n_neighbors, n_pcs=n_pca)
    sc.tl.umap(adata, min_dist=min_dist)
    sc.tl.leiden(adata, resolution=res)
    return adata
end

function retrieve_scanpy_data(adata::PyObject; data_type="visium")
    cells = DataFrame(cell = collect(String,adata.obs_names),
        nFeature_RNA = collect(Float64,adata.obs["n_genes_by_counts"]), 
        nCount_RNA = collect(Float64, adata.obs["total_counts"]), 
        scanpy_clusters = collect(String, adata.obs["leiden"]))
    umap = get(adata.obsm,"X_umap")
    umap = DataFrame(umap, :auto)
    rename!(umap, :x1 => :UMAP_1, :x2 => :UMAP_2)
    if data_type === "visium"
        tissue_coord = get(adata.obsm,"spatial")
        tissue_coord = DataFrame(tissue_coord, :auto)
        rename!(tissue_coord, :x1 => :x, :x2 => :y)
        cells = [tissue_coord cells umap]
    elseif data_type === "scRNA"
        cells = [cells umap]
    else
        error("data_type can only be \"visium\" or \"scRNA\"")
    end
    genes = collect(String,adata.var_names)
    raw_counts = adata.raw.X.toarray()
    raw_counts = raw_counts'
    raw_counts = DataFrame(raw_counts, :auto)
    rename!(raw_counts, cells.cell)
    raw_counts = [genes raw_counts]
    rename!(raw_counts, :x1 => :gene)
    norm_counts = adata.X.toarray()
    norm_counts = norm_counts'
    norm_counts = DataFrame(norm_counts, :auto)
    rename!(norm_counts, cells.cell)
    norm_counts = [genes norm_counts]
    rename!(norm_counts, :x1 => :gene)
    return cells, raw_counts, norm_counts
end