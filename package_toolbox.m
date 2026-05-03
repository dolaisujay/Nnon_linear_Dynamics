function package_toolbox()
% SPDX-License-Identifier: MIT
% Copyright (c) 2024-2026 Sujay Kumar Dolai and Somnath Roy (Bigyanlabs R&D)
% See `LICENSE` for full terms.

% PACKAGE_TOOLBOX  Build the protected Hybrid VDP-Duffing Toolbox (.mltbx).
%
%   The distributed package contains ONLY the p-code (.p) binary — the
%   source .m file is NEVER included.  Users can run the toolbox but
%   cannot read, edit, or inspect the source code.
%
%   Requirements:
%       MATLAB R2022a or later (for matlab.addons.toolbox API)
%
%   Usage:
%       >> cd('d:\SOMNATH DA\working April Final\working April Final\Hybrid_VDP_Duffing_GUI_2RC_v1')
%       >> package_toolbox

    src_dir  = fileparts(mfilename('fullpath'));
    dist_dir = fullfile(src_dir, 'dist');
    if ~isfolder(dist_dir)
        mkdir(dist_dir);
    end
    out_file = fullfile(dist_dir, 'Hybrid_VDP_Duffing_Toolbox_v2.1.0.mltbx');

    % ── Step 1: Generate fresh p-code from source ────────────────────────
    src_m = fullfile(src_dir, 'Hybrid_VDP_Duffing_GUI.m');
    src_p = fullfile(src_dir, 'Hybrid_VDP_Duffing_GUI.p');

    if ~isfile(src_m)
        error('Source file not found: %s', src_m);
    end

    fprintf('Generating p-code from source...\n');
    pcode(src_m, '-inplace');

    if ~isfile(src_p)
        error('P-code generation failed — %s not created.', src_p);
    end
    fprintf('  -> %s  (%.1f KB)\n', src_p, dir(src_p).bytes / 1024);

    % ── Step 2: Toolbox options ───────────────────────────────────────────
    opts = matlab.addons.toolbox.ToolboxOptions(src_dir, ...
        'b4c20a7e-1d3f-4a8b-9c6d-2e5f8a0b3c1d');   % Fixed GUID – keep same across versions

    opts.ToolboxName          = 'Hybrid VDP-Duffing Oscillator Workbench';
    opts.ToolboxVersion       = '2.1.0';
    opts.AuthorName           = 'Sujay Kumar Dolai & Somnath Roy';
    opts.AuthorEmail          = 'bigyanlabs@example.com';
    opts.AuthorCompany        = 'Bigyanlabs R&D';
    opts.Summary              = 'Hybrid Van der Pol-Duffing oscillator research GUI with Simscape RC networks';
    opts.Description          = fileread(fullfile(src_dir, 'Contents.m'));
    opts.MinimumMatlabRelease = 'R2022a';
    opts.MaximumMatlabRelease = '';

    % ── Step 3: File list — .p only, source .m excluded ──────────────────
    opts.ToolboxFiles = { ...
        src_p, ...                                      % protected binary ONLY
        fullfile(src_dir, 'Contents.m'), ...
        fullfile(src_dir, 'info.xml'), ...
        fullfile(src_dir, 'README.md') ...
    };

    % Include all files from the docs/ folder (manual PDF, tex source)
    doc_dir = fullfile(src_dir, 'docs');
    if isfolder(doc_dir)
        doc_files = dir(fullfile(doc_dir, '*'));
        for k = 1:numel(doc_files)
            if ~doc_files(k).isdir
                opts.ToolboxFiles{end+1} = fullfile(doc_dir, doc_files(k).name);
            end
        end
    end

    % ── Step 4: Package ───────────────────────────────────────────────────
    opts.OutputFile = out_file;

    fprintf('Packaging toolbox (protected)...\n');
    matlab.addons.toolbox.packageToolbox(opts);
    fprintf('Done.\n');
    fprintf('  Output : %s\n', out_file);
    fprintf('  Size   : %.1f KB\n', dir(out_file).bytes / 1024);
    fprintf('\nTo install:\n');
    fprintf('  matlab.addons.install(''%s'')\n\n', out_file);
    fprintf('NOTE: The .mltbx contains only p-code. Source .m is NOT distributed.\n');
end
