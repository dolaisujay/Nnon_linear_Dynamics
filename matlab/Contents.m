% Hybrid VDP-Duffing Oscillator Research Toolbox
% Version 2.1.0  (MATLAB R2022a or later)
%
% Main Application
%   Hybrid_VDP_Duffing_GUI  - Launch the research workbench GUI
%
% Overview:
%   This toolbox provides an interactive MATLAB/Simulink/Simscape workbench
%   for simulating and analysing the Hybrid Van der Pol-Duffing nonlinear
%   oscillator driven by a parametric forcing signal.  The RC ladder
%   sub-networks (Simscape) emulate a fractional-order impedance element.
%   Three build modes are supported:
%     1. Simulink Only    - variable-step ODE solver (ode15s), no hardware.
%     2. Deploy to Due    - fixed-step code-generation for Arduino Due HIL.
%     3. USB Scope Only   - oscilloscope control without DAC output.
%
% Quick Start:
%   >> Hybrid_VDP_Duffing_GUI
%
% Authors:
%   Mr. Sujay Kumar Dolai  and  Dr. Somnath Roy
%   Research & Development — Bigyanlabs
%
% SPDX-License-Identifier: MIT
% Copyright (c) 2024-2026 Sujay Kumar Dolai and Somnath Roy (Bigyanlabs R&D)
%
% See also: Hybrid_VDP_Duffing_GUI
