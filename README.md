# Nnon_linear_Dynamics

Public MATLAB toolbox distribution for hybrid Van der Pol-Duffing nonlinear dynamics with Simscape RC realization, Nth-order RC ladder modeling, analysis plots, and Arduino Due deployment support.

R&D by Bigyanlabs.

Developed by Mr. Sujay Kumar Dolai and Dr. Somnath Roy.

## What This Repository Contains

This public repository is intentionally limited to installable MATLAB toolbox artifacts and documentation. Editable development source code is not included here.

The current release is version `2.0`, which adds Nth-order RC ladder modeling. Version `1.0.1` is also provided for users who need the original fixed-RC release.

## Toolbox Downloads

- Latest v2.0: `toolbox/Hybrid_VDP_Duffing_GUI_v2_0_NthOrder.mltbx`
- Original v1.0.1: `toolbox/Hybrid_VDP_Duffing_GUI_v1_0_1.mltbx`

## Main Features

- Interactive light-theme MATLAB GUI.
- Simulink-only simulation mode.
- Arduino Due waveform deployment workflow.
- USB scope-control workflow.
- Simscape RC realization of the nonlinear oscillator states.
- Configurable `RC Order (N)` for Nth-order RC ladder modeling in v2.0.
- `Math Mode` selection in v2.0:
  - `Raw (no compensation)` for canonical/published equation matching.
  - `Bandwidth-compensated` for optional N-stage bandwidth scaling.
- Plot tools:
  - Phase portrait.
  - State vs parametric excitation.
  - Power spectrum.
  - Poincare section.
  - Spectrogram.
  - Return map.

## Installation

1. Download the required `.mltbx` file from the `toolbox/` folder.

2. Open MATLAB.

3. Install the toolbox using MATLAB `Add-Ons > Install from File`, or run:

   ```matlab
   matlab.addons.install('toolbox/Hybrid_VDP_Duffing_GUI_v2_0_NthOrder.mltbx')
   ```

4. Launch the GUI:

   ```matlab
   start_Hybrid_VDP_Duffing_GUI
   ```

## Repository Layout

```text
toolbox/
  Hybrid_VDP_Duffing_GUI_v2_0_NthOrder.mltbx
  Hybrid_VDP_Duffing_GUI_v1_0_1.mltbx

docs/
  screenshots/
    model_snapshot.png
```

## Version 2.0 Compared With Version 1

- Version 1 focused on the original fixed RC realization.
- Version 2.0 adds Nth-order RC ladder control through `RC Order (N)`.
- Version 2.0 adds `Math Mode` for raw and bandwidth-compensated dynamics.
- Version 2.0 separates internal ladder stage resistance from leakage resistance.
- Version 2.0 corrects the `N=2` behavior so the output matches the expected nonlinear response.
- Version 2.0 includes improved nonlinear-dynamics plot tools.

## Requirements

- MATLAB R2023b or newer.
- Simulink.
- Simscape.
- Arduino support package is required only for Arduino Due deployment.


## MATLAB Package Manager Metadata

Package name for File Exchange / MATLAB Package Manager:

```text
bigyanlabs_vdp_duffing_rc
```

Package version:

```text
2.0.0
```

The package definition is stored in `resources/mpackage.json`.
## MATLAB File Exchange Note

This repository is prepared as an artifact-only public repository. Use the latest `.mltbx` file from `toolbox/` as the File Exchange upload/package artifact.

## Source Code Policy

The editable development source remains private. This public repository contains only packaged toolbox installers and documentation.

## Citation

If this toolbox is used in academic or research work, cite this repository and acknowledge the developers:

Mr. Sujay Kumar Dolai and Dr. Somnath Roy, R&D by Bigyanlabs.



