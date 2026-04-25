# Changelog

## Public Repository Cleanup

- Converted the public branch to an artifact-only distribution.
- Removed visible source and protected payload folders from the public repository branch.
- Kept installable `.mltbx` toolbox files for MATLAB File Exchange/public download.

## 2.0

- Added Nth-order RC ladder support through `RC Order (N)`.
- Added `Math Mode` with raw and bandwidth-compensated options.
- Corrected internal RC ladder implementation so stage resistors use `Base R`.
- Kept `RxLeak` and `RyLeak` as leakage-only resistors.
- Validated corrected `N=2` behavior against the expected nonlinear response.
- Added additional plot tools for nonlinear-dynamics analysis.
- Packaged the toolbox as `Hybrid_VDP_Duffing_GUI_v2_0_NthOrder.mltbx`.

## 1.0.1

- Included original fixed-RC toolbox artifact.
- Packaged artifact: `Hybrid_VDP_Duffing_GUI_v1_0_1.mltbx`.

## 1.x

- Original hybrid VDP-Duffing GUI with fixed RC realization.
- Simulink-only and Arduino Due deployment workflows.
