function Hybrid_VDP_Duffing_GUI()
    % SPDX-License-Identifier: MIT
    % Copyright (c) 2024-2026 Sujay Kumar Dolai and Somnath Roy (Bigyanlabs R&D)
    % See `LICENSE` for full terms.

    % ============================================================
    % MAIN GUI
    % ============================================================
    fig = uifigure('Name', 'Hybrid VDP-Duffing RC Workbench', ...
        'Position', [80, 20, 1520, 1020], ...
        'Color', [0.95 0.96 0.98], ...
        'AutoResizeChildren', 'off');
    theme_bg_panel = [0.975 0.978 0.985];
    theme_surface = [1.00 1.00 1.00];
    theme_panel_border = [0.79 0.83 0.90];
    theme_text_main = [0.14 0.18 0.24];
    theme_text_muted = [0.41 0.46 0.55];
    theme_section = [0.07 0.32 0.62];
    theme_accent = [0.02 0.39 0.77];
    theme_help_bg = [0.92 0.95 0.99];
    dev_credit_lbl = uilabel(fig, ...
        'Position', [18, 1000, 980, 18], ...
        'Text', 'Developed by Mr. Sujay Kumar Dolai and Dr. Somnath Roy | R&D by Bigyanlabs', ...
        'FontAngle', 'italic', ...
        'FontColor', theme_text_muted);
    pnl = uipanel(fig, 'Position', [18, 18, 500, 984], ...
        'Title', 'Simulation Parameters', ...
        'BackgroundColor', theme_bg_panel, ...
        'ForegroundColor', theme_text_main, ...
        'BorderType', 'line', ...
        'HighlightColor', theme_panel_border, ...
        'FontWeight', 'bold', ...
        'FontSize', 12);

    % Fixed values from formula text
    R_fixed_default = 10e3;     % 10 kOhm
    C_fixed_default = 100e-9;   % 100 nF

    % Arduino Due DAC streaming defaults
    % NOTE:
    % The Due DAC is physically 0..3.3 V (unipolar), even if we define a
    % logical signal range like [-2, 2] for internal scaling.
    % For XY scope display this is fine, as long as both channels use the
    % same mapping. The displayed phase portrait will be offset/scaled.
    arduino_due_output_enabled = true;
    arduino_due_dac_pin = 'DAC0';
    arduino_due_signal_min = -0.5;
    arduino_due_signal_max = 0.5;

    % IMPORTANT FIX:
    % Old default was 2e-2 (50 Hz), which is too slow for a clean XY trace.
    % Use 1e-3 as a practical starting point for Arduino Due DAC display.
    arduino_due_sample_time = 1e-3;

    arduino_due_phase_output_enabled = true;
    arduino_due_output_view = 'Limit Cycle (x-y)';
    arduino_due_self_test_enabled = false;
    arduino_due_self_test_waveform = 'Square';
    arduino_due_amplitude_multiplier = 2.0;

    % Keep smoothing available, but with a much smaller tau.
    arduino_due_smoothing_enabled = false;
    arduino_due_filter_tau = 1e-3;

    build_mode_default = 'Simulink Only';
    last_built_mode = "";
    latest_sim_results = [];
    last_plot_data = [];
    export_prefs = struct('folder', pwd, 'format', 'PNG', 'dpi', 600, 'prefix', 'results');
    run_poll_timer = [];
    run_in_progress = false;
    stop_requested = false;

    % Base layout reference used for responsive resize/reflow.
    % Widened to provide a clean right-side action-button column.
    base_panel_size = [500, 984];

    section_mode = uilabel(pnl, 'Position', [24, 924, 160, 22], 'Text', 'Mode', ...
        'FontWeight', 'bold');
    uilabel(pnl, 'Position', [24, 900, 110, 22], 'Text', 'Build Mode:');
    build_mode_dropdown = uidropdown(pnl, ...
        'Position', [24, 872, 334, 28], ...
        'Items', {'Simulink Only', 'Deploy to Arduino Due', 'USB Scope Control Only'}, ...
        'Value', build_mode_default, ...
        'ValueChangedFcn', @(~,~) update_build_mode_ui());
    mode_help_lbl = uilabel(pnl, ...
        'Position', [24, 822, 334, 44], ...
        'Text', '', ...
        'WordWrap', 'on', ...
        'FontAngle', 'italic');

    % Base constants
    section_circuit = uilabel(pnl, 'Position', [24, 792, 180, 22], 'Text', 'Circuit Constants', ...
        'FontWeight', 'bold');
    uilabel(pnl, 'Position', [24, 768, 150, 22], 'Text', 'Base R (Ohms):');
    Rbase_edit = uieditfield(pnl, 'numeric', ...
        'Position', [24, 742, 145, 26], ...
        'Value', R_fixed_default, ...
        'Editable', 'off');
    uilabel(pnl, 'Position', [210, 768, 150, 22], 'Text', 'Capacitance C (F):');
    Cbase_edit = uieditfield(pnl, 'numeric', ...
        'Position', [210, 742, 145, 26], ...
        'Value', C_fixed_default);

    % Coefficient-setting resistors
    uilabel(pnl, 'Position', [24, 706, 165, 22], 'Text', 'R1 for d = R / R1:');
    R1coef_edit = uieditfield(pnl, 'numeric', ...
        'Position', [24, 680, 145, 26], ...
        'Value', 800e3);
    uilabel(pnl, 'Position', [210, 706, 165, 22], 'Text', 'R2 for w0^2 = R / R2:');
    R2coef_edit = uieditfield(pnl, 'numeric', ...
        'Position', [210, 680, 145, 26], ...
        'Value', 10e3);
    uilabel(pnl, 'Position', [24, 644, 165, 22], 'Text', 'R3 for beta = R / R3:');
    R3coef_edit = uieditfield(pnl, 'numeric', ...
        'Position', [24, 618, 145, 26], ...
        'Value', 30e3);

    % Computed values
    section_params = uilabel(pnl, 'Position', [24, 586, 180, 22], 'Text', 'Computed Parameters', ...
        'FontWeight', 'bold');
    uilabel(pnl, 'Position', [24, 562, 90, 22], 'Text', 'Computed d:');
    d_val_lbl = uilabel(pnl, 'Position', [112, 562, 70, 22], 'Text', '', ...
        'HorizontalAlignment', 'left', 'FontWeight', 'bold');
    uilabel(pnl, 'Position', [210, 562, 95, 22], 'Text', 'Computed w0:');
    w0_val_lbl = uilabel(pnl, 'Position', [304, 562, 60, 22], 'Text', '', ...
        'HorizontalAlignment', 'left', 'FontWeight', 'bold');
    uilabel(pnl, 'Position', [24, 534, 100, 22], 'Text', 'Computed beta:');
    b_val_lbl = uilabel(pnl, 'Position', [123, 534, 60, 22], 'Text', '', ...
        'HorizontalAlignment', 'left', 'FontWeight', 'bold');
    uilabel(pnl, 'Position', [210, 534, 78, 22], 'Text', sprintf('f/%s^2:', char(937)));
    f_over_omega_sq_lbl = uilabel(pnl, 'Position', [286, 534, 78, 22], 'Text', '', ...
        'HorizontalAlignment', 'left', 'FontWeight', 'bold');
    btn_update = uibutton(pnl, 'push', ...
        'Position', [24, 496, 334, 30], ...
        'Text', 'Update Computed Parameters', ...
        'ButtonPushedFcn', @(~,~) update_computed_params());

    % Forcing and modulation
    section_excitation = uilabel(pnl, 'Position', [24, 462, 180, 22], 'Text', 'Excitation', ...
        'FontWeight', 'bold');
    uilabel(pnl, 'Position', [24, 438, 150, 22], 'Text', 'Forcing Amplitude (f):');
    f_edit = uieditfield(pnl, 'numeric', ...
        'Position', [24, 412, 145, 26], ...
        'Value', 140, ...
        'ValueChangedFcn', @(src, evt) update_computed_params());
    uilabel(pnl, 'Position', [210, 438, 145, 22], 'Text', 'Modulation Depth (h):');
    h_edit = uieditfield(pnl, 'numeric', ...
        'Position', [210, 412, 60, 26], ...
        'Value', 0.2);
    h_slider = uislider(pnl, ...
        'Position', [280, 425, 75, 3], ...
        'Limits', [0.1, 1.0], ...
        'Value', 0.2, ...
        'MajorTicks', [0.1, 0.5, 1.0], ...
        'MinorTicks', 0.1:0.1:1.0, ...
        'ValueChangingFcn', @(src, evt) sync_slider_to_edit(evt.Value, h_edit), ...
        'ValueChangedFcn', @(src, evt) sync_slider_to_edit_and_update(src.Value, h_edit));
    uilabel(pnl, 'Position', [24, 380, 170, 22], 'Text', sprintf('Parametric Freq (%s_p):', char(969)));
    wp_edit = uieditfield(pnl, 'numeric', ...
        'Position', [24, 354, 60, 26], ...
        'Value', 3.0, ...
        'ValueChangedFcn', @(src, evt) sync_edit_to_slider(src, wp_slider));
    wp_slider = uislider(pnl, ...
        'Position', [98, 367, 257, 3], ...
        'Limits', [0.1, 5.0], ...
        'Value', 3.0, ...
        'MajorTicks', [0.1, 1, 2, 3, 4, 5], ...
        'MinorTicks', 0.5:0.5:5.0, ...
        'ValueChangingFcn', @(src, evt) sync_slider_to_edit(evt.Value, wp_edit), ...
        'ValueChangedFcn', @(src, evt) sync_slider_to_edit(src.Value, wp_edit));
    h_edit.ValueChangedFcn = @(src, evt) sync_edit_to_slider(src, h_slider);
    uilabel(pnl, 'Position', [24, 322, 170, 22], 'Text', sprintf('Driving Freq (%s):', char(937)));
    omega_edit = uieditfield(pnl, 'numeric', ...
        'Position', [24, 296, 60, 26], ...
        'Limits', [1, 10], ...
        'LowerLimitInclusive', 'on', ...
        'UpperLimitInclusive', 'on', ...
        'Value', 10, ...
        'ValueChangedFcn', @(src, evt) sync_edit_to_slider_and_update(src, omega_slider));
    omega_slider = uislider(pnl, ...
        'Position', [98, 309, 257, 3], ...
        'Limits', [1.0, 10.0], ...
        'Value', 10, ...
        'MajorTicks', 1:10, ...
        'MinorTicks', 1:10, ...
        'ValueChangingFcn', @(src, evt) sync_slider_to_edit(evt.Value, omega_edit), ...
        'ValueChangedFcn', @(src, evt) sync_slider_to_edit_and_update(src.Value, omega_edit));

    % Leak resistors
    section_hardware = uilabel(pnl, 'Position', [24, 270, 180, 22], 'Text', 'Hardware Output', ...
        'FontWeight', 'bold');
    uilabel(pnl, 'Position', [24, 246, 155, 20], 'Text', 'Leak Resistor Rx (Ohms):');
    Rx_edit = uieditfield(pnl, 'numeric', ...
        'Position', [24, 220, 145, 24], ...
        'Value', 1e9);
    uilabel(pnl, 'Position', [210, 246, 155, 20], 'Text', 'Leak Resistor Ry (Ohms):');
    Ry_edit = uieditfield(pnl, 'numeric', ...
        'Position', [210, 220, 145, 24], ...
        'Value', 1e9);

    % Arduino Due DAC output controls
    dac_section_lbl = uilabel(pnl, 'Position', [24, 188, 180, 22], 'Text', 'Arduino Due DAC Output');
    dac_enable_chk = uicheckbox(pnl, ...
        'Position', [24, 164, 145, 20], ...
        'Text', 'Enable DAC Output', ...
        'Value', arduino_due_output_enabled);
    phase_output_chk = uicheckbox(pnl, ...
        'Position', [24, 142, 190, 20], ...
        'Text', 'Enable XY DAC1 = y(t)', ...
        'Value', arduino_due_phase_output_enabled);
    smooth_output_chk = uicheckbox(pnl, ...
        'Position', [24, 120, 145, 20], ...
        'Text', 'Smooth DAC Output', ...
        'Value', arduino_due_smoothing_enabled);
    self_test_chk = uicheckbox(pnl, ...
        'Position', [210, 142, 145, 20], ...
        'Text', 'DAC Self-Test', ...
        'Value', arduino_due_self_test_enabled, ...
        'ValueChangedFcn', @(~,~) update_build_mode_ui());
    dac_pin_lbl = uilabel(pnl, 'Position', [210, 164, 145, 20], 'Text', 'Physical View:');
    dac_pin_dropdown = uidropdown(pnl, ...
        'Position', [210, 140, 145, 24], ...
        'Items', {'Limit Cycle (x-y)', 'State vs Forcing', 'Power Spectrum of x'}, ...
        'Value', arduino_due_output_view);
    dac_sample_lbl = uilabel(pnl, 'Position', [24, 98, 76, 18], 'Text', 'Sample Time');
    dac_sample_time_edit = uieditfield(pnl, 'numeric', ...
        'Position', [24, 76, 66, 22], ...
        'Limits', [1e-6, Inf], ...
        'LowerLimitInclusive', 'on', ...
        'Value', arduino_due_sample_time);
    filter_tau_lbl = uilabel(pnl, 'Position', [96, 98, 52, 18], 'Text', 'LPF tau');
    filter_tau_edit = uieditfield(pnl, 'numeric', ...
        'Position', [96, 76, 52, 22], ...
        'Limits', [1e-6, Inf], ...
        'LowerLimitInclusive', 'on', ...
        'Value', arduino_due_filter_tau);
    self_test_wave_lbl = uilabel(pnl, 'Position', [154, 98, 34, 18], 'Text', 'Test');
    self_test_wave_dropdown = uidropdown(pnl, ...
        'Position', [154, 76, 60, 22], ...
        'Items', {'Square', 'Sine', 'Ramp'}, ...
        'Value', arduino_due_self_test_waveform);
    amp_mult_lbl = uilabel(pnl, 'Position', [220, 98, 42, 18], 'Text', 'Amp x');
    amp_mult_edit = uieditfield(pnl, 'numeric', ...
        'Position', [220, 76, 42, 22], ...
        'Limits', [0.1, Inf], ...
        'LowerLimitInclusive', 'on', ...
        'Value', arduino_due_amplitude_multiplier);
    dac_min_lbl = uilabel(pnl, 'Position', [268, 98, 28, 18], 'Text', 'Min');
    dac_signal_min_edit = uieditfield(pnl, 'numeric', ...
        'Position', [268, 76, 42, 22], ...
        'Value', arduino_due_signal_min);
    dac_max_lbl = uilabel(pnl, 'Position', [314, 98, 28, 18], 'Text', 'Max');
    dac_signal_max_edit = uieditfield(pnl, 'numeric', ...
        'Position', [314, 76, 42, 22], ...
        'Value', arduino_due_signal_max);

    % Simulation and initial conditions
    section_run = uilabel(pnl, 'Position', [24, 58, 180, 18], 'Text', 'Run Setup', ...
        'FontWeight', 'bold');
    uilabel(pnl, 'Position', [24, 40, 120, 16], 'Text', 'Simulation Time');
    t_edit = uieditfield(pnl, 'numeric', ...
        'Position', [24, 18, 156, 20], ...
        'Value', 600);
    uilabel(pnl, 'Position', [186, 40, 70, 16], 'Text', 'Init Pos');
    x0_edit = uieditfield(pnl, 'numeric', ...
        'Position', [186, 18, 80, 20], ...
        'Value', -1.0);
    uilabel(pnl, 'Position', [278, 40, 70, 16], 'Text', 'Init Vel');
    y0_edit = uieditfield(pnl, 'numeric', ...
        'Position', [278, 18, 80, 20], ...
        'Value', 1.0);

    info_box = uitextarea(pnl, ...
        'Position', [24, 8, 1, 1], ...
        'Editable', 'off', ...
        'Visible', 'off', ...
        'Value', {'Set DAC pin, sample time, and x-range for DSO output.'});

    btn_clean = uibutton(pnl, 'push', ...
        'Position', [20, 0, 54, 18], ...
        'Text', 'Clean', ...
        'ButtonPushedFcn', @(~,~) apply_clean_output_preset());
    btn_debug = uibutton(pnl, 'push', ...
        'Position', [78, 0, 54, 18], ...
        'Text', 'Debug', ...
        'ButtonPushedFcn', @(~,~) apply_dac_debug_preset());

    btn_build = uibutton(pnl, 'push', ...
        'Position', [136, 0, 54, 18], ...
        'Text', 'Build', ...
        'ButtonPushedFcn', @(~,~) build_model());
    btn_run = uibutton(pnl, 'push', ...
        'Position', [194, 0, 72, 18], ...
        'Text', 'Deploy', ...
        'ButtonPushedFcn', @(~,~) run_analysis());
    btn_stop = uibutton(pnl, 'push', ...
        'Position', [270, 0, 50, 18], ...
        'Text', 'Stop', ...
        'Enable', 'off', ...
        'ButtonPushedFcn', @(~,~) stop_simulation());
    btn_export = uibutton(pnl, 'push', ...
        'Position', [324, 0, 54, 18], ...
        'Text', 'Export...', ...
        'ButtonPushedFcn', @(~,~) open_export_dialog());
    btn_modelshot = uibutton(pnl, 'push', ...
        'Position', [382, 0, 108, 18], ...
        'Text', 'Model Shot...', ...
        'ButtonPushedFcn', @(~,~) open_modelshot_dialog());

    btn_poincare = uibutton(fig, 'push', ...
        'Position', [980, 980, 110, 24], ...
        'Text', 'Poincare', ...
        'ButtonPushedFcn', @(~,~) show_poincare_plot());
    btn_specgram = uibutton(fig, 'push', ...
        'Position', [1098, 980, 110, 24], ...
        'Text', 'Spectrogram', ...
        'ButtonPushedFcn', @(~,~) show_spectrogram_plot());
    btn_returnmap = uibutton(fig, 'push', ...
        'Position', [1216, 980, 110, 24], ...
        'Text', 'Return Map', ...
        'ButtonPushedFcn', @(~,~) show_return_map_plot());

    % Professional theme styling
    set([section_mode, section_circuit, section_params, section_excitation, section_hardware, dac_section_lbl, section_run], ...
        'FontColor', theme_section, ...
        'FontWeight', 'bold', ...
        'FontSize', 11);
    mode_help_lbl.BackgroundColor = theme_help_bg;
    mode_help_lbl.FontColor = theme_text_main;
    mode_help_lbl.FontSize = 10;

    btn_clean.BackgroundColor = [0.91 0.95 0.99];
    btn_debug.BackgroundColor = [0.93 0.95 1.00];
    btn_build.BackgroundColor = [0.88 0.95 0.90];
    btn_run.BackgroundColor = [0.18 0.53 0.89];
    btn_export.BackgroundColor = [0.99 0.94 0.86];
    btn_modelshot.BackgroundColor = [0.92 0.95 0.99];
    btn_stop.BackgroundColor = [0.93 0.86 0.86];
    set([btn_clean, btn_debug, btn_build, btn_run, btn_export, btn_modelshot, btn_poincare, btn_specgram, btn_returnmap], ...
        'FontWeight', 'bold');
    set([btn_clean, btn_debug, btn_build, btn_export, btn_modelshot], 'FontColor', theme_text_main);
    btn_run.FontColor = [1 1 1];
    btn_stop.FontColor = [0.40 0.10 0.10];
    btn_poincare.BackgroundColor = [0.90 0.95 0.99];
    btn_specgram.BackgroundColor = [0.91 0.96 0.99];
    btn_returnmap.BackgroundColor = [0.93 0.97 0.99];
    set([btn_poincare, btn_specgram, btn_returnmap], 'FontColor', theme_text_main);

    set([d_val_lbl, w0_val_lbl, b_val_lbl, f_over_omega_sq_lbl], 'FontColor', theme_accent);

    all_font_controls = findall(fig, '-property', 'FontName');
    for k = 1:numel(all_font_controls)
        if isprop(all_font_controls(k), 'FontName')
            all_font_controls(k).FontName = 'Segoe UI';
        end
    end

    panel_labels = findall(pnl, 'Type', 'uilabel');
    for k = 1:numel(panel_labels)
        if ~ismember(panel_labels(k), [section_mode, section_circuit, section_params, section_excitation, section_hardware, dac_section_lbl, section_run])
            panel_labels(k).FontColor = theme_text_main;
        end
    end

    panel_edits = findall(pnl, 'Type', 'uieditfield');
    for k = 1:numel(panel_edits)
        panel_edits(k).BackgroundColor = theme_surface;
        panel_edits(k).FontColor = theme_text_main;
    end

    panel_dropdowns = findall(pnl, 'Type', 'uidropdown');
    for k = 1:numel(panel_dropdowns)
        panel_dropdowns(k).BackgroundColor = theme_surface;
        panel_dropdowns(k).FontColor = theme_text_main;
    end

    panel_checks = findall(pnl, 'Type', 'uicheckbox');
    for k = 1:numel(panel_checks)
        panel_checks(k).FontColor = theme_text_main;
    end

    % Axes
    ax_phase = uiaxes(fig, 'Position', [440, 580, 500, 275]);
    set_axes_latex(ax_phase, 'Phase Portrait', '$x$', '$y$');
    grid(ax_phase, 'on');

    ax_forcing = uiaxes(fig, 'Position', [970, 580, 500, 275]);
    set_axes_latex(ax_forcing, 'State vs Parametric Excitation', '$t$ (s)', 'Amplitude');
    grid(ax_forcing, 'on');

    ax_spectrum = uiaxes(fig, 'Position', [705, 220, 500, 285]);
    set_axes_latex(ax_spectrum, 'Power Spectrum of $x$', 'Angular Frequency (rad/s)', 'Magnitude (dB)');
    grid(ax_spectrum, 'on');
    set([ax_phase, ax_forcing, ax_spectrum], ...
        'Color', [0.995 0.998 1.0], ...
        'GridColor', [0.85 0.89 0.94], ...
        'XColor', theme_text_main, ...
        'YColor', theme_text_main, ...
        'LineWidth', 1.0, ...
        'GridAlpha', 0.25, ...
        'MinorGridAlpha', 0.12);

    % Capture all panel child positions once, then reflow on resize.
    layout_items = pnl.Children;
    layout_base_pos = cell(numel(layout_items), 1);
    for k = 1:numel(layout_items)
        if isprop(layout_items(k), 'Position')
            layout_base_pos{k} = layout_items(k).Position;
        else
            layout_base_pos{k} = [];
        end
    end

    model_name = 'Hybrid_VDP_Duffing_RC_Simscape';
    fig.CloseRequestFcn = @(~,~) close_gui();
    fig.SizeChangedFcn = @(~,~) update_responsive_layout();
    update_responsive_layout();
    update_computed_params();
    update_build_mode_ui();

    function update_responsive_layout()
        fig_pos = fig.Position;
        fig_w = fig_pos(3);
        fig_h = fig_pos(4);

        % Keep developer credit at the top of the app, outside panel title region.
        dev_credit_lbl.Position = [18, max(2, fig_h - 20), min(900, fig_w - 36), 18];

        % Reflow panel area.
        panel_margin = 18;
        % Do not upscale controls on large windows; keep a stable authoring width.
        % Only shrink the panel when the window is too small.
        panel_w = min(base_panel_size(1), max(420, fig_w - (2 * panel_margin) - 420));
        panel_h = min(base_panel_size(2), max(620, fig_h - (2 * panel_margin)));
        panel_y = max(panel_margin, fig_h - panel_margin - panel_h); % top anchored
        pnl.Position = [panel_margin, panel_y, panel_w, panel_h];

        sx = panel_w / base_panel_size(1);
        sy = panel_h / base_panel_size(2);
        % Prevent expansion artifacts: only shrink controls, never upscale.
        sx = min(1.0, sx);
        sy = min(1.0, sy);
        for i = 1:numel(layout_items)
            if isempty(layout_base_pos{i}) || ~isvalid(layout_items(i))
                continue;
            end
            b = layout_base_pos{i};
            new_pos = [b(1) * sx, b(2) * sy, b(3) * sx, b(4) * sy];
            layout_items(i).Position = new_pos;
        end

        % Keep main action buttons in a dedicated right-side stack near the top
        % (more space and better ergonomics than bottom placement).
        act_btn_w = 112;
        act_btn_h = 28;
        act_btn_gap = 8;
        act_btn_x = panel_w - act_btn_w - 16;
        act_btn_y_top = panel_h - 16 - act_btn_h;

        btn_clean.Position    = [act_btn_x, act_btn_y_top - 0*(act_btn_h + act_btn_gap), act_btn_w, act_btn_h];
        btn_debug.Position    = [act_btn_x, act_btn_y_top - 1*(act_btn_h + act_btn_gap), act_btn_w, act_btn_h];
        btn_build.Position    = [act_btn_x, act_btn_y_top - 2*(act_btn_h + act_btn_gap), act_btn_w, act_btn_h];
        btn_run.Position      = [act_btn_x, act_btn_y_top - 3*(act_btn_h + act_btn_gap), act_btn_w, act_btn_h];
        btn_stop.Position     = [act_btn_x, act_btn_y_top - 4*(act_btn_h + act_btn_gap), act_btn_w, act_btn_h];
        btn_export.Position   = [act_btn_x, act_btn_y_top - 5*(act_btn_h + act_btn_gap), act_btn_w, act_btn_h];
        btn_modelshot.Position = [act_btn_x, act_btn_y_top - 6*(act_btn_h + act_btn_gap), act_btn_w, act_btn_h];

        % Reflow plot axes on the right.
        right_gap = 18;
        outer_margin = 18;
        right_x = pnl.Position(1) + pnl.Position(3) + right_gap;
        avail_w = max(500, fig_w - right_x - outer_margin);
        avail_h = max(420, fig_h - (2 * outer_margin));

        % Analysis buttons row in right workspace (kept above plots).
        btn_w = 110;
        btn_h = 24;
        btn_gap = 8;
        row_w = (3 * btn_w) + (2 * btn_gap);
        row_x = max(right_x, right_x + floor((avail_w - row_w) / 2));
        row_y = max(outer_margin + 8, fig_h - outer_margin - btn_h - 6);
        btn_poincare.Position = [row_x, row_y, btn_w, btn_h];
        btn_specgram.Position = [row_x + btn_w + btn_gap, row_y, btn_w, btn_h];
        btn_returnmap.Position = [row_x + 2 * (btn_w + btn_gap), row_y, btn_w, btn_h];

        % Keep all plots below the analysis controls with consistent spacing.
        spec_gap = 18;
        spec_h = max(180, round(avail_h * 0.36));
        spec_w = avail_w;
        spec_x = right_x;
        spec_y = outer_margin;

        top_area_y = spec_y + spec_h + spec_gap;
        top_area_h = max(180, row_y - 14 - top_area_y);
        top_gap = 22;
        top_w = floor((avail_w - top_gap) / 2);

        ax_phase.Position = [right_x, top_area_y, top_w, top_area_h];
        ax_forcing.Position = [right_x + top_w + top_gap, top_area_y, top_w, top_area_h];
        ax_spectrum.Position = [spec_x, spec_y, spec_w, spec_h];
    end

    % ============================================================
    % PARAMETER COMPUTATION
    % ============================================================
    function [d_val, w0_val, beta_val, omega_val, f_over_omega_sq] = compute_params()
        R  = Rbase_edit.Value;
        C  = Cbase_edit.Value;
        R1 = R1coef_edit.Value;
        R2 = R2coef_edit.Value;
        R3 = R3coef_edit.Value;
        omega_val = omega_edit.Value;
        if any([R, C, R1, R2, R3, omega_val] <= 0)
            error('R, C, R1, R2, R3, and \Omega must all be positive.');
        end
        d_val    = R / R1;
        w0_val   = sqrt(R / R2);
        beta_val = R / R3;
        f_over_omega_sq = f_edit.Value / (omega_val^2);
    end

    function update_computed_params()
        try
            [d_val, w0_val, beta_val, ~, f_over_omega_sq] = compute_params();
            d_val_lbl.Text  = sprintf('%.6g', d_val);
            w0_val_lbl.Text = sprintf('%.6g', w0_val);
            b_val_lbl.Text  = sprintf('%.6g', beta_val);
            f_over_omega_sq_lbl.Text = sprintf('%.6g', f_over_omega_sq);
        catch ME
            d_val_lbl.Text  = 'Invalid';
            w0_val_lbl.Text = 'Invalid';
            b_val_lbl.Text  = 'Invalid';
            f_over_omega_sq_lbl.Text = 'Invalid';
            uialert(fig, ME.message, 'Parameter Error');
        end
    end

    function update_build_mode_ui()
        hil_mode = is_hil_mode();
        scope_mode = is_scope_remote_mode();

        dac_enable_chk.Enable = matlab.lang.OnOffSwitchState(hil_mode);
        phase_output_chk.Enable = matlab.lang.OnOffSwitchState(hil_mode);
        dac_pin_dropdown.Enable = matlab.lang.OnOffSwitchState(hil_mode);
        dac_sample_time_edit.Enable = matlab.lang.OnOffSwitchState(hil_mode);
        amp_mult_edit.Enable = matlab.lang.OnOffSwitchState(hil_mode);
        dac_signal_min_edit.Enable = matlab.lang.OnOffSwitchState(hil_mode);
        dac_signal_max_edit.Enable = matlab.lang.OnOffSwitchState(hil_mode);
        smooth_output_chk.Enable = matlab.lang.OnOffSwitchState(hil_mode);
        filter_tau_edit.Enable = matlab.lang.OnOffSwitchState(hil_mode && smooth_output_chk.Value);
        self_test_chk.Enable = matlab.lang.OnOffSwitchState(hil_mode);
        self_test_wave_dropdown.Enable = matlab.lang.OnOffSwitchState(hil_mode && self_test_chk.Value);

        if hil_mode && ~dac_enable_chk.Value
            dac_enable_chk.Value = true;
            phase_output_chk.Value = true;
        elseif ~hil_mode
            dac_enable_chk.Value = false;
        end

        if hil_mode
            mode_help_lbl.Text = ['Arduino Due mode simulates on the PC, then uploads a direct waveform-player sketch to the board.' newline ...
                'The deployed waveform runs continuously until the Due is reset or re-deployed.' newline ...
                char(get_hil_output_guidance())];
            dac_color = [0.10 0.10 0.10];
            btn_run.Text = 'Deploy';
        elseif scope_mode
            mode_help_lbl.Text = 'USB scope control only. This mode can control or read the scope, but it does not output a physical waveform.';
            dac_color = [0.55 0.55 0.55];
            btn_run.Text = 'Simulate';
        else
            mode_help_lbl.Text = 'Builds the simulation model only, with no Arduino DAC output branch.';
            dac_color = [0.55 0.55 0.55];
            btn_run.Text = 'Simulate';
        end

        set([dac_section_lbl, dac_pin_lbl, dac_sample_lbl, filter_tau_lbl, self_test_wave_lbl, amp_mult_lbl, dac_min_lbl, dac_max_lbl], ...
            'FontColor', dac_color);
    end

    function tf = is_hil_mode()
        tf = strcmp(build_mode_dropdown.Value, 'Deploy to Arduino Due');
    end

    function tf = is_hardware_self_test_mode()
        tf = is_hil_mode() && dac_enable_chk.Value && self_test_chk.Value;
    end

    function view_name = get_hil_output_view()
        view_name = string(dac_pin_dropdown.Value);
    end

    function view_idx = get_hil_output_view_index()
        switch get_hil_output_view()
            case "Limit Cycle (x-y)"
                view_idx = 0;
            case "State vs Forcing"
                view_idx = 1;
            otherwise
                view_idx = 2;
        end
    end

    function guidance = get_hil_output_guidance()
        switch get_hil_output_view()
            case "Limit Cycle (x-y)"
                guidance = 'Physical output: DAC0 = x(t), DAC1 = y(t). Use scope XY mode for the phase portrait.';
            case "State vs Forcing"
                guidance = 'Physical output: DAC0 = x(t), DAC1 = h cos(\omega_p t). Use normal scope mode to compare state and excitation.';
            otherwise
                guidance = 'Physical output: DAC0 = x(t). Use scope FFT on CH1 for the power spectrum of x. DAC1 is 0 V.';
        end
    end

    function apply_clean_output_preset()
        dac_enable_chk.Value = true;
        phase_output_chk.Value = true;
        self_test_chk.Value = false;
        dac_pin_dropdown.Value = 'Limit Cycle (x-y)';

        % DSO-safe defaults:
        % Use no smoothing, a fast sample time, tighter logical range,
        % and nontrivial initial conditions so the XY trace is easier to see.
        smooth_output_chk.Value = false;
        dac_sample_time_edit.Value = 1e-3;
        filter_tau_edit.Value = 1e-3;
        amp_mult_edit.Value = 4.0;
        dac_signal_min_edit.Value = -0.5;
        dac_signal_max_edit.Value = 0.5;
        t_edit.Value = max(t_edit.Value, 20);
        x0_edit.Value = -1.0;
        y0_edit.Value = 1.0;

        update_build_mode_ui();

        uialert(fig, ['Clean Output preset applied for the DSO.' newline ...
            'Sample Time = 1e-3 s, smoothing = off, physical DAC amplitude multiplier = 4x, DAC logical range = [-0.5, 0.5].' newline ...
            'Initial conditions set to x0 = -1, y0 = 1.' newline ...
            'Use CH1 = DAC0 and CH2 = DAC1 in XY mode.'], ...
            'Preset Applied');
    end

    function apply_dac_debug_preset()
        build_mode_dropdown.Value = 'Deploy to Arduino Due';
        dac_enable_chk.Value = true;
        phase_output_chk.Value = true;
        self_test_chk.Value = true;
        self_test_wave_dropdown.Value = 'Square';
        smooth_output_chk.Value = false;
        dac_sample_time_edit.Value = 1e-3;
        filter_tau_edit.Value = 1e-3;
        amp_mult_edit.Value = 8.0;
        dac_signal_min_edit.Value = -0.5;
        dac_signal_max_edit.Value = 0.5;
        update_build_mode_ui();

        uialert(fig, ['DAC debug preset applied.' newline ...
            'Self-test = Square, Amp x = 8, smoothing = off.' newline ...
            'Check DAC0 on CH1 in normal time mode first.'], ...
            'Preset Applied');
    end

    function tf = is_scope_remote_mode()
        tf = strcmp(build_mode_dropdown.Value, 'USB Scope Control Only');
    end

    function mode_name = get_selected_build_mode()
        mode_name = string(build_mode_dropdown.Value);
    end

    % ============================================================
    % BUILD MODEL
    % ============================================================
    function build_model()
        warning('off', 'Simulink:Commands:NewSystemTemplateNotFound');
        warning('off', 'Simulink:Commands:NewSystemFailedToUseDefaultTemplate');

        update_computed_params();
        if is_hil_mode()
            validate_arduino_due_settings();
        end
        bdclose('all');
        evalin('base', 'clear x_data y_data t_data forcing_data selected_output_data');
        latest_sim_results = [];

        % IMPORTANT FIX:
        % exist(...,'file') for a normal file returns 2, not 4.
        if exist([model_name '.slx'], 'file') == 2
            delete([model_name '.slx']);
        end

        new_system(model_name);
        open_system(model_name);

        configure_model_solver_for_selected_mode();
        configure_model_callbacks_for_selected_mode();
        if is_hil_mode()
            set_param(model_name, 'StopTime', 'inf');
        else
            set_param(model_name, 'StopTime', num2str(t_edit.Value));
        end
        set_param(model_name, 'SignalLogging', 'off');
        if is_hil_mode()
            configure_arduino_due_target();
        end

        x0p = 70; y0p = 120; dx = 120; dy = 90; bw = 40; bh = 40;

        % ---------------- Simulink side ----------------
        add_block('simulink/Sources/Clock', [model_name '/Clock'], ...
            'Position', [x0p, y0p+3*dy, x0p+bw, y0p+3*dy+bh]);
        add_block('simulink/User-Defined Functions/Fcn', [model_name '/ForcingFcn'], ...
            'Position', [x0p+1.2*dx, y0p+3*dy, x0p+1.2*dx+170, y0p+3*dy+40], ...
            'Expr', '0');
        add_block('simulink/Signal Routing/Mux', [model_name '/Mux'], ...
            'Position', [x0p+3*dx, y0p+2.7*dy, x0p+3*dx+10, y0p+2.7*dy+90], ...
            'Inputs', '3');
        add_block('simulink/User-Defined Functions/Fcn', [model_name '/AccelFcn'], ...
            'Position', [x0p+4*dx, y0p+2.7*dy, x0p+4*dx+250, y0p+2.7*dy+40], ...
            'Expr', '0');
        add_block('simulink/Math Operations/Gain', [model_name '/IxGain'], ...
            'Position', [x0p+4*dx, y0p+1.4*dy, x0p+4*dx+60, y0p+1.4*dy+bh], ...
            'Gain', num2str(Cbase_edit.Value));
        add_block('simulink/Math Operations/Gain', [model_name '/IyGain'], ...
            'Position', [x0p+6.3*dx, y0p+2.7*dy, x0p+6.3*dx+60, y0p+2.7*dy+bh], ...
            'Gain', num2str(Cbase_edit.Value));

        % Group each RC branch into a subsystem (journal-ready screenshots).
        add_block('simulink/Ports & Subsystems/Subsystem', [model_name '/RC_X'], ...
            'Position', [x0p+5.0*dx, y0p+0.15*dy, x0p+8.2*dx, y0p+0.15*dy+1.0*dy]);
        add_block('simulink/Ports & Subsystems/Subsystem', [model_name '/RC_Y'], ...
            'Position', [x0p+5.0*dx, y0p+1.85*dy, x0p+8.2*dx, y0p+1.85*dy+1.0*dy]);
        populate_rc_subsystem([model_name '/RC_X'], Cbase_edit.Value, Rx_edit.Value, x0_edit.Value, 'X');
        populate_rc_subsystem([model_name '/RC_Y'], Cbase_edit.Value, Ry_edit.Value, y0_edit.Value, 'Y');

        % BREAK ALGEBRAIC LOOPS WITHOUT STIFFNESS (Using Memory Blocks)
        add_block('simulink/Discrete/Memory', [model_name '/Mem_x'], ...
            'Position', [x0p+8.5*dx, y0p+0.3*dy, x0p+9.2*dx, y0p+0.3*dy+bh], ...
            'InitialCondition', num2str(x0_edit.Value));
        add_block('simulink/Discrete/Memory', [model_name '/Mem_y'], ...
            'Position', [x0p+8.5*dx, y0p+2.0*dy, x0p+9.2*dx, y0p+2.0*dy+bh], ...
            'InitialCondition', num2str(y0_edit.Value));

        add_block('simulink/Sinks/To Workspace', [model_name '/Out_x'], ...
            'Position', [x0p+9.6*dx, y0p+0.5*dy, x0p+9.6*dx+bw, y0p+0.5*dy+bh], ...
            'VariableName', 'x_data', 'SaveFormat', 'Array');
        add_block('simulink/Sinks/To Workspace', [model_name '/Out_y'], ...
            'Position', [x0p+9.6*dx, y0p+2.0*dy, x0p+9.6*dx+bw, y0p+2.0*dy+bh], ...
            'VariableName', 'y_data', 'SaveFormat', 'Array');
        add_block('simulink/Sinks/To Workspace', [model_name '/Out_forcing'], ...
            'Position', [x0p+3.0*dx, y0p+3.0*dy, x0p+3.0*dx+bw, y0p+3.0*dy+bh], ...
            'VariableName', 'forcing_data', 'SaveFormat', 'Array');
        add_block('simulink/Sinks/To Workspace', [model_name '/Out_t'], ...
            'Position', [x0p+3.8*dx, y0p+3*dy, x0p+3.8*dx+bw, y0p+3*dy+bh], ...
            'VariableName', 't_data', 'SaveFormat', 'Array');

        add_block('simulink/Signal Routing/Mux', [model_name '/ScopeMux'], ...
            'Position', [x0p+9.4*dx, y0p+1.0*dy, x0p+9.4*dx+10, y0p+1.0*dy+80], ...
            'Inputs', '2');
        add_block('simulink/Sinks/Scope', [model_name '/StateScope'], ...
            'Position', [x0p+9.8*dx, y0p+1.0*dy, x0p+9.8*dx+bw, y0p+1.0*dy+bh]);
        add_block('simulink/Signal Routing/Manual Switch', [model_name '/StateSignalSwitch'], ...
            'Position', [x0p+10.3*dx, y0p+0.95*dy, x0p+10.3*dx+30, y0p+2.25*dy]);
        add_block('simulink/Signal Routing/Manual Switch', [model_name '/OscilloscopeSourceSwitch'], ...
            'Position', [x0p+11.0*dx, y0p+1.65*dy, x0p+11.0*dx+30, y0p+3.05*dy]);
        add_block('simulink/Sinks/Scope', [model_name '/SelectedOutputScope'], ...
            'Position', [x0p+11.5*dx, y0p+2.0*dy, x0p+11.5*dx+110, y0p+2.0*dy+60]);
        add_block('simulink/Sinks/To Workspace', [model_name '/Out_selected'], ...
            'Position', [x0p+11.5*dx, y0p+2.8*dy, x0p+11.5*dx+70, y0p+2.8*dy+bh], ...
            'VariableName', 'selected_output_data', 'SaveFormat', 'Array');

        if is_hil_mode() && dac_enable_chk.Value
            add_arduino_due_output_branch();
            if phase_output_chk.Value
                add_arduino_due_phase_branch();
            end
        end

        % Converter units are set inside each RC subsystem.
        try, set_param([model_name '/Clock'], 'AttributesFormatString', 'Input: simulation time t'); catch, end
        try, set_param([model_name '/AccelFcn'], 'AttributesFormatString', 'Output: y_dot'); catch, end
        try, set_param([model_name '/Mem_x'], 'AttributesFormatString', 'State x(t)'); catch, end
        try, set_param([model_name '/Mem_y'], 'AttributesFormatString', 'State y(t)'); catch, end
        try, set_param([model_name '/ForcingFcn'], 'AttributesFormatString', 'h cos(w_p t)'); catch, end
        try, set_param([model_name '/StateSignalSwitch'], 'AttributesFormatString', 'Up: x(t), Down: y(t)'); catch, end
        try, set_param([model_name '/OscilloscopeSourceSwitch'], 'AttributesFormatString', 'Up: selected state, Down: forcing'); catch, end
        try, set_param([model_name '/SelectedOutputScope'], 'AttributesFormatString', 'Simulink preview only: selected single-channel view'); catch, end
        add_model_annotations();

        % ---------------- Simulink wiring (With Memory Blocks) ----------------
        % Wire RC subsystem outputs to Memory blocks
        add_line(model_name, 'RC_X/1', 'Mem_x/1', 'autorouting', 'on');
        add_line(model_name, 'RC_Y/1', 'Mem_y/1', 'autorouting', 'on');

        % Wire Memory blocks to Math
        add_line(model_name, 'Mem_x/1', 'Mux/1', 'autorouting', 'on');
        add_line(model_name, 'Mem_y/1', 'Mux/2', 'autorouting', 'on');
        add_line(model_name, 'Clock/1', 'Mux/3', 'autorouting', 'on');
        add_line(model_name, 'Clock/1', 'ForcingFcn/1', 'autorouting', 'on');
        add_line(model_name, 'Mux/1', 'AccelFcn/1', 'autorouting', 'on');
        add_line(model_name, 'Mem_y/1', 'IxGain/1', 'autorouting', 'on');
        add_line(model_name, 'AccelFcn/1', 'IyGain/1', 'autorouting', 'on');
        add_line(model_name, 'IxGain/1', 'RC_X/1', 'autorouting', 'on');
        add_line(model_name, 'IyGain/1', 'RC_Y/1', 'autorouting', 'on');

        % Wire Memory blocks to Scopes
        add_line(model_name, 'Mem_x/1', 'Out_x/1', 'autorouting', 'on');
        add_line(model_name, 'Mem_y/1', 'Out_y/1', 'autorouting', 'on');
        add_line(model_name, 'ForcingFcn/1', 'Out_forcing/1', 'autorouting', 'on');
        add_line(model_name, 'Clock/1', 'Out_t/1', 'autorouting', 'on');
        add_line(model_name, 'Mem_x/1', 'ScopeMux/1', 'autorouting', 'on');
        add_line(model_name, 'Mem_y/1', 'ScopeMux/2', 'autorouting', 'on');
        add_line(model_name, 'ScopeMux/1', 'StateScope/1', 'autorouting', 'on');
        add_line(model_name, 'Mem_x/1', 'StateSignalSwitch/1', 'autorouting', 'on');
        add_line(model_name, 'Mem_y/1', 'StateSignalSwitch/2', 'autorouting', 'on');
        add_line(model_name, 'StateSignalSwitch/1', 'OscilloscopeSourceSwitch/1', 'autorouting', 'on');
        add_line(model_name, 'ForcingFcn/1', 'OscilloscopeSourceSwitch/2', 'autorouting', 'on');
        add_line(model_name, 'OscilloscopeSourceSwitch/1', 'SelectedOutputScope/1', 'autorouting', 'on');
        add_line(model_name, 'OscilloscopeSourceSwitch/1', 'Out_selected/1', 'autorouting', 'on');

        % Physical Simscape wiring is contained inside RC_X/RC_Y subsystems.

        apply_requested_start_point(x0_edit.Value, y0_edit.Value);

        style_model_inkscape();
        try
            save_system(model_name);
        catch
        end

        if is_hil_mode()
            if is_hardware_self_test_mode()
                success_msg = ['Simscape model built successfully.' newline ...
                    'Deploy mode will upload a direct Arduino DAC self-test sketch to the Due.'];
            else
                success_msg = ['Simscape RC model built successfully.' newline ...
                    'Simulink preview remains for on-screen viewing.' newline ...
                    'Deploy mode now uses host-simulated waveform playback on the Arduino Due.' newline ...
                    char(get_hil_output_guidance())];
            end
        elseif is_scope_remote_mode()
            success_msg = ['Simscape RC model built in USB Scope Control Only mode.' newline ...
                'No DAC output branch was added.'];
        else
            success_msg = 'Simscape RC model built successfully in Simulink-only mode.';
        end

        last_built_mode = get_selected_build_mode();
        uialert(fig, success_msg, 'Success');
    end

    % ============================================================
    % RUN ANALYSIS
    % ============================================================
    function run_analysis()
        if run_in_progress
            return;
        end

        try
            ensure_model_ready_for_selected_mode();
        catch ME
            uialert(fig, ME.message, 'Build Error');
            return;
        end

        evalin('base', 'clear x_data y_data t_data forcing_data selected_output_data');
        [d_val, w0_val, beta_val, omega_val, f_over_omega_sq] = compute_params();
        x0_val = x0_edit.Value;
        y0_val = y0_edit.Value;
        update_computed_params();

        core = [model_name '/ODE_Core'];
        if bdIsLoaded(model_name) && ~isempty(find_system(model_name,'SearchDepth',1,'Name','ODE_Core'))
            pfx = core;
        else
            pfx = model_name;  % fallback: blocks at top level (old build)
        end
        try, set_param([pfx '/RC_X/C'],    'c', num2str(Cbase_edit.Value)); catch
             set_param([model_name '/RC_X/C'],'c', num2str(Cbase_edit.Value)); end
        try, set_param([pfx '/RC_Y/C'],    'c', num2str(Cbase_edit.Value)); catch
             set_param([model_name '/RC_Y/C'],'c', num2str(Cbase_edit.Value)); end
        try, set_param([pfx '/RC_X/Rleak'],'R', num2str(Rx_edit.Value)); catch
             set_param([model_name '/RC_X/Rleak'],'R', num2str(Rx_edit.Value)); end
        try, set_param([pfx '/RC_Y/Rleak'],'R', num2str(Ry_edit.Value)); catch
             set_param([model_name '/RC_Y/Rleak'],'R', num2str(Ry_edit.Value)); end
        try, set_param([pfx '/IxGain'],    'Gain', num2str(Cbase_edit.Value)); catch
             set_param([model_name '/IxGain'],'Gain', num2str(Cbase_edit.Value)); end
        try, set_param([pfx '/IyGain'],    'Gain', num2str(Cbase_edit.Value)); catch
             set_param([model_name '/IyGain'],'Gain', num2str(Cbase_edit.Value)); end

        if block_exists('DAC_ZOH')
            set_param([model_name '/DAC_ZOH'], 'SampleTime', num2str(get_effective_hil_sample_time()));
            set_param([model_name '/DAC_CodeGain'], 'Gain', ...
                num2str(4095 / (dac_signal_max_edit.Value - dac_signal_min_edit.Value)));
            set_param([model_name '/DAC_CodeBias'], 'Bias', ...
                num2str(-dac_signal_min_edit.Value * 4095 / (dac_signal_max_edit.Value - dac_signal_min_edit.Value)));
        end

        if block_exists('DAC_Y_ZOH')
            set_param([model_name '/DAC_Y_ZOH'], 'SampleTime', num2str(get_effective_hil_sample_time()));
            set_param([model_name '/DAC_Y_CodeGain'], 'Gain', ...
                num2str(4095 / (dac_signal_max_edit.Value - dac_signal_min_edit.Value)));
            set_param([model_name '/DAC_Y_CodeBias'], 'Bias', ...
                num2str(-dac_signal_min_edit.Value * 4095 / (dac_signal_max_edit.Value - dac_signal_min_edit.Value)));
        end

        % Updated forcing law: u(1)=x, u(2)=y, u(3)=t
        eq_str = sprintf('-(%g)*(u(1)^2 - 1) - (%g)*(1 + (%g)*cos((%g)*u(3)))*u(1) - (%g)*(u(1)^3) + (%g)*cos((%g)*u(3))', ...
            d_val, w0_val^2, h_edit.Value, wp_edit.Value, beta_val, f_edit.Value, omega_val);
        try, set_param([pfx '/AccelFcn'],   'Expr', eq_str); catch
             set_param([model_name '/AccelFcn'],'Expr', eq_str); end
        try, set_param([pfx '/ForcingFcn'], 'Expr', sprintf('(%g)*cos((%g)*u)', h_edit.Value, wp_edit.Value)); catch
             set_param([model_name '/ForcingFcn'],'Expr', sprintf('(%g)*cos((%g)*u)', h_edit.Value, wp_edit.Value)); end

        apply_requested_start_point(x0_val, y0_val);

        try
            stop_requested = false;
            set_run_ui_state(true);
            if is_hil_mode()
                run_hil_on_due();
            else
                set_param(model_name, 'SimulationMode', 'normal');
                set_param(model_name, 'Solver', 'ode15s');
                set_param(model_name, 'MaxStep', '0.01');
                set_param(model_name, 'RelTol', '1e-4');
                set_param(model_name, 'StopTime', num2str(t_edit.Value));
                set_param(model_name, 'SimulationCommand', 'update');
                sim_out = sim(model_name, ...
                    'StopTime', num2str(t_edit.Value), ...
                    'ReturnWorkspaceOutputs', 'on');
                latest_sim_results = struct( ...
                    't', extract_sim_output(sim_out, 't_data'), ...
                    'x', extract_sim_output(sim_out, 'x_data'), ...
                    'y', extract_sim_output(sim_out, 'y_data'), ...
                    'forcing', extract_sim_output(sim_out, 'forcing_data'));
                finalize_run();
            end
        catch ME
            cleanup_run_timer();
            set_run_ui_state(false);
            uialert(fig, sprintf('Simulation failed to start.\n\nError: %s', ME.message), 'Simulation Error');
            return;
        end
    end

    % ============================================================
    % HELPERS
    % ============================================================
    function ph = get_ports(blk)
        ph = get_param([model_name '/' blk], 'PortHandles');
    end

    function stop_simulation()
        stop_requested = true;
        if is_hil_mode()
            cleanup_after_run(false);
            uialert(fig, ['The Arduino Due path is running as a deployed standalone program.' newline ...
                'Use the Due reset button or deploy again to stop or change the waveform.'], ...
                'Stop Info');
            return;
        end

        if ~bdIsLoaded(model_name)
            set_run_ui_state(false);
            return;
        end

        try
            sim_status = get_param(model_name, 'SimulationStatus');
        catch
            sim_status = 'stopped';
        end

        if ~strcmpi(sim_status, 'stopped')
            try
                set_param(model_name, 'SimulationCommand', 'stop');
            catch
            end
        end

        if strcmpi(sim_status, 'external')
            cleanup_after_run(false);
        end
    end

    function ensure_model_ready_for_selected_mode()
        needs_build = ~bdIsLoaded(model_name);
        selected_mode = get_selected_build_mode();

        if ~needs_build && strlength(last_built_mode) == 0
            needs_build = true;
        end

        if ~needs_build
            has_dac_branch = block_exists('Arduino_Due_DAC');
            if is_hil_mode() ~= has_dac_branch
                needs_build = true;
            end
        end

        if ~needs_build && selected_mode ~= last_built_mode
            needs_build = true;
        end

        if needs_build
            build_model();
        end
    end

    function poll_simulation_status()
        try
            if ~bdIsLoaded(model_name)
                cleanup_after_run(false);
                return;
            end

            sim_status = get_param(model_name, 'SimulationStatus');
            if strcmpi(sim_status, 'stopped')
                finalize_run();
            end
        catch
            cleanup_after_run(false);
        end
    end

    function finalize_run()
        cleanup_run_timer();
        set_run_ui_state(false);

        if is_hil_mode()
            if ~isempty(latest_sim_results)
                forcing_signal = latest_sim_results.forcing;
                if isempty(forcing_signal)
                    forcing_signal = h_edit.Value * cos(wp_edit.Value * latest_sim_results.t);
                end
                update_result_plots(latest_sim_results.t, latest_sim_results.x, latest_sim_results.y, ...
                    forcing_signal, x0_edit.Value, y0_edit.Value);
            end
            if ~stop_requested
                if is_hardware_self_test_mode()
                    uialert(fig, ['Arduino Due direct self-test deployed.' newline ...
                        'DAC0 carries the selected test wave and DAC1 carries its paired reference wave.'], ...
                        'Deploy Complete');
                else
                    uialert(fig, ['Arduino Due waveform player deployed.' newline ...
                        'The board is replaying host-simulated data from a direct Arduino sketch.' newline ...
                        char(get_hil_output_guidance())], ...
                    'Deploy Complete');
                end
            end
            stop_requested = false;
            latest_sim_results = [];
            return;
        end

        if ~isempty(latest_sim_results)
            t = latest_sim_results.t;
            x = latest_sim_results.x;
            y = latest_sim_results.y;
        else
            t = safe_extract_base('t_data');
            x = safe_extract_base('x_data');
            y = safe_extract_base('y_data');
        end

        if isempty(t) || isempty(x) || isempty(y)
            if ~stop_requested
                uialert(fig, 'Simulation finished but returned empty data.', 'Simulation Error');
            end
            stop_requested = false;
            return;
        end

        [d_val, w0_val, beta_val, omega_val, f_over_omega_sq] = compute_params();
        x0_val = x0_edit.Value;
        y0_val = y0_edit.Value;
        forcing_signal = h_edit.Value * cos(wp_edit.Value * t);

        fprintf('\nComputed parameters:\n');
        fprintf('d    = %.6f\n', d_val);
        fprintf('w0   = %.6f\n', w0_val);
        fprintf('beta = %.6f\n', beta_val);
        fprintf('Omega= %.6f\n', omega_val);
        fprintf('f/Omega^2 = %.6f\n', f_over_omega_sq);
        fprintf('Requested initial point: x0 = %.6f, y0 = %.6f\n', x0_val, y0_val);
        fprintf('Actual first sample:     x(1)= %.6f, y(1)= %.6f\n', x(1), y(1));

        update_result_plots(t, x, y, forcing_signal, x0_val, y0_val);

        if is_scope_remote_mode()
            uialert(fig, ['USB scope control complete.' newline ...
                'No physical waveform was sent to the oscilloscope input.'], ...
                'USB Scope Control Only');
        end
        stop_requested = false;
        latest_sim_results = [];
    end

    function run_hil_on_due()
        cleanup_run_timer();
        if is_hardware_self_test_mode()
            [dac0_signal, dac1_signal, playback_dt] = build_self_test_playback();
            latest_sim_results = [];
        else
            [t_play, x_play, y_play, forcing_play] = simulate_waveforms_for_due();
            latest_sim_results = struct( ...
                't', t_play, ...
                'x', x_play, ...
                'y', y_play, ...
                'forcing', forcing_play);
            [dac0_signal, dac1_signal, playback_dt] = build_due_playback_signals(t_play, x_play, y_play, forcing_play);
        end

        dac0_codes = convert_signal_to_dac_codes(dac0_signal);
        dac1_codes = convert_signal_to_dac_codes(dac1_signal);
        upload_due_waveform_player(dac0_codes, dac1_codes, playback_dt);
        finalize_run();
    end

    function [t_play, x_play, y_play, forcing_play] = simulate_waveforms_for_due()
        set_param(model_name, 'SimulationMode', 'normal');
        set_param(model_name, 'Solver', 'ode15s');
        set_param(model_name, 'MaxStep', '0.01');
        set_param(model_name, 'RelTol', '1e-4');
        set_param(model_name, 'StopTime', num2str(t_edit.Value));
        set_param(model_name, 'SimulationCommand', 'update');
        sim_out = sim(model_name, ...
            'StopTime', num2str(t_edit.Value), ...
            'ReturnWorkspaceOutputs', 'on');

        t_play = extract_sim_output(sim_out, 't_data');
        x_play = extract_sim_output(sim_out, 'x_data');
        y_play = extract_sim_output(sim_out, 'y_data');
        forcing_play = extract_sim_output(sim_out, 'forcing_data');

        if isempty(t_play) || isempty(x_play) || isempty(y_play)
            error('Deploy simulation finished but did not return waveform data for Arduino playback.');
        end
        if isempty(forcing_play)
            forcing_play = h_edit.Value * cos(wp_edit.Value * t_play);
        end
    end

    function [dac0_signal, dac1_signal, playback_dt] = build_due_playback_signals(t_in, x_in, y_in, forcing_in)
        max_points = 4096;
        [t_resampled, x_resampled] = resample_playback_series(t_in, x_in, max_points);
        [~, y_resampled] = resample_playback_series(t_in, y_in, max_points);
        [~, forcing_resampled] = resample_playback_series(t_in, forcing_in, max_points);

        dac0_signal = x_resampled;
        switch get_hil_output_view()
            case "Limit Cycle (x-y)"
                dac1_signal = y_resampled;
            case "State vs Forcing"
                dac1_signal = forcing_resampled;
            otherwise
                dac1_signal = zeros(size(dac0_signal));
        end

        if numel(t_resampled) >= 2
            playback_dt = mean(diff(t_resampled));
        else
            playback_dt = get_effective_hil_sample_time();
        end
    end

    function [signal0, signal1, playback_dt] = build_self_test_playback()
        playback_dt = get_effective_hil_sample_time();
        t_end = 8.0;
        t_vec = (0:playback_dt:t_end).';
        amplitude = 0.45 * (dac_signal_max_edit.Value - dac_signal_min_edit.Value);
        if amplitude <= 0
            amplitude = 1.0;
        end

        switch char(self_test_wave_dropdown.Value)
            case 'Square'
                signal0 = amplitude * sign(sin(2*pi*0.5*t_vec));
                signal1 = -signal0;
            case 'Ramp'
                phase = mod(t_vec / 4.0, 1.0);
                signal0 = amplitude * (2 * phase - 1);
                signal1 = -signal0;
            otherwise
                signal0 = amplitude * sin(2*pi*0.5*t_vec);
                signal1 = amplitude * cos(2*pi*0.5*t_vec);
        end
    end

    function [t_resampled, y_resampled] = resample_playback_series(t_in, y_in, max_points)
        t_in = t_in(:);
        y_in = y_in(:);
        if numel(t_in) ~= numel(y_in)
            error('Playback data sizes do not match.');
        end

        if numel(t_in) <= max_points
            t_resampled = t_in;
            y_resampled = y_in;
            return;
        end

        t_resampled = linspace(t_in(1), t_in(end), max_points).';
        y_resampled = interp1(t_in, y_in, t_resampled, 'linear');
    end

    function dac_codes = convert_signal_to_dac_codes(signal_in)
        scaled_signal = amp_mult_edit.Value * signal_in(:);
        signal_span = dac_signal_max_edit.Value - dac_signal_min_edit.Value;
        dac_codes = round((scaled_signal - dac_signal_min_edit.Value) * 4095 / signal_span);
        dac_codes = max(0, min(4095, dac_codes));
        dac_codes = uint16(dac_codes);
    end

    function upload_due_waveform_player(dac0_codes, dac1_codes, playback_dt)
        cli_path = get_arduino_cli_path();
        sketch_dir = fullfile(pwd, 'generated_due_wave_player');
        if ~exist(sketch_dir, 'dir')
            mkdir(sketch_dir);
        end

        ino_path = fullfile(sketch_dir, 'generated_due_wave_player.ino');
        write_due_wave_player_sketch(ino_path, dac0_codes, dac1_codes, playback_dt);

        run_cli_or_fail(sprintf('"%s" core install arduino:sam', cli_path), ...
            'Unable to prepare Arduino Due toolchain for direct waveform deployment.');
        run_cli_or_fail(sprintf('"%s" compile --fqbn arduino:sam:arduino_due_x_dbg "%s"', cli_path, sketch_dir), ...
            'Unable to compile the Arduino Due waveform player sketch.');
        run_cli_or_fail(sprintf('"%s" upload -p %s --fqbn arduino:sam:arduino_due_x_dbg "%s"', ...
            cli_path, char(detect_arduino_due_com_port()), sketch_dir), ...
            'Unable to upload the Arduino Due waveform player sketch.');
    end

    function write_due_wave_player_sketch(ino_path, dac0_codes, dac1_codes, playback_dt)
        fid = fopen(ino_path, 'w');
        if fid < 0
            error('Unable to create Arduino Due waveform player sketch.');
        end
        cleaner = onCleanup(@() fclose(fid));

        fprintf(fid, "#include <Arduino.h>\n\n");
        fprintf(fid, "const uint16_t ch0_data[%d] = {%s};\n", numel(dac0_codes), join_uint16_array(dac0_codes));
        fprintf(fid, "const uint16_t ch1_data[%d] = {%s};\n\n", numel(dac1_codes), join_uint16_array(dac1_codes));
        fprintf(fid, "const size_t kSampleCount = %d;\n", numel(dac0_codes));
        fprintf(fid, "const uint32_t kIntervalMicros = %u;\n\n", max(100, round(playback_dt * 1e6)));
        fprintf(fid, "void setup() {\n");
        fprintf(fid, "  analogWriteResolution(12);\n");
        fprintf(fid, "}\n\n");
        fprintf(fid, "void loop() {\n");
        fprintf(fid, "  static size_t idx = 0;\n");
        fprintf(fid, "  static uint32_t nextTick = 0;\n");
        fprintf(fid, "  const uint32_t now = micros();\n");
        fprintf(fid, "  if ((int32_t)(now - nextTick) >= 0) {\n");
        fprintf(fid, "    analogWrite(DAC0, ch0_data[idx]);\n");
        fprintf(fid, "    analogWrite(DAC1, ch1_data[idx]);\n");
        fprintf(fid, "    idx = (idx + 1) %% kSampleCount;\n");
        fprintf(fid, "    nextTick = now + kIntervalMicros;\n");
        fprintf(fid, "  }\n");
        fprintf(fid, "}\n");
    end

    function joined = join_uint16_array(values)
        joined = strjoin(arrayfun(@(v) sprintf('%u', v), values(:).', 'UniformOutput', false), ',');
    end

    function cli_path = get_arduino_cli_path()
        cli_candidates = { ...
            'C:\ProgramData\MATLAB\SupportPackages\R2025b\aCLI\arduino-cli.exe', ...
            'arduino-cli.exe'};

        cli_path = '';
        for idx = 1:numel(cli_candidates)
            candidate = cli_candidates{idx};
            if exist(candidate, 'file') == 2 || ~isempty(which(candidate))
                cli_path = candidate;
                return;
            end
        end
        error('arduino-cli.exe was not found. The direct Arduino deployment path cannot continue.');
    end

    function run_cli_or_fail(command_str, failure_message)
        [status, cmd_out] = system(command_str);
        if status ~= 0
            error('%s\n\n%s', failure_message, strtrim(cmd_out));
        end
    end


    function update_result_plots(t, x, y, forcing_signal, x0_val, y0_val)
        last_plot_data = struct('t', t(:), 'x', x(:), 'y', y(:), 'forcing', forcing_signal(:));

        cla(ax_phase); cla(ax_forcing); cla(ax_spectrum);

        % Colour palette
        c_trans  = [0.60 0.65 0.78];
        c_steady = [0.82 0.07 0.15];
        c_sf     = [0.99 0.80 0.10];  c_se = [0.50 0.35 0.00];
        c_state  = [0.05 0.31 0.62];  c_force = [0.90 0.40 0.02];
        c_spec   = [0.00 0.56 0.55];  ax_bg = [0.98 0.98 0.96];

        steady_idx = max(1, floor(length(x)*0.35)) : length(x);
        trans_idx  = 1 : steady_idx(1);

        % ---- Phase portrait ----
        plot(ax_phase, x(trans_idx), y(trans_idx), ...
            'Color', [c_trans 0.55], 'LineWidth', 0.9, 'DisplayName', 'Transient');
        hold(ax_phase, 'on');
        plot(ax_phase, x(steady_idx), y(steady_idx), ...
            'Color', c_steady, 'LineWidth', 1.8, 'DisplayName', 'Attractor');
        plot(ax_phase, x(1), y(1), 'o', ...
            'MarkerFaceColor', c_sf, 'MarkerEdgeColor', c_se, ...
            'MarkerSize', 9, 'LineWidth', 1.2, 'DisplayName', 'IC');
        hold(ax_phase, 'off');
        try
            xl=ax_phase.XLim; yl=ax_phase.YLim;
            annotation_arrow_on_ax(ax_phase, ...
                x(1)+(xl(2)-xl(1))*0.13, y(1)+(yl(2)-yl(1))*0.13, ...
                x(1), y(1), c_se, sprintf('$x_0=(%.2g,%.2g)$',x(1),y(1)));
            mid=steady_idx(round(end/2));
            annotation_arrow_on_ax(ax_phase, ...
                x(mid)+(xl(2)-xl(1))*0.14, y(mid)+(yl(2)-yl(1))*0.10, ...
                x(mid), y(mid), c_steady, 'Attractor');
        catch, end
        ax_phase.Color=[ax_bg]; ax_phase.GridAlpha=0.22;
        ax_phase.MinorGridAlpha=0.10; ax_phase.XMinorGrid='on'; ax_phase.YMinorGrid='on';
        apply_latex_legend(legend(ax_phase,'Location','northeast','FontSize',8));

        % ---- State vs forcing ----
        try
            tt=t(trans_idx); yrng=[min(x)*1.15 max(x)*1.15];
            patch(ax_forcing,[tt(1) tt(end) tt(end) tt(1)], ...
                [yrng(1) yrng(1) yrng(2) yrng(2)],[0.92 0.94 1.0], ...
                'EdgeColor','none','FaceAlpha',0.4,'HandleVisibility','off');
        catch, end
        hold(ax_forcing,'on');
        plot(ax_forcing,t,x,'Color',c_state,'LineWidth',1.6,'DisplayName','$x(t)$');
        plot(ax_forcing,t,forcing_signal,'Color',c_force,'LineWidth',1.2, ...
            'LineStyle','-.','DisplayName','$h\cos(\omega_p t)$');
        hold(ax_forcing,'off');
        try
            t_bd=t(steady_idx(1)); yl2=ax_forcing.YLim;
            annotation_arrow_on_ax(ax_forcing, ...
                t_bd, yl2(2)*0.72, t_bd, x(steady_idx(1)), ...
                [0.3 0.3 0.3], 'Steady state $\rightarrow$');
        catch, end
        ax_forcing.Color=ax_bg; ax_forcing.GridAlpha=0.22;
        ax_forcing.MinorGridAlpha=0.10; ax_forcing.XMinorGrid='on'; ax_forcing.YMinorGrid='on';
        apply_latex_legend(legend(ax_forcing,'Location','northeast','FontSize',8));

        % ---- Power spectrum (Hann-windowed) ----
        L=length(x(steady_idx)); dt=mean(diff(t)); Fs=1/dt;
        x_w=x(steady_idx).*hann(L);
        Yf=fft(x_w); P2=abs(Yf/L);
        P1=P2(1:floor(L/2)+1); P1(2:end-1)=2*P1(2:end-1);
        fhz=Fs*(0:(L/2))/L; om_ax=2*pi*fhz;
        P1dB=20*log10(P1+1e-12);
        plot(ax_spectrum,om_ax,P1dB,'Color',c_spec,'LineWidth',1.6, ...
            'DisplayName','$|X(\omega)|$ (dB)');
        hold(ax_spectrum,'on');
        try
            om_d=omega_edit.Value;
            yl3=[min(P1dB(om_ax<=10)) max(P1dB(om_ax<=10))];
            plot(ax_spectrum,[om_d om_d],yl3,'--','Color',[c_force 0.7], ...
                'LineWidth',1.1,'DisplayName',sprintf('$\\Omega=%.3g$',om_d));
        catch, end
        hold(ax_spectrum,'off');
        xlim(ax_spectrum,[0 10]);
        try
            mask=om_ax<=10; [pk,pi2]=max(P1dB(mask)); om_pk=om_ax(pi2);
            annotation_arrow_on_ax(ax_spectrum, ...
                om_pk+0.55, pk-7, om_pk, pk, ...
                c_spec, sprintf('Peak $\\omega=%.3g$',om_pk));
        catch, end
        ax_spectrum.Color=ax_bg; ax_spectrum.GridAlpha=0.22;
        ax_spectrum.MinorGridAlpha=0.10; ax_spectrum.XMinorGrid='on'; ax_spectrum.YMinorGrid='on';
        apply_latex_legend(legend(ax_spectrum,'Location','northeast','FontSize',8));
    end

    function annotation_arrow_on_ax(ax, xtail, ytail, xhead, yhead, clr, lbl)
        xl=ax.XLim; yl=ax.YLim; p=ax.Position;
        n=@(xd,yd)[p(1)+(xd-xl(1))/(xl(2)-xl(1))*p(3), ...
                   p(2)+(yd-yl(1))/(yl(2)-yl(1))*p(4)];
        c01=@(v)max(0.01,min(0.99,v));
        pt=c01(n(xtail,ytail)); ph=c01(n(xhead,yhead));
        f=ax.Parent;
        while ~isa(f,'matlab.ui.Figure'), f=f.Parent; end
        annotation(f,'arrow',[pt(1) ph(1)],[pt(2) ph(2)], ...
            'Color',clr,'HeadWidth',7,'HeadLength',7,'LineWidth',1.2);
        if nargin>=7 && ~isempty(lbl)
            annotation(f,'textbox',[pt(1)-0.04,pt(2)-0.015,0.10,0.03], ...
                'String',lbl,'Interpreter','latex','FontSize',7.5, ...
                'Color',clr,'EdgeColor','none','BackgroundColor','none', ...
                'HorizontalAlignment','center');
        end
    end

    function data = get_plot_data_or_alert()
        data = last_plot_data;
        if isempty(data) || ~isstruct(data) || ~isfield(data, 't') || numel(data.t) < 8
            uialert(fig, 'Run or deploy once to generate data before opening advanced plots.', 'No Data');
            data = [];
            return;
        end
    end

    function show_poincare_plot()
        data = get_plot_data_or_alert();
        if isempty(data)
            return;
        end
        try
            create_poincare_figure(data, 'on');
        catch ME
            uialert(fig, ME.message, 'Plot Error');
        end
    end

    function populate_rc_subsystem(subsys_path, C_value, R_value, init_voltage, axis_tag)
        % Creates a self-contained Simscape RC branch with:
        % Simulink in: commanded current (A), Simulink out: capacitor voltage (V)
        % Includes its own Solver Configuration and Electrical Reference so that
        % RC_X/RC_Y are independent physical networks (clean for screenshots).
        subsys_path = char(subsys_path);
        try
            Simulink.SubSystem.deleteContents(subsys_path);
        catch
        end
        % Fallback cleanup for older Simulink releases or locked subsystems.
        try
            inner_blks = find_system(subsys_path, 'SearchDepth', 1, 'Type', 'Block');
            inner_blks = setdiff(inner_blks, {subsys_path});
            for bi = 1:numel(inner_blks)
                try, delete_block(inner_blks{bi}); catch, end
            end
            inner_lines = find_system(subsys_path, 'FindAll', 'on', 'Type', 'Line');
            for li = 1:numel(inner_lines)
                try, delete_line(inner_lines(li)); catch, end
            end
        catch
        end

        % Original proven-working positions (Simscape autorouter is
        % position-sensitive for physical lines — do not move these).
        add_block('simulink/Ports & Subsystems/In1',  [subsys_path '/Icmd'], ...
            'Position', [30,  48, 60,  62]);
        add_block('simulink/Ports & Subsystems/Out1', [subsys_path '/Vout'], ...
            'Position', [520, 48, 550, 62]);

        add_block('nesl_utility/Simulink-PS Converter', [subsys_path '/SL2PS_I'], ...
            'Position', [90,  40, 140, 80]);
        add_block('fl_lib/Electrical/Electrical Sources/Controlled Current Source', ...
            [subsys_path '/ISrc'], ...
            'Position', [170, 30, 220, 90]);
        add_block('fl_lib/Electrical/Electrical Elements/Capacitor', ...
            [subsys_path '/C'], ...
            'Position', [260, 20, 310, 80], ...
            'c', num2str(C_value));
        add_block('fl_lib/Electrical/Electrical Elements/Resistor', ...
            [subsys_path '/Rleak'], ...
            'Position', [260, 95, 310, 155], ...
            'R', num2str(R_value));
        add_block('fl_lib/Electrical/Electrical Sensors/Voltage Sensor', ...
            [subsys_path '/VSens'], ...
            'Position', [350, 30, 400, 90]);
        add_block('nesl_utility/PS-Simulink Converter', [subsys_path '/PS2SL_V'], ...
            'Position', [420, 40, 470, 80]);

        add_block('nesl_utility/Solver Configuration', [subsys_path '/Solver'], ...
            'Position', [170, 130, 220, 170]);
        add_block('fl_lib/Electrical/Electrical Elements/Electrical Reference', ...
            [subsys_path '/GND'], ...
            'Position', [350, 130, 400, 170]);

        try, set_param([subsys_path '/SL2PS_I'], 'Unit', 'A'); catch, end
        try, set_param([subsys_path '/PS2SL_V'], 'OutputSignalUnit', 'V'); catch, end
        try, set_param([subsys_path '/C'], 'LabelModeActiveChoice', 'c'); catch, end

        try, set_param(subsys_path, 'AttributesFormatString', sprintf('RC_%s: I->V (Simscape)', axis_tag)); catch, end

        % Simulink signal wiring
        add_line(subsys_path, 'Icmd/1', 'SL2PS_I/1', 'autorouting', 'on');
        add_line(subsys_path, 'PS2SL_V/1', 'Vout/1', 'autorouting', 'on');

        % Physical wiring using port handles (works inside subsystem too).
        ph = @(blk) get_param([subsys_path '/' blk], 'PortHandles');
        add_line(subsys_path, ph('SL2PS_I').RConn(1), ph('ISrc').RConn(1), 'autorouting', 'on');

        % Node connections (capacitor + resistor in parallel, measured to ground).
        add_line(subsys_path, ph('C').LConn(1), ph('Rleak').LConn(1), 'autorouting', 'on');
        add_line(subsys_path, ph('C').RConn(1), ph('GND').LConn(1), 'autorouting', 'on');
        add_line(subsys_path, ph('Rleak').RConn(1), ph('GND').LConn(1), 'autorouting', 'on');

        % Current source between node and ground.
        add_line(subsys_path, ph('ISrc').RConn(2), ph('C').LConn(1), 'autorouting', 'on');
        add_line(subsys_path, ph('ISrc').LConn(1), ph('GND').LConn(1), 'autorouting', 'on');

        % Voltage sensor across node and ground; feed PS2SL.
        add_line(subsys_path, ph('VSens').LConn(1), ph('C').LConn(1), 'autorouting', 'on');
        add_line(subsys_path, ph('VSens').RConn(2), ph('GND').LConn(1), 'autorouting', 'on');
        add_line(subsys_path, ph('VSens').RConn(1), ph('PS2SL_V').LConn(1), 'autorouting', 'on');

        % Solver configuration must connect to reference in each network.
        add_line(subsys_path, ph('Solver').RConn(1), ph('GND').LConn(1), 'autorouting', 'on');

        % Initial condition for capacitor (for Simscape state and for GUI start point).
        try
            set_capacitor_ic([subsys_path '/C'], init_voltage);
        catch
        end
    end

    function show_spectrogram_plot()
        data = get_plot_data_or_alert();
        if isempty(data)
            return;
        end
        try
            create_spectrogram_figure(data, 'on');
        catch ME
            uialert(fig, ME.message, 'Plot Error');
        end
    end

    function show_return_map_plot()
        data = get_plot_data_or_alert();
        if isempty(data)
            return;
        end
        try
            create_returnmap_figure(data, 'on');
        catch ME
            uialert(fig, ME.message, 'Plot Error');
        end
    end

    function f = create_poincare_figure(data, visible_state)
        t = data.t(:);
        x = data.x(:);
        y = data.y(:);
        omega_drive = omega_edit.Value;
        if ~(isfinite(omega_drive) && omega_drive > 0)
            error('Driving frequency Ω must be positive for Poincare section.');
        end

        T = 2 * pi / omega_drive;
        t_start = t(1) + 0.35 * (t(end) - t(1));
        n0 = ceil((t_start - t(1)) / T);
        n1 = floor((t(end) - t(1)) / T);
        sample_times = t(1) + (n0:n1).' * T;
        if numel(sample_times) < 8
            error('Not enough periods in the current run for a Poincare section.');
        end

        xp = interp1(t, x, sample_times, 'linear');
        yp = interp1(t, y, sample_times, 'linear');
        valid = isfinite(xp) & isfinite(yp);
        xp = xp(valid);
        yp = yp(valid);
        if numel(xp) < 8
            error('Could not compute enough valid Poincare samples.');
        end

        f = figure('Name', 'Poincare Section', 'Color', 'w', 'Visible', visible_state);
        ax = axes(f);
        scatter(ax, xp, yp, 24, 'filled', ...
            'MarkerFaceColor', [0.10 0.40 0.75], 'MarkerFaceAlpha', 0.75);
        grid(ax, 'on');
        xlabel(ax, '$x(nT)$', 'Interpreter', 'latex', 'FontSize', 20);
        ylabel(ax, '$y(nT)$', 'Interpreter', 'latex', 'FontSize', 20);
        title(ax, sprintf('Poincare Section $(T = 2\\pi/\\Omega,\\; \\Omega = %.3g)$', omega_drive), ...
            'Interpreter', 'latex', 'FontSize', 22);
        ax.TickLabelInterpreter = 'latex';
        ax.FontSize = 20;
    end

    function f = create_spectrogram_figure(data, visible_state)
        t = data.t(:);
        x = data.x(:);
        if numel(t) < 64
            error('Need more samples to compute a spectrogram.');
        end

        dt = mean(diff(t));
        if ~(isfinite(dt) && dt > 0)
            error('Invalid time base for spectrogram.');
        end
        Fs = 1 / dt;

        if exist('spectrogram', 'file') ~= 2
            error('spectrogram() is unavailable in this MATLAB setup.');
        end

        x_det = x - mean(x, 'omitnan');
        win = max(64, 2^nextpow2(max(64, floor(numel(x_det) / 20))));
        win = min(win, 1024);
        noverlap = floor(0.75 * win);
        nfft = max(256, 2^nextpow2(win));
        [S, F, TT] = spectrogram(x_det, hamming(win), noverlap, nfft, Fs, 'yaxis');
        Pdb = 20 * log10(abs(S) + 1e-12);

        f = figure('Name', 'Spectrogram of x(t)', 'Color', 'w', 'Visible', visible_state);
        ax = axes(f);
        imagesc(ax, t(1) + TT, 2 * pi * F, Pdb);
        axis(ax, 'xy');
        colormap(ax, parula);
        cb = colorbar(ax);
        cb.Label.String = 'Magnitude (dB)';
        cb.Label.Interpreter = 'latex';
        cb.FontSize = 18;
        cb.Label.FontSize = 20;
        xlabel(ax, '$t$ (s)', 'Interpreter', 'latex', 'FontSize', 20);
        ylabel(ax, '$\\omega$ (rad/s)', 'Interpreter', 'latex', 'FontSize', 20);
        title(ax, 'Spectrogram of $x(t)$', 'Interpreter', 'latex', 'FontSize', 22);
        ax.TickLabelInterpreter = 'latex';
        ax.FontSize = 20;
        grid(ax, 'on');
    end

    function f = create_returnmap_figure(data, visible_state)
        x = data.x(:);
        n0 = max(2, floor(0.35 * numel(x)));
        xs = x(n0:end);
        if numel(xs) < 10
            error('Not enough steady-state samples for return map.');
        end

        peak_idx = find(xs(2:end-1) > xs(1:end-2) & xs(2:end-1) >= xs(3:end)) + 1;
        p = xs(peak_idx);
        if numel(p) < 3
            error('Not enough peaks detected for return map.');
        end

        x_n = p(1:end-1);
        x_np1 = p(2:end);

        f = figure('Name', 'Return Map', 'Color', 'w', 'Visible', visible_state);
        ax = axes(f);
        scatter(ax, x_n, x_np1, 26, 'filled', ...
            'MarkerFaceColor', [0.75 0.28 0.15], 'MarkerFaceAlpha', 0.75);
        hold(ax, 'on');
        minv = min([x_n; x_np1]);
        maxv = max([x_n; x_np1]);
        plot(ax, [minv maxv], [minv maxv], '--', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.0);
        hold(ax, 'off');
        grid(ax, 'on');
        xlabel(ax, '$x_n$ (peak amplitude)', 'Interpreter', 'latex', 'FontSize', 20);
        ylabel(ax, '$x_{n+1}$', 'Interpreter', 'latex', 'FontSize', 20);
        title(ax, 'Peak-to-Peak Return Map', 'Interpreter', 'latex', 'FontSize', 22);
        ax.TickLabelInterpreter = 'latex';
        ax.FontSize = 20;
    end

    function set_run_ui_state(is_running)
        run_in_progress = is_running;
        btn_run.Enable = matlab.lang.OnOffSwitchState(~is_running);
        btn_build.Enable = matlab.lang.OnOffSwitchState(~is_running);
        btn_stop.Enable = matlab.lang.OnOffSwitchState(is_running);
    end

    function cleanup_after_run(reset_stop_flag)
        cleanup_run_timer();
        set_run_ui_state(false);
        if nargin > 0 && reset_stop_flag
            stop_requested = false;
        end
    end

    function cleanup_run_timer()
        if isempty(run_poll_timer)
            return;
        end
        try
            stop(run_poll_timer);
        catch
        end
        try
            delete(run_poll_timer);
        catch
        end
        run_poll_timer = [];
    end

    function close_gui()
        stop_simulation();
        cleanup_run_timer();
        delete(fig);
    end

    function add_line_phys(p1, p2)
        try
            add_line(model_name, p1, p2, 'autorouting', 'on');
        catch ME
            warning('Failed to connect physical line: %s', ME.message);
        end
    end

    function connect_sensor(phSens, phCap, phGnd, phPS2SL_port)
        % Voltage Sensor ports for this library block:
        % LConn(1) = electrical +, RConn(1) = physical signal output,
        % RConn(2) = electrical -.
        add_line_phys(phSens.LConn(1), phCap);
        add_line_phys(phSens.RConn(2), phGnd);

        try
            add_line(model_name, phSens.RConn(1), phPS2SL_port, 'autorouting', 'on');
        catch ME
            warning('Failed to connect Voltage Sensor output: %s', ME.message);
        end
    end

    function connect_source(phSrc, phCap, phGnd, phSL2PS_port)
        % Controlled Current Source ports for this library block:
        % RConn(1) = physical signal control input, LConn(1) = electrical +,
        % RConn(2) = electrical -.
        try
            add_line(model_name, phSL2PS_port, phSrc.RConn(1), 'autorouting', 'on');
        catch ME
            warning('Failed to connect current source control input: %s', ME.message);
        end

        add_line_phys(phSrc.LConn(1), phGnd);
        add_line_phys(phSrc.RConn(2), phCap);
    end

    function set_capacitor_ic(block_path, init_voltage)
        init_str = num2str(init_voltage);
        try, set_param(block_path, 'v', init_str); catch, end
        try, set_param(block_path, 'v', [init_str ' V']); catch, end
        try, set_param(block_path, 'v_priority', 'High'); catch, end
        try, set_param(block_path, 'v_priority', '3'); catch, end
        try, set_param(block_path, 'v_target_value', init_str); catch, end
        try, set_param(block_path, 'v_target_priority', 'High'); catch, end
        try, set_param(block_path, 'Variables', {'v', init_str, 'High'}); catch, end
    end

    function set_memory_ic(block_path, init_value)
        init_str = num2str(init_value);
        try, set_param(block_path, 'InitialCondition', init_str); catch, end
        try, set_param(block_path, 'X0', init_str); catch, end
    end

    function apply_requested_start_point(x_init, y_init)
        core2 = [model_name '/ODE_Core'];
        in_core = bdIsLoaded(model_name) && ~isempty(find_system(model_name,'SearchDepth',1,'Name','ODE_Core'));
        pfx2 = core2; if ~in_core, pfx2 = model_name; end
        try, set_capacitor_ic([pfx2 '/RC_X/C'], x_init); catch
             set_capacitor_ic([model_name '/RC_X/C'], x_init); end
        try, set_capacitor_ic([pfx2 '/RC_Y/C'], y_init); catch
             set_capacitor_ic([model_name '/RC_Y/C'], y_init); end
        try, set_memory_ic([pfx2 '/Mem_x'], x_init); catch
             set_memory_ic([model_name '/Mem_x'], x_init); end
        try, set_memory_ic([pfx2 '/Mem_y'], y_init); catch
             set_memory_ic([model_name '/Mem_y'], y_init); end
    end

    function style_model_inkscape()
        % Applies Inkscape-style colours and labels to whatever blocks exist.
        % Works whether blocks are at top level or inside ODE_Core subsystem.
        has_core = bdIsLoaded(model_name) && ...
            ~isempty(find_system(model_name,'SearchDepth',1,'Name','ODE_Core'));
        pfx = model_name; if has_core, pfx = [model_name '/ODE_Core']; end

        % --- ODE block colours (blue-teal palette) ---
        bc = { ...
            'Clock',     '[0.94 0.96 1.0]'; ...
            'ForcingFcn','[0.90 0.85 1.0]'; ...
            'Mux',       '[0.93 0.93 0.98]'; ...
            'AccelFcn',  '[0.82 0.93 1.0]'; ...
            'IxGain',    '[0.80 0.97 0.86]'; ...
            'IyGain',    '[0.80 0.97 0.86]'; ...
            'RC_X',      '[0.65 0.83 1.0]'; ...
            'RC_Y',      '[0.65 0.83 1.0]'; ...
            'Mem_x',     '[1.0  0.94 0.72]'; ...
            'Mem_y',     '[1.0  0.94 0.72]'};
        for i = 1:size(bc,1)
            try, set_param([pfx '/' bc{i,1}], ...
                'BackgroundColor', bc{i,2}); catch, end
        end
        if has_core
            try, set_param([model_name '/ODE_Core'], ...
                'BackgroundColor','[0.80 0.91 1.0]', ...
                'ForegroundColor','[0.04 0.22 0.52]'); catch, end
        end
        % --- Output block colours (green / amber) ---
        oc = {'Out_x','[0.83 0.97 0.86]';'Out_y','[0.83 0.97 0.86]'; ...
              'Out_forcing','[0.99 0.91 0.78]';'Out_t','[0.93 0.93 0.93]'; ...
              'Out_selected','[0.93 0.93 0.93]'};
        for i = 1:size(oc,1)
            try, set_param([model_name '/' oc{i,1}], ...
                'BackgroundColor', oc{i,2}); catch, end
        end
        % --- Block labels ---
        try, set_param([pfx '/AccelFcn'],   'AttributesFormatString', 'y'' = f(x,y,t)'); catch, end
        try, set_param([pfx '/ForcingFcn'], 'AttributesFormatString', 'h cos(wp t)');    catch, end
        try, set_param([pfx '/Mem_x'],      'AttributesFormatString', 'x(t)');           catch, end
        try, set_param([pfx '/Mem_y'],      'AttributesFormatString', 'y(t)');           catch, end
        try, set_param([pfx '/RC_X'],       'AttributesFormatString', 'Simscape RC-X');  catch, end
        try, set_param([pfx '/RC_Y'],       'AttributesFormatString', 'Simscape RC-Y');  catch, end
        try, set_param([pfx '/IxGain'],     'AttributesFormatString', 'C * y');          catch, end
        try, set_param([pfx '/IyGain'],     'AttributesFormatString', 'C * acc');        catch, end
    end

    function sync_slider_to_edit(raw_value, edit_field)
        edit_field.Value = round(raw_value / 0.001) * 0.001;
    end

    function add_arduino_due_output_branch()
        ensure_arduino_support_package_loaded();
        dac_block_path = add_arduino_analog_output_block([model_name '/Arduino_Due_DAC']);
        if isempty(dac_block_path)
            warning('Arduino Due Analog Output block was not found. Install the Simulink Support Package for Arduino Hardware to enable DSO output.');
            return;
        end

        try_set_param(model_name, 'HardwareBoard', 'Arduino Due');

        add_block('simulink/Discrete/Zero-Order Hold', [model_name '/DAC_ZOH'], ...
            'Position', [980, 520, 1040, 560], ...
            'SampleTime', num2str(get_effective_hil_sample_time()));
        add_optional_dac_filter('DAC', [1055, 520, 1125, 560]);
        add_block('simulink/Math Operations/Gain', [model_name '/DAC_PhysicalGain'], ...
            'Position', [1140, 520, 1200, 560], ...
            'Gain', num2str(amp_mult_edit.Value));
        add_block('simulink/Math Operations/Gain', [model_name '/DAC_CodeGain'], ...
            'Position', [1220, 520, 1285, 560], ...
            'Gain', num2str(4095 / (dac_signal_max_edit.Value - dac_signal_min_edit.Value)));
        add_block('simulink/Math Operations/Bias', [model_name '/DAC_CodeBias'], ...
            'Position', [1305, 520, 1370, 560], ...
            'Bias', num2str(-dac_signal_min_edit.Value * 4095 / (dac_signal_max_edit.Value - dac_signal_min_edit.Value)));
        add_block('simulink/Discontinuities/Saturation', [model_name '/DAC_Saturation'], ...
            'Position', [1390, 520, 1460, 560], ...
            'UpperLimit', '4095', ...
            'LowerLimit', '0');
        add_block('simulink/Signal Attributes/Data Type Conversion', [model_name '/DAC_uint16'], ...
            'Position', [1485, 520, 1565, 560], ...
            'OutDataTypeStr', 'uint16', ...
            'RndMeth', 'Round');

        connect_dac_filter_to_scaler('DAC');
        add_line(model_name, 'DAC_PhysicalGain/1', 'DAC_CodeGain/1', 'autorouting', 'on');
        add_line(model_name, 'DAC_CodeGain/1', 'DAC_CodeBias/1', 'autorouting', 'on');
        add_line(model_name, 'DAC_CodeBias/1', 'DAC_Saturation/1', 'autorouting', 'on');
        add_line(model_name, 'DAC_Saturation/1', 'DAC_uint16/1', 'autorouting', 'on');
        add_line(model_name, 'DAC_uint16/1', 'Arduino_Due_DAC/1', 'autorouting', 'on');

        try, set_param([model_name '/DAC_ZOH'], 'AttributesFormatString', 'HIL DAC0 input: x(t) for XY limit cycle'); catch, end
        try, set_param([model_name '/DAC_PhysicalGain'], 'AttributesFormatString', 'Physical DAC amplitude multiplier'); catch, end
        try, set_param([model_name '/Arduino_Due_DAC'], 'AttributesFormatString', 'Physical output: DAC0 -> scope CH1 (X axis)'); catch, end

        % HIL limit-cycle output is fixed to DAC0 = x(t).
        try_set_param(dac_block_path, 'DACPin', 'DAC0');
        try_set_param(dac_block_path, 'DAC pin', 'DAC0');
        try_set_param(dac_block_path, 'pinNumber', 'DAC0');
    end

    function add_arduino_due_phase_branch()
        ensure_arduino_support_package_loaded();
        dac_block_path = add_arduino_analog_output_block([model_name '/Arduino_Due_DAC_Y']);
        if isempty(dac_block_path)
            warning('Arduino Due second Analog Output block was not found. DAC1 phase output will be unavailable.');
            return;
        end

        add_block('simulink/Discrete/Zero-Order Hold', [model_name '/DAC_Y_ZOH'], ...
            'Position', [980, 610, 1040, 650], ...
            'SampleTime', num2str(get_effective_hil_sample_time()));
        add_optional_dac_filter('DAC_Y', [1055, 610, 1125, 650]);
        add_block('simulink/Math Operations/Gain', [model_name '/DAC_Y_PhysicalGain'], ...
            'Position', [1140, 610, 1200, 650], ...
            'Gain', num2str(amp_mult_edit.Value));
        add_block('simulink/Math Operations/Gain', [model_name '/DAC_Y_CodeGain'], ...
            'Position', [1220, 610, 1285, 650], ...
            'Gain', num2str(4095 / (dac_signal_max_edit.Value - dac_signal_min_edit.Value)));
        add_block('simulink/Math Operations/Bias', [model_name '/DAC_Y_CodeBias'], ...
            'Position', [1305, 610, 1370, 650], ...
            'Bias', num2str(-dac_signal_min_edit.Value * 4095 / (dac_signal_max_edit.Value - dac_signal_min_edit.Value)));
        add_block('simulink/Discontinuities/Saturation', [model_name '/DAC_Y_Saturation'], ...
            'Position', [1390, 610, 1460, 650], ...
            'UpperLimit', '4095', ...
            'LowerLimit', '0');
        add_block('simulink/Signal Attributes/Data Type Conversion', [model_name '/DAC_Y_uint16'], ...
            'Position', [1485, 610, 1565, 650], ...
            'OutDataTypeStr', 'uint16', ...
            'RndMeth', 'Round');

        connect_dac_filter_to_scaler('DAC_Y');
        add_line(model_name, 'DAC_Y_PhysicalGain/1', 'DAC_Y_CodeGain/1', 'autorouting', 'on');
        add_line(model_name, 'DAC_Y_CodeGain/1', 'DAC_Y_CodeBias/1', 'autorouting', 'on');
        add_line(model_name, 'DAC_Y_CodeBias/1', 'DAC_Y_Saturation/1', 'autorouting', 'on');
        add_line(model_name, 'DAC_Y_Saturation/1', 'DAC_Y_uint16/1', 'autorouting', 'on');
        add_line(model_name, 'DAC_Y_uint16/1', 'Arduino_Due_DAC_Y/1', 'autorouting', 'on');

        try, set_param([model_name '/DAC_Y_ZOH'], 'AttributesFormatString', 'HIL DAC1 input: y(t) for XY limit cycle'); catch, end
        try, set_param([model_name '/DAC_Y_PhysicalGain'], 'AttributesFormatString', 'Physical DAC amplitude multiplier'); catch, end
        try, set_param([model_name '/Arduino_Due_DAC_Y'], 'AttributesFormatString', 'Physical output: DAC1 -> scope CH2 (Y axis)'); catch, end

        try_set_param(dac_block_path, 'DACPin', 'DAC1');
        try_set_param(dac_block_path, 'DAC pin', 'DAC1');
        try_set_param(dac_block_path, 'pinNumber', 'DAC1');
    end

    function add_hil_output_view_selector()
        add_block('simulink/Sources/Constant', [model_name '/DAC_ViewIndex'], ...
            'Position', [820, 600, 880, 630], ...
            'Value', num2str(get_hil_output_view_index()));
        add_block('simulink/Sources/Constant', [model_name '/DAC_Zero'], ...
            'Position', [820, 700, 880, 730], ...
            'Value', '0');
        add_block('simulink/Signal Routing/Multiport Switch', [model_name '/DAC_Y_ViewSwitch'], ...
            'Position', [900, 625, 960, 715], ...
            'Inputs', '3', ...
            'DataPortOrder', 'Zero-based contiguous');

        add_line(model_name, 'DAC_ViewIndex/1', 'DAC_Y_ViewSwitch/1', 'autorouting', 'on');
        add_line(model_name, 'Mem_y/1', 'DAC_Y_ViewSwitch/2', 'autorouting', 'on');
        add_line(model_name, 'ForcingFcn/1', 'DAC_Y_ViewSwitch/3', 'autorouting', 'on');
        add_line(model_name, 'DAC_Zero/1', 'DAC_Y_ViewSwitch/4', 'autorouting', 'on');
        add_line(model_name, 'DAC_Y_ViewSwitch/1', 'DAC_Y_ZOH/1', 'autorouting', 'on');

        try, set_param([model_name '/DAC_ViewIndex'], 'AttributesFormatString', '0=phase,1=state-forcing,2=spectrum'); catch, end
        try, set_param([model_name '/DAC_Y_ViewSwitch'], 'AttributesFormatString', 'DAC1 source selector for physical output mode'); catch, end
    end

    function add_optional_dac_filter(prefix, position_vec)
        if ~smooth_output_chk.Value
            return;
        end

        [num_coeff, den_coeff] = get_dac_filter_coeffs();
        add_block('simulink/Discrete/Discrete Transfer Fcn', [model_name '/' prefix '_LPF'], ...
            'Position', position_vec, ...
            'Numerator', mat2str(num_coeff), ...
            'Denominator', mat2str(den_coeff), ...
            'SampleTime', num2str(get_effective_hil_sample_time()));
        try, set_param([model_name '/' prefix '_LPF'], 'AttributesFormatString', 'DAC smoothing LPF'); catch, end
    end

    function connect_dac_filter_to_scaler(prefix)
        if smooth_output_chk.Value && block_exists([prefix '_LPF'])
            add_line(model_name, [prefix '_ZOH/1'], [prefix '_LPF/1'], 'autorouting', 'on');
            add_line(model_name, [prefix '_LPF/1'], [prefix '_PhysicalGain/1'], 'autorouting', 'on');
        else
            add_line(model_name, [prefix '_ZOH/1'], [prefix '_PhysicalGain/1'], 'autorouting', 'on');
        end
    end

    function [num_coeff, den_coeff] = get_dac_filter_coeffs()
        Ts = get_effective_hil_sample_time();
        tau = max(filter_tau_edit.Value, Ts);
        alpha = Ts / (tau + Ts);
        num_coeff = [alpha];
        den_coeff = [1 -(1 - alpha)];
    end

    function add_model_annotations()
        try
            Simulink.Annotation(model_name, ...
                'Input to dynamics: time t enters through Clock and [x y t] enters AccelFcn.');
        catch
        end

        try
            Simulink.Annotation(model_name, ...
                'Internal outputs: Mem_x = x(t), Mem_y = y(t), ForcingFcn = h cos(w_p t).');
        catch
        end

        if is_hil_mode() && dac_enable_chk.Value
            try
                Simulink.Annotation(model_name, ...
                    ['Physical oscilloscope output in HIL mode: ' char(get_hil_output_guidance()) newline ...
                     'Both DAC channels use the same logical scaling before conversion to the Due 0..3.3 V range.']);
            catch
            end
        end
    end

    function build_minimal_dac_self_test_model()
        add_block('simulink/Sources/Clock', [model_name '/Clock'], ...
            'Position', [90, 140, 130, 180]);
        try, set_param([model_name '/Clock'], 'AttributesFormatString', 'Self-test time base'); catch, end

        add_arduino_due_output_branch();
        if phase_output_chk.Value
            add_arduino_due_phase_branch();
        end
        add_hardware_self_test_sources();

        add_block('simulink/Sinks/Scope', [model_name '/SelfTestScope'], ...
            'Position', [1180, 180, 1260, 240]);
        add_line(model_name, 'DAC_Test_CH1/1', 'SelfTestScope/1', 'autorouting', 'on');
        try, set_param([model_name '/SelfTestScope'], 'AttributesFormatString', 'Preview of DAC0 self-test waveform'); catch, end

        try
            Simulink.Annotation(model_name, ...
                'Minimal DAC self-test model: no Simscape plant, direct waveform generation for Arduino Due DAC verification.');
        catch
        end

        try
            Simulink.Annotation(model_name, ...
                'Wire DAC0 to scope CH1 and DAC1 to scope CH2. Use normal time mode first, then XY if needed.');
        catch
        end
    end

    function configure_arduino_due_target()
        ensure_arduino_support_package_loaded();
        due_com_port = detect_arduino_due_com_port();
        if strlength(due_com_port) == 0
            error(['Arduino Due was not detected on this PC.' newline ...
                build_due_detection_help()]);
        end

        try_set_param(model_name, 'HardwareBoard', 'Arduino Due');
        try_set_param(model_name, 'ExtMode', 'off');
        try_set_param(model_name, 'ExtModeTransport', '0');
        try_set_param(model_name, 'ProdEqTarget', 'on');
        try
            cs = getActiveConfigSet(model_name);
            if has_param(cs, 'HardwareBoard')
                set_param(cs, 'HardwareBoard', 'Arduino Due');
            end
            if has_param(cs, 'ExtMode')
                set_param(cs, 'ExtMode', 'off');
            end
            if has_param(cs, 'ExtModeTransport')
                set_param(cs, 'ExtModeTransport', '0');
            end
            % Configure the support-package target data for deterministic
            % deploy-and-run behavior on the Due programming port.
            codertarget.data.setParameterValue(cs, 'Runtime.BuildAction', 'Build');
            codertarget.data.setParameterValue(cs, 'HostBoardConnection.AppDownload_port_source', 'Manually Specify');
            codertarget.data.setParameterValue(cs, 'HostBoardConnection.AppDownload_COMPort_specify', char(due_com_port));
            codertarget.data.setParameterValue(cs, 'HostBoardConnection.AppDownload_baud', '115200(Default)');
        catch
        end

        assignin('base', 'arduino_due_detected_com_port', char(due_com_port));
    end

    function add_hardware_self_test_sources()
        add_self_test_source('DAC_Test_CH1', [1260, 430, 1340, 470], [1360, 430, 1420, 470], 1);
        add_line(model_name, 'DAC_Test_CH1/1', 'DAC_ZOH/1', 'autorouting', 'on');

        if block_exists('DAC_Y_ZOH')
            add_self_test_source('DAC_Test_CH2', [1260, 600, 1340, 640], [1360, 600, 1420, 640], -1);
            add_line(model_name, 'DAC_Test_CH2/1', 'DAC_Y_ZOH/1', 'autorouting', 'on');
        end
    end

    function add_self_test_source(block_name, source_pos, gain_pos, sign_gain)
        amplitude = 0.5 * (dac_signal_max_edit.Value - dac_signal_min_edit.Value);
        if amplitude <= 0
            amplitude = 1.0;
        end

        switch char(self_test_wave_dropdown.Value)
            case 'Square'
                add_block('simulink/Sources/Pulse Generator', [model_name '/' block_name '_raw'], ...
                    'Position', source_pos, ...
                    'Amplitude', '1', ...
                    'Period', '2', ...
                    'PulseWidth', '50', ...
                    'SampleTime', num2str(get_effective_hil_sample_time()));
                add_block('simulink/Math Operations/Gain', [model_name '/' block_name '_scale'], ...
                    'Position', gain_pos, ...
                    'Gain', num2str(sign_gain * 2 * amplitude));
                add_block('simulink/Math Operations/Bias', [model_name '/' block_name], ...
                    'Position', [1440, source_pos(2), 1500, source_pos(4)], ...
                    'Bias', num2str(-sign_gain * amplitude));
                add_line(model_name, [block_name '_raw/1'], [block_name '_scale/1'], 'autorouting', 'on');
                add_line(model_name, [block_name '_scale/1'], [block_name '/1'], 'autorouting', 'on');
            case 'Ramp'
                add_block('simulink/Sources/Repeating Sequence Stair', [model_name '/' block_name '_raw'], ...
                    'Position', source_pos, ...
                    'TimeValues', '[0 1 2 3 4]', ...
                    'OutputValues', '[-1 -0.5 0 0.5 1]');
                add_block('simulink/Math Operations/Gain', [model_name '/' block_name], ...
                    'Position', gain_pos, ...
                    'Gain', num2str(sign_gain * amplitude));
                add_line(model_name, [block_name '_raw/1'], [block_name '/1'], 'autorouting', 'on');
            otherwise
                add_block('simulink/Sources/Sine Wave', [model_name '/' block_name], ...
                    'Position', source_pos, ...
                    'Amplitude', num2str(sign_gain * amplitude), ...
                    'Frequency', num2str(2*pi*0.5), ...
                    'SampleTime', num2str(get_effective_hil_sample_time()));
        end

        try, set_param([model_name '/' block_name], 'AttributesFormatString', 'Hardware DAC self-test source'); catch, end
    end

    function configure_model_solver_for_selected_mode()
        if is_hil_mode()
            % Arduino HIL needs a deterministic fixed-step schedule.
            % IMPORTANT FIX:
            % This now uses a much faster floor via get_effective_hil_sample_time().
            hil_step = num2str(get_effective_hil_sample_time());
            try_set_param(model_name, 'SolverType', 'Fixed-step');
            try_set_param(model_name, 'Solver', 'ode4');
            try_set_param(model_name, 'FixedStep', hil_step);
            try_set_param(model_name, 'AutoInsertRateTranBlk', 'off');

            core3 = [model_name '/ODE_Core'];
            has_core = ~isempty(find_system(model_name,'SearchDepth',1,'Name','ODE_Core'));
            if has_core
                solver_blocks = {[core3 '/RC_X/Solver'], [core3 '/RC_Y/Solver']};
            else
                solver_blocks = {[model_name '/RC_X/Solver'], [model_name '/RC_Y/Solver']};
            end
            for k = 1:numel(solver_blocks)
                try, set_param(solver_blocks{k}, 'UseLocalSolver', 'on'); catch, end
                try, set_param(solver_blocks{k}, 'LocalSolverChoice', 'NE_BACKWARD_EULER_ADVANCER'); catch, end
                try, set_param(solver_blocks{k}, 'LocalSolverSampleTime', hil_step); catch, end
            end
        else
            try_set_param(model_name, 'SolverType', 'Variable-step');
            try_set_param(model_name, 'Solver', 'ode15s');
            try_set_param(model_name, 'MaxStep', '0.01');
            try_set_param(model_name, 'RelTol', '1e-4');
        end
    end

    function configure_model_callbacks_for_selected_mode()
        if is_hil_mode()
            pre_start_msg = [ ...
                'error(''This model was built for direct Arduino deployment from the GUI.'',' ...
                '''Use the GUI button "Deploy to Due" instead of the Simulink Run button.'');'];
            try_set_param(model_name, 'PreStartFcn', pre_start_msg);
        else
            try_set_param(model_name, 'PreStartFcn', '');
        end
    end

    function tf = has_param(obj, param_name)
        tf = false;
        try
            get_param(obj, param_name);
            tf = true;
        catch
        end
    end

    function ensure_arduino_support_package_loaded()
        try
            matlab.internal.supportPackages.addInstalledSupportPackagesToPath();
        catch
        end

        try
            load_system('arduinolib');
        catch
        end
    end

    function blk_path = add_arduino_analog_output_block(blk_path)
        library_candidates = { ...
            'arduinolib/Common/Analog Output', ...
            'arduinolib/Analog Output', ...
            'arduino_lib/Common/Analog Output', ...
            'simulinksupportpkgarduino/Common/Analog Output', ...
            'arduinoio_lib/Common/Analog Output'};

        for k = 1:numel(library_candidates)
            try
                load_system(strtok(library_candidates{k}, '/'));
            catch
            end

            try
                add_block(library_candidates{k}, blk_path, ...
                    'Position', [1490, 520, 1580, 565]);
                return;
            catch
            end
        end

        blk_path = '';
    end

    function try_set_param(block_or_model, param_name, param_value)
        try
            set_param(block_or_model, param_name, param_value);
        catch
        end
    end

    function tf = block_exists(block_name)
        tf = ~isempty(find_system(model_name, 'SearchDepth', 1, 'Name', block_name));
    end

    function validate_arduino_due_settings()
        if ~is_hil_mode() || ~dac_enable_chk.Value
            return;
        end

        if dac_sample_time_edit.Value <= 0
            error('Arduino Due sample time must be positive.');
        end

        if dac_signal_max_edit.Value <= dac_signal_min_edit.Value
            error('Arduino Due signal max must be greater than signal min.');
        end

        if amp_mult_edit.Value <= 0
            error('Physical DAC amplitude multiplier must be positive.');
        end

        % IMPORTANT FIX:
        % Previously this forced sample time >= 1e-2, which is too slow.
        % Use 1e-4 as the hard minimum for HIL timing.
        if dac_sample_time_edit.Value < 1e-4
            dac_sample_time_edit.Value = 1e-4;
        end

        if smooth_output_chk.Value && filter_tau_edit.Value < 1e-4
            filter_tau_edit.Value = 1e-4;
        end

        due_com_port = detect_arduino_due_com_port();
        if strlength(due_com_port) == 0
            due_com_port = 'COM3';   % placeholder – deploy will fail if Due is absent
            safe_uialert(fig, ...
                ['Arduino Due was not detected on any COM port.' newline newline ...
                 'The model will be built with a placeholder port (COM3).' newline ...
                 'Connect the Due before deploying, or set:' newline ...
                 '  arduino_due_com_port_override = ''COMx''' newline ...
                 'in the MATLAB Command Window.' newline newline ...
                 build_due_detection_help()], ...
                'Arduino Due Not Found');
        end
    end

    function sample_time = get_effective_hil_sample_time()
        % IMPORTANT FIX:
        % Previously max(sample_time, 1e-2), which crippled the XY display.
        sample_time = max(dac_sample_time_edit.Value, 1e-4);
    end

    function due_com_port = detect_arduino_due_com_port()
        due_com_port = "";
        override_port = get_arduino_due_com_override();
        if strlength(override_port) > 0
            due_com_port = override_port;
            return;
        end

        matlab_ports = get_available_serial_ports();
        if isscalar(matlab_ports)
            due_com_port = matlab_ports;
            return;
        end

        candidates = query_windows_serial_devices();
        if isempty(candidates)
            if numel(matlab_ports) >= 2
                scope_like = startsWith(upper(matlab_ports), "COM6");
                non_scope_ports = matlab_ports(~scope_like);
                if isscalar(non_scope_ports)
                    due_com_port = non_scope_ports;
                end
            end
            return;
        end

        for idx = 1:numel(candidates)
            name_upper = upper(candidates(idx).Name);
            pnp_upper = upper(candidates(idx).PNPDeviceID);
            if contains(name_upper, 'ARDUINO') || contains(name_upper, 'BOSSAC') || ...
                    contains(pnp_upper, 'VID_2341') || contains(pnp_upper, 'VID_2A03') || ...
                    contains(pnp_upper, 'VID_03EB')
                token = regexp(candidates(idx).Name, 'COM\d+', 'match', 'once');
                if ~isempty(token)
                    due_com_port = string(token);
                    return;
                end
            end
        end

        % Fallback: if there is exactly one non-scope COM port, use it.
        non_scope_ports = strings(0, 1);
        for idx = 1:numel(candidates)
            token = regexp(candidates(idx).Name, 'COM\d+', 'match', 'once');
            if isempty(token)
                continue;
            end
            pnp_upper = upper(candidates(idx).PNPDeviceID);
            name_upper = upper(candidates(idx).Name);
            if ~(contains(pnp_upper, 'VID_0558') || contains(name_upper, 'GW INSTEK') || contains(name_upper, 'GDS'))
                non_scope_ports(end+1, 1) = string(token); %#ok<AGROW>
            end
        end
        if isscalar(non_scope_ports)
            due_com_port = non_scope_ports;
        end
    end

    function override_port = get_arduino_due_com_override()
        override_port = "";
        try
            raw = evalin('base', 'arduino_due_com_port_override');
        catch
            return;
        end

        override_port = upper(strtrim(string(raw)));
        if strlength(override_port) == 0
            override_port = "";
            return;
        end

        token = regexp(char(override_port), 'COM\d+', 'match', 'once');
        if isempty(token)
            override_port = "";
        else
            override_port = string(token);
        end
    end

    function msg = build_due_detection_help()
        port_list = compose_available_port_list(query_windows_serial_devices());
        matlab_port_list = strjoin(cellstr(get_available_serial_ports()), ', ');
        if isempty(matlab_port_list)
            matlab_port_list = 'none';
        end
        msg = sprintf(['Connect the Due by USB and make sure Windows shows a COM port for it before using HIL mode.' ...
            '\nAvailable COM ports right now: %s' ...
            '\nMATLAB serialportlist sees: %s' ...
            '\nIf your Due appears with a generic USB-serial identity, you can force it manually from MATLAB:' ...
            '\narduino_due_com_port_override = ''COMx'';'], port_list, matlab_port_list);
    end

    function port_list = compose_available_port_list(devices)
        labels = strings(0, 1);
        if ~isempty(devices)
            for idx = 1:numel(devices)
                token = regexp(devices(idx).Name, 'COM\d+', 'match', 'once');
                if isempty(token)
                    continue;
                end
                labels(end+1, 1) = string(token) + " (" + string(devices(idx).Name) + ")"; %#ok<AGROW>
            end
        end

        if isempty(labels)
            matlab_ports = get_available_serial_ports();
            for idx = 1:numel(matlab_ports)
                labels(end+1, 1) = matlab_ports(idx); %#ok<AGROW>
            end
        end

        if isempty(labels)
            port_list = 'none';
        else
            port_list = strjoin(cellstr(labels), ', ');
        end
    end

    function ports = get_available_serial_ports()
        ports = strings(0, 1);
        try
            raw_ports = serialportlist("available");
            if ~isempty(raw_ports)
                ports = string(raw_ports(:));
            end
        catch
        end
    end

    function devices = query_windows_serial_devices()
        devices = struct('Name', {}, 'PNPDeviceID', {});
        if ~ispc
            return;
        end

        ps_cmd = [ ...
            "Get-CimInstance Win32_PnPEntity | " + ...
            "Where-Object { $_.Name -match 'COM\\d+' } | " + ...
            "Select-Object Name,PNPDeviceID | ConvertTo-Json -Compress"];
        [status, raw] = system(sprintf('powershell -NoProfile -Command "%s"', char(ps_cmd)));
        if status ~= 0
            return;
        end

        raw = strtrim(raw);
        if isempty(raw)
            return;
        end

        try
            parsed = jsondecode(raw);
        catch
            return;
        end

        if isstruct(parsed)
            if isscalar(parsed)
                devices = parsed;
            else
                devices = parsed(:);
            end
        end
    end

    function sync_slider_to_edit_and_update(raw_value, edit_field)
        sync_slider_to_edit(raw_value, edit_field);
        update_computed_params();
    end

    function sync_edit_to_slider(edit_field, slider)
        slider.Value = min(max(round(edit_field.Value / 0.001) * 0.001, slider.Limits(1)), slider.Limits(2));
        edit_field.Value = slider.Value;
    end

    function sync_edit_to_slider_and_update(edit_field, slider)
        sync_edit_to_slider(edit_field, slider);
        update_computed_params();
    end

    function set_axes_latex(ax, title_text, xlabel_text, ylabel_text)
        title(ax, title_text, 'Interpreter', 'latex', 'FontSize', 22);
        xlabel(ax, xlabel_text, 'Interpreter', 'latex', 'FontSize', 20);
        ylabel(ax, ylabel_text, 'Interpreter', 'latex', 'FontSize', 20);
        ax.TickLabelInterpreter = 'latex';
        ax.FontSize = 20;
        try, ax.TitleFontSizeMultiplier = 1.0; catch, end
        try, ax.LabelFontSizeMultiplier = 1.0; catch, end
    end

    function apply_latex_legend(lgnd)
        try
            lgnd.Interpreter = 'latex';
            lgnd.FontSize = 18;
        catch
        end
    end

    function open_export_dialog()
        d = uifigure('Name', 'Export Results', 'Color', 'w', ...
            'Position', [260, 220, 640, 420], 'WindowStyle', 'modal');

        uilabel(d, 'Position', [24, 382, 90, 18], 'Text', 'Folder:');
        folder_edit = uieditfield(d, 'text', 'Position', [110, 378, 420, 24], ...
            'Value', export_prefs.folder);
        uibutton(d, 'push', 'Position', [540, 378, 76, 24], 'Text', 'Browse', ...
            'ButtonPushedFcn', @(~,~) browse_export_folder(folder_edit));

        uilabel(d, 'Position', [24, 346, 90, 18], 'Text', 'Base Name:');
        prefix_edit = uieditfield(d, 'text', 'Position', [110, 342, 220, 24], ...
            'Value', export_prefs.prefix);
        stamp_chk = uicheckbox(d, 'Position', [346, 342, 240, 24], ...
            'Value', true, 'Text', 'Append timestamp (recommended)');

        uilabel(d, 'Position', [24, 310, 90, 18], 'Text', 'Format:');
        fmt_dd = uidropdown(d, 'Position', [110, 306, 220, 26], ...
            'Items', {'PNG', 'JPEG', 'MATLAB FIG'}, 'Value', export_prefs.format);

        uilabel(d, 'Position', [346, 310, 50, 18], 'Text', 'DPI:');
        dpi_edit = uieditfield(d, 'numeric', 'Position', [392, 306, 120, 26], ...
            'Limits', [72 2400], 'RoundFractionalValues', 'on', 'Value', export_prefs.dpi);
        uilabel(d, 'Position', [520, 310, 110, 18], 'Text', '(raster only)');

        uilabel(d, 'Position', [24, 274, 160, 18], 'Text', 'Results to export:');
        chk_phase = uicheckbox(d, 'Position', [30, 248, 220, 22], 'Value', true, 'Text', 'Phase portrait');
        chk_forcing = uicheckbox(d, 'Position', [30, 224, 260, 22], 'Value', true, 'Text', 'State vs excitation');
        chk_spec = uicheckbox(d, 'Position', [30, 200, 220, 22], 'Value', true, 'Text', 'Spectrum');
        chk_combo = uicheckbox(d, 'Position', [30, 176, 280, 22], 'Value', false, 'Text', 'Combined tiled figure (2x2)');

        uilabel(d, 'Position', [330, 274, 220, 18], 'Text', 'Advanced plots (optional):');
        chk_poincare = uicheckbox(d, 'Position', [336, 248, 260, 22], 'Value', false, 'Text', 'Poincare section');
        chk_sgram = uicheckbox(d, 'Position', [336, 224, 260, 22], 'Value', false, 'Text', 'Spectrogram');
        chk_return = uicheckbox(d, 'Position', [336, 200, 260, 22], 'Value', false, 'Text', 'Return map');

        export_btn = uibutton(d, 'push', 'Position', [360, 22, 120, 32], 'Text', 'Export', ...
            'FontWeight', 'bold', 'BackgroundColor', [0.18 0.53 0.89], 'FontColor', [1 1 1]);
        uibutton(d, 'push', 'Position', [496, 22, 120, 32], 'Text', 'Cancel', ...
            'ButtonPushedFcn', @(~,~) delete(d));

        export_btn.ButtonPushedFcn = @(~,~) do_export_from_dialog();

        function do_export_from_dialog()
            export_folder = string(strtrim(folder_edit.Value));
            if strlength(export_folder) == 0
                safe_uialert(d, 'Please choose an export folder.', 'Export');
                return;
            end
            try
                if exist(export_folder, 'dir') ~= 7
                    mkdir(export_folder);
                end
            catch ME
                safe_uialert(d, sprintf('Failed to create folder:\n%s', ME.message), 'Export');
                return;
            end

            base_name = string(strtrim(prefix_edit.Value));
            if strlength(base_name) == 0
                base_name = "results";
            end
            base_name = sanitize_filename(base_name);
            if stamp_chk.Value
                base_name = base_name + "_" + string(datestr(now, 'yyyymmdd_HHMMSS'));
            end

            export_prefs.folder = char(export_folder);
            export_prefs.prefix = char(strtrim(prefix_edit.Value));
            export_prefs.format = char(fmt_dd.Value);
            export_prefs.dpi = dpi_edit.Value;

            fmt = string(fmt_dd.Value);
            dpi = dpi_edit.Value;

            try
                if chk_phase.Value
                    export_single_axes(ax_phase, fullfile(export_folder, base_name + "_phase"), fmt, dpi);
                end
                if chk_forcing.Value
                    export_single_axes(ax_forcing, fullfile(export_folder, base_name + "_forcing"), fmt, dpi);
                end
                if chk_spec.Value
                    export_single_axes(ax_spectrum, fullfile(export_folder, base_name + "_spectrum"), fmt, dpi);
                end
                if chk_combo.Value
                    export_tiled_results(fullfile(export_folder, base_name + "_tiled"), fmt, dpi);
                end

                if chk_poincare.Value || chk_sgram.Value || chk_return.Value
                    data = get_plot_data_or_alert();
                    if isempty(data)
                        return;
                    end
                    if chk_poincare.Value
                        export_advanced_plot(@() create_poincare_figure(data, 'off'), fullfile(export_folder, base_name + "_poincare"), fmt, dpi);
                    end
                    if chk_sgram.Value
                        export_advanced_plot(@() create_spectrogram_figure(data, 'off'), fullfile(export_folder, base_name + "_spectrogram"), fmt, dpi);
                    end
                    if chk_return.Value
                        export_advanced_plot(@() create_returnmap_figure(data, 'off'), fullfile(export_folder, base_name + "_returnmap"), fmt, dpi);
                    end
                end
            catch ME
                safe_uialert(d, sprintf('Export failed.\n\nError: %s', ME.message), 'Export Error');
                return;
            end

            do_open_after = true;  % nothing to open here, just reuse pattern
            delete(d);
            safe_uialert(fig, sprintf('Export complete.\nFolder:\n%s', export_folder), 'Export Complete');
        end
    end

    function browse_export_folder(folder_edit)
        picked = uigetdir(folder_edit.Value, 'Select export folder');
        if isequal(picked, 0)
            return;
        end
        folder_edit.Value = picked;
    end

    function name = sanitize_filename(name)
        name = string(name);
        name = regexprep(name, '[\\/:*?"<>|]+', '_');
        name = regexprep(name, '\s+', '_');
        name = strip(name, '_');
        if strlength(name) == 0
            name = "results";
        end
        name = char(name);
    end

    function export_single_axes(source_ax, base_path_no_ext, fmt, dpi)
        % Export directly from the source axes for PNG/JPEG to avoid
        % creating a new figure() window (which triggers drawnow and can
        % invalidate a modal uifigure dialog that is still open).
        fmt = upper(string(fmt));
        switch fmt
            case "PNG"
                exportgraphics(source_ax, char(base_path_no_ext + ".png"), ...
                    'Resolution', dpi, 'BackgroundColor', 'white');
            case "JPEG"
                exportgraphics(source_ax, char(base_path_no_ext + ".jpg"), ...
                    'Resolution', dpi, 'BackgroundColor', 'white');
            case "MATLAB FIG"
                export_fig = figure('Visible', 'off', 'Color', 'w', ...
                    'Position', [100, 100, 1200, 800]);
                target_ax = axes(export_fig);
                copy_axes_contents(source_ax, target_ax);
                savefig(export_fig, char(base_path_no_ext + ".fig"));
                try, close(export_fig); catch, end
            otherwise
                error('Unsupported format: %s', fmt);
        end
    end

    function export_tiled_results(base_path_no_ext, fmt, dpi)
        fmt = upper(string(fmt));
        if ~strcmp(fmt, 'MATLAB FIG')
            % Build a stand-alone figure for the tiled layout.
            export_fig = figure('Visible', 'off', 'Color', 'w', ...
                'Position', [100, 100, 1400, 900]);
            export_layout = tiledlayout(export_fig, 2, 2, ...
                'Padding', 'compact', 'TileSpacing', 'compact');
            source_axes = {ax_phase, ax_forcing, ax_spectrum};
            for k = 1:numel(source_axes)
                target_ax = nexttile(export_layout);
                copy_axes_contents(source_axes{k}, target_ax);
            end
            exportgraphics(export_layout, char(base_path_no_ext + "." + lower(fmt(1:min(3,end)))), ...
                'Resolution', dpi, 'BackgroundColor', 'white');
            try, close(export_fig); catch, end
        else
            export_fig = figure('Visible', 'off', 'Color', 'w', ...
                'Position', [100, 100, 1400, 900]);
            export_layout = tiledlayout(export_fig, 2, 2, ...
                'Padding', 'compact', 'TileSpacing', 'compact');
            for k = 1:numel({ax_phase, ax_forcing, ax_spectrum})
                src = {ax_phase, ax_forcing, ax_spectrum};
                copy_axes_contents(src{k}, nexttile(export_layout));
            end
            savefig(export_fig, char(base_path_no_ext + ".fig"));
            try, close(export_fig); catch, end
        end
    end

    function export_advanced_plot(fig_factory, base_path_no_ext, fmt, dpi)
        f = fig_factory();
        export_any(f, base_path_no_ext, fmt, dpi);
        close(f);
    end

    function export_any(fig_handle, base_path_no_ext, fmt, dpi)
        fmt = upper(string(fmt));
        switch fmt
            case "PNG"
                exportgraphics(fig_handle, base_path_no_ext + ".png", 'Resolution', dpi);
            case "JPEG"
                exportgraphics(fig_handle, base_path_no_ext + ".jpg", 'Resolution', dpi);
            case "MATLAB FIG"
                savefig(fig_handle, base_path_no_ext + ".fig");
            otherwise
                error('Unsupported export format: %s', fmt);
        end
    end

    function open_modelshot_dialog()
        d = uifigure('Name', 'Export Simscape/Simulink Screenshot', 'Color', 'w', ...
            'Position', [280, 240, 660, 360], 'WindowStyle', 'modal');

        uilabel(d, 'Position', [24, 320, 90, 18], 'Text', 'Folder:');
        folder_edit = uieditfield(d, 'text', 'Position', [110, 316, 440, 24], ...
            'Value', export_prefs.folder);
        uibutton(d, 'push', 'Position', [562, 316, 76, 24], 'Text', 'Browse', ...
            'ButtonPushedFcn', @(~,~) browse_export_folder(folder_edit));

        uilabel(d, 'Position', [24, 284, 90, 18], 'Text', 'Base Name:');
        prefix_edit = uieditfield(d, 'text', 'Position', [110, 280, 240, 24], ...
            'Value', export_prefs.prefix);
        stamp_chk = uicheckbox(d, 'Position', [366, 280, 260, 24], ...
            'Value', true, 'Text', 'Append timestamp (recommended)');

        uilabel(d, 'Position', [24, 248, 90, 18], 'Text', 'Format:');
        fmt_dd = uidropdown(d, 'Position', [110, 244, 240, 26], ...
            'Items', {'PNG', 'JPEG', 'TIFF'}, 'Value', 'PNG');

        uilabel(d, 'Position', [366, 248, 50, 18], 'Text', 'DPI:');
        dpi_edit = uieditfield(d, 'numeric', 'Position', [412, 244, 120, 26], ...
            'Limits', [72 2400], 'RoundFractionalValues', 'on', 'Value', export_prefs.dpi);

        uilabel(d, 'Position', [24, 210, 110, 18], 'Text', 'Zoom (%):');
        zoom_edit = uieditfield(d, 'numeric', 'Position', [110, 206, 120, 26], ...
            'Limits', [10 400], 'RoundFractionalValues', 'on', 'Value', 250);
        fit_chk = uicheckbox(d, 'Position', [246, 206, 180, 24], ...
            'Value', false, 'Text', 'Fit system to page');
        uilabel(d, 'Position', [430, 210, 220, 18], 'Text', 'Tip: Zoom 250% + DPI 600+' , ...
            'FontColor', [0.25 0.35 0.55]);

        uilabel(d, 'Position', [24, 170, 260, 18], 'Text', 'Systems to capture:');
        chk_top = uicheckbox(d, 'Position', [30, 144, 280, 22], 'Value', true, ...
            'Text', sprintf('Top model (%s)', model_name));
        chk_rcx = uicheckbox(d, 'Position', [30, 120, 280, 22], 'Value', true, 'Text', 'Subsystem: RC_X');
        chk_rcy = uicheckbox(d, 'Position', [30, 96, 280, 22], 'Value', true, 'Text', 'Subsystem: RC_Y');

        open_chk = uicheckbox(d, 'Position', [330, 144, 300, 22], 'Value', false, ...
            'Text', 'Open model after export');

        export_btn = uibutton(d, 'push', 'Position', [388, 22, 120, 32], 'Text', 'Export', ...
            'FontWeight', 'bold', 'BackgroundColor', [0.18 0.53 0.89], 'FontColor', [1 1 1]);
        uibutton(d, 'push', 'Position', [518, 22, 120, 32], 'Text', 'Cancel', ...
            'ButtonPushedFcn', @(~,~) delete(d));

        export_btn.ButtonPushedFcn = @(~,~) do_export_modelshots();

        function do_export_modelshots()
            export_folder = string(strtrim(folder_edit.Value));
            if strlength(export_folder) == 0
                safe_uialert(d, 'Please choose an export folder.', 'Export');
                return;
            end
            try
                if exist(export_folder, 'dir') ~= 7
                    mkdir(export_folder);
                end
            catch ME
                safe_uialert(d, sprintf('Failed to create folder:\n%s', ME.message), 'Export');
                return;
            end

            base_name = string(strtrim(prefix_edit.Value));
            if strlength(base_name) == 0
                base_name = "model";
            end
            base_name = sanitize_filename(base_name);
            if stamp_chk.Value
                base_name = base_name + "_" + string(datestr(now, 'yyyymmdd_HHMMSS'));
            end

            export_prefs.folder = char(export_folder);
            export_prefs.prefix = char(strtrim(prefix_edit.Value));
            export_prefs.dpi = dpi_edit.Value;

            if ~(chk_top.Value || chk_rcx.Value || chk_rcy.Value)
                safe_uialert(d, 'Select at least one system to capture.', 'Export');
                return;
            end

            fmt = string(fmt_dd.Value);
            dpi = dpi_edit.Value;
            zoom_pct = zoom_edit.Value;
            fit_to_page = logical(fit_chk.Value);

            try
                ensure_model_loaded_for_snapshot();
                if chk_top.Value
                    export_simulink_snapshot(model_name, fullfile(export_folder, base_name + "_top"), fmt, dpi, zoom_pct, fit_to_page);
                end
                if chk_rcx.Value
                    export_simulink_snapshot(model_name + "/RC_X", fullfile(export_folder, base_name + "_RC_X"), fmt, dpi, zoom_pct, fit_to_page);
                end
                if chk_rcy.Value
                    export_simulink_snapshot(model_name + "/RC_Y", fullfile(export_folder, base_name + "_RC_Y"), fmt, dpi, zoom_pct, fit_to_page);
                end
            catch ME
                safe_uialert(d, sprintf('Model screenshot export failed.\n\nError: %s', ME.message), 'Export Error');
                return;
            end

            do_open = open_chk.Value;   % read BEFORE delete(d) destroys the widget
            delete(d);
            if do_open
                try, open_system(model_name); catch, end
            end
            uialert(fig, sprintf('Model screenshots exported.\nFolder:\n%s', export_folder), 'Export Complete');
        end
    end

    function safe_uialert(preferred_parent, message, title_text)
        parent = [];
        try
            if ~isempty(preferred_parent) && isvalid(preferred_parent) && isa(preferred_parent, 'matlab.ui.Figure')
                parent = preferred_parent;
            end
        catch
        end
        try
            if isempty(parent) && isvalid(fig) && isa(fig, 'matlab.ui.Figure')
                parent = fig;
            end
        catch
        end
        try
            if ~isempty(parent)
                uialert(parent, message, title_text);
            else
                warning('%s: %s', title_text, message);
            end
        catch
            warning('%s: %s', title_text, message);
        end
    end

    function ensure_model_loaded_for_snapshot()
        if bdIsLoaded(model_name)
            return;
        end
        if exist([model_name '.slx'], 'file') ~= 2
            error('Model file not found: %s.slx. Click Build first.', model_name);
        end
        load_system(model_name);
    end

    function export_simulink_snapshot(system_path, base_path_no_ext, fmt, dpi, zoom_pct, fit_to_page)
        ensure_model_loaded_for_snapshot();
        sys = char(system_path);
        fmt = upper(string(fmt));

        % Open the specific system so it is rendered on screen.
        try, open_system(sys); catch, end
        try, open_system(model_name); catch, end
        drawnow; pause(0.3);

        % Apply zoom.
        try
            if fit_to_page
                set_param(sys, 'ZoomFactor', 'FitSystem');
            else
                z = max(10, min(400, round(zoom_pct * max(1, min(3, dpi/200)))));
                set_param(sys, 'ZoomFactor', num2str(z));
            end
            drawnow; pause(0.1);
        catch, end

        ext = ''; driver = '';
        switch fmt
            case "PNG";  ext = '.png'; driver = '-dpng';
            case "JPEG"; ext = '.jpg'; driver = '-djpeg';
            case "TIFF"; ext = '.tif'; driver = '-dtiff';
            otherwise;   error('Unsupported format: %s', fmt);
        end
        out_path = char(base_path_no_ext + ext);

        % Method 1 — print -s: true rasterisation at requested DPI.
        % (prepare_diagram_for_export is disabled, so no Simscape-line crash.)
        captured = false;
        try
            print(['-s' sys], driver, sprintf('-r%d', round(dpi)), out_path);
            captured = (exist(out_path, 'file') == 2);
        catch
        end

        % Method 2 — getScreenshot: screen-resolution bitmap fallback.
        if ~captured
            img = [];
            try, img = Simulink.BlockDiagram.getScreenshot(sys); catch, end
            if isempty(img)
                try
                    drawnow; pause(0.4);
                    img = Simulink.BlockDiagram.getScreenshot(sys);
                catch, end
            end
            if ~isempty(img)
                try
                    switch fmt
                        case "PNG";  imwrite(img, out_path);
                        case "JPEG"; imwrite(img, out_path, 'Quality', 92);
                        case "TIFF"; imwrite(img, out_path, 'Compression', 'none');
                    end
                    captured = true;
                catch, end
            end
        end

        if ~captured
            error(['Could not capture "%s".\n' ...
                'Make sure the model is built first (click Build).\n' ...
                'Then try Model Shot with PNG format and DPI <= 300.'], sys);
        end
    end

    function cleanup_obj = prepare_diagram_for_export(sys)
        % Temporarily boosts visibility (fonts/lines/background) for publication-ready screenshots.
        % Restores all touched parameters automatically via onCleanup.
        touched = struct('path', {}, 'param', {}, 'value', {});
        function remember(p, prm)
            try
                touched(end+1).path = p; %#ok<AGROW>
                touched(end).param = prm;
                touched(end).value = get_param(p, prm);
            catch
            end
        end
        function setp(p, prm, val)
            remember(p, prm);
            try, set_param(p, prm, val); catch, end
        end

        % Background to pure white.
        bd = bdroot(sys);
        setp(bd, 'ScreenColor', 'white');

        % Increase overall zoom for subsystem captures if user picked FitSystem.
        % (FitSystem can still look "thin" on high-DPI; the line/font boosts below help.)

        % Boost font sizes and line widths for blocks inside the system.
        blocks = find_system(sys, 'SearchDepth', 1, 'Type', 'Block');
        for bi = 1:numel(blocks)
            b = blocks{bi};
            setp(b, 'FontName', 'Times New Roman');
            setp(b, 'FontSize', '14');
            setp(b, 'ForegroundColor', 'black');
            setp(b, 'BackgroundColor', 'white');
        end

        % Boost diagram line thickness and darken signal lines.
        % NOTE: Simscape physical connection lines do NOT support LineWidth/Color;
        % setting those properties on them crashes MATLAB. We skip any line that
        % does not accept the standard signal-line parameters.
        % Disabled: touching line handles can hard-crash MATLAB in some Simscape diagrams.
        if false
        lines = find_system(sys, 'FindAll', 'on', 'Type', 'Line');
        for li = 1:numel(lines)
            lh = lines(li);
            try
                % Only touch lines that carry Simulink signals (not Simscape connections).
                src_blk = get_param(lh, 'SrcBlockHandle');
                if src_blk == -1
                    continue;  % No valid source → physical/unconnected line, skip.
                end
                % Some releases expect numeric values (not strings) for LineWidth/Color.
                try, setp(lh, 'LineWidth', 2); catch, end
                try, setp(lh, 'Color', [0 0 0]); catch, end
            catch
                % Silently skip lines that reject these properties.
            end
        end
        end

        % Cleanup restores parameters in reverse order.
        cleanup_obj = onCleanup(@() restore_all());
        function restore_all()
            for ii = numel(touched):-1:1
                try
                    set_param(touched(ii).path, touched(ii).param, touched(ii).value);
                catch
                end
            end
        end
    end

    function copy_axes_contents(source_ax, target_ax)
        copied_children = copyobj(allchild(source_ax), target_ax);
        set(target_ax, 'Box', source_ax.Box, 'XGrid', source_ax.XGrid, 'YGrid', source_ax.YGrid, ...
            'XLim', source_ax.XLim, 'YLim', source_ax.YLim, 'FontSize', source_ax.FontSize);
        set_axes_latex(target_ax, source_ax.Title.String, source_ax.XLabel.String, source_ax.YLabel.String);
        target_ax.TickLabelInterpreter = 'latex';

        if ~isempty(copied_children)
            copied_children = flipud(copied_children);
            legend_children = copied_children(arrayfun(@(h) isprop(h, 'DisplayName'), copied_children));
            display_names = arrayfun(@(h) string(h.DisplayName), legend_children, 'UniformOutput', false);
            if any(~cellfun(@strlength, display_names))
                apply_latex_legend(legend(target_ax, 'show', 'Location', 'best'));
            end
        end
    end

    function val = safe_extract(sim_out, var_name)
        try
            obj = sim_out.get(var_name);
            if isa(obj, 'timeseries')
                val = obj.Data;
            else
                val = obj;
            end
            val = squeeze(val);
            val = val(:);
        catch
            val = [];
        end
    end

    function val = safe_extract_base(var_name)
        try
            val = evalin('base', var_name);
            val = squeeze(val);
            val = val(:);
        catch
            val = [];
        end
    end

    function val = extract_sim_output(sim_out, var_name)
        val = [];
        try
            val = sim_out.get(var_name);
        catch
        end
        if isempty(val)
            val = safe_extract_base(var_name);
            return;
        end
        try
            if isstruct(val) && isfield(val, 'signals') && isfield(val, 'time')
                val = val.signals.values;
            elseif isobject(val) && isprop(val, 'Data')
                val = val.Data;
            end
            val = squeeze(val);
            val = val(:);
        catch
            val = [];
        end
    end
end






