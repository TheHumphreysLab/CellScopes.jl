# CellScopes.jl <img src="https://github.com/HaojiaWu/CellScopes.jl/blob/main/data/logo.png" width="60" height="60"> <br>
<img src="https://github.com/HaojiaWu/CellScopes.jl/blob/main/data/cs_demo.png"> <br>

```CellScopes.jl``` is a toolkit built using the Julia programming language, designed for the analysis of single cell and spatial transcriptomic data. It offers a range of functionalities including data normalization, dimensional reduction, cell clustering and visualization, all tailored to various types of data generated by scRNA-seq, scATAC-seq, Visium, Xenium, Slide-seq, MERFISH, seqFISH, STARmap and Cartana. The current version of ```CellScopes.jl``` is structured as follows:

<img src="https://github.com/HaojiaWu/CellScopes.jl/blob/main/data/CellScopes2.png" width="1000"> <br>

## 1. Installation
#### 1.1. Install Julia 1.10.4
To install ```CellScopes.jl```, you will need to have Julia 1.6 or higher installed. It is recommended to use Julia 1.10.4 or higher to avoid issues with dependencies. Here we will show how to install Julia in the Linux system.

Assume you have access to the directory ```/home/users/doe```. Here is how to install ```Julia 1.10.4```.

```bash
cd /home/users/doe/
wget https://julialang-s3.julialang.org/bin/linux/x64/1.10/julia-1.10.4-linux-x86_64.tar.gz
tar xvf julia-1.10.4-linux-x86_64.tar.gz
```
Then add Julia to PATH. Assume you have a ```~/.bashrc``` file, then append the following code to the end of the ```~/.bashrc``` file.

```bash
export PATH=/home/users/doe/julia-1.10.4/bin:$PATH
```

To implement your changes, either open a new login session or reload the .bashrc via

```
source ~/.bashrc
```

#### 1.2. Install CellScopes and dependencies
To install all of the necessary dependencies, run the following command line in ```Julia```. Note that this will not install the unregisterd package ```Leiden.jl```, which you may need to install manually from the GitHub repository first.

```julia
using Pkg;
Pkg.add(url="https://github.com/bicycle1885/Leiden.jl") # Install the unregistered dependency Leiden.jl
Pkg.add(url="https://github.com/TheHumphreysLab/CellScopes.jl") # Install CellScopes.jl
```

## 2. Tutorials
```CellScopes``` supports analysis for single-cell RNA sequencing (scRNA-seq), single-cell ATAC-seq (scATAC-seq), Visium, Slide-seq, Cartana, MERFISH, seqFISH, STARmap and Xenium datasets. For more information, please refer to the tutorials provided below.
### 2.1. Standalone analysis
***a. dRNA HybISS by Cartana***: https://github.com/HaojiaWu/CellScopes.jl/tree/main/docs/cartana_tutorial
<br>
***b. scRNA-seq***: https://github.com/HaojiaWu/CellScopes.jl/tree/main/docs/scRNA_tutorial
<br>
***c. scATAC-seq***: https://github.com/HaojiaWu/CellScopes.jl/tree/main/docs/scATAC_tutorial
<br>
***d. 10x Visium***: https://github.com/HaojiaWu/CellScopes.jl/tree/main/docs/visium_tutorial
<br>
***e. 10x Xenium***: https://github.com/HaojiaWu/CellScopes.jl/tree/main/docs/xenium_tutorial
<br>
***f. MERFISH***: https://github.com/HaojiaWu/CellScopes.jl/tree/main/docs/MERFISH_tutorial
<br>
***g. Slide-seq***: https://github.com/HaojiaWu/CellScopes.jl/tree/main/docs/SlideSeq_tutorial
<br>
***h. seqFISH***: https://github.com/HaojiaWu/CellScopes.jl/tree/main/docs/seqfish_tutorial
<br>
***i. STARmap***: https://github.com/HaojiaWu/CellScopes.jl/tree/main/docs/starmap_tutorial
<br>
***j. Visium HD***: https://github.com/HaojiaWu/CellScopes.jl/blob/main/docs/VisiumHD_tutorial
<br>

### 2.2. Interaction with other tools
In addition to these standalone CellScopes analyses, we also provide tutorials how CellScopes can interact with other popular tools such as Seurat, Scanpy and tools for gene imputation and spot deconvolution.
<br>
***k. Conversion of Scanpy AnnData to CellScopes Objects***: https://github.com/HaojiaWu/CellScopes.jl/tree/main/docs/scanpy_conversion
<br>
***l. Conversion of Seurat Objects to CellScopes Objects***: https://github.com/HaojiaWu/CellScopes.jl/tree/main/docs/seurat_conversion
<br>
***m. Gene imputation using SpaGE***: https://github.com/HaojiaWu/CellScopes.jl/tree/main/docs/gene_imputation
<br>

### 2.3. Incorporation of high-res images
We also provide tutorials for incorporating high-resolution H&E and nuclei staining images for Visium and Xenium data visualization.
<br>
***n. Visium data visualization with a high-resolution H&E image***: https://github.com/HaojiaWu/CellScopes.jl/tree/main/docs/Visium_more_viz
<br>
***o. Xenium data visualization with a high-resolution H&E/DAPI image***: https://github.com/HaojiaWu/CellScopes.jl/tree/main/docs/Xenium_more_viz
<br>
### 2.4. Data integration
Coming soon!

## 3. Citation
If the tool is helpful to your study, please consider citing our paper: <br />
https://www.nature.com/articles/s41467-024-45752-8 <br />
**Nature Communications.**  2024 Feb 15;15(1):1396.<br />
Wu H, Dixon EE, Xuanyuan Q, Guo J, Yoshimura Y, Debashish C, Niesnerova A, Xu H, Rouault M, Humphreys BD. <br />
**High resolution spatial profiling of kidney injury and repair using RNA hybridization-based in situ sequencing.** <br />

## 4. Contact
For more information, please contact <a href="https://humphreyslab.com/">The Humphreys Lab</a> or follow our Twitter account <a href="https://twitter.com/humphreyslab?lang=en">@HumphreysLab</a>
