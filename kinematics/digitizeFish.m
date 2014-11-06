function digitizeFish(datafile)
% function digitizeFish(datafile)
% datafile is a .mat file, which allows you to restart if you like.  If you
% don't pass it in, it creates a new file
% Copyright (c) 2013, Eric Tytell

Menu = {'C','Calibrate',@dfCalibrate; ...
        'H','Click head position',@dfHead; ...
        'T','Click tail position',@dfTail; ...
        'X','Click extra points',@dfExtraPoints; ...
        'S','Smooth head and tail positions',@dfSmoothPts; ...
        'V','Plot head velocity and acceleration',@dfPlotPts; ...
        'W','Get fish width',@dfWidth; ...
        '1','Click first midline',@dfFirstMidline; ...
        'B','Subtract background',@dfSubBack; ...
        'M','Digitize midline',@dfMidline; ...
        'A','Smooth midline',@dfSmoothMid; ...
        'K','Generate kinematic parameters',@dfAnalyze; ...
        'E','Save CSV file',@dfSaveCSV; ...
        'Q','Quit',[]};
NMenu = size(Menu,1);

%check about whether to start a new file or continue an old one
if (nargin == 0),
    butt = questdlg('Start new data file or continue old one?','Start',...
        'Start new','Continue old','Start new');
    switch butt,
        case 'Start new',
            [datafile,pathname] = uiputfile('*.mat','New data file name');
            
        case 'Continue old',
            [datafile,pathname] = uigetfile('*.mat');
    end;
    if (isnumeric(datafile) && (datafile == 0)),
        return;
    end;
    datafile = fullfile(pathname,datafile);
end;

%load in the file
if (exist(datafile,'file')),
	DF = load(datafile);
	DF.datafile = datafile;
else
	DF = struct('datafile',datafile,'step',1);
        [pn,fn,ext] = fileparts(datafile);
        datafilevar = genvarname(fn);
        DF.(datafilevar) = 1;
end;

%if we have an avi file name, check to make sure it exists
if (isfield(DF,'avifile') && exist(DF.avifile,'file')),
	isavi = true;
else
    isavi = false;
end;

%get a file if we don't have one
if (~isavi),
    [avifile,pathname] = uigetfile({'*.avi','AVI';'*.cine','Cine';...
        '*.mpg','MPG';'*.tif','TIFF';'*.im7','DaVis IM7'},'Choose movie file');
    if (isnumeric(avifile) && (avifile == 0)),
        return;
    end;
    DF.avifile = fullfile(pathname,avifile);
end;

%check which step we're on
if (~isfield(DF,'step')),
	DF.step = 1;
end;

%use the even newer VideoReader functions so that we can handle modern codecs
%but uncompressed files may cause a problem
DF.mmfile = VideoReader2(DF.avifile);
DF.nFrames = DF.mmfile.NumberOfFrames;
DF.fr = 1:DF.nFrames;

dfSaveData(DF);

%now the main loop - show the menu and wait for a selection
done = 0;
while (~done),
	DF.step = dfShowMenu(Menu, DF.step);
	
	if (DF.step == NMenu),
		done = 1;
		DF.step = 1;
	else
		DF = feval(Menu{DF.step,3}, DF);
	end;
	
	dfSaveData(DF);
	
	DF.step = DF.step+1;
end;

% ****************************
%Menu function.  Just shows a list of text options, with a star beside the
%current one
function choice = dfShowMenu(menu, def)

nMenu = size(menu,1);

stepstr = num2cell(repmat(' ',[nMenu 1]));
stepstr{def,1} = '*';

M = {stepstr{:}; menu{:,1}; menu{:,2}};

fprintf('Menu:\n');
fprintf('%s (%s) %s\n', M{:});

cmd = input('\nEnter command or hit return for default. ','s');
if (isempty(cmd)),
	choice = def;
else
	choice = strmatch(upper(cmd),menu(:,1));
	while (isempty(choice)),
		fprintf('Error: Unrecognized command %c\n',cmd);
		
		cmd = input('\nEnter command or hit return for default. ','s');
		choice = strmatch(upper(cmd),menu(:,1));
	end;
end; 

% ****************************
% Calibration function.  Allows a direct entry of a scale value,
% loading a scale from a file, clicking the scale on a ruler.  Also lets a
% second AVI file be calibrated relative to the main one
function DF = dfCalibrate(DF)

calMenu = {'V','Enter calibration value (mm/pix)', @dfCalibrateVal; ...
		   'F','Load calibration from file', @dfCalibrateFile; ...
		   'C','Click calibration points', @dfCalibrateClick; ...
           'N','No scale.  Use pixels.', @dfCalibrateNone; ...
		   'S','Add secondary avi file',@dfCalibrateAvi2; ...
		   'Q','Quit',[]};

if (isfield(DF,'scale')),
	def = 1;
else
	def = 2;
end;

c = dfShowMenu(calMenu, def);

if (c < length(calMenu)),
	DF = feval(calMenu{c,3},DF);
end;

if (~isfield(DF,'scale')),
	fprintf('Warning: No scale value saved.\n');
end;

fpsdefault = double(DF.mmfile.FrameRate);
fps = input(sprintf('Frames per second? (default %g) ', fpsdefault));
if (isempty(fps)),
    fps = fpsdefault;
end;
DF.fps = fps;

DF.t = DF.fr/DF.fps;

% ****************************
function DF = dfCalibrateVal(DF)

if (isfield(DF,'scale')),
	def = DF.scale;
else
	def = [];
end;
sc = input(sprintf('Calibration value (%fmm/pix): ',def));
if (isempty(sc)),
	sc = def;
end;
DF.scale = sc;

% ****************************
function DF = dfCalibrateFile(DF)

[pathname,fn] = fileparts(DF.datafile);
[fn,pn] = uigetfile('*.mat','Select calibration data file',[pathname '\\']);
fn = fullfile(pn,fn);
if (~isempty(fn)),
	F = load(fn,'*scale*');
	scalenames = fieldnames(F);
	if (~isfield(F,'scale') || (length(scalenames) > 1)),
		fprintf('File contains multiple scale variables:\n');
		fprintf('%s,', scalenames{:});
		
		nm = input('Enter the one you wish to use: ','s');
		
		scale = F.(nm);
	else
		scale = F.scale;
	end;
end;
DF.scale = scale;

% ****************************
function DF = dfCalibrateClick(DF)

[pathname,fn] = fileparts(DF.avifile);
[fn,pn] = uigetfile('*.tif;*.jpg;*.avi','Select calibration image or movie',[pathname '\\']);
fn = fullfile(pn,fn);

if (strcmpi(fn(end-2:end),'avi')),
    vid = VideoReader2(fn);
    fr = input('Which frame to load? ');
    if (isempty(fr) || ~isnumeric(fr))
        fr = 1;
    elseif (fr < 1) || (fr > vid.NumberOfFrames)
        error('Frame is out of range');
    end
    im = read(vid, fr);
    if (size(im,3) == 3),
        im = im(:,:,1);
    end;
    im = im2double(im);
    isImage = true;
else
    isImage = false;
end;

if (~isempty(fn)),
    dist = inputdlg('Distance to click on ruler in mm? ','Calibration',1,{'10'});
    dist = str2double(dist);
    
    if (isImage),
        [scale,scaleErr] = rulercalib(im, dist);
    else
        [scale,scaleErr] = rulercalib(fn, dist);
    end;        
	
	fprintf('Scale = %f+-%f\n', scale, scaleErr);
	
	c = input('Repeat?', 's');
	while (~isempty(c) && (lower(c(1)) == 'y')),
		[scale,scaleErr] = rulercalib(fn, dist);
		fprintf('Scale = %f+-%f\n', scale, scaleErr);
		c = input('Repeat?', 's');
	end;
end;

DF.scale = scale;
DF.scaleErr = scaleErr;

% ****************************
function DF = dfCalibrateNone(DF)

if (isfield(DF,'scale')),
    DF = rmfield(DF,'scale');
end;

% ****************************
function DF = dfCalibrateAvi2(DF)

[pn,fn,ext] = fileparts(DF.avifile);
[fn,pn] = uigetfile('*.avi','Select second AVI',[pn '\\']);
avi2file = fullfile(pn,fn);

vid = VideoReader2(avi2file);
if (vid.NumFrames ~= DF.nFrames),
	fprintf('Error: Avi files don''t match.\n');
	beep;
	return;
end;

DF.avi2file = avi2file;

[pn,fn,ext] = fileparts(DF.datafile);
[fn,pn] = uigetfile('*.mat','Select MAT file with AVI transform',[pn '\\']);
tformfile = fullfile(pn,fn);

F = load(tformfile,'tform*','TF');
tformnames = fieldnames(F);
if (isfield(F,'TF')),
    tfind = strmatch('TF',tformnames,'exact');
    tformnames = tformnames([1:tfind-1 tfind+1:end]);
    
    tfnames = fieldnames(F.TF);
    for i = 1:length(tfnames),
        tfnames{i} = strcat('TF.',tfnames{i});
    end;
    tformnames = cat(1,tformnames,tfnames);
end;
if (isempty(tformnames)),
	fprintf('Error: No transform structure in file.\n');
	beep;
	return;
elseif (length(tformnames) > 1),
    [tfind,ok] = listdlg('PromptString','Select transform:', ...
        'ListString',tformnames, ...
        'SelectionMode','single');
    if (~ok),
        fprintf('No transform selected.');
        return;
    end;
else
    tfind = 1;
end;

tformname = tformnames{tfind};
if ((length(tformname) > 3) && strcmp(tformname(1:3),'TF.')),
    DF.tform = F.TF.(tformname(4:end));
else
    DF.tform = F.(tformname);
end;

butt = questdlg('Transform type?','AVI 2 transform','Forward','Inverse','Forward');
switch butt,
    case 'Forward',
        DF.tformfcn = @tformfwd;
    case 'Inverse',
        DF.tformfcn = @tforminv;
end;



% ****************************
function DF = dfHead(DF)

if (~isfield(DF,'fps'))
    fprintf('You must select a calibration option before clicking points');
    return
end

skip = input('Frame skip? ');

fn = DF.avifile;
if (isfield(DF,'avi2file')),
	fnum = input('Which avi file (1 or 2)? ');
	if (fnum == 2),
		fn = DF.avi2file;
	end;
else
    fnum = 1;
end;

scrsz = get(0,'ScreenSize');
fig = figure;
%fig = figure('Position',[1 scrsz(4) scrsz(3) scrsz(4)], 'WindowStyle','normal');
clf;
[hx,hy] = manualTrackPoint(fn, skip);
close(fig);

if ((fnum == 2) && isfield(DF,'tform')),
	good = isfinite(hx);
	[hx(good), hy(good)] = feval(DF.tformfcn, DF.tform, hx(good), hy(good)); 
end;

DF.hx = hx;
DF.hy = hy;

% ****************************
function DF = dfTail(DF)

if (~isfield(DF,'fps'))
    fprintf('You must select a calibration option before clicking points');
    return
end

skip = input('Frame skip? ');
fn = DF.avifile;
if (isfield(DF,'avi2file')),
	fnum = input('Which avi file (1 or 2)? ');
	if (fnum == 2),
		fn = DF.avi2file;
	end;
else
    fnum = 1;
end;

scrsz = get(0,'ScreenSize');
fig = figure;
%fig = figure('Position',[1 scrsz(4) scrsz(3) scrsz(4)], 'WindowStyle','normal');
clf;
[tx,ty] = manualTrackPoint(fn, skip);
close(fig);

if (fnum == 2),
	good = isfinite(tx2);
	[tx(good),ty(good)] = feval(DF.tformfcn,DF.tform,tx(good),ty(good));
end;

DF.tx = tx;
DF.ty = ty;

% ****************************
function DF = dfExtraPoints(DF)

if (~isfield(DF,'fps'))
    fprintf('You must select a calibration option before clicking points');
    return
end

defname = [];
if (~isfield(DF,'ex') || isempty(DF.ex))
    DF.ex = NaN(0,DF.nFrames);
    DF.ey = NaN(0,DF.nFrames);
    DF.exptnames = cell(0,1);
    pt = 1;
else
    fprintf('You have %d extra points:\n', size(DF.ex,1));
    for i = 1:size(DF.ex,1)
        fprintf('  %d: %s\n', i, DF.exptnames{i});
    end
    pt = input('Choose point to modify, or hit return to add another point. ');
    if (isempty(pt) || ~isnumeric(pt) || (pt < 1) || (pt > size(DF.ex,1)))
        pt = size(DF.ex,1)+1;
    else
        defname = DF.exptnames{pt};
    end
end

if isempty(defname)
    defname = sprintf('pt%d',pt+1);
end
ptname = input(sprintf('Name of point (%s): ',defname),'s');
if isempty(ptname)
    ptname = defname;
end
    
skip = input('Frame skip? ');

fn = DF.avifile;
if (isfield(DF,'avi2file')),
	fnum = input('Which avi file (1 or 2)? ');
	if (fnum == 2),
		fn = DF.avi2file;
	end;
else
    fnum = 1;
end;

scrsz = get(0,'ScreenSize');
fig = figure;
%fig = figure('Position',[1 scrsz(4) scrsz(3) scrsz(4)], 'WindowStyle','normal');
clf;
[ex,ey] = manualTrackPoint(fn, skip);
close(fig);

if ((fnum == 2) && isfield(DF,'tform')),
	good = isfinite(ex);
	[ex(good), ey(good)] = feval(DF.tformfcn, DF.tform, ex(good), ey(good)); 
end;

if (all(~isfinite(ex)) && inputyn('No points were clicked.  Delete extra point completely? ','default',false))
    if (pt < size(DF.ex,1))
        DF.ex = DF.ex([1:pt-1 pt+1:end],:);
        DF.ey = DF.ey([1:pt-1 pt+1:end],:);
        DF.exptnames = DF.exptnames([1:pt-1 pt+1:end]);
    end
end

DF.ex(pt,:) = ex;
DF.ey(pt,:) = ey;
DF.exptnames{pt} = ptname;

% ****************************
function DF = dfSmoothPts(DF)

%get where the head and the tail both are clicked
kt = find(isfinite(DF.tx));
kh = find(isfinite(DF.hx));

%and look for how many frames separate each defined frame
d = diff(kh);

%find big gaps
dvals = unique(d);
nvals = zeros(size(dvals));
for i = 1:length(dvals),
    nvals(i) = sum(d == dvals(i));
end;

%find the biggest common gap
[~,ind] = max(dvals);
if (ind < length(dvals)),
    toobig = dvals(ind)+1;
    
    %build up a set of frames to interpolate.  Don't interpolate if the gap is
    %too big
    hspan = false(size(DF.hx));
    for i = 1:length(d),
        if (d(i) < toobig),
            hspan(kh(i):kh(i+1)) = true;
        end;
    end;
else
    hspan = false(size(DF.hx));
    hspan(kh(1):kh(end)) = true;
end;

%** same thing for the tail points
%and look for how many frames separate each defined frame
d = diff(kt);

%find big gaps
dvals = unique(d);
nvals = zeros(size(dvals));
for i = 1:length(dvals),
    nvals(i) = sum(d == dvals(i));
end;

%find the biggest common gap
[~,ind] = max(dvals);
if (ind < length(dvals)),
    toobig = dvals(ind+1);
    
    %build up a set of frames to interpolate.  Don't interpolate if the gap is
    %too big
    tspan = false(size(DF.tx));
    for i = 1:length(d),
        if (d(i) < toobig),
            tspan(kt(i):kt(i+1)) = true;
        end;
    end;
else
    tspan = false(size(DF.tx));
    tspan(kt(1):kt(end)) = true;
end;

k = hspan & tspan;

MSE = input('Smoothing value? (0.5) ');
if (isempty(MSE)),
    MSE = 0.5;
end;

hsp = spaps(DF.fr(kh), [DF.hx(kh); DF.hy(kh)], MSE(1)^2, 3, ...
    ones(size(kh))/length(kh));
tsp = spaps(DF.fr(kt), [DF.tx(kt); DF.ty(kt)], MSE(1)^2, 3, ...
    ones(size(kt))/length(kt));

hxs = NaN(size(DF.fr));
hys = NaN(size(DF.fr));
hxys = fnval(hsp, DF.fr(k));
hxs(k) = hxys(1,:);
hys(k) = hxys(2,:);
txs = NaN(size(DF.fr));
tys = NaN(size(DF.fr));
txys = fnval(tsp, DF.fr(k));
txs(k) = txys(1,:);
tys(k) = txys(2,:);

hus = NaN(size(DF.fr));
hvs = NaN(size(DF.fr));
huvs = fnval(fnder(hsp,1), DF.fr(k));
hus(k) = huvs(1,:);
hvs(k) = huvs(2,:);

haxs = NaN(size(DF.fr));
hays = NaN(size(DF.fr));
haxys = fnval(fnder(hsp,2), DF.fr(k));
haxs(k) = haxys(1,:);
hays(k) = haxys(2,:);

DF.hxs = hxs;
DF.hys = hys;
DF.hus = hus;
DF.hvs = hvs;
DF.haxs = haxs;
DF.hays = hays;

DF.txs = txs;
DF.tys = tys;

if (isfield(DF,'scale')),
	DF.hxmm = hxs*DF.scale;
	DF.hymm = hys*DF.scale;
	DF.humms = hus*DF.scale*DF.fps;
	DF.hvmms = hvs*DF.scale*DF.fps;
	DF.haxmmss = haxs*DF.scale*DF.fps^2;
	DF.haymmss = hays*DF.scale*DF.fps^2;
	
	DF.txmm = txs*DF.scale;
	DF.tymm = tys*DF.scale;
else
	fprintf('Warning: No scale value.  Please calibrate.\n');
end;

%smooth extra points if they exist
if isfield(DF,'ex')
    exs = NaN(size(DF.ex));
    eys = NaN(size(DF.ey));
    
    for i = 1:size(DF.ex,1)
        good = isfinite(DF.ex(i,:));
        span = first(good):last(good);
        esp = spaps(DF.fr(good), [DF.ex(i,good); DF.ey(i,good)], MSE(1)^2, 3, ...
            ones(1,sum(good))/sum(good));
        
        exys = fnval(esp, DF.fr(span));
        exs(i,span) = exys(1,:);
        eys(i,span) = exys(2,:);
    end
    
    DF.exs = exs;
    DF.eys = eys;
    
    if (isfield(DF,'scale'))
        DF.exmm = exs*DF.scale;
        DF.eymm = exs*DF.scale;
    end
end

% ****************************
function DF = dfPlotPts(DF)

if (nanmean2(abs(DF.hxs-DF.txs)) > nanmean2(abs(DF.hys-DF.tys))),
    ishoriz = true;
    if (isfield(DF,'scale')),
        hs = DF.hymm;
        h = DF.hy*DF.scale;
        ts = DF.tymm;
        t = DF.ty*DF.scale;
        
        u = DF.humms;
        a = DF.haxmmss;
        units = 'mm';
    else
        hs = DF.hys;
        h = DF.hy;
        ts = DF.tys;
        t = DF.ty;
        
        u = DF.hus;
        a = DF.haxs;
        units = 'pix';
    end;
else
    ishoriz = false;
    if (isfield(DF,'scale')),
        hs = DF.hxmm;
        h = DF.hx*DF.scale;
        ts = DF.txmm;
        t = DF.tx*DF.scale;

        u = DF.hvmms;
        a = DF.haymmss;
        units = 'mm';
    else
        hs = DF.hxs;
        h = DF.hx;
        ts = DF.txs;
        t = DF.tx;

        u = DF.hvs;
        a = DF.hays;
        units = 'pix';
    end;
end;

subplot(3,1,1);
plot(DF.t,h,'bo',DF.t,t,'ro',DF.t,hs,'k-',DF.t,ts,'k-');
if (isfield(DF,'ex'))
    if (ishoriz)
        addplot(DF.t,DF.ey,'+', DF.t,DF.eys,'b-');
    else
        addplot(DF.t,DF.ex,'+', DF.t,DF.exs,'b-');
    end        
end

legend('Head','Tail');
ylabel(['Position (' units ')']);

subplot(3,1,2);
plot(DF.t,u,'k-');
ylabel(['Velocity (' units '/s)']);

subplot(3,1,3);
plot(DF.t,a,'k-');
ylabel(['Acceleration (' units '/s^2)']);
xlabel('Time (s)');

% ****************************
function DF = dfWidth(DF)

calMenu = {'F','Load width from file', @dfWidthFile; ...
		   'W','Click width points', @dfWidthClick; ...
		   'Q','Quit',[]};

c = dfShowMenu(calMenu, 1);

if (c < length(calMenu)),
	DF = feval(calMenu{c,3},DF);
end;

% ****************************
function DF = dfWidthFile(DF)

[fn,pn] = uigetfile('*.mat','Width data file');
fn = fullfile(pn,fn);

F = load(fn,'width');
if (~isfield(F,'width'))
	fprintf('No width variable.\n');
else
    w = shiftdim(F.width);
    if (any(size(w) ~= [20 1])),
        if (all(size(w) == 1)),
            w = repmat(w,[20 1]);
        else
            s0 = linspace(0,1,length(w));
            s1 = linspace(0,1,20);
            w1 = spline(s0,w,s1);
            w = w1;
        end;
    end;
    DF.width = w;
end;

% ****************************
function DF = dfWidthClick(DF)

fprintf('Step to appropriate frame in movie.\n');
clf;
fr = multiplot({'m',DF.avifile});

reader = mmreader(DF.avifile);

I = im2double(read(reader, fr));

w = digitizeFishWidth(I,20);
w = makecol(w);
DF.width = w;

% ****************************
function DF = dfFirstMidline(DF)

reader = VideoReader2(DF.avifile);

frame = first(DF.fr,isfinite(DF.hxs));

I = im2double(read(reader, frame));
if (size(I,3) > 1),
    I = rgb2gray(I);
end;

clf;
imshow6(I,'n');

input('Zoom to fish and press return');

disp('Click some points along the midline (don''t need to be evenly spaced)');
done = false;
while (~done),
    [mx1,my1] = ginputb;
    
    done = inputyn('OK? ');
end;

%interpolate evenly spaced points
mx1 = makecol(mx1);
my1 = makecol(my1);
s1 = [0; cumsum(sqrt(diff(mx1).^2 + diff(my1).^2))];

sp = spaps(s1',[mx1 my1]',0.5^2);

s = linspace(0,max(s1),20);
xy = fnval(sp, s);

DF.mx1 = xy(1,:)';
DF.my1 = xy(2,:)';

% ****************************
function DF = dfSubBack(DF)

if ~inputyn('Subtract backgound? ', 'default',true)
    DF.background = [];
else
    done = false;
    while ~done
        n = input('How many frames to use to generate background image? (default = 10) ');
        if isempty(n)
            n = 10;
        end

        fr = linspace(1,DF.nFrames,n);
        fr = round(fr);
        back = zeros(DF.mmfile.Height, DF.mmfile.Width);

        timedWaitBar(0, 'Generating background image');
        for i = fr
            I1 = im2double(read(DF.mmfile, i));
            if (size(I1,3) == 3)
                I1 = rgb2gray(I1);
            end
            back = back + I1;
            timedWaitBar(i/DF.nFrames);
        end
        timedWaitBar(1);

        switch class(I1)
            case 'uint8'
                m = 255;
            case 'uint16'
                m = 65535;
            case 'double'
                m = 1;
        end
        back = back/n / m;
       
        imshow6(back);
        title('Average background');

        done = inputyn('Is background OK? ', 'default',true);
    end
    DF.background = back;
end

% ****************************
function DF = dfMidline(DF)

clf;

midfcns = {'getMidlineExt','getMidline4'};
sel = listdlg('PromptString','Midline tracking function:',...
                'SelectionMode','single',...
                'ListString',midfcns);
midfcn = midfcns{sel};

frame = first(DF.fr,isfinite(DF.hxs));
if (isfield(DF,'mx1') && ~isempty(DF.mx1))
    fishlenpix = sum(sqrt(diff(DF.mx1).^2 + diff(DF.my1).^2));
else
    fishlenpix = sqrt((DF.hxs(frame)-DF.txs(frame))^2 + (DF.hys(frame)-DF.tys(frame))^2);
end

if (isfield(DF,'scale')),
    fishlenmm = fishlenpix * DF.scale;
    units = 'mm';
else
    fishlenmm = fishlenpix;
    units = 'pix';
end;

opts = inputdlg({'Maximum segment angle (deg)?', ['Fish length (' units ')?'], ...
    'Number of points'}, ...
    'Midline finding paramaters',1,{'30',num2str(fishlenmm),'20'});
maxSegAng = str2double(opts{1}) * pi/180;
if (maxSegAng > pi),
    error('Maximum segment angle must be less than 180 deg.');
end;
fishlenmm = str2double(opts{2});
if (isempty(fishlenmm) || (fishlenmm == 0)),
    error('Midline requires an (approximate) fish length');
end;

npts = str2double(opts{3});

DF.fishlenmm = fishlenmm;
DF.fishlenpix = fishlenpix;
DF.npts = npts;

butt = questdlg('Silhouette type?','Midline','Black fish on white','White fish on black','Black fish on white');
switch butt,
    case 'Black fish on white',
        invert = true;
    case 'White fish on black',
        invert = false;
end;

if (isfield(DF,'avi2file')),
    [pn,fn1,ext] = fileparts(DF.avifile);
    [pn,fn2,ext] = fileparts(DF.avi2file);
    
    butt = questdlg('Which AVI file?',fn1,fn2,'Both','Both');
    switch butt,
        case fn1,
            avifile = DF.avifile;
        case fn2,
            avifile = DF.avi2file;
        case 'Both',
            avifile = '';
    end;
else
    avifile = DF.avifile;
end;

if (~isfield(DF,'background'))
    DF.background = [];
end

frames = DF.fr(isfinite(DF.hxs) & isfinite(DF.txs));
if (~isempty(avifile)),
    if (isfield(DF,'mx1') && strcmp(midfcn,'getMidline3')),
        firstmid = {'startmidline',DF.mx1,DF.my1};
    else
        firstmid = {};
    end;
    
    switch midfcn,
        case 'getMidlineExt',
            [mx,my] = getMidlineExt(avifile, frames, DF.hxs,DF.hys, DF.txs,DF.tys, npts, ...
                DF.width, DF.fishlenpix, maxSegAng, 'invert',invert, 'enforcetail', ...
                'noedges','nohomogeneity', 'subtractbackground',DF.background);
        case 'getMidline3',
            [mx,my] = getMidline3(avifile, frames, DF.hxs,DF.hys, DF.txs,DF.tys, npts, ...
                DF.width,DF.fishlenpix,...
                'invert',invert,'fps',DF.fps, firstmid{:});
        case 'getMidline4'
            if (~isfield(DF, 'mx1') || isempty(DF.mx1))
                warning('Must digitize the first midline before running getMidline4');
                mx = [];
                my = [];
            else
                if (length(DF.mx1) ~= npts)
                    s1 = [0; cumsum(sqrt(diff(DF.mx1).^2 + diff(DF.my1).^2))];
                    s2 = linspace(0,s1(end), npts);
                    
                    DF.mx1 = spline(s1, DF.mx1, s2);
                    DF.my1 = spline(s1, DF.my1, s2);
                end
                if (inputyn('Ignore pectoral fin region?'))
                    rgn = input('Pectoral fin region, in fraction of body length (default [0.3 0.55]): ');
                    if (length(rgn) ~= 2)
                        rgn = [0.25 0.6];
                    end
                else
                    rgn = [];
                end
                [mx,my] = getMidline4(avifile, frames, DF.hxs,DF.hys, DF.txs,DF.tys, ...
                    DF.mx1,DF.my1, npts, ...
                    DF.fishlenpix, maxSegAng, ...
                    'invert',invert, 'subtractbackground',DF.background, ...
                    'ignore',rgn);
            end
    end;
else
    mx = NaN([npts length(DF.hxs)]);
    my = NaN([npts length(DF.hxs)]);
    
    prevmx = linspace(DF.hxs(frames(1)),DF.txs(frames(1)), npts)';
    prevmy = linspace(DF.hxs(frames(1)),DF.txs(frames(1)), npts)';
    
    vid1 = VideoReader2(DF.avifile);
    ix1 = [1 vid1.Width];
    iy1 = [1 vid1.Height];
    
    vid2 = VideoReader2(DF.avi2file);
    [xcorner,ycorner] = feval(DF.tformfcn, DF.tform, [1 1 vid2.Width vid2.Width],...
        [1 vid2.Height vid2.Height 1]);
    ix2 = round([min(xcorner) max(xcorner)]);
    iy2 = round([min(ycorner) max(ycorner)]);
    
    ix0 = min([ix1 ix2]);
    ix1 = ix1 - ix0 + 1;
    ix2 = ix2 - ix0 + 1;
    iy0 = min([iy1 iy2]);
    iy1 = iy1 - iy0 + 1;
    iy2 = iy2 - iy0 + 1;
    
    I = zeros(range([ix1 ix2])+1, range([iy1 iy2])+1);
    
    for i = 1:length(frames),
        fr = frames(i);
        
        I(iy1(1):iy1(2), ix1(1):ix1(2)) = read(vid1, fr);        
        I2 = read(vid2, fr);
        I2 = imtransform(I2, 'XData',ix2+ix0-1, 'YData',iy2+ix0-1);
        I(iy2(1):iy2(2), ix2(1):ix2(2)) = I2;
        
        [mx(:,fr),my(:,fr)] = getMidlineExt(I, 1, DF.hxs(fr),DF.hys(fr), ...
            DF.txs(fr),DF.tys(fr), npts, DF.width,DF.fishlenpix,maxSegAng, ...
            'invert',invert, 'enforcetail','nohomogeneity','eqhist','useedges', ...
            'previousmidline',prevmx, prevmy, 'subtractbackground',DF.background);
        
        prevmx = mx(:,fr);
        prevmy = mx(:,fr);
    end;
end;

DF.mx = mx;
DF.my = my;


% ****************************
function DF = dfSmoothMid(DF)

serr1 = input('Spatial smoothing value (0.05): ');
if (isempty(serr1))
    DF.serr = 0.05;
else
    DF.serr = serr1;
end
terr1 = input('Temporal smoothing value (0.05): ');
if (isempty(terr1))
    DF.terr = 0.05;
else
    DF.terr = terr1;
end

if inputyn('Does the head go off the screen?','default',false)
    headopt = {'discardbadspacing',false, 'offscreen','head'};
else
    headopt = {};
end
[mxs,mys] = smoothEelMidline2(DF.fr, DF.mx,DF.my, DF.fishlenpix, DF.serr,DF.terr, ...
    headopt{:});

DF.mxs = mxs;
DF.mys = mys;

if (isfield(DF,'scale')),
    DF.mxmm = mxs*DF.scale;
    DF.mymm = mys*DF.scale;
end;

% ****************************
function DF = dfAnalyze(DF)

if (DF.fps > 100),
    smooth = 3;
else
    smooth = 0;
end;

if ((~isfield(DF,'mxs') && ~isfield(DF,'mys')) || ...
        ~inputyn('Analyze entire midline (Y), or just the tailbeat (n)?','default',false))
    if ~isfield(DF,'fishlenmm')
        DF.fishlenmm = input('Fish length in mm? ');
        DF.fishlenpix = DF.fishlenmm/DF.scale;
    end
    s = NaN(20,1);
    s([1 end]) = [0; DF.fishlenpix];
    if isfield(DF,'scale')
        smm = s*DF.scale;
        [indpeak,per,amp] = analyzeTailbeat(DF.fishlenmm,DF.t, DF.hxmm,DF.hymm,...
            DF.txmm,DF.tymm);
    else
        [indpeak,per,amp] = analyzeTailbeat(DF.fishlenmm,DF.t, DF.hxmm,DF.hymm,...
            DF.txmm,DF.tymm);
    end
    confpeak = [];
    midx = [];
    midy = [];
    exc = [];
    wavevel = [];
    wavelen = [];
    waver = [];
    waven = [];
else
    s = [zeros(1,size(DF.mx,2)); cumsum(sqrt(diff(DF.mxs).^2 + diff(DF.mys).^2))];

    if (isfield(DF,'scale')),
        if (istoolbox('statistics'))
            smm = nanmedian(s,2)*DF.scale;
        else
            smm = nanmedian2(s,2)*DF.scale;
        end

        [indpeak,confpeak, per,amp,midx,midy,exc,wavevel,wavelen,waver,waven] = ...
            analyzeKinematics(smm,DF.t,DF.mxmm,DF.mymm,'dtsmoothcurve',0.1);
    else
        [indpeak,confpeak, per,amp,midx,midy,exc,wavevel,wavelen,waver,waven] = ...
            analyzeKinematics(s,DF.t,DF.mxs,DF.mys,'dtsmoothcurve',0.1);
    end;
end

DF.s = s;
DF.smm = smm;
DF.indpeak = indpeak;
DF.confpeak = confpeak;
DF.per = per;
DF.amp = amp;
DF.midx = midx;
DF.midy = midy;
DF.exc = exc;
DF.wavevel = wavevel;
DF.wavelen = wavelen;
DF.waver = waver;
DF.waven = waven;

% ****************************
function DF = dfSaveCSV(DF)

[pn,fn,ext] = fileparts(DF.datafile);

csvfile = input(['Output file name (default = ' fn '.csv): '],'s');

if (isempty(csvfile)),
    csvfile = [fn '.csv'];
end
csvfile = fullfile(pn,csvfile);

saveKinematicsCSV(csvfile,DF.datafile);

% ****************************
function dfSaveData(DF)

save(DF.datafile,'-struct','DF', '-mat');


