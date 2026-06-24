function time = read_sto_time_vector(stoFile)

fid = fopen(stoFile, 'r');

if fid == -1
    error('Could not open STO file: %s', stoFile);
end

foundHeader = false;

while true
    line = fgetl(fid);

    if ~ischar(line)
        break;
    end

    if startsWith(strtrim(line), 'time')
        foundHeader = true;
        break;
    end
end

if ~foundHeader
    fclose(fid);
    error('Could not find time header in STO file.');
end

data = textscan(fid, '%f%*[^\n]', 'Delimiter', '\t');

fclose(fid);

time = data{1};

if isempty(time)
    error('No time data found in STO file.');
end

end