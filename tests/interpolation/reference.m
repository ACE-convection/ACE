function reference(directory)
% Independent MATLAB interp1 references; hold endpoint values outside the grid.
files=dir(fullfile(directory,'*.input'));
for i=1:numel(files)
    stem=files(i).name(1:end-6);
    fid=fopen(fullfile(directory,files(i).name),'r','ieee-le');
    cleanup=onCleanup(@() fclose(fid));
    sizes=fread(fid,2,'int32'); n=sizes(1); nq=sizes(2);
    x=fread(fid,n,'double'); y=fread(fid,n,'double'); xq=fread(fid,nq,'double');
    clear cleanup
    for method={'pchip','makima'}
        extrapolated=interp1(x,y,xq,method{1},'extrap');
        held=extrapolated; held(xq<x(1))=y(1); held(xq>x(end))=y(end);
        for policy={'extrap','endpoint'}
            if strcmp(policy{1},'extrap'), value=extrapolated; else, value=held; end
            fid=fopen(fullfile(directory,[stem '.matlab_' method{1} '_' policy{1}]),'w','ieee-le');
            fwrite(fid,value,'double'); fclose(fid);
        end
    end
end
fid=fopen(fullfile(directory,'matlab_version.txt'),'w');fprintf(fid,'%s\n',version);fclose(fid);
fprintf('MATLAB interp1 reference: %d cases, pchip/makima, extrapolate/hold endpoints\n',numel(files));
end
