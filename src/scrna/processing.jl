
function normalize_object(mtx::AbstractMatrix{<:Real}; scale_factor = 10000, norm_method = "logarithm", pseudocount = 1)
    n= size(mtx)[2]
    sum_val = sum(mtx, dims=1)
    norm_count = hcat(Folds.collect(log.((mtx[:, i] ./ sum_val[i]) .* scale_factor .+ pseudocount) for i in 1:n)...)
    return norm_count
end

function normalize_object(ct_obj::RawCountObject; scale_factor = 10000, norm_method = "logarithm", pseudocount = 1)
    norm_count = normalize_object(ct_obj.count_mtx; scale_factor=scale_factor, norm_method=norm_method, pseudocount=pseudocount)
    norm_obj = NormCountObject(norm_count, ct_obj.cell_name, ct_obj.gene_name, scale_factor, norm_method, pseudocount)
    return norm_obj
end

function normalize_object(sc_obj::Union{scRNAObject, VisiumObject, CartanaObject, XeniumObject, MerfishObject}; scale_factor = 10000, norm_method = "logarithm", pseudocount = 1)
    norm_obj = normalize_object(sc_obj.rawCount; scale_factor = scale_factor, norm_method = norm_method, pseudocount = pseudocount)
    sc_obj.normCount = norm_obj
    return sc_obj
end

function scale_object(count_mtx::AbstractMatrix{<:Real}; scale_max = 10.0, do_scale::Bool = true, do_center::Bool = true)
    rmean = mean(count_mtx, dims=2)
    rsd = sqrt.(var(count_mtx, dims=2))
    count_mtx = hcat(Folds.collect(count_mtx[i, :] .- rmean[i] for i in 1:length(rmean))...)
    if do_scale
        count_mtx = hcat([count_mtx[:, i] ./ rsd[i] for i in 1:length(rsd)]...)
    end
    count_mtx = Folds.map(x -> x > scale_max ? scale_max : x, count_mtx)
    count_mtx = convert(SparseArrays.SparseMatrixCSC{Float64, Int64}, count_mtx')
    return count_mtx
end

function scale_object(ct_obj::NormCountObject; features::Union{Vector{String}, Nothing}=nothing, scale_max = 10.0, do_scale::Bool = true, do_center::Bool = true)
    if features !== nothing
        ct_obj = subset_count(ct_obj; genes = features)
    end
    scale_count = scale_object(ct_obj.count_mtx; scale_max=scale_max, do_scale=do_scale, do_center=do_center)
    scale_obj = ScaleCountObject(scale_count, ct_obj.cell_name, ct_obj.gene_name, do_scale, do_center, scale_max)
    return scale_obj
end

function scale_object(sc_obj::Union{scRNAObject, VisiumObject, CartanaObject, XeniumObject,MerfishObject}; features::Union{Vector{String}, Nothing}=nothing, scale_max = 10.0, do_scale::Bool = true, do_center::Bool = true)
    scale_obj = scale_object(sc_obj.normCount; features = features, scale_max=scale_max, do_scale=do_scale, do_center=do_center)
    sc_obj.scaleCount = scale_obj
    return sc_obj
end

function find_variable_genes(ct_mtx::RawCountObject; nFeatures::Int64 = 2000, span::Float64 = 0.3)
    mean_val = mean(ct_mtx.count_mtx, dims=2)
    var_val = var(ct_mtx.count_mtx, dims=2)
    vst_data = [mean_val var_val zeros(length(mean_val)) zeros(length(mean_val))]
    vst_data = DataFrame(vst_data, :auto)
    rename!(vst_data, ["mean", "variance", "variance_expected","variance_standardized"])
    vst_data = filter(:variance => >(0.0), vst_data)
    fit_data = loess(log10.(vst_data.mean), log10.(vst_data.variance), span=span)
    vst_data.variance_expected = 10 .^ Loess.predict(fit_data, log10.(vst_data.mean))
    mean1 = sparsevec(vst_data.mean)
    var1 = sparsevec(sqrt.(vst_data.variance_expected))
    mat = convert(SparseMatrixCSC{Int64, Int64}, ct_mtx.count_mtx')
    sd_val = Folds.collect(var((x .- mean1[i]) ./ var1[i]) for (i, x) in enumerate(eachcol(mat)))
    vst_data.variance_standardized = vec(sd_val)
    vst_data.gene = ct_mtx.gene_name;
    vst_data = sort(vst_data, :variance_standardized, rev=true)
    Features = vst_data.gene[1:nFeatures]
    return vst_data, Features
end

function find_variable_genes(sc_obj::Union{scRNAObject, VisiumObject, CartanaObject, XeniumObject,MerfishObject}; nFeatures::Int64 = 2000, span::Float64 = 0.3)
    vst_data, Features = find_variable_genes(sc_obj.rawCount;  nFeatures = nFeatures, span = span)
    var_obj = VariableGeneObject(Features, vst_data)
    sc_obj.varGene = var_obj
    return sc_obj
end

function run_pca(sc_obj::Union{scRNAObject, VisiumObject, CartanaObject, XeniumObject,MerfishObject}; method=:svd, pratio = 1, maxoutdim = 10)
    features = sc_obj.varGene.var_gene
    if length(sc_obj.scaleCount.gene_name) == length(sc_obj.rawCount.gene_name)
        new_count = subset_count(sc_obj.scaleCount; genes = features)
    else
        new_count = sc_obj.scaleCount
    end
    pca_mat = new_count.count_mtx'
    pca_mat = Matrix(pca_mat)
    pca_mat = convert(Matrix{Float64}, pca_mat)
    M = MultivariateStats.fit(PCA, pca_mat; method=method, pratio=pratio, maxoutdim=maxoutdim)
    proj = MultivariateStats.projection(M)
    percent_var = principalvars(M) ./ tvar(M) * 100
    key = "PC"
    pca_obj = PCAObject(proj, M, percent_var, key , method, pratio, maxoutdim)
    reduction_obj = ReductionObject(pca_obj, nothing, nothing)
    sc_obj.dimReduction = reduction_obj
    return sc_obj
end

function run_clustering_atlas(sc_obj::Union{scRNAObject, VisiumObject, CartanaObject, XeniumObject, scATACObject,MerfishObject}; n_neighbors=30, metric=CosineDist(), res= 0.06, seed_use=1234)
    if isdefined(sc_obj.dimReduction, :umap)
        indices = sc_obj.dimReduction.umap.knn_data
    else
        pca_vec = Folds.collect(collect(i) for i in eachrow(sc_obj.dimReduction.pca.cell_embedding))
        graph = nndescent(pca_vec, n_neighbors, metric)
        indices, dist_mat = knn_matrices(graph)
    end
    n = size(indices, 2)
    adj_mat = Array{Int64}(undef, n, n)
    @simd for i in 1:n
        @simd for j in 1:size(indices, 1)
            adj_mat[indices[j, i], i] = 1
            adj_mat[i, indices[j, i]] = 1
        end
    end
    if n > 10000 # Input as SparseMatrix to Leiden runs quicker for large dataset
        adj_mat = convert(SparseMatrixCSC{Int64,Int64}, adj_mat)
    end
    Random.seed!(seed_use)
    result = Leiden.leiden(adj_mat, resolution = res)
    df = DataFrame()
    for (i, members) in enumerate(result.partition)
        cells = sc_obj.rawCount.cell_name[members]
        df1 = DataFrame(cluster = repeat([string(i)], length(cells)), cell_id=cells)
        df = [df;df1]
    end
    df = df[indexin(colnames(sc_obj), df.cell_id),:];
    metric_type = string(metric)
    cluster_obj = ClusteringObject(df, metric_type, adj_mat, result, res)
    sc_obj.clustData = cluster_obj
    sc_obj.metaData.cluster = df.cluster
    return sc_obj
end

function run_clustering_small(sc_obj::Union{scRNAObject, VisiumObject, CartanaObject, XeniumObject, scATACObject,MerfishObject}; n_neighbors=30, metric=CosineDist(), res= 0.06, seed_use=1234)
    knn_data = [collect(i) for i in eachrow(sc_obj.dimReduction.pca.cell_embedding)]
    graph = nndescent(knn_data, n_neighbors, metric)
    indices, dist_mat = knn_matrices(graph);
    n = size(indices, 2)  
    adj_mat = zeros(Int64, n, n)
    for i in 1:size(indices, 2)
        for j in 1:size(indices, 1)
            adj_mat[indices[j, i], i] = 1
        end
    end
    for i in 1:size(indices, 2)
        for j in 1:size(indices, 1)
            adj_mat[i, indices[j, i]] = 1
        end
    end
    Random.seed!(seed_use)
    result = Leiden.leiden(adj_mat, resolution = res);
    df = DataFrame()
    for (i, members) in enumerate(result.partition)
        cells = sc_obj.rawCount.cell_name[members]
        df1 = DataFrame(cluster = repeat([string(i)], length(cells)), cell_id=cells)
        df = [df;df1]
    end
    df = df[indexin(colnames(sc_obj), df.cell_id),:];
    metric_type = string(metric)
    cluster_obj = ClusteringObject(df, metric_type, adj_mat, result, res)
    sc_obj.clustData = cluster_obj
    sc_obj.metaData.cluster = df.cluster
    return sc_obj
end

function run_clustering(sc_obj::Union{scRNAObject, VisiumObject, CartanaObject, XeniumObject, scATACObject,MerfishObject}; n_neighbors=30, metric=CosineDist(), res= 0.06, seed_use=1234)
    n = size(sc_obj.rawCount.count_mtx, 2)
    if n < 10000
        obj = run_clustering_small(sc_obj; n_neighbors=n_neighbors, metric=metric, res= res, seed_use=seed_use)
        return obj
    else
        obj = run_clustering_atlas(sc_obj; n_neighbors=n_neighbors, metric=metric, res= res, seed_use=seed_use)
        return obj
    end
end

function run_tsne(sc_obj::Union{scRNAObject, VisiumObject, CartanaObject, XeniumObject, scATACObject,MerfishObject}; ndim::Int64 = 2, dims_use = 1:10, max_iter::Int64 = 2000, perplexit::Real = 30.0, pca_init::Bool = true,  seed_use::Int64 = 1234)
    Random.seed!(seed_use)
    pca_mat = sc_obj.dimReduction.pca.cell_embedding
    pca_mat = pca_mat[:, dims_use]
    reduce_dims = maximum(dims_use) - minimum(dims_use) + 1
    embedding = tsne(pca_mat, ndim, reduce_dims, max_iter, perplexit ; pca_init = pca_init)
    key = "tSNE"
    tsne_obj = tSNEObject(embedding, key, ndim, reduce_dims, max_iter, perplexit)
    sc_obj.dimReduction.tsne = tsne_obj
    return sc_obj
end

function run_umap(sc_obj::Union{scRNAObject, VisiumObject, CartanaObject, XeniumObject, scATACObject,MerfishObject}; ndim::Int64 = 2, dims_use = 1:10, n_neighbors::Int64 = 30, n_epochs=300, init = :spectral, metric = CosineDist(), min_dist::Real = 0.4, seed_use::Int64 = 1234)
    Random.seed!(seed_use)
    pca_mat = sc_obj.dimReduction.pca.cell_embedding
    pca_mat = pca_mat[:, dims_use]
    pca_mat = transpose(pca_mat)
    pca_mat = convert(SparseArrays.SparseMatrixCSC{Float64, Int64}, pca_mat)
    umap_data = UMAP_(pca_mat, ndim; n_neighbors=n_neighbors , min_dist = min_dist, metric = metric, n_epochs = n_epochs, init=init)
    knns = umap_data.knns
    embedding = umap_data.embedding
    embedding = embedding'
    key = "UMAP"
    metric_use = string(metric)
    reduce_dims = maximum(dims_use) - minimum(dims_use) + 1
    umap_obj = UMAPObject(embedding, key, ndim, reduce_dims, n_neighbors, metric_use, min_dist, knns)
    sc_obj.dimReduction.umap = umap_obj
    return sc_obj
end

function find_markers(sc_obj::Union{scRNAObject, VisiumObject, CartanaObject, XeniumObject, scATACObject, MerfishObject}; cluster_1::Union{String, Nothing}=nothing, cluster_2::Union{String, Nothing}=nothing, 
    anno::Union{String, Symbol}="cluster", expr_cutoff=0.0, min_pct=0.1, p_cutoff = 0.05, only_pos = true)
    if isa(cluster_1, Nothing)
        error("Please provide the name of the cell cluster for which you wish to obtain the differential genes. The \"cluster_1\" parameter cannot be left blank.")
    end
    if isa(cluster_2, Nothing)
        error("Please enter the name of the cell cluster you wish to compare against. The \"cluster_2\" parameter cannot be left blank.")
    end
    if !isdefined(sc_obj, :clustData)
        error("Clustering has not been done. Please complete the \"RunClustering\" first!")
    end
    cl1_obj = extract_cluster_count(sc_obj, cluster_1; anno = anno)
    cl2_obj = extract_cluster_count(sc_obj, cluster_2; anno = anno)
    genes = cl1_obj.gene_name
    common_genes = hcat((vec ∘ collect)(rowSum(cl1_obj.count_mtx) .> 0.0), (vec ∘ collect)(rowSum(cl2_obj.count_mtx) .> 0.0))
    common_genes = (vec ∘ collect)(rowSum(common_genes) .== 2)
    genes = genes[common_genes]
    cl1_obj = subset_count(cl1_obj; genes = genes)
    cl2_obj = subset_count(cl2_obj; genes = genes)
    cl1_ct = cl1_obj.count_mtx
    cl2_ct = cl2_obj.count_mtx
    cl1_ct = Matrix(cl1_ct)
    cl1_ct = convert(Matrix{Float64}, cl1_ct)
    cl2_ct = Matrix(cl2_ct)
    cl2_ct = convert(Matrix{Float64}, cl2_ct)
    wilcon_test = Folds.collect(MannWhitneyUTest(x, y) for (x,y) in zip(eachrow(cl1_ct), eachrow(cl2_ct)))
    p_value = pvalue.(wilcon_test)
    mean1 = Folds.collect(log(mean(expm1.(x)) + 1) for x in eachrow(cl1_ct))
    mean2 = Folds.collect(log(mean(expm1.(x)) + 1) for x in eachrow(cl2_ct))
    avg_logFC = mean1 - mean2
    pct1 = Folds.collect(countmap(x .> expr_cutoff)[:1]/length(x) for x in eachrow(cl1_ct))
    pct2 = Folds.collect(countmap(x .> expr_cutoff)[:1]/length(x) for x in eachrow(cl2_ct))
    test_result = DataFrame(gene = cl1_obj.gene_name, p_val = p_value, avg_logFC = avg_logFC, pct_1 = pct1, pct_2 = pct2)    
    test_result.p_val_adj = MultipleTesting.adjust(test_result.p_val, Bonferroni())
    filter!([:pct_1, :p_val] => (y, z) -> y > min_pct && z < p_cutoff, test_result)
    if only_pos
        filter!(:avg_logFC => >(0.0), test_result)
    end
    sort!(test_result, :avg_logFC, rev=true)
    return test_result
end

function find_all_markers(sc_obj::Union{scRNAObject, VisiumObject, CartanaObject, XeniumObject, scATACObject,MerfishObject}; anno::Union{String, Symbol}="cluster", expr_cutoff=0.0, min_pct=0.1, p_cutoff = 0.05, only_pos = true)
    if isa(anno, String)
        anno = Symbol(anno)
    end
    all_clusters = unique(sc_obj.clustData.clustering[!, anno])
    all_markers = DataFrame()
    n=length(all_clusters)
    p = Progress(n, dt=0.5, barglyphs=BarGlyphs("[=> ]"), barlen=40, color=:black)
    @simd for i in 1:n
        cluster = all_clusters[i]
        cl1_obj = extract_cluster_count(sc_obj, cluster; anno = anno)
        from = all_clusters
        to = [cluster == x ? cluster : "nonself" for x in from]
        df = sc_obj.clustData.clustering
        df = map_values(df, anno, :new_cluster, from, to)
        sc_obj.clustData.clustering = df
        markers = find_markers(sc_obj; anno= "new_cluster", cluster_1 = cluster, cluster_2 = "nonself")
        markers.cluster .= cluster
        all_markers = [all_markers;markers]
        next!(p)
    end
    return all_markers
end