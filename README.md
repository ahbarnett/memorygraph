# memorygraph
MATLAB/octave unix tool to record true MATLAB/octave memory and CPU usage vs time

Alex Barnett 1/30/18

<img src="selftest.png" width="600"/>

One point of this tool is to be able to extract true peak RAM usage by
a MATLAB/ocatve code, without the need to continuously human-read (h)top.

### Usage

From MATLAB/octave,
to start a graph (starts recording to a temp file in current directory):

`memorygraph('start');`

This samples every 1 sec. If you want more often use, eg

`opts.dt = 0.1; memorygraph('start',opts);`

This, or smaller dt, may cause top to slow down the CPU.

To read off graph recorded so far:

`[bytes est_times cpu_times cpu_usages] = memorygraph('get');`

Outputs:

  `bytes` : total RAM used by MATLAB/octave, in bytes  
  `est_times` : estimated clock time in secs since graph started  
  `cpu_times` : MATLAB/octave CPU time used (counting all threads) reported by top  
  `cpu_usages` : current percentage CPU usage by MATLAB/octave at each time

To clean up (sadly, this kills all instances of `top` the user has!):

`memorygraph('done');`

Without args: does a self-test, produces the graph shown above.

### Notes:

- Linux/unix only. MATLAB or octave.  
- Very crude: assumes only one MATLAB instance per user, and no other instances of top running by user. Hard-coded temp-file. Etc.  
- If only a few secs have elapsed, the memory graph can come back empty. This is because of caching of the pipe to the temp file.  
- Max run time is baked in at 1e4 secs (about 3 hrs).  
- The 'top' display config must be standard (no changes to `/etc/toprc` nor `~/.toprc`).

### Issues:

- How do we get actual time without estimating?  
- How get PID of the top process to kill only it?  

Please contribute fixes for the above issues.
