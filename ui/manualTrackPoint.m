function [tx,ty] = manualTrackPoint(varargin)
% function [tx,ty] = manualTrackPoint(aviname,step,[tx,ty])
% Tracks points through an avi, stepping every step frames.  tx and ty are
% defaults for previously clicked points.
%
% Mercurial revision hash: $Revision$ $Date$
% Copyright (c) 2010, Eric Tytell

global mmfile cur step off N imfiles;
global hImage;
global tx ty extrax extray;
global showPt;
global isadjust;

if (~isempty(varargin{1})),
    if (iscell(varargin{1}))
        imfiles = varargin{1};
        N = length(imfiles);
        mmfile = [];
    else
        aviname = varargin{1};
        mmfile = VideoReader2(aviname);
        N = get(mmfile,'NumberOfFrames');
    end;
	step = varargin{2};
	cur = 1;
	off = 0;
	isadjust = true;
    
    tx = NaN(1,N);
    ty = NaN(1,N);
    extrax = [];
    extray = [];
    
    i = 3;
    while (i <= nargin),
        if (ischar(varargin{i})),
            switch lower(varargin{i}),
                case 'extrapts',
                    extrax = varargin{i+1};
                    extray = varargin{i+2};
                    if (any(size(extrax) ~= size(extray)) || (size(extrax,2) ~= N)),
                        error('Extra points must be the same size and have the same number of frames as the AVI.');
                    end;
                    i = i+3;
                    
                otherwise,
                    error('Unrecognized argument %s.',varargin{i});
            end;
        elseif (isnumeric(varargin{i}) && (i+1 <= nargin) && isnumeric(varargin{i+1})),
            tx = varargin{i};
            ty = varargin{i+1};
            if ((length(tx) ~= length(ty)) || (length(tx) ~= N)),
                error('tx and ty must be the same length as the AVI.');
            end;
            i = i+2;
        end;
    end;
	
    if (isempty(mmfile))
        I = imread(imfiles{cur});
    else
        I = read(mmfile,cur);
    end;
    if isadjust
        I = imadjust(I,stretchlim(I),[]);
    end
	hImage = imshow(I,'InitialMagnification','fit');
    if isa(I,'uint16')
        caxis auto;
    end
	
	set(gcf, 'DoubleBuffer', 'on', ...
				'KeyPressFcn',		'manualTrackPoint([],''OnKeyPress'');');
	set(hImage, 'ButtonDownFcn',	'manualTrackPoint([],''OnClick'');');
	title('Return or ''q'' when done.  Arrows step. +- looks around current frame.  ''s'' toggles trail. ''c'' to increase contrast.');
    
	set(gcf,'Name',sprintf('Frame %d/%d',cur,N));

	showPt = 1;
	
	waitfor(gcf,'UserData','done');
	
	set(hImage, 'ButtonDownFcn', '');
	set(gcf, 'UserData', '', 'KeyPressFcn', '');
else
	try
		feval(varargin{2:end}); % FEVAL switchyard
	catch
		disp(lasterr);
	end;
end;

% ------------------------------------
function doUpdate

global mmfile cur step off N imfiles;
global tx ty extrax extray;
global hImage hPt hPtExtra;
global showPt;
global isadjust;

if (isempty(mmfile))
    I = imread(imfiles{cur+off});
else
    I = read(mmfile,cur+off);
end;
if isadjust
    I = adapthisteq(I,'range','original','cliplimit',0.05);
end
set(hImage, 'CData', I);
set(gcf,'Name',sprintf('Frame %d/%d',cur+off,N));

if (ishandle(hPt)),
	delete(hPt);
end;
if (ishandle(hPtExtra)),
    delete(hPtExtra);
end;
if (showPt),
	pt = cur + [-10:-1 1:10]*step;
	pt = pt((pt >= 1) & (pt <= N));
	if (off == 0),
		hPt = addplot(tx(pt),ty(pt),'y.-', tx(cur),ty(cur),'r.');
	else
		hPt = addplot(tx(pt),ty(pt),'y.-', tx(cur),ty(cur),'ro');
	end;	
	set(hPt, 'HitTest', 'off');
    
    if (~isempty(extrax)),
        hPtExtra = addplot(extrax(:,cur),extray(:,cur),'c.-');
        set(hPtExtra, 'HitTest','off');
    end;
end;

% ------------------------------------
function OnClick

global cur step off N;
global tx ty;

c = get(gca, 'CurrentPoint');
tx(cur) = c(1,1);
ty(cur) = c(1,2);

if (cur == N),
    set(gcf, 'UserData', 'done');
end;

cur = cur+step;
off = 0;

if (cur > N),
    cur = N;
end;

doUpdate;


% ------------------------------------
function OnKeyPress

global cur step off N;
global showPt;
global isadjust;

c = get(gcf,'CurrentCharacter');

switch lower(c),
    case char(13),
        set(gcf, 'UserData', 'done');
    case 'q',
        set(gcf, 'UserData', 'done');
    case char(28),				% left arrow
        cur = cur - step;
        off = 0;
        if (cur < 1),
            beep;
            cur = 1;
        end;
        doUpdate;
    case char(29),				% right arrow
        cur = cur + step;
        off = 0;
        if (cur > N),
            beep;
            cur = N;
        end;
        doUpdate;
    case '+',
        off = off + 1;
        if (cur+off > N),
            beep;
            off = off-1;
        end;
        doUpdate;
    case '-',
        off = off - 1;
        if (cur+off < 1),
            beep;
            off = off+1;
        end;
        doUpdate;
    case ' ',
        if (off ~= 0),
            off = 0;
            doUpdate;
        end;
    case 's',
        showPt = ~showPt;
        doUpdate;
    case 'g',
        fr = input('Frame? ');
        if ((fr >= 1) && (fr <= N)),
            cur = fr;
        else
            beep;
        end;
        
    case 'c',
        isadjust = ~isadjust;
        doUpdate;
        
end;

