close all;
clear all;


allEventTypes = [-1 0 11 12 21 22 31 32 41 42 43 44 45 46]';
colorMap = [0, 0, 0; ...                    % OTHER, -1, black
            120.0, 0.4, 1.0; ...      % COMPUTE, 0, green
            240.0, 0.4, 1.0; ...      % MEM_IO, 11, blue
            240.0, 0.4, 1.0; ...      % GPU_MEM_IO, 12, blue
            180.0, 0.4, 1.0; ...      % NETWORK_IO, 21, cyan
            300.0, 0.4, 1.0; ...      % NETWORK_WAIT, 22, magenta
            60.0, 0.4, 1.0; ...       % FILE_I, 31, yellow
            0.0, 0.4, 1.0; ...        % FILE_O, 32, red
            180.0, 1.0, 1.0; ...      % ADIOS_INIT, 41, cyan
            300.0, 1.0, 1.0; ...      % ADIOS_OPEN, 42, magenta
            240.0, 1.0, 1.0; ...      % ADIOS_ALLOC, 43, blue
            60.0, 1.0, 1.0; ...       % ADIOS_WRITE, 44, yellow
            0.0, 1.0, 1.0; ...        % ADIOS_CLOSE, 45, red
            120.0, 1.0, 1.0; ...      % ADIOS_FINALIZE, 46, green
];
colorMap(:, 1) = colorMap(:, 1) / 180.0 * pi;  % in radian
allTypeNames = {'Other',...
    'Compute',...
    'Mem IO',...
    'GPU mem IO', ...
    'Network IO', ...
    'Network wait', ...
    'File read', ...
    'File write', ...
    'ADIOS init', ...
    'ADIOS open', ...
    'ADIOS alloc', ...
    'ADIOS write', ...
    'ADIOS close', ...
    'ADIOS finalize'};
        
dirs = {...
    '/home/tcpan/PhD/path/Data/adios/cci-gpu-clus-async', ...
    '/home/tcpan/PhD/path/Data/adios/yellowstone-async', ...
    '/home/tcpan/PhD/path/Data/adios/Jaguar-tcga4-grouped', ...
    '/home/tcpan/PhD/path/Data/adios/Jaguar-tcga3-grouped', ...
    '/home/tcpan/PhD/path/Data/adios/Jaguar-tcga2-grouped', ...
    '/home/tcpan/PhD/path/Data/adios/Jaguar-tcga1-grouped', ...
    '/home/tcpan/PhD/path/Data/adios/keeneland-tcga-small11-grouped-bench', ...
    '/home/tcpan/PhD/path/Data/adios/yellowstone', ...
    '/home/tcpan/PhD/path/Data/adios/cci-old-clus', ...
    '/home/tcpan/PhD/path/Data/adios/keeneland-tcga-small10-grouped', ...
    '/home/tcpan/PhD/path/Data/adios/keeneland-tcga-small9-grouped-debug', ...
    '/home/tcpan/PhD/path/Data/adios/keeneland-tcga-small8-grouped', ...
    '/home/tcpan/PhD/path/Data/adios/keeneland-tcga-small6-TP-barrier', ...
    '/home/tcpan/PhD/path/Data/adios/keeneland-tcga-small7-TP-gapped-barrier', ...
    '/home/tcpan/PhD/path/Data/adios/keeneland-tcga-small4-TP', ...
    '/home/tcpan/PhD/path/Data/adios/keeneland-tcga-small5-TP-gapped-nobarrier', ...
    '/home/tcpan/PhD/path/Data/adios/keeneland-tcga-small1',...
    '/home/tcpan/PhD/path/Data/adios/keeneland-tcga-small2',...
    '/home/tcpan/PhD/path/Data/adios/keeneland-tcga-small3-throughput',...
    '/home/tcpan/PhD/path/Data/adios/keeneland-tcga1',...
    '/home/tcpan/PhD/path/Data/adios/keeneland-tcga2',...
    '/home/tcpan/PhD/path/Data/adios/keeneland-tcga3-throughput',...
    '/home/tcpan/PhD/path/Data/adios/keeneland-tcga4-throughput-smallAMR'...
    };
    
selections = [1];

timeIntervals = [...
    10000; ...
    10000; ...
    repmat([100000], 5, 1); ...
    1000; ...
    repmat([10000], 11, 1);...
    repmat([100000], 4, 1)...
    ];
procWidth = 1;

proc_types = [...
    repmat(['*'],2, 1);
    
    repmat(['w'], 21, 1)...
    ];

    
for j = 1 : length(selections)
    close all;
    id = selections(j);
    
    dirname = dirs{id};
    timeInterval = timeIntervals(id);

    proc_type = proc_types(id);
    
    fid = fopen([dirname, '.TP.csv'], 'w');

    files = dir(fullfile(dirname, '*.csv'));
    

    for i = 1:length(files)
        clear proc_events;
        csvfile = files(i).name;
                
        [~, n, ~] = fileparts(csvfile);
        prefix = fullfile(dirname, n)
        
        proc_events = readComputeAndIOTimingOneLineFormat(fullfile(dirname, csvfile), proc_type);
        [~, ~] = plotProcEvents(proc_events, procWidth, timeInterval, prefix, allEventTypes, colorMap);
        close all;
        fprintf(fid, '%s\n', prefix);
        summarize(proc_events, timeInterval, fid, proc_type, allEventTypes, allTypeNames);
    end
    
    
    fclose(fid);
end










