function T = read_opensim_mot(motFile)

fid = fopen(motFile, 'r');

if fid == -1
    error('Could not open MOT file: %s', motFile);
end

headerLine = '';

while true

    line = fgetl(fid);

    if ~ischar(line)
        break;
    end

    if startsWith(strtrim(line), 'time')
        headerLine = line;
        break;
    end
end

if isempty(headerLine)
    fclose(fid);
    error('Could not find column header line starting with time.');
end

colNames = strsplit(strtrim(headerLine), '\t');

data = textscan(fid, repmat('%f', 1, length(colNames)), ...
    'Delimiter', '\t', ...
    'CollectOutput', true);

fclose(fid);

A = data{1};

T = array2table(A, 'VariableNames', matlab.lang.makeValidName(colNames));

end