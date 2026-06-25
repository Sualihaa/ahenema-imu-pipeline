function timeSync = get_sync_time_vector(SyncTable, fs_sync)

names = SyncTable.Properties.VariableNames;

possibleNames = {'time','Time','time_s','Time_s','TimeSeconds','timestamp_s'};

timeSync = [];

for i = 1:length(possibleNames)
    if ismember(possibleNames{i}, names)
        timeSync = SyncTable.(possibleNames{i});
        timeSync = timeSync(:);
        return;
    end
end

% If no time column exists, build one from sampling frequency
n = height(SyncTable);
timeSync = (0:n-1)' ./ fs_sync;

end