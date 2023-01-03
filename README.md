# CellScopes.jl

```CellScopes.jl``` is a Julia-based toolkit for analyzing single cell data. It accepts a gene by cell count matrix as input and applies data normalization, dimensional reduction, cell clustering, and visualization techniques similar to those used in Seurat and Scanpy. Currently, CellScopes.jl only supports scRNA-seq data, but support for spatial transcriptomics and scATAC-seq is planned for future releases. This is our proposal for the package's development.

<img src="https://github.com/HaojiaWu/CellScopes.jl/blob/main/data/CellScopes.png" width="600"> <br>

### 1. Installation
To install ```CellScopes.jl```, you will need to have Julia 1.6 or higher installed. It is recommended to use Julia 1.7.3 or higher to avoid issues with dependencies. To install all of the necessary dependencies, run the following command line in Julia. Note that this will not install the unregisterd package ```Leiden.jl```, which you may need to install manually from the GitHub repository first.

```julia
using Pkg;
Pkg.add("https://github.com/bicycle1885/Leiden.jl") # Install the unregistered dependency Leiden.jl
Pkg.add("https://github.com/HaojiaWu/CellScopes.jl") # Install CellScopes.jl
```
### 2. Tutorial for scRNA-seq analysis
This tutorial uses the pbmc3k dataset from 10x Genomics, which has been previously used by [Seurat](https://satijalab.org/seurat/articles/pbmc3k_tutorial.html) and [Scanpy](https://scanpy-tutorials.readthedocs.io/en/latest/pbmc3k.html) for demo purpose. This will read in the data and create a RawCountObject that can be used as input for ```CellScopes.jl```.
#### 2.1 Download the pbmc3k data (in Terminal)
```bash
wget https://cf.10xgenomics.com/samples/cell/pbmc3k/pbmc3k_filtered_gene_bc_matrices.tar.gz
tar xvf pbmc3k_filtered_gene_bc_matrices.tar.gz
```

#### 2.2 Read the data (in Julia)

```julia
import CellScopes as cs
raw_counts = cs.read_10x("filtered_gene_bc_matrices/hg19"; min_gene = 3);
```
This should create an object type called RawCountObject.
```julia
raw_counts

#CellScopes.RawCountObject
#Genes x Cells = 13100 x 2700
#Available fields:
#- count_mtx
#- cell_name
#- gene_name
```
#### 2.3 Create scRNAObject
We then create a scRNAObject using the count object above. The scRNAObject serves as a container to store all the data needed for and generated from the downstream analysis.
```julia
pbmc = cs.scRNAObject(raw_counts)

#scRNAObject in CellScopes.jl
#Genes x Cells = 13100 x 2700
#Available data:
#- Raw count
#Available fields:
#- rawCount
#- normCount
#- scaleCount
#- metaData
#- varGene
#- dimReduction
#- clustData
#- undefinedData
```

