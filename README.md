# Hybrid Van der Pol–Duffing Oscillator Workbench

> **Interactive MATLAB/Simulink/Simscape research GUI for chaotic nonlinear dynamics, fractional-order RC emulation, and Arduino Due hardware-in-the-loop (HIL) streaming.**

Developed by **Mr. Sujay Kumar Dolai** and **Dr. Somnath Roy** | R&D — *Bigyanlabs*

---

## What is this?

This toolbox provides a self-contained research workbench for the **Hybrid Van der Pol–Duffing (HVDPD)** parametrically-forced oscillator:

$$\ddot{x} - d(1-x^2)\dot{x} + \omega_0^2 x + \beta x^3 = f\cos(\Omega t)\bigl[1 + h\cos(\omega_p t)\bigr]$$

Key features:

| Feature | Detail |
|---|---|
| **Simulink model builder** | Generates a clean Simulink/Simscape model from GUI parameters |
| **Simscape RC networks** | Two independent RC sub-networks (RC_X, RC_Y) emulate fractional-order impedance (Foster-I) |
| **Live plots** | Phase portrait · State vs forcing · Hann-windowed power spectrum |
| **Advanced analysis** | Poincaré sections · Spectrograms · Peak-to-peak return maps |
| **Arduino Due HIL** | Real-time DAC streaming at up to 10 kHz via fixed-step code generation |
| **High-res export** | PNG / JPEG / FIG for all plots and Simulink diagrams |
| **MATLAB Toolbox** | Packaged as `.mltbx` for one-click install via MATLAB Add-Ons |

---

## Quick Start

```matlab
% From MATLAB Command Window (repo clone)
addpath(fullfile(pwd,'matlab'))
Hybrid_VDP_Duffing_GUI
```

**Workflow:** `Build` → `Simulate` → inspect plots → `Export`

---

## Requirements

| Component | Minimum |
|---|---|
| MATLAB | R2022a (9.12) |
| Simulink | 10.5 |
| Simscape | 5.3 |
| Simscape Electrical | 7.7 |
| *(optional)* Simulink Support Package for Arduino Hardware | any |
| *(optional)* Embedded Coder | any |

---

## Installation

### Option A — MATLAB Toolbox (recommended)

```matlab
% Build the .mltbx first (one-time step):
cd('path/to/Hybrid_VDP_Duffing_GUI_2RC_v1/matlab')
package_toolbox()

% Then install:
matlab.addons.install(fullfile('releases','dist','Hybrid_VDP_Duffing_Toolbox_v2.1.0.mltbx'))
```

### Option B — Add to path directly

```matlab
addpath(fullfile('path/to/Hybrid_VDP_Duffing_GUI_2RC_v1','matlab'))
savepath
Hybrid_VDP_Duffing_GUI
```

---

## Repository Structure

```
Hybrid_VDP_Duffing_GUI_2RC_v1/
├── README.md
├── CHANGELOG.md
├── LICENSE
├── matlab/                         ← MATLAB sources + helpers
├── docs/                           ← user manual (LaTeX + PDF)
├── releases/                       ← toolbox installers (.mltbx)
├── resources/                      ← package metadata
└── assets/                         ← figures (kept out of git)
```

---

## Parameter Reference (defaults)

| Parameter | Symbol | Default | Computed value |
|---|---|---|---|
| Base R | $R$ | 10 kΩ | — |
| Capacitance | $C$ | 100 nF | — |
| R1 | $R_1$ | 800 kΩ | $d = R/R_1 = 0.0125$ |
| R2 | $R_2$ | 10 kΩ | $\omega_0 = \sqrt{R/R_2} = 1$ rad/s |
| R3 | $R_3$ | 30 kΩ | $\beta = R/R_3 \approx 0.333$ |
| Forcing amp | $f$ | 140 | $f/\Omega^2 = 1.4$ |
| Modulation depth | $h$ | 0.2 | — |
| Parametric freq | $\omega_p$ | 3 rad/s | — |
| Driving freq | $\Omega$ | 10 rad/s | — |
| Simulation time | — | 600 s | — |
| Initial position | $x_0$ | −1 | — |
| Initial velocity | $y_0$ | 1 | — |

---

## Arduino Due HIL

1. Connect Due via the **programming USB port**.
2. Select **Deploy to Arduino Due** in the Build Mode dropdown.
3. Click **Build** (model generated even without hardware connected).
4. If auto-detection fails, set the COM port override before building:

```matlab
arduino_due_com_port_override = 'COM7';
```

DAC channels: **DAC0** → $x(t)$, **DAC1** → $y(t)$ (XY scope display).

---

## Compiling the PDF Manual

Install [MiKTeX](https://miktex.org) or [TeX Live](https://tug.org/texlive/), then:

```matlab
compile_manual()
```

Or upload `docs/HybridVDPDuffing_Manual.tex` to [Overleaf](https://overleaf.com) (no install needed).

---

## Citation

If you use this toolbox in published research, please cite:

```bibtex
@software{dolai2026hvdp,
  author  = {Dolai, Sujay Kumar and Roy, Somnath},
  title   = {Hybrid {Van der Pol--Duffing} Oscillator Workbench},
  year    = {2026},
  version = {2.1.0},
  url     = {https://github.com/dolaisujay/Nnon_linear_Dynamics},
  note    = {MATLAB/Simulink/Simscape toolbox, Bigyanlabs R\\&D}
}
```

---

## License

MIT License — see [LICENSE](LICENSE).

Copyright © 2024–2026 Sujay Kumar Dolai and Somnath Roy (Bigyanlabs R&D).
