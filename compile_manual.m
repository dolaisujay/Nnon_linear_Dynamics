% COMPILE_MANUAL  Compile the LaTeX user manual to PDF using pdflatex.
%   Run this script from MATLAB. Requires MiKTeX or TeX Live to be installed
%   and on the system PATH.
%
%   Download MiKTeX (free, Windows): https://miktex.org/download
%   Download TeX Live (free, all OS): https://tug.org/texlive/
%
%   Usage:
%       >> cd('d:\path\to\Hybrid_VDP_Duffing_GUI_2RC_v1')
%       >> compile_manual
%
% SPDX-License-Identifier: MIT
% Copyright (c) 2024-2026 Sujay Kumar Dolai and Somnath Roy (Bigyanlabs R&D)
% See `LICENSE` for full terms.

function compile_manual()
    doc_dir = fullfile(fileparts(mfilename('fullpath')), 'docs');
    tex_file = fullfile(doc_dir, 'HybridVDPDuffing_Manual.tex');
    pdf_file = fullfile(doc_dir, 'HybridVDPDuffing_Manual.pdf');

    % Check pdflatex is available
    [st, ~] = system('where pdflatex');
    if st ~= 0
        fprintf('\n');
        fprintf('  pdflatex NOT found on your PATH.\n\n');
        fprintf('  To compile the manual to PDF, install one of:\n');
        fprintf('    * MiKTeX  (Windows): https://miktex.org/download\n');
        fprintf('    * TeX Live          : https://tug.org/texlive/\n\n');
        fprintf('  After installation, restart MATLAB and run compile_manual again.\n\n');
        fprintf('  Alternatively, upload HybridVDPDuffing_Manual.tex to:\n');
        fprintf('    * Overleaf (https://overleaf.com) and compile there.\n\n');
        return;
    end

    % Run twice so cross-references resolve
    for pass = 1:2
        cmd = sprintf('pdflatex -interaction=nonstopmode -output-directory "%s" "%s"', ...
                      doc_dir, tex_file);
        fprintf('Pass %d: %s\n', pass, cmd);
        [st2, out] = system(cmd);
        if st2 ~= 0 && pass == 2
            fprintf('LaTeX errors:\n%s\n', out);
            error('pdflatex returned error code %d on pass %d.', st2, pass);
        end
    end

    if isfile(pdf_file)
        fprintf('\nManual compiled successfully:\n  %s\n\n', pdf_file);
        % Open in default PDF viewer
        winopen(pdf_file);
    else
        error('PDF not produced. Check LaTeX log in: %s', doc_dir);
    end
end
