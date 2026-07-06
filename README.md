# CT Concentration Analysis Toolbox

This repository contains MATLAB scripts for processing dynamic X-ray CT experiments, converting CT images into concentration maps, extracting transport metrics, and visualizing fluid displacement in porous media.

The processing can be performed using either:

1. A modular workflow (`CT_preproc` → `CT_extract` → `CT_imaging` → `CT_plots`)
2. A simplified workflow (`CT_simple`)

---

# Workflow 1: Modular Processing Workflow

This workflow separates image processing, data extraction, visualization, and plotting into independent steps.

```text
Raw CT Data
      |
      +-- Reference scans
      +-- Experimental scans
      +-- PCA files
      +-- PCP files
      +-- PCJ files
      |
      v
CT_preproc
      |
      v
Experiment.h5
      |
      v
CT_extract
      |
      v
Experiment.mat
      |
      +--> CT_imaging
      |
      +--> CT_plots
```

## CT_preproc

Preprocesses reconstructed CT images and generates concentration maps.

Main tasks:

- Import CT images and metadata.
- Load reference scans.
- Normalize image intensity.
- Crop the core region.
- Calculate concentration images using the reference scans.
- Save concentration maps into an HDF5 file.

Output:

```text
Experiment.h5
```

Example HDF5 structure:

```text
/exp
├── run_01
│   └── conc
├── run_02
│   └── conc
└── ...
```

---

## CT_extract

Reads the processed concentration maps and calculates transport-related quantities.

Computed outputs include:

- Axial concentration profiles
- Vertical concentration profiles
- Concentration histograms
- Breakthrough curves
- Front locations (C = 0.1 and C = 0.9)
- Front width
- Front velocity estimates
- Contour-based velocity fields

Output:

```text
Experiment.mat
```

This file contains all processed variables required for visualization and analysis.

---

## CT_imaging

Interactive visualization tool for exploring processed CT experiments.

The breakthrough curve is linked to the CT images. Clicking a point on the breakthrough curve automatically updates:

- Concentration image
- Axial concentration profile
- Vertical concentration profile
- Concentration histogram
- Experiment information

This workflow is useful for investigating how concentration distributions evolve during a displacement experiment.

---

## CT_plots

Post-processing and comparison tool.

Typical uses include:

- Comparing concentration profiles between experiments
- Comparing breakthrough curves
- Selecting profiles at similar displacement states
- Creating publication-quality figures

---

# Workflow 2: CT_simple

`CT_simple` is an all-in-one script that combines processing, analysis, and visualization in a single workflow.

```text
Raw CT Data
      |
      v
CT_simple
      |
      +-- Import data
      +-- Normalize images
      +-- Crop images
      +-- Calculate concentration maps
      +-- Generate concentration profiles
      +-- Generate breakthrough curves
      +-- Create videos
      +-- Interactive visualization
      |
      v
MAT files + Movies
```

## Purpose

`CT_simple` was developed as a lightweight workflow for rapid analysis and testing.

Instead of saving intermediate HDF5 datasets, all processing is performed directly in MATLAB memory.

Outputs typically include:

```text
expCTlight_<Experiment>.mat
movie_<Experiment>.mp4
crop_xCoords.mat
```

---

# Choosing a Workflow

### Modular workflow

```text
CT_preproc
    ↓
CT_extract
    ↓
CT_imaging
    ↓
CT_plots
```

Recommended when:

- Processing large datasets
- Running multiple experiments
- Reusing processed results
- Performing detailed transport analysis
- Working with HDF5 storage

### CT_simple

```text
CT_simple
```

Recommended when:

- Testing new datasets
- Developing methods
- Running quick analyses
- Working with small experiments

---

# Repository Structure

```text
.
├── functions/
│   ├── cropImage.m
│   ├── findcropCore_xAxis.m
│   ├── importImages.m
│   ├── import_inputCTExp.m
│   ├── importPCA.m
│   ├── importPCJ.m
│   ├── importPCP.m
│   ├── normImage.m
│   ├── satImage.m
│   └── onClickCallback.m
│
├── CT_preproc.m
├── CT_extract.m
├── CT_imaging.m
├── CT_plots.m
├── CT_simple.m
│
├── inputCTExpConfig.xlsx
└── README.md
```

# Recommended Workflow

For routine processing and long-term use, the recommended workflow is:

```text
CT_preproc → CT_extract → CT_imaging → CT_plots
```

The modular structure reduces memory usage, makes debugging easier, and allows processing and visualization steps to be run independently.