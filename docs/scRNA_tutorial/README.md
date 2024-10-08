# Tutorial for scRNA-seq analysis with CellScopes.jl

The following tutorials guide you through using ```CellScopes.jl``` to analyze scRNA-seq data from a sample of 2,700 cells, and show you how to scale the analysis up to 400,000 cells. 

## 1 Tutorial: PBMC 3K
This tutorial uses the pbmc3k dataset from 10x Genomics, which has been previously used by [Seurat](https://satijalab.org/seurat/articles/pbmc3k_tutorial.html) and [Scanpy](https://scanpy-tutorials.readthedocs.io/en/latest/pbmc3k.html) for demo purpose. This will read in the data and create a RawCountObject that can be used as input for ```CellScopes.jl```. All codes from this tutorial are run on Julia REPL.
### 1.1 Download the pbmc3k data
```julia
;wget https://cf.10xgenomics.com/samples/cell/pbmc3k/pbmc3k_filtered_gene_bc_matrices.tar.gz
;tar xvf pbmc3k_filtered_gene_bc_matrices.tar.gz
```

### 1.2 Read the data
The cells and genes can be filtered by setting the parameters ```min_gene``` and ```min_cell```, respectively.
```julia
import CellScopes as cs
raw_counts = cs.read_10x("filtered_gene_bc_matrices/hg19"; min_gene = 3);
```
This should create an object type called ```RawCountObject```.
```julia
raw_counts
#=
CellScopes.RawCountObject
Genes x Cells = 13100 x 2700
Available fields:
- count_mtx
- cell_name
- gene_name
=#
```
### 1.3 Create a scRNAObject
We then create a ```scRNAObject``` using the count object above. The ```scRNAObject``` serves as a container to store all the data needed for and generated from the downstream analysis. The cells and genes can be further filtered by setting the parameters ```min_gene``` and ```min_cell```, respectively.
```julia
pbmc = cs.scRNAObject(raw_counts)
#=
scRNAObject in CellScopes.jl
Genes x Cells = 13100 x 2700
Available data:
- Raw count
=#
```
### 1.4 Normalize the scRNAObject
We use a normalization method called global-scaling, which is similar to Seurat's "LogNormalize" method. This normalization method scales the feature expression measurements for each cell by the total expression, multiplies the result by a default scale factor of 10,000, and log-transforms the final value. The normalized values are stored as a ```NormCountObject```.
```julia
pbmc = cs.normalize_object(pbmc; scale_factor = 10000)
#=
scRNAObject in CellScopes.jl
Genes x Cells = 13100 x 2700
Available data:
- Raw count
- Normalized count
=#
```
We then use the ```ScaleObject``` function to scale and center the data.

```julia
pbmc = cs.scale_object(pbmc)
#=
scRNAObject in CellScopes.jl
Genes x Cells = 13100 x 2700
Available data:
- Raw count
- Normalized count
- Scaled count
=#
```

### 1.5 Find variable genes
We use the ```vst``` approach implemented in the ```FindVariableFeatures``` function in Seurat or the ```pp.highly_variable_genes``` function in Scanpy to identify the variable genes. To standardize the counts, we use the following formula:
```math
Z_{ij} = \frac{x_{ij} - \bar{x}_i}{σ_i}
```
x<sub>ij</sub> is observed UMI, x̄ is the gene mean (rowMean) and σ<sub>i</sub> is the expected variance from the loess fit.

```julia
pbmc = cs.find_variable_genes(pbmc)
#=
scRNAObject in CellScopes.jl
Genes x Cells = 13100 x 2700
Available data:
- Raw count
- Normalized count
- Scaled count
- Variable genes
=#
```

### 1.6 Run principal component analysis (PCA).
Next, we perform PCA on the scaled data using only the previously identified variable genes as input. This is completed by the [MultivariateStats.jl](https://github.com/JuliaStats/MultivariateStats.jl) package.
```julia
pbmc = cs.run_pca(pbmc;  method=:svd, pratio = 1, maxoutdim = 10)
#=
scRNAObject in CellScopes.jl
Genes x Cells = 13100 x 2700
Available data:
- Raw count
- Normalized count
- Scaled count
- Variable genes
- PCA data
=#
```
### 1.7 Cluster the cells.
We use a graph-based approach to identify the clusters. We first construct a KNN graph based on the significant components using the [NearestNeighborDescent.jl](https://github.com/dillondaudert/NearestNeighborDescent.jl) package. We then extract the KNN matrix from the graph and convert it into an adjacency matrix. This adjacent matrix is used as input for the [Leiden.jl](https://github.com/bicycle1885/Leiden.jl) package, which performs community detection. The entire process is implemented in the ```run_clustering``` function.

```julia
pbmc = cs.run_clustering(pbmc; res=0.06, n_neighbors=100)
#=
scRNAObject in CellScopes.jl
Genes x Cells = 13100 x 2700
Available data:
- Raw count
- Normalized count
- Scaled count
- Variable genes
- Clustering data
- PCA data
=#
```
### 1.8 Run UMAP or tSNE.
```CellScopes.jl``` provides two non-linear dimensionality reduction techniques, tSNE and UMAP, to allow for visualization and exploration of datasets. In the current version, UMAP is much faster than tSNE for large datasets, so it is highly recommended. We use the [TSne.jl](https://github.com/lejon/TSne.jl) and [UMAP.jl](https://github.com/dillondaudert/UMAP.jl) packages for tSNE and UMAP analysis, respectively.
```julia
pbmc = cs.run_tsne(pbmc; max_iter = 3000, perplexit = 50)
pbmc = cs.run_umap(pbmc; min_dist=0.4)
#=
scRNAObject in CellScopes.jl
Genes x Cells = 13100 x 2700
Available data:
- Raw count
- Normalized count
- Scaled count
- Variable genes
- Clustering data
- PCA data
- tSNE data
- UMAP data
=#
```
### 1.9 Find markers.
```CellScopes.jl``` can help you find markers that define clusters through differential expression analysis. Same as Seurat and Scanpy, we perform wilcoxon rank sum test on each pair of cell types to identify the differential genes. This is implemented by the [HypothesisTests.jl](https://github.com/JuliaStats/HypothesisTests.jl) and [MultipleTesting.jl](https://github.com/juliangehring/MultipleTesting.jl)
```julia
markers = cs.find_markers(pbmc; cluster_1 = "7", cluster_2 = "6")
```
<img src="https://github.com/HaojiaWu/CellScopes.jl/blob/main/data/markers.png" width="600"> <br>

Like in Seurat and Scanpy, we also provide a ```find_all_markers``` function to identify the marker genes for all clusters.
```julia
all_markers = cs.find_all_markers(pbmc)
```

## 2 Data visualization
Inspired by Seurat and Scanpy, we utilize various methods to visualize cell annotations and gene expression. 
### 2.1 Visualize cell annotaiton.
a. Dim plot on PCA
```julia
cs.dim_plot(pbmc; dim_type = "pca", marker_size = 4)
```
<img src="https://github.com/HaojiaWu/CellScopes.jl/blob/main/data/pca.png" width="600"> <br>

b. Dim plot on tSNE
```julia
cs.dim_plot(pbmc; dim_type = "tsne", marker_size = 4)
```
<img src="https://github.com/HaojiaWu/CellScopes.jl/blob/main/data/tsne.png" width="600"> <br>

c. Dim plot on UMAP
```julia
cs.dim_plot(pbmc; dim_type = "umap", marker_size = 4)
```
<img src="https://github.com/HaojiaWu/CellScopes.jl/blob/main/data/umap.png" width="600"> <br>

d. Dim plot on selected cluster
```julia
cs.highlight_cells(pbmc, "6")
```
<img src="https://github.com/HaojiaWu/CellScopes.jl/blob/main/data/highlight.png" width="500"> <br>

### 2.2 Visualize gene expression.
a. Feature plot
```julia
cs.feature_plot(pbmc, ["CST3","IL32","CD79A"]; 
    order=false, marker_size = 4, 
    count_type ="norm", color_keys=("black","indianred1","red"))
```
<img src="https://github.com/HaojiaWu/CellScopes.jl/blob/main/data/featureplot.png" width="800"> <br>

b. Feature plot (split by condition)
```julia
pbmc.metaData.fake_group = repeat(["group1","group2","group3"],900) # Create a fake condition
cs.feature_plot(pbmc, ["CST3","IL32","CD79A"]; 
    order=false, marker_size = 7, 
    count_type ="norm", color_keys=("black","indianred1","red"), split_by="fake_group")
```
<img src="https://github.com/HaojiaWu/CellScopes.jl/blob/main/data/split_by1.png" width="800"> <br>

c. Dot plot 
```julia
cs.dot_plot(pbmc, ["GZMB","GZMA", "CD3D","CD68","CD79A"], "cluster";
               count_type="norm",height=300, width=150,  expr_cutoff = 1, 
                cell_order=["1","5","4","3","8","2","7","6"])
```
<img src="https://github.com/HaojiaWu/CellScopes.jl/blob/main/data/dotgraph.png" width="300"> <br>

d. Dot plot (split by condition)
```julia
cs.dot_plot(pbmc, ["GZMB","GZMA", "CD3D","CD68","CD79A"], 
                "cluster"; split_by="fake_group",
                count_type="norm",height=300, width=150,  expr_cutoff = 1, 
                cell_order=["1","5","4","3","8","2","7","6"])
```
<img src="https://github.com/HaojiaWu/CellScopes.jl/blob/main/data/split_by2.png" width="600"> <br>

e. Violin plot
```julia
from = ["1","5","4","3","8","2","7","6"]
to = ["c1","c2","c3","c4","c5","c6","c7","c8"]
pbmc.metaData = cs.mapvalues(pbmc.metaData, :cluster, :cluster2, from, to);
cs.violin_plot(pbmc, ["GZMB","GZMA", "CD3D","CD68","CD79A"]; group_by="cluster2",
height = 500,alpha=0.5, col_use = :tab10)
```
<img src="https://github.com/HaojiaWu/CellScopes.jl/blob/main/data/violin.png" width="600"> <br>

## 3. Tutorial: MCA 400K cells
```CellScopes.jl``` can analyze atlas-scale single cell data as well. Below are some example codes to complete the analysis of the [MCA dataset](https://figshare.com/articles/MCA_DGE_Data/5435866) which contains ~400K cells. This takes about 50 minutes in a linux server with 128GB RAM and 16 cores.

```julia
import CellScopes as cs
using MatrixMarket, CSV, DataFrames
using SparseArrays
```

```julia
counts = MatrixMarket.mmread("mca_mtx/matrix.mtx");
cells = CSV.File("mca_mtx/barcodes.tsv", header = false) |> DataFrame
cells = string.(cells.Column1)
genes = CSV.File("mca_mtx/genes.tsv", header = false) |> DataFrame
genes = string.(genes.Column2);
@time gene_kept = (vec ∘ collect)(cs.rowSum(counts).> 0.0);
genes = genes[gene_kept];
```
*1.811749 seconds (2.46 M allocations: 131.292 MiB, 37.24% compilation time)*
```julia
@time cell_kept = (vec ∘ collect)(cs.colSum(counts) .> 0.0)
cells = cells[cell_kept];
```
*0.180891 seconds (18.55 k allocations: 4.606 MiB, 3.59% compilation time)*
```julia
@time counts = counts[gene_kept, cell_kept];
```
*4.641869 seconds (631.47 k allocations: 3.878 GiB, 28.75% gc time, 7.56% compilation time)*
```julia
@time rawcount = cs.RawCountObject(counts, cells, genes);
```
*0.011193 seconds (5.12 k allocations: 290.205 KiB, 99.64% compilation time)*
```julia
@time mca = cs.scRNAObject(rawcount)
```
*4.828527 seconds (1.61 M allocations: 3.954 GiB, 6.74% gc time, 16.00% compilation time)*
```julia
@time mca = cs.normalize_object(mca; scale_factor = 10000)
```
*15.791931 seconds (3.82 M allocations: 11.933 GiB, 20.05% gc time, 2.43% compilation time)*
```julia
@time mca = cs.find_variable_genes(mca)
```
*217.251548 seconds (21.15 M allocations: 126.109 GiB, 4.52% gc time, 2.32% compilation time)*
```julia
@time mca = cs.scale_object(mca; features = mca.varGene.var_gene)
```
*147.311905 seconds (4.10 M allocations: 97.858 GiB, 8.31% gc time, 1.23% compilation time)*
```julia
@time mca = cs.run_pca(mca; maxoutdim = 30)
```
*236.710203 seconds (4.22 M allocations: 24.603 GiB, 0.52% gc time, 0.74% compilation time)*
```julia
@time mca = cs.run_umap(mca; dims_use = 1:30, min_dist = 0.6, n_neighbors=30, n_epochs=100)
```
*1075.675636 seconds (63.08 M allocations: 23.239 GiB, 1.64% gc time, 0.37% compilation time)*
```julia
@time mca = cs.run_clustering(mca; res=0.0001,n_neighbors=30) # To-do list: runtime optimization
```
*590.371976 seconds (40.33 M allocations: 1.199 TiB, 0.43% gc time, 0.13% compilation time)*

```julia
cs.dim_plot(mca; marker_size =1, do_label=false, do_legend=false)
```
<img src="https://github.com/HaojiaWu/CellScopes.jl/blob/main/data/umap2.png" width="600"> <br>
