function outputVideo = xyzToVideo(xyzFile)
% XYZToVideo creates a dual-view MP4 video from a multi-frame XYZ file.
%
% Usage:
%   xyzToVideo('trajectory.xyz')
%
%   outputVideo = xyzToVideo('trajectory.xyz')
%
% The video is saved in the same folder as the XYZ file:
%
%   trajectory.xyz -> trajectory.mp4
%
% Features:
%   - Exact top and side views
%   - Three-dimensional shaded atomic spheres
%   - Atom-colored bonds
%   - Bonds visible only between atomic surfaces
%   - Fixed limits throughout the trajectory
%   - Equal-sized top- and side-view panels
%   - Independent side-view magnification
%   - Optional frame and time display

%% ============================================================
% VIDEO SETTINGS
% =============================================================

fps = 10;

% Process every nth XYZ frame.
% 1 = every frame
% 2 = every second frame
% 5 = every fifth frame
frameStride = 1;

videoQuality = 95;

% Hold the final frame for this duration
finalFrameHold_s = 1.0;

% Figure dimensions in pixels
figureWidth = 1600;
figureHeight = 800;

% Use 'off' for potentially faster processing
figureVisibility = 'on';

%% ============================================================
% TIME SETTINGS
% =============================================================

showTime = true;

% Time interval between consecutive saved XYZ frames.
%
% Example:
% MD timestep = 0.5 fs
% Coordinates printed every 5 MD steps
% Time between XYZ frames = 2.5 fs
timePerXYZFrame_fs = 2.5;

%% ============================================================
% THREE-DIMENSIONAL ATOM RADII
% =============================================================

% Visual radii in Angstrom.
% These are rendering radii, not exact physical atomic radii.

carbonRadius_A = 0.47;
oxygenRadius_A = 0.50;
nitrogenRadius_A = 0.45;
hydrogenRadius_A = 0.25;
otherRadius_A = 0.40;

% Sphere surface resolution:
% 12 = moderately smooth and faster
% 18 = smooth
% 24 = very smooth, recommended for final video
% 32 = extremely smooth but considerably slower
sphereResolution = 24;

%% ============================================================
% ATOM COLORS
% =============================================================

carbonColor = [0.22, 0.22, 0.22];
oxygenColor = [0.92, 0.02, 0.02];
nitrogenColor = [0.05, 0.05, 0.60];
hydrogenColor = [0.95, 0.95, 0.95];
otherColor = [0.85, 0.10, 0.85];

%% ============================================================
% SPHERE LIGHTING
% =============================================================

atomAmbientStrength = 0.38;
atomDiffuseStrength = 0.82;
atomSpecularStrength = 0.30;
atomSpecularExponent = 20;

% 'dull' gives softer shading.
% 'shiny' gives stronger reflections.
materialType = 'dull';

%% ============================================================
% BOND SETTINGS
% =============================================================

% Fallback bond color if atom-colored bonds are disabled
bondColor = [0.15, 0.15, 0.15];

bondLineWidth = 4.0;

% Draw each half of a bond using the color of the connected atom
useAtomColoredBonds = true;

% Bond endpoints are placed slightly inside the atom surfaces.
%
% 1.00 = endpoint at the nominal sphere surface
% 0.88 = endpoint slightly inside the sphere
%
% The spheres are drawn after the bonds, so the line ends are
% hidden inside the atomic spheres.
bondSurfaceFactor = 0.88;

%% ============================================================
% BOND DETECTION CUTOFFS
% =============================================================

useElementSpecificCutoffs = true;

defaultBondCutoff_A = 1.65;

CCcutoff_A = 1.75;
COcutoff_A = 1.85;
OOcutoff_A = 1.70;
CHcutoff_A = 1.25;
OHcutoff_A = 1.25;
NHcutoff_A = 1.25;
CNcutoff_A = 1.75;
NOcutoff_A = 1.75;

maximumBondsPerFrame = 1500;

%% ============================================================
% COORDINATE DISPLAY
% =============================================================

% Extra margin around all atomic coordinates
axisMargin_A = 0.55;

% Use fixed manual limits if needed
useManualLimits = false;

manualXLimits = [-7, 7];
manualYLimits = [-6, 6];
manualZLimits = [0, 24];

%% ============================================================
% VIEW SETTINGS
% =============================================================

% Exact top view
topAzimuth = 0;
topElevation = 90;

% Exact side view
sideAzimuth = 0;
sideElevation = 0;

topViewTitle = 'Top view';
sideViewTitle = 'Side view';

% Orthographic projection avoids perspective distortion
projectionType = 'orthographic';

backgroundColor = [1, 1, 1];

titleFontSize = 16;
mainTitleFontSize = 17;

%% ============================================================
% SIDE-VIEW SIZE CONTROL
% =============================================================

% This changes only the apparent size of the structure inside
% the side-view panel.
%
% The panel position and panel dimensions remain unchanged.
%
% 1.00 = original side-view size
% 0.85 = slightly smaller
% 0.72 = recommended
% 0.60 = considerably smaller
% 0.50 = very small

sideViewZoom = 0.65;

%% ============================================================
% PANEL POSITIONS
% =============================================================

% Equal-sized manually positioned panels with essentially no
% unused central gap.

topAxisPosition = [0.005, 0.06, 0.495, 0.86];
sideAxisPosition = [0.500, 0.06, 0.495, 0.86];

%% ============================================================
% SELECT OR CHECK XYZ FILE
% =============================================================

if nargin < 1 || isempty(xyzFile)

    [selectedFile, selectedFolder] = uigetfile( ...
        {'*.xyz', 'XYZ trajectory files (*.xyz)'}, ...
        'Select an XYZ trajectory');

    if isequal(selectedFile, 0)
        error('No XYZ file was selected.');
    end

    xyzFile = fullfile(selectedFolder, selectedFile);
end

if isstring(xyzFile)
    xyzFile = char(xyzFile);
end

if ~exist(xyzFile, 'file')
    error('The XYZ file does not exist: %s', xyzFile);
end

[fileFolder, baseName, fileExtension] = fileparts(xyzFile);

if isempty(fileFolder)

    fileFolder = pwd;

    xyzFile = fullfile( ...
        fileFolder, ...
        [baseName, fileExtension]);
end

if ~strcmpi(fileExtension, '.xyz')
    error('The input file must have an .xyz extension.');
end

outputVideo = fullfile( ...
    fileFolder, ...
    [baseName, '.mp4']);

fprintf('\n');
fprintf('====================================================\n');
fprintf('XYZ trajectory video generator\n');
fprintf('====================================================\n');
fprintf('Input file:      %s\n', xyzFile);
fprintf('Output file:     %s\n', outputVideo);
fprintf('Side-view zoom:  %.2f\n', sideViewZoom);
fprintf('====================================================\n');

%% ============================================================
% READ XYZ TRAJECTORY
% =============================================================

frames = readXYZTrajectoryLocal(xyzFile);

if isempty(frames)
    error('No valid XYZ frames were found in %s.', xyzFile);
end

originalNumberFrames = numel(frames);

selectedOriginalIndices = ...
    1:frameStride:originalNumberFrames;

frames = frames(selectedOriginalIndices);

numberFrames = numel(frames);

referenceAtomCount = ...
    size(frames(1).coordinates, 1);

referenceSymbols = frames(1).symbols;

fprintf('Original frames: %d\n', originalNumberFrames);
fprintf('Frames selected: %d\n', numberFrames);
fprintf('Atoms per frame: %d\n', referenceAtomCount);

%% ============================================================
% VALIDATE FRAMES
% =============================================================

validFrames = true(numberFrames, 1);

for iFrame = 1:numberFrames

    currentAtomCount = ...
        size(frames(iFrame).coordinates, 1);

    if currentAtomCount ~= referenceAtomCount

        warning(['Frame %d contains %d atoms instead of %d. ', ...
            'The frame will be skipped.'], ...
            iFrame, currentAtomCount, referenceAtomCount);

        validFrames(iFrame) = false;
        continue;
    end

    if ~isequal(frames(iFrame).symbols, referenceSymbols)

        warning(['Element ordering differs in frame %d. ', ...
            'The frame will still be processed.'], ...
            iFrame);
    end
end

frames = frames(validFrames);

selectedOriginalIndices = ...
    selectedOriginalIndices(validFrames);

numberFrames = numel(frames);

if numberFrames == 0
    error('No valid and consistent XYZ frames remain.');
end

%% ============================================================
% CALCULATE FIXED COORDINATE LIMITS
% =============================================================

allCoordinates = [];

for iFrame = 1:numberFrames

    allCoordinates = [ ...
        allCoordinates; ...
        frames(iFrame).coordinates]; %#ok<AGROW>
end

if useManualLimits

    xLimits = manualXLimits;
    yLimits = manualYLimits;
    zLimits = manualZLimits;

else

    largestRadius = max([ ...
        carbonRadius_A, ...
        oxygenRadius_A, ...
        nitrogenRadius_A, ...
        hydrogenRadius_A, ...
        otherRadius_A]);

    totalMargin = axisMargin_A + largestRadius;

    xLimits = [ ...
        min(allCoordinates(:,1)) - totalMargin, ...
        max(allCoordinates(:,1)) + totalMargin];

    yLimits = [ ...
        min(allCoordinates(:,2)) - totalMargin, ...
        max(allCoordinates(:,2)) + totalMargin];

    zLimits = [ ...
        min(allCoordinates(:,3)) - totalMargin, ...
        max(allCoordinates(:,3)) + totalMargin];
end

% Avoid invalid zero-width coordinate ranges

if diff(xLimits) < 0.1
    xLimits = xLimits + [-1, 1];
end

if diff(yLimits) < 0.1
    yLimits = yLimits + [-1, 1];
end

if diff(zLimits) < 0.1
    zLimits = zLimits + [-1, 1];
end

fprintf('x range: %.3f to %.3f Angstrom\n', ...
    xLimits(1), xLimits(2));

fprintf('y range: %.3f to %.3f Angstrom\n', ...
    yLimits(1), yLimits(2));

fprintf('z range: %.3f to %.3f Angstrom\n', ...
    zLimits(1), zLimits(2));

%% ============================================================
% PRECOMPUTE BONDS
% =============================================================

fprintf('Precomputing bonds...\n');

allBondPairs = cell(numberFrames, 1);

for iFrame = 1:numberFrames

    coordinates = frames(iFrame).coordinates;
    symbols = frames(iFrame).symbols;

    bondPairs = calculateBondPairsLocal( ...
        coordinates, ...
        symbols, ...
        useElementSpecificCutoffs, ...
        defaultBondCutoff_A, ...
        CCcutoff_A, ...
        COcutoff_A, ...
        OOcutoff_A, ...
        CHcutoff_A, ...
        OHcutoff_A, ...
        NHcutoff_A, ...
        CNcutoff_A, ...
        NOcutoff_A);

    if size(bondPairs, 1) > maximumBondsPerFrame

        warning(['Frame %d contains %d proposed bonds. ', ...
            'Only the first %d will be displayed.'], ...
            iFrame, ...
            size(bondPairs,1), ...
            maximumBondsPerFrame);

        bondPairs = ...
            bondPairs(1:maximumBondsPerFrame, :);
    end

    allBondPairs{iFrame} = bondPairs;
end

%% ============================================================
% CREATE VIDEO WRITER
% =============================================================

try

    videoObject = VideoWriter( ...
        outputVideo, ...
        'MPEG-4');

catch

    warning(['MPEG-4 is unavailable. ', ...
        'Motion JPEG AVI will be used instead.']);

    outputVideo = fullfile( ...
        fileFolder, ...
        [baseName, '.avi']);

    videoObject = VideoWriter( ...
        outputVideo, ...
        'Motion JPEG AVI');
end

videoObject.FrameRate = fps;

if isprop(videoObject, 'Quality')
    videoObject.Quality = videoQuality;
end

open(videoObject);

%% ============================================================
% CREATE FIGURE
% =============================================================

videoFigure = figure( ...
    'Color', backgroundColor, ...
    'Position', [50, 50, figureWidth, figureHeight], ...
    'Visible', figureVisibility, ...
    'Renderer', 'opengl', ...
    'GraphicsSmoothing', 'on');

%% ============================================================
% GENERATE VIDEO FRAMES
% =============================================================

for iFrame = 1:numberFrames

    if iFrame == 1 || ...
            mod(iFrame, 10) == 0 || ...
            iFrame == numberFrames

        fprintf('Writing frame %d of %d\n', ...
            iFrame, numberFrames);
    end

    clf(videoFigure);

    coordinates = frames(iFrame).coordinates;
    symbols = frames(iFrame).symbols;
    bondPairs = allBondPairs{iFrame};

    %% --------------------------------------------------------
    % Create equal-sized manually positioned panels
    % ---------------------------------------------------------

    topAxis = axes( ...
        'Parent', videoFigure, ...
        'Position', topAxisPosition);

    sideAxis = axes( ...
        'Parent', videoFigure, ...
        'Position', sideAxisPosition);

    %% ========================================================
    % TOP VIEW
    % =========================================================

    drawAtomicStructureLocal( ...
        topAxis, ...
        coordinates, ...
        symbols, ...
        bondPairs, ...
        carbonColor, ...
        oxygenColor, ...
        nitrogenColor, ...
        hydrogenColor, ...
        otherColor, ...
        carbonRadius_A, ...
        oxygenRadius_A, ...
        nitrogenRadius_A, ...
        hydrogenRadius_A, ...
        otherRadius_A, ...
        sphereResolution, ...
        bondColor, ...
        bondLineWidth, ...
        bondSurfaceFactor, ...
        useAtomColoredBonds, ...
        atomAmbientStrength, ...
        atomDiffuseStrength, ...
        atomSpecularStrength, ...
        atomSpecularExponent);

    view(topAxis, topAzimuth, topElevation);

    xlim(topAxis, xLimits);
    ylim(topAxis, yLimits);
    zlim(topAxis, zLimits);

    axis(topAxis, 'equal');
    axis(topAxis, 'vis3d');

    % Restore limits after axis equal
    xlim(topAxis, xLimits);
    ylim(topAxis, yLimits);
    zlim(topAxis, zLimits);

    axis(topAxis, 'off');

    set(topAxis, ...
        'Projection', projectionType, ...
        'Color', backgroundColor, ...
        'Clipping', 'on');

    % shading(topAxis, 'interp');
    lighting(topAxis, 'gouraud');
    material(topAxis, materialType);

    camlight(topAxis, 'headlight');
    camlight(topAxis, -35, 30);

    title(topAxis, topViewTitle, ...
        'FontSize', titleFontSize, ...
        'FontWeight', 'bold', ...
        'Units', 'normalized', ...
        'Position', [0.5, 0.96, 0]);

    %% ========================================================
    % SIDE VIEW
    % =========================================================

    drawAtomicStructureLocal( ...
        sideAxis, ...
        coordinates, ...
        symbols, ...
        bondPairs, ...
        carbonColor, ...
        oxygenColor, ...
        nitrogenColor, ...
        hydrogenColor, ...
        otherColor, ...
        carbonRadius_A, ...
        oxygenRadius_A, ...
        nitrogenRadius_A, ...
        hydrogenRadius_A, ...
        otherRadius_A, ...
        sphereResolution, ...
        bondColor, ...
        bondLineWidth, ...
        bondSurfaceFactor, ...
        useAtomColoredBonds, ...
        atomAmbientStrength, ...
        atomDiffuseStrength, ...
        atomSpecularStrength, ...
        atomSpecularExponent);

    view(sideAxis, sideAzimuth, sideElevation);

    xlim(sideAxis, xLimits);
    ylim(sideAxis, yLimits);
    zlim(sideAxis, zLimits);

    axis(sideAxis, 'equal');
    axis(sideAxis, 'vis3d');

    % Restore limits after axis equal
    xlim(sideAxis, xLimits);
    ylim(sideAxis, yLimits);
    zlim(sideAxis, zLimits);

    axis(sideAxis, 'off');

    set(sideAxis, ...
        'Projection', projectionType, ...
        'Color', backgroundColor, ...
        'Clipping', 'on');

    % Reduce only the apparent size of the side-view structure.
    % The panel position and dimensions do not change.
    camzoom(sideAxis, sideViewZoom);

    % shading(sideAxis, 'interp');
    lighting(sideAxis, 'gouraud');
    material(sideAxis, materialType);

    camlight(sideAxis, 'headlight');
    camlight(sideAxis, 35, 25);

    title(sideAxis, sideViewTitle, ...
        'FontSize', titleFontSize, ...
        'FontWeight', 'bold', ...
        'Units', 'normalized', ...
        'Position', [0.5, 0.96, 0]);

    %% ========================================================
    % VIDEO TITLE
    % =========================================================

    if showTime

        currentOriginalFrame = ...
            selectedOriginalIndices(iFrame);

        currentTime_fs = ...
            (currentOriginalFrame - 1) * ...
            timePerXYZFrame_fs;

        mainTitle = sprintf( ...
            '%s | Frame %d/%d | Time = %.1f fs', ...
            strrep(baseName, '_', '\_'), ...
            iFrame, ...
            numberFrames, ...
            currentTime_fs);

    else

        mainTitle = sprintf( ...
            '%s | Frame %d/%d', ...
            strrep(baseName, '_', '\_'), ...
            iFrame, ...
            numberFrames);
    end

    sgtitle(videoFigure, mainTitle, ...
        'FontSize', mainTitleFontSize, ...
        'FontWeight', 'bold');

    %% Capture and write video frame

    drawnow;

    movieFrame = getframe(videoFigure);

    writeVideo(videoObject, movieFrame);
end

%% ============================================================
% HOLD FINAL FRAME
% =============================================================

numberFinalCopies = round( ...
    finalFrameHold_s * fps);

if numberFinalCopies > 0

    finalMovieFrame = getframe(videoFigure);

    for iCopy = 1:numberFinalCopies
        writeVideo(videoObject, finalMovieFrame);
    end
end

%% ============================================================
% CLOSE VIDEO
% =============================================================

close(videoObject);
close(videoFigure);

fprintf('====================================================\n');
fprintf('Video completed successfully:\n%s\n', ...
    outputVideo);
fprintf('====================================================\n');

end

%% ============================================================
% READ MULTI-FRAME XYZ TRAJECTORY
% =============================================================

function frames = readXYZTrajectoryLocal(filename)

frames = struct( ...
    'symbols', {}, ...
    'coordinates', {}, ...
    'comment', {});

fid = fopen(filename, 'r');

if fid == -1
    error('Cannot open XYZ file: %s', filename);
end

while true

    line = fgetl(fid);

    if ~ischar(line)
        break;
    end

    line = strtrim(line);

    if isempty(line)
        continue;
    end

    numberAtoms = str2double(line);

    if isnan(numberAtoms) || numberAtoms <= 0
        continue;
    end

    commentLine = fgetl(fid);

    if ~ischar(commentLine)
        break;
    end

    symbols = cell(numberAtoms, 1);
    coordinates = nan(numberAtoms, 3);

    validFrame = true;

    for iAtom = 1:numberAtoms

        atomLine = fgetl(fid);

        if ~ischar(atomLine)

            validFrame = false;
            break;
        end

        atomLine = strtrim(atomLine);

        if isempty(atomLine)

            validFrame = false;
            break;
        end

        parts = strsplit(atomLine);

        if numel(parts) < 4

            validFrame = false;
            break;
        end

        symbols{iAtom} = parts{1};

        coordinates(iAtom,1) = ...
            str2double(parts{2});

        coordinates(iAtom,2) = ...
            str2double(parts{3});

        coordinates(iAtom,3) = ...
            str2double(parts{4});

        if any(~isfinite(coordinates(iAtom,:)))

            validFrame = false;
            break;
        end
    end

    if validFrame

        frame.symbols = symbols;
        frame.coordinates = coordinates;
        frame.comment = commentLine;

        frames(end+1) = frame; %#ok<AGROW>
    end
end

fclose(fid);

end

%% ============================================================
% CALCULATE BONDS
% =============================================================

function bondPairs = calculateBondPairsLocal( ...
    coordinates, ...
    symbols, ...
    useElementSpecificCutoffs, ...
    defaultBondCutoff_A, ...
    CCcutoff_A, ...
    COcutoff_A, ...
    OOcutoff_A, ...
    CHcutoff_A, ...
    OHcutoff_A, ...
    NHcutoff_A, ...
    CNcutoff_A, ...
    NOcutoff_A)

numberAtoms = size(coordinates,1);

bondPairs = zeros(0,2);

for iAtom = 1:numberAtoms-1

    for jAtom = iAtom+1:numberAtoms

        displacement = ...
            coordinates(iAtom,:) - ...
            coordinates(jAtom,:);

        distance = sqrt(sum(displacement.^2));

        bondCutoff = defaultBondCutoff_A;

        if useElementSpecificCutoffs

            element1 = upper(strtrim(symbols{iAtom}));
            element2 = upper(strtrim(symbols{jAtom}));

            if strcmp(element1,'C') && ...
                    strcmp(element2,'C')

                bondCutoff = CCcutoff_A;

            elseif isElementPairLocal( ...
                    element1, element2, 'C', 'O')

                bondCutoff = COcutoff_A;

            elseif strcmp(element1,'O') && ...
                    strcmp(element2,'O')

                bondCutoff = OOcutoff_A;

            elseif isElementPairLocal( ...
                    element1, element2, 'C', 'H')

                bondCutoff = CHcutoff_A;

            elseif isElementPairLocal( ...
                    element1, element2, 'O', 'H')

                bondCutoff = OHcutoff_A;

            elseif isElementPairLocal( ...
                    element1, element2, 'N', 'H')

                bondCutoff = NHcutoff_A;

            elseif isElementPairLocal( ...
                    element1, element2, 'C', 'N')

                bondCutoff = CNcutoff_A;

            elseif isElementPairLocal( ...
                    element1, element2, 'N', 'O')

                bondCutoff = NOcutoff_A;
            end
        end

        if distance <= bondCutoff

            bondPairs(end+1,:) = ...
                [iAtom, jAtom]; %#ok<AGROW>
        end
    end
end

end

%% ============================================================
% CHECK ELEMENT PAIR
% =============================================================

function pairMatches = isElementPairLocal( ...
    element1, element2, target1, target2)

pairMatches = ...
    (strcmp(element1,target1) && ...
     strcmp(element2,target2)) || ...
    (strcmp(element1,target2) && ...
     strcmp(element2,target1));

end

%% ============================================================
% DRAW 3D ATOMS AND COLORED BONDS
% =============================================================

function drawAtomicStructureLocal( ...
    axisHandle, ...
    coordinates, ...
    symbols, ...
    bondPairs, ...
    carbonColor, ...
    oxygenColor, ...
    nitrogenColor, ...
    hydrogenColor, ...
    otherColor, ...
    carbonRadius_A, ...
    oxygenRadius_A, ...
    nitrogenRadius_A, ...
    hydrogenRadius_A, ...
    otherRadius_A, ...
    sphereResolution, ...
    bondColor, ...
    bondLineWidth, ...
    bondSurfaceFactor, ...
    useAtomColoredBonds, ...
    atomAmbientStrength, ...
    atomDiffuseStrength, ...
    atomSpecularStrength, ...
    atomSpecularExponent)

hold(axisHandle, 'on');

%% Draw shortened atom-colored bonds

for iBond = 1:size(bondPairs, 1)

    atom1 = bondPairs(iBond, 1);
    atom2 = bondPairs(iBond, 2);

    point1 = coordinates(atom1, :);
    point2 = coordinates(atom2, :);

    bondVector = point2 - point1;
    bondLength = norm(bondVector);

    if bondLength < 1.0e-12
        continue;
    end

    bondDirection = bondVector / bondLength;

    radius1 = getElementRadiusLocal( ...
        symbols{atom1}, ...
        carbonRadius_A, ...
        oxygenRadius_A, ...
        nitrogenRadius_A, ...
        hydrogenRadius_A, ...
        otherRadius_A);

    radius2 = getElementRadiusLocal( ...
        symbols{atom2}, ...
        carbonRadius_A, ...
        oxygenRadius_A, ...
        nitrogenRadius_A, ...
        hydrogenRadius_A, ...
        otherRadius_A);

    startPoint = point1 + ...
        bondSurfaceFactor * radius1 * bondDirection;

    endPoint = point2 - ...
        bondSurfaceFactor * radius2 * bondDirection;

    visibleVector = endPoint - startPoint;

    if dot(visibleVector, bondDirection) <= 0
        continue;
    end

    middlePoint = 0.5 * ...
        (startPoint + endPoint);

    if useAtomColoredBonds

        color1 = getElementColorLocal( ...
            symbols{atom1}, ...
            carbonColor, ...
            oxygenColor, ...
            nitrogenColor, ...
            hydrogenColor, ...
            otherColor);

        color2 = getElementColorLocal( ...
            symbols{atom2}, ...
            carbonColor, ...
            oxygenColor, ...
            nitrogenColor, ...
            hydrogenColor, ...
            otherColor);

    else

        color1 = bondColor;
        color2 = bondColor;
    end

    plot3( ...
        axisHandle, ...
        [startPoint(1), middlePoint(1)], ...
        [startPoint(2), middlePoint(2)], ...
        [startPoint(3), middlePoint(3)], ...
        '-', ...
        'Color', color1, ...
        'LineWidth', bondLineWidth);

    plot3( ...
        axisHandle, ...
        [middlePoint(1), endPoint(1)], ...
        [middlePoint(2), endPoint(2)], ...
        [middlePoint(3), endPoint(3)], ...
        '-', ...
        'Color', color2, ...
        'LineWidth', bondLineWidth);
end

%% Create one high-resolution unit sphere

[unitSphereX, unitSphereY, unitSphereZ] = ...
    sphere(sphereResolution);

%% Draw atoms as shaded 3D spheres

numberAtoms = size(coordinates, 1);

for iAtom = 1:numberAtoms

    atomColor = getElementColorLocal( ...
        symbols{iAtom}, ...
        carbonColor, ...
        oxygenColor, ...
        nitrogenColor, ...
        hydrogenColor, ...
        otherColor);

    atomRadius = getElementRadiusLocal( ...
        symbols{iAtom}, ...
        carbonRadius_A, ...
        oxygenRadius_A, ...
        nitrogenRadius_A, ...
        hydrogenRadius_A, ...
        otherRadius_A);

    sphereX = coordinates(iAtom, 1) + ...
        atomRadius * unitSphereX;

    sphereY = coordinates(iAtom, 2) + ...
        atomRadius * unitSphereY;

    sphereZ = coordinates(iAtom, 3) + ...
        atomRadius * unitSphereZ;

    atomSurface = surf( ...
        axisHandle, ...
        sphereX, ...
        sphereY, ...
        sphereZ);

    set(atomSurface, ...
        'FaceColor', atomColor, ...
        'EdgeColor', 'none', ...
        'FaceLighting', 'gouraud', ...
        'BackFaceLighting', 'reverselit', ...
        'AmbientStrength', atomAmbientStrength, ...
        'DiffuseStrength', atomDiffuseStrength, ...
        'SpecularStrength', atomSpecularStrength, ...
        'SpecularExponent', atomSpecularExponent, ...
        'Clipping', 'on');
end

axis(axisHandle, 'vis3d');

hold(axisHandle, 'off');

end

%% ============================================================
% GET ELEMENT COLOR
% =============================================================

function elementColor = getElementColorLocal( ...
    elementSymbol, ...
    carbonColor, ...
    oxygenColor, ...
    nitrogenColor, ...
    hydrogenColor, ...
    otherColor)

elementSymbol = upper(strtrim(elementSymbol));

switch elementSymbol

    case 'C'
        elementColor = carbonColor;

    case 'O'
        elementColor = oxygenColor;

    case 'N'
        elementColor = nitrogenColor;

    case 'H'
        elementColor = hydrogenColor;

    otherwise
        elementColor = otherColor;
end

end

%% ============================================================
% GET ELEMENT RENDERING RADIUS
% =============================================================

function atomRadius = getElementRadiusLocal( ...
    elementSymbol, ...
    carbonRadius_A, ...
    oxygenRadius_A, ...
    nitrogenRadius_A, ...
    hydrogenRadius_A, ...
    otherRadius_A)

elementSymbol = upper(strtrim(elementSymbol));

switch elementSymbol

    case 'C'
        atomRadius = carbonRadius_A;

    case 'O'
        atomRadius = oxygenRadius_A;

    case 'N'
        atomRadius = nitrogenRadius_A;

    case 'H'
        atomRadius = hydrogenRadius_A;

    otherwise
        atomRadius = otherRadius_A;
end

end