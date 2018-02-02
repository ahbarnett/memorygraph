function [bytes estclock cput cpuu] = memorygraph(s,opts)
% MEMORYGRAPH  collect RAM usage over used time for MATLAB, from MATLAB.
%
% Usage:
% To start a graph (starts recording to a temp file in current directory):
%     memorygraph('start');
% This samples every 1 sec. If you want more often use, eg
%     opts.dt = 0.1; memorygraph('start',opts);
% This, or smaller dt, may cause top to slow down the CPU.
%
% To read off graph recorded so far:
%     [bytes est_times cpu_times cpu_usages] = memorygraph('get');
% Outputs:
%  bytes          = total RAM used by MATLAB, in bytes
%  est_times      = estimated clock time in secs since graph started
%  cpu_times      = MATLAB CPU time used (counting all threads) reported by top
%  cpu_usages     = current percentage CPU usage by MATLAB at each time
% One may do multiple such calls.
%
% To clean up (kills the spawned 'top' and 'grep' processes):
%     memorygraph('done');
%
% Without args: does a self-test, produces the graph shown in git repo.
%
% Notes:
% 0) Linux/unix only. MATLAB or octave.
% 1) Very crude: assumes no other instances of top running by user.
%    Hard-coded temp-file. Etc.
% 2) Max run time is baked in at 1e4 secs (about 3 hrs).
% 3) The 'top' display config must be standard (no changes to /etc/toprc
%    nor ~/.toprc).
%
% Todo:
% * How do we get actual timestamps without estimating?

% (C) Alex Barnett 1/30/18-2/1/18. Improvements by Joakim Anden, Jeremy Magland.

if nargin==0, test_memorygraph; return; end

bytes = []; estclock = []; cput = []; cpuu = [];

tempfile = 'memorygraph.tmp';  % hard-coded; hope doesn't overwrite something
if nargin<2, opts=[]; end
persistent dt top_pid

% decide what unix process id to search for: the current MATLAB/octave PID
pid = get_pid();   % see function defined below

if strcmp(s,'start')
  dt = 1.0;                      % default sampling interval in secs
  if isfield(opts,'dt'), dt=opts.dt; end
  top_cmd = sprintf('top -b -p %d -d %.1f -n 100000 | awk ''{$1=$1}1'' | grep --line-buffered "^%d" > %s',pid,dt,pid,tempfile);
  % change -n here for longest run; mostly to prevent running forever.
  % line-buffering needed otherwise have to wait for 4kB chunks.
  % Note: 'top' is better than 'ps' since it sums up child processes RAM and
  % CPU usage.
  % awk hack is needed to remove leading space
  % (grep "^%d" doesn't handle leading space)
  [~,out] = system(sprintf('%s & jobs -p',top_cmd)); % sim to Jeremy Magland...
  % But, using jobs gives the parent PID (top), which when killed also kills
  % the grep. However, if echo $! were used, it only gets PID of grep,
  % and the top is not killed.
  top_pid = str2double(strtrim(out));
  
elseif strcmp(s,'get')
  empty = true; count = 0;   % if no file yet, wait a bit...
  while (empty || count>=10)
    f = fopen(tempfile);      % read in temp text file
    c = textscan(f,'%d %s %d %d %s %s %d %s %f %f %s %s'); % let's hope no-one
        % changed the column ordering of the top command...
    fclose(f);
    empty = (numel(c)==0);
    pause(dt);
    count=count+1;
  end
  ba = c{6};   % cell array of mem strings. Assumes std "top" col ordering.
  ta = c{11};  % cell array of CPU time strings
  ca = c{9};   % double array of CPU usages
  n = min(numel(ba),numel(ta));    % # valid rows
  if n<1, warning('we waited, but no memorygraph data found!'); end
  estclock = (0:n-1)*dt;   % assume top outputs like clockwork
  for i=1:n
    b = ba{i};
    if b(end)=='t', by = 2^40*str2double(b(1:end-1));     % interpret TiB units
    elseif b(end)=='g', by = 2^30*str2double(b(1:end-1)); % GiB units
    elseif b(end)=='m', by = 2^20*str2double(b(1:end-1)); % MiB units
    else by = 2^10*str2double(b); end                     % KiB units
    bytes(i) = by;
    t = sscanf(ta{i},'%d:%d.%d',3);
    mins=t(1); secs=t(2);
    if numel(t)==3, hundr=t(3); else hundr=0; end   % get the uptime
    cput(i) = 60*mins + secs + hundr/100;
    cpuu(i) = ca(i);
  end

elseif strcmp(s,'done')
  system(sprintf('kill %d',top_pid));    % killing top also kills rest of pipe
  system(sprintf('rm -f %s',tempfile));
  
else error('unknown usage');
end

function pid = get_pid()
% Joakim Anden
if exist('OCTAVE_VERSION', 'builtin')
  pid = getpid();
else
  pid = feature('getpid');   % cute
end


%%%%%%%%%%%
function test_memorygraph
opts.dt = 0.1; memorygraph('start',opts);
disp('testing memorygraph: please wait 10 secs...')
pause(1)
a = randn(1,2e8);   % fill some RAM, not too fast (randn is single-threaded)
disp('randn done');
pause(1)
b = exp(a);         % use more cores
disp('exp done');
clear a             % check clearing is as expected
pause(1)
clear b
pause(1)
[b et ct c] = memorygraph('get');
memorygraph('done');
if isempty(b)
  disp('no data found! This shouldn''t happen')
else
  figure; subplot(1,2,1);
  plot(et,b,'.-'); xlabel('est elapsed time (s)'); ylabel('RAM used (bytes)');
  title('memorygraph self-test: RAM');
  subplot(1,2,2);
  plot(et,c,'.-'); xlabel('est elapsed time (s)'); ylabel('CPU usage (percent)');
  title('memorygraph self-test: CPU');
  disp('check the graph: RAM should go up ~3GB in two slopes, then jump down.');
  disp('CPU: a couple of secs of 100% (single core) then a couple of secs of all cores used, with 1-sec intervals in-between.');
end
  
% to check no remaining top running:  ps -e |grep " top"
