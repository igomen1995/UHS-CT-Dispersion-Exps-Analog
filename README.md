# CT Concentration Analysis Toolbox

This repository contains MATLAB scripts for processing dynamic X-ray CT experiments, converting CT images into concentration maps, extracting transport metrics, and visualizing fluid displacement in porous media.

The processing can be performed using either:

1. A modular workflow (`CT_preproc` → `CT_extract` → `CT_imaging` → `CT_plots`)
2. A simplified workflow (`CT_simple`)

---

# Workflow

The repository provides two alternative workflows for processing dynamic CT experiments.

## Workflow 1: Modular Workflow

The modular workflow separates image processing, transport analysis, visualization, and plotting into independent steps.

```text
Raw CT Data
│
├── Reference scans
├── Experimental scans
├── PCA files
├── PCP files
└── PCJ files
      │
      ▼
CT_extract
      │
      ├── Import images
      ├── Normalize images
      ├── Crop core region
      ├── Calculate concentration maps
      └── Save HDF5 datasets
              │
              ▼
          Experiment.h5
              │
              ▼
CT_preproc
      │
      ├── Extract concentration profiles
      ├── Calculate breakthrough curves
      ├── Track concentration fronts
      ├── Estimate front velocities
      └── Save processed variables
              │
              ▼
          Experiment.mat
              │
      ┌───────┴────────┐
      ▼                ▼
CT_imaging       CT_plots
```

### CT_extract

This script performs the image-processing stage of the workflow.

Main tasks:

- Import CT images and metadata.
- Load initial and final reference scans.
- Normalize image intensity.
- Crop the core region.
- Compute concentration maps using the reference images.
- Store concentration images in HDF5 format.

Output:

```text
Experiment.h5
```

---

### CT_preproc

This script performs the quantitative analysis stage.

Main tasks:

- Read concentration images from HDF5.
- Calculate concentration profiles.
- Generate concentration histograms.
- Calculate breakthrough curves.
- Track concentration fronts.
- Estimate front propagation velocities.
- Compute contour-based velocity fields.

Output:

```text
Experiment.mat
```

---

### CT_imaging

Interactive visualization of processed experiments.

Features:

- Browse all scans through the breakthrough curve.
- Display concentration maps.
- Display axial and vertical concentration profiles.
- Visualize concentration histograms.
- Inspect displacement evolution interactively.

---

### CT_plots

Comparison and plotting tool.

Typical applications:

- Compare concentration profiles.
- Compare breakthrough curves.
- Create publication-quality figures.
- Compare multiple experiments at similar displacement states.

---

## Workflow 2: CT_simple

`CT_simple` combines all processing steps into a single script.

```text
Raw CT Data
      │
      ▼
CT_simple
      │
      ├── Import data
      ├── Normalize images
      ├── Crop images
      ├── Calculate concentration maps
      ├── Generate profiles
      ├── Generate breakthrough curves
      ├── Create movies
      ├── Interactive visualization
      └── Export processed data
```

Outputs:

```text
expCTlight_<Experiment>.mat
movie_<Experiment>.mp4
crop_xCoords.mat
```

---

## Which Workflow Should I Use?

### Modular workflow

```text
CT_extract
    ↓
CT_preproc
    ↓
CT_imaging
    ↓
CT_plots
```

Recommended for:

- Multiple experiments
- Large datasets
- Reproducible analysis
- Publication-quality results
- Long-term project maintenance

### CT_simple

Recommended for:

- Rapid testing
- Small datasets
- Method development
- Exploratory analysis

---

## Recommended Workflow

For routine use, the recommended workflow is:

```text
CT_extract → CT_preproc → CT_imaging → CT_plots
```

This workflow minimizes memory usage, separates processing from analysis, and allows previously processed datasets to be reused without reprocessing the original CT images.