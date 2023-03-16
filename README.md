# CellScopes.jl <img src="https://github.com/HaojiaWu/CellScopes.jl/blob/main/data/logo.png" width="60" height="60"> <br>
```CellScopes.jl``` is a toolkit built using the Julia programming language, designed for the analysis of single cell and spatial transcriptomic data. It offers a range of functionalities including data normalization, dimensional reduction, cell clustering and visualization, all tailored to various types of data generated by scRNA-seq, Visium, Xenium and Cartana. The current version of ```CellScopes.jl``` is structured as follows:

<img src="https://github.com/HaojiaWu/CellScopes.jl/blob/main/data/CellScopes.png" width="600"> <br>

## 1. Installation
To install ```CellScopes.jl```, you will need to have Julia 1.6 or higher installed. It is recommended to use Julia 1.7.3 or higher to avoid issues with dependencies. To install all of the necessary dependencies, run the following command line in Julia. Note that this will not install the unregisterd package ```Leiden.jl```, which you may need to install manually from the GitHub repository first.

```julia
using Pkg;
Pkg.add(url="https://github.com/bicycle1885/Leiden.jl") # Install the unregistered dependency Leiden.jl
Pkg.add(url="https://github.com/HaojiaWu/CellScopes.jl") # Install CellScopes.jl
```
## 2. Tutorials
On this markdown page, we will demonstrate how to use ```CellScopes.jl``` to analyze a kidney dRNA HybISS dataset generated by Cartana (Similar to 10x Xenium). CellScopes also supports analysis for single-cell RNA sequencing (scRNA-seq), Visium and Xenium datasets. For more information, please refer to the tutorials provided below.
<br>
a. scRNA-seq: https://github.com/HaojiaWu/CellScopes.jl/tree/main/docs/scRNA_tutorial
<br>
b. 10x Visium: https://github.com/HaojiaWu/CellScopes.jl/tree/main/docs/visium_tutorial
<br>
c. 10x Xenium: https://github.com/HaojiaWu/CellScopes.jl/tree/main/docs/xenium_tutorial
<br>

## 3. Analysis of imaging-based spatial transcriptomic data (dRNA HybISS by Cartana)
The tutorial below used the spatial data from CARTANA for demo but basically it can process any FISH-based methods (such as Xenium and MERFISH) after slight data formatting. If you find ```CellScopes.jl``` useful to your research, please cite our paper or this github page. <br>

<img src="https://github.com/HaojiaWu/CellScopes.jl/blob/main/docs/cartana_tutorial/img/CellScopes_struct.png" width="600"> <br>


### 3.1. Example data for a test?
If you don't have sample data at hands, you can download our data from GEO (GSE227044) to test the functionality of CellScopes.jl. If you're using your own data, please complete cell segmentation with other tools (we recommend Baysor) before running any downstream analysis. To start the analysis, you'll need three files generated by most cell segmentation tools as data inputs: 1) a metadata file with spatial coordinates of each detected transcript, 2) a metadata file with spatial coordinates of each individual segmented cell, and 3) a gene-by-cell matrix to quantify transcript counts for each gene in each cell, with gene names as rows and cell names as columns.

### 3.2. What is ```CartanaObject```?
```CartanaObject``` is a data type we constructed in Julia to store the original and processed data generated by Cartana, including the 2D spatial coordinates, gene and cell annotations, raw and normalized count matrices, and the results produced during the analysis. We have implemented a variety of computational methods to process the ```CartanaObject```, which results in a wide range of high-quality plots for data visualization.

### 3.3. How to construct a ```CartanaObject```?
**a. Read the spatial data into Julia.** You will need three files in DataFrame format as input: the Molecule file, which includes spatial coordinates for the detected transcripts; the Cell file, which contains spatial coordinates after cell segmentation; and the Count file, which provides the gene-by-cell count matrix resulting from cell segmentation. <br>
```julia
import CellScopes as cs
using CSV, DataFrames
using SparseArrays
molecules =  DataFrame(CSV.File("/mnt/sdc/cartana_weekend/Day2_Jia/segmentation.csv"));
count_df =  DataFrame(CSV.File("/mnt/sdc/cartana_weekend/Day2_Jia/segmentation_counts.tsv"));
cells =  DataFrame(CSV.File("/mnt/sdc/cartana_weekend/Day2_Jia/segmentation_cell_stats.csv"));
```
**b. Construct a CartanaObject** using the count data, the cell and molecules coordinates data. .<br>
```julia
gene_name = count_df.gene
cell_name = string.(names(count_df)[2:end])
count_df = count_df[!, 2:end]
count_df = convert(SparseMatrixCSC{Int64, Int64},Matrix(count_df))
raw_count = cs.RawCountObject(count_df, cell_name, gene_name)
molecules.cell = string.(molecules.cell)
cells.cell = string.(cells.cell)
kidney = cs.CartanaObject(molecules, cells, raw_count;
    prefix = "kidney", min_gene = 0, min_cell = 3)
```
**c. Normalize the raw count data** <br>
```julia
kidney = cs.normalize_object(kidney)
```

### 3.4. CellScopes file I/O
We used the [JLD2.jl](https://github.com/JuliaIO/JLD2.jl) package to save and load the ```CellScopes``` objects. Here are some example lines:
```julia
### save CartanaObject to disk.
cs.save(kidney; filename = "kidney_SpaObj.jld2") 
### read SpaObj object from disk.
kidney = cs.load(filename="kidney_SpaObj.jld2")
```

### 3.5. Data processing and analysis
#### a. Cell clustering
We provide codes to run cell clustering using pure Julia language (https://github.com/HaojiaWu/CellScopes.jl/tree/main/docs/scRNA_tutorial). Additionally, we also offer the option to run clustering using popular sc tools (such as [SpaGCN](https://github.com/jianhuupenn/SpaGCN), [Seurat](https://github.com/satijalab/seurat), and [Scanpy](https://github.com/scverse/scanpy)) via the [RCall.jl](https://github.com/JuliaInterop/RCall.jl) and [PyCall.jl](https://github.com/JuliaPy/PyCall.jl) packages, which seamlessly bridge R and Python with Julia. If your data has already been completed cell clustering using other tools (such as Baysor), this step can be skipped.
<br/>

i. **SpaGCN**: Please refer to the original tutorial to select the paramenters. Below are some example codes (Clustering results will be stored in the cell metadata of the CartanaObject):
```julia
CSV.write("count_data.csv",kidney.rawCount.count)
kidney = cs.run_SpaGCN(kidney, "count_data.csv", "/home/users/haojiawu/anaconda3/bin/python")
```
ii. Here is how to run **Scanpy** in CellScopes:
```julia
adata = cs.run_scanpy(kidney.rawCount.count)
```
iii. To run **Seurat**:
```julia
seu_obj = cs.run_seurat(kidney.rawCount.count)
```

#### b. Cell polygons and mapping
We used Baysor to create a polygon object and store it in CellScopes for cell drawing. Baysor is required to install before running this step. For more information, please visit the original repo here: https://github.com/kharchenkolab/Baysor
```julia
import Baysor as B
scale=30
min_pixels_per_cell = 15
grid_step = scale / min_pixels_per_cell
bandwidth= scale / 10
polygons = B.boundary_polygons(molecules, molecules.cell, grid_step=grid_step, bandwidth=bandwidth)
kidney.polygons = polygons
```
Then the gene expression can be mapped to the cell polygons by approximation based on the Elucidean distance between the original cell coordinate and the center of the ploygons. This can be done with the ```polygons_cell_mapping``` function.
```julia
kidney = cs.polygons_cell_mapping(kidney)
```
Based on the cell mapping results, we can obtain a polygons count matrix. this count matrix can be used for ploting gene expression directly on cell polygons (see the Visualization section).
```julia
kidney = cs.generate_polygon_counts(kidney)
```

#### c. Calculate cell-cell distance
To reveal the phycical cell-cell contact, we provided two functions to calculate the distance of any given cell populations depending on their cell distribution patterns.

**i.** When the cells are confined to some specific regions (such as the glomerular cell types in the kidney), we take a cell-centric approach to calculate the cell-cell distance. We take each cell from the cell population of interest, and compute the distance between this cell and the cells from other cell types. This process will be iteratively repeated until all cells from the cell type of interest are done. An example of measuring the proximity of an EC subtype to a podocyte within a specified search radius can be achieved by following the step below:
```julia
cell_dist = cs.compare_cell_distances(kidney, :celltype, "Podo", "gEC", "vEC", 50)
```
**ii.** When the cell distribution is very diffusive (such as the immune cells or fibroblasts), we use a cell-enrichment approach to compute the patial proximity of pairs of cell types as reported by [Lu et al](https://www.nature.com/articles/s41421-021-00266-1). We calculate the probability of cell type pairs in a neighborhood within a given searching area (e.g. radius =50). We then compute the enrichment of cell type pairs in spatial proximity after normalized to the control probability based on random pairing. 
```julia
cell_dist = cs.run_cell_pairing(kidney.cells, :cell2, :celltype, 50)
```
#### d. Convert the xy coordinates to kidney coordinates
In ```CellScopes.jl```, we created a new coordinate system, namely **kidney coordinate system**, to precisely depict the position of every single cell in the kidney. In this system, the position of a cell is defined by the kidney depth, and the kidney angle. To transform the xy coordinate system to kidney coordinate system, we first define the origin of the coordinate by finding the center point in the papilla. For each cell, we compute the kidney depth by calculating the distance of the cell to the kidney boundary, and divided by the distance of the kidney boundary to the origin of the coordinate. We can define the kidney angle of the cells by measuring the angle of the slope and the new x coordinate (in tangent value). The schematic below explains the coordinate transformation.

<img src="https://github.com/HaojiaWu/CellScopes.jl/blob/main/docs/cartana_tutorial/img/kidney_coordinate.png" width="300"> <br>

This kidney coordinate system can help define the kidney compartment where the cell resides, how the cell type and transcript distribution changes from outer cortex to papilla, and how the gene expression changes in different condiitons. Here are some steps to complete the transformation.
```julia
cs.plot_fov(kidney, 40,40; group_label="celltype", cell_highlight="CD-PC", shield=true) ### use grid to find the papilla area
cell_sub=cs.subset_fov(kidney, [661,671,941,951], 40,40); ### select the papilla area
cell_sub=filter(:celltype => x -> x =="CD-PC", cell_sub); ### select the PC cells in the papilla
center=[mean(cell_sub.x),mean(cell_sub.y)]; ### find the center point as origin
kidney = cs.compute_kidney_coordinates(kidney, center)
```
#### e. Integrating scRNA-seq for gene imputation
Since most of the imaging-based spatial techniques only allow for detection of several hundreds genes, it is important to employ data integration approaches to infer the expression of the genes not included in the gene panel, by using the corresponding scRNA-seq dataset as reference. ```CellScopes.jl``` provides julia functions to run [SpaGE](https://github.com/tabdelaal/SpaGE), [gimVI](https://github.com/scverse/scvi-tools) and [Tangram](https://github.com/broadinstitute/Tangram) for gene imputation. Please refer to the github repos for more detail. The codes below show you how to run these tools conveniently. ```CellScopes.jl``` also provides functions to plot the results (See the Visualization session).
```julia
data_path = "/mnt/sdc/new_analysis_cellscopes/for_imputate/IRI_2d/"
### SpaGE
spaGE_path = "/mnt/sdc/new_analysis_cellscopes/SpaGE"
@time kidney = cs.run_spaGE(kidney, data_path, spaGE_path);
### gimVI
kidney = cs.run_gimVI(kidney, data_path)
### Tangram
kidney = cs.run_tangram(kidney, data_path)
```
Some tools such as tangram might need a long time to run. Imputed gene count will be stored in the ```spImputedObject``` of the ```CartanaObject```.

### 3.6. Visualization
We provided a number of functions to visualize the results from the above analysis. 
#### a. Plot gene expression on segmented cells. 
The sp_feature_plot function is for visualizing spatial expression pattern of the selected genes on the segmented cells. 
```julia
cs.sp_feature_plot(kidney, "Umod"; color_keys=["gray94", "dodgerblue1", "blue"], height=1000, width=800, marker_size = 4)
cs.sp_feature_plot(kidney, "Aqp2"; color_keys=["gray94", "dodgerblue1", "blue"], height=1000, width=800, marker_size = 4)
cs.sp_feature_plot(kidney, "Eln"; color_keys=["gray94", "dodgerblue1", "blue"], height=1000, width=800, marker_size = 4)
```
<p float="left">
  <img src="https://github.com/HaojiaWu/CellScopes.jl/blob/main/docs/cartana_tutorial/img/Umod.png" width=30% height=250>
  <img src="https://github.com/HaojiaWu/CellScopes.jl/blob/main/docs/cartana_tutorial/img/Aqp2.png" width=30% height=250> 
  <img src="https://github.com/HaojiaWu/CellScopes.jl/blob/main/docs/cartana_tutorial/img/Eln.png" width=30% height=250>
</p>

Usually it's hard to see the delicate tructure when ploting gene on the whole kidney. Therefore, we provided three ways to plot gene expression in a selected field of view. <br/>

```julia
##i.plot gene on cells as data points
p1=cs.sp_feature_plot(kidney, ["Podxl"]; 
    layer="molecules",molecule_colors=["red"], x_lims=(21600,24400), y_lims=(4200,6200),order=true,
    pt_size=20,fig_width=600, fig_height=500)
##ii. plot gene on cells as segmented polygons
cmap=ColorSchemes.ColorScheme([colorant"gray98",colorant"red", colorant"red4"])
p2=cs.plot_gene_polygons(kidney, "Podxl",cmap; 
    x_lims=(21600,24400), y_lims=(4200,6200),
    canvas_size=(600,500))
##iii. plot transcripts on cells as segmented polygons
alpha_trans=0.5
anno2 = Dict("Podo" => ("fuchsia",alpha_trans), "HealthyPT"=>("green",alpha_trans),"InjPT"=>("lime",alpha_trans),"TAL"=>("cyan4",alpha_trans),"DCT"=>("yellow",alpha_trans),"CD-PC"=>("gray95",alpha_trans),
            "CD-IC"=>("gray95",alpha_trans),"aEC"=>("red",alpha_trans),"gEC"=>("blue",alpha_trans),"Fib"=>("gray95",alpha_trans),"MC"=>("coral",alpha_trans),"Immune"=>("gray95",alpha_trans),"Uro"=>("gray95",alpha_trans))
@time cs.plot_transcript_polygons(kidney; 
    genes=["Podxl","Ehd3","Ren1"], colors=["fuchsia","blue","coral"],canvas_size=(600,600),
    markersize=2,annotation=:celltype, ann_colors=anno2, is_noise=:is_noise,noise_kwargs=(markersize=0, color="transparent"),
    show_legend=false,bg_color="transparent",x_lims=(17600,20000), y_lims=(7700,10000),segline_size=1, transparency=0.3
)
```
<p float="left">
  <img src="https://github.com/HaojiaWu/CellScopes.jl/blob/main/docs/cartana_tutorial/img/datapoints.png" width=32% height=400>
  <img src="https://github.com/HaojiaWu/CellScopes.jl/blob/main/docs/cartana_tutorial/img/polygons.png" width=32% height=400> 
  <img src="https://github.com/HaojiaWu/CellScopes.jl/blob/main/docs/cartana_tutorial/img/glom.png" width=32% height=400>
</p>

#### b. Plot cell annotation
Cell type annotation can be easily visualized by the ```plot_cell_polygons``` function. Here is an example for ploting the whole kidney.
```julia
alpha_trans=1
anno2 = Dict("Podo" => ("magenta1",alpha_trans), "HealthyPT"=>("green3",alpha_trans), "InjPT"=>("#f92874",alpha_trans),"TAL"=>("lightslateblue",alpha_trans),"DCT"=>("blue",alpha_trans),"CD-PC"=>("turquoise1",alpha_trans),"CD-IC"=>("#924cfa",alpha_trans),"vEC"=>("firebrick",alpha_trans),"gEC"=>("dodgerblue",alpha_trans),"Fib"=>("#edff4d",alpha_trans),"JGA"=>("sienna2",alpha_trans),"Immune"=>("darkgreen",alpha_trans),"Uro"=>("black",alpha_trans));
p3=cs.plot_cell_polygons(kidney, "celltype"; 
    anno_color=anno2,x_lims=(0,35000), 
    y_lims=(0,40000),canvas_size=(5000,6000),
    stroke_color="gray80")
```
<img src="https://github.com/HaojiaWu/CellScopes.jl/blob/main/docs/cartana_tutorial/img/whole.jpg" width="300"> <br>

Here are some examples to show how to visualize the kidney structure in different region.
```julia
### tubule
alpha_trans=1
anno2 = Dict("Podo" => ("magenta1",alpha_trans), "HealthyPT"=>("green3",alpha_trans),"InjPT"=>("#f92874",alpha_trans),"TAL"=>("lightslateblue",alpha_trans),"DCT"=>("blue",alpha_trans),"CD-PC"=>("turquoise1",alpha_trans),"CD-IC"=>("#924cfa",alpha_trans),"vEC"=>("firebrick",alpha_trans),"gEC"=>("dodgerblue",alpha_trans),"Fib"=>("#edff4d",0.5),"JGA"=>("sienna2",alpha_trans),"Immune"=>("darkgreen",alpha_trans),"Uro"=>("black",alpha_trans));
cs.plot_cell_polygons(kidney, "celltype"; 
    anno_color=anno2, x_lims=(18300,19800), y_lims=(10700,14000), 
    canvas_size=(300,600),stroke_color="gray80")

### renal artery
alpha_trans=1
anno2 = Dict("Podo" => ("white",alpha_trans), "HealthyPT"=>("white",alpha_trans),"InjPT"=>("white",alpha_trans),"TAL"=>("white",alpha_trans),"DCT"=>("white",alpha_trans),"CD-PC"=>("white",alpha_trans),"CD-IC"=>("white",alpha_trans),"vEC"=>("firebrick",alpha_trans),"gEC"=>("white",alpha_trans),"Fib"=>("#edff4d",alpha_trans),"JGA"=>("white",alpha_trans),"Immune"=>("white",alpha_trans),"Uro"=>("white",alpha_trans));
cs.plot_cell_polygons(kidney, "celltype"; 
    anno_color=anno2, x_lims=(21900,24500), y_lims=(11500,19500),
    canvas_size=(300,900),stroke_color="gray80")

### renal cortex
alpha_trans=1
anno2 = Dict("Podo" => ("magenta1",alpha_trans), "HealthyPT"=>("green3",alpha_trans),"InjPT"=>("#f92874",alpha_trans),"TAL"=>("lightslateblue",alpha_trans),"DCT"=>("blue",alpha_trans),"CD-PC"=>("turquoise1",alpha_trans),"CD-IC"=>("#924cfa",alpha_trans),"vEC"=>("firebrick",alpha_trans),"gEC"=>("dodgerblue",alpha_trans),"Fib"=>("#edff4d",0.5),"JGA"=>("sienna2",alpha_trans),"Immune"=>("darkgreen",alpha_trans),"Uro"=>("black",alpha_trans));
cs.plot_cell_polygons(kidney, "celltype"; 
    anno_color=anno2, x_lims=(23000,24800), y_lims=(7400,9000), 
    canvas_size=(450,400),stroke_color="gray80")
```
<p float="left">
  <img src="https://github.com/HaojiaWu/CellScopes.jl/blob/main/docs/cartana_tutorial/img/tubule.png" height=400>
  <img src="https://github.com/HaojiaWu/CellScopes.jl/blob/main/docs/cartana_tutorial/img/artery.png" height=400> 
  <img src="https://github.com/HaojiaWu/CellScopes.jl/blob/main/docs/cartana_tutorial/img/cortex.png" height=400> 
</p>

#### c. Plot gene expression across clusters.
We provided a gene rank function to identify the marker genes for each cluster. If cell types were annotated, the ```sp_dot_plot``` function can visualize the gene expression across cell types.

**i.** plot gene rank
```julia
cs.plot_marker_rank(kidney, "celltype","vEC"; num_gene=20)
```
<img src="https://github.com/HaojiaWu/CellScopes.jl/blob/main/docs/cartana_tutorial/img/gene_rank.png" height="200"> <br>

**ii.** Plot gene expression in dotplot format
```julia
cell_order=["Podo", "HealthyPT", "InjPT","TAL","DCT","CD-PC","CD-IC","Uro","gEC","aEC","MC","Fib","Immune"];
genes=["Podxl","Slc26a4","Havcr1","Slc5a2","Krt19","Aqp2","Slc12a3","Eln","Ehd3","Acta2","Col1a1"]
cs.sp_dot_plot(kidney, genes, :celltype; cell_order=cell_order, expr_cutoff=0.1,fontsize=16,fig_height=500, fig_width=300)
```
<img src="https://github.com/HaojiaWu/CellScopes.jl/blob/main/docs/cartana_tutorial/img/dotplot2.png" width="400"> <br>

#### d. Plot cell fraction.
We also provided a way to plot cell fraction across multiple conditions.
```julia
using VegaLite
sham_cell=cs.make_cell_proportion_df(sham.spmetaData.cell; nfeatures=0)
sham_cell.time.="Sham";
hour4_cell=cs.make_cell_proportion_df(hour4.spmetaData.cell; nfeatures=0)
hour4_cell.time.="Hour4";
hour12_cell=cs.make_cell_proportion_df(hour12.spmetaData.cell; nfeatures=0)
hour12_cell.time.="Hour12";
day2_cell=cs.make_cell_proportion_df(day2.spmetaData.cell; nfeatures=0)
day2_cell.time.="Day2";
week6_cell=cs.make_cell_proportion_df(week6.spmetaData.cell; nfeatures=0)
week6_cell.time.="Week6";
all_time=[sham_cell; hour4_cell; hour12_cell; day2_cell; week6_cell];
p=all_time |> @vlplot()+@vlplot(mark={:area, opacity=0.6}, x={"index", axis={grid=false} }, y={:fraction, stack=:zero, axis={grid=false}}, color={"celltype2:n",  scale={
            domain=cell_order2,
            range=cell_color
        }},width=200,height=200) +
@vlplot(mark={:bar, width=1, opacity=1}, x={"index", title="Time point"}, y={:fraction, stack=:zero, title="Cell proportion"}, color={"celltype2:n",  scale={
            domain=cell_order2,
            range=cell_color
        }},
    width=200,height=200)
```
<img src="https://github.com/HaojiaWu/CellScopes.jl/blob/main/docs/cartana_tutorial/img/cellfrac.png" width="600"> <br>

#### e. Select and plot field of view (fov).
```CellScopes.jl``` allows you to select the field of view for further analysis. First, we provided a function to draw grid on the spatial graph. Then the fov of interest can be selected using the ```subset_fov``` function.
```julia
cs.plot_fov(kidney, 10,10; group_label="celltype", cell_highlight="CD-PC", shield=true)
cell_sub = cs.subset_fov(kidney, [47,48,57,58], 10,10);
```
<img src="https://github.com/HaojiaWu/CellScopes.jl/blob/main/docs/cartana_tutorial/img/grid.jpg" width="400"> <br>

#### f. Plot cell type/transcript distribution from cortex to papilla.
After we transform the xy coordinates to the kidney coordinates (See the **Data processing and analysis** section), we can plot the cell type and transcript distribution from outer cortex to papilla.
```julia
markers = ["Slc5a2","Slc12a3","Podxl","Slc26a4","Ehd3","Havcr1","Cd74","Ren1","Col1a1", "Eln","Umod","Krt19","Aqp2"]
markers = reverse(markers);
celltypes = ["HealthyPT","DCT","Podo","CD-IC","gEC","InjPT","Immune","gEC","Fib", "vEC","TAL","Uro","CD-PC"]
celltypes = reverse(celltypes)
cs.plot_depth(kidney, celltypes = celltypes, markers = markers)
```
<img src="https://github.com/HaojiaWu/CellScopes.jl/blob/main/docs/cartana_tutorial/img/kidney_depth.png" height="300"> <br>
We can make this into animation too.
```julia
cs.plot_depth_animation(kidney, celltypes = celltypes, markers = markers)
```
<img src="https://github.com/HaojiaWu/CellScopes.jl/blob/main/docs/cartana_tutorial/img/animations.gif" height="300"> <br>

#### g. Plot imputed gene expression in space and time.
After gene imputation, the expression values of the imputed genes can be visualized using the same function ```sp_feature_plot``` by setting the paramenter ```use_imputed=true```. Here is the example code:
```julia
```
After gene imputation and kidney coordinate transformation, we can plot the gene changes across time and space.
```julia
```



