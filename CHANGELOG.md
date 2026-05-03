# Changelog

All notable changes to the **Hybrid VDP-Duffing Oscillator Workbench** are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [2.1.0] — 2026-05-04

### Added
- Full MATLAB/Simulink/Simscape GUI (`Hybrid_VDP_Duffing_GUI.m`) in a single-file architecture.
- Three build modes: *Simulink Only*, *Deploy to Arduino Due*, *USB Scope Control Only*.
- Simscape RC sub-networks (RC_X, RC_Y) with independent Solver Configuration blocks.
- Live phase portrait, state-vs-forcing time-series, and Hann-windowed power spectrum.
- Annotated arrow overlays on all three plots (initial condition, attractor, dominant peak).
- Advanced plot windows: Poincaré section, spectrogram, peak-to-peak return map.
- Results Export dialog (PNG / JPEG / MATLAB FIG) with timestamp option.
- Model Screenshot dialog with configurable zoom and fit-to-page option.
- `annotation_arrow_on_ax` helper for data-coordinate figure annotations.
- `safe_uialert` helper preventing crashes when export dialogs are closed mid-operation.
- Toolbox packaging: `Contents.m`, `info.xml`, `package_toolbox.m`.
- LaTeX user manual: `doc/HybridVDPDuffing_Manual.tex` with `compile_manual.m`.
- `CHANGELOG.md`, `LICENSE`, `.gitignore`.

### Fixed
- **Critical:** `Invalid or deleted object` crash when reading `open_chk.Value` after `delete(d)` in model-shot dialog — value now read before dialog is closed.
- **Critical:** `Invalid or deleted figure handle` crash in export dialog — `uialert(d,...)` replaced with `safe_uialert` throughout; export now uses `exportgraphics(source_ax,...)` directly for PNG/JPEG, avoiding intermediate `figure()` creation that invalidated the modal dialog handle.
- **Critical:** `Invalid parameter/value pair` export error — missing `source_ax.YGrid` value in `copy_axes_contents` `set()` call.
- **Major:** `Solver Configuration not connected` Simscape error on RC_Y — block positions reverted to verified working coordinates after autorouter sensitivity was discovered.
- **Major:** `validate_arduino_due_settings` hard-erroring in `build_model` even in *Simulink Only* mode — guarded with `if is_hil_mode()` and changed to non-blocking warning+placeholder when Due is absent in HIL mode.
- **Major:** `SizeChangedFcn` silently suppressed — `AutoResizeChildren` set to `off` on main `uifigure`.
- **Minor:** Default build mode changed from *Deploy to Arduino Due* to *Simulink Only*.
- **Minor:** Default parameters updated to match validated research values (R1=800kΩ, R3=30kΩ, f=140, ωp=3, T=600 s).
- Power spectrum now uses Hann-windowed FFT instead of raw FFT for cleaner peak resolution.

### Changed
- Phase portrait colours: muted slate transient + vivid crimson attractor (replaces near-black palette).
- State-vs-forcing: shaded transient region added; transition marker arrow added.
- Spectrum: dashed vertical line at driving frequency Ω; peak annotation arrow.
- All advanced plot figures: font size increased to 20 pt (axes) / 22 pt (titles).
- `set_axes_latex` and `apply_latex_legend` updated with explicit font sizes.

---

## [0.9.0] — 2026-05-03 *(pre-release)*

- Initial working implementation with Simscape RC networks.
- Basic phase portrait and spectrum plots.
- Arduino Due HIL skeleton.
