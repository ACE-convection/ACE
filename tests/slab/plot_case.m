function plot_case(work,job_name)
% Export completed native/physics-off slab MF comparisons as PNG/PDF.
job=fullfile(work,job_name);
cfg=jsondecode(fileread(fullfile(work,'configuration.json')));
case_cfg=jsondecode(fileread(fullfile(job,'configuration.json')));
report=jsondecode(fileread(fullfile(job,'results.json')));
width=ncread(cfg.input,'ace_width'); z=ncread(cfg.input,'zm')/1000;
nc=numel(width); nz=numel(z); nt=report.saved_states;
assert(nt>=2 && report.duration_seconds==case_cfg.duration_seconds);
assert(all(abs(width-width(1))<=64*eps(max(width))), 'This plot requires equal-width ACEs');
m=read_mf(fullfile(job,'matlab_states.bin'),nc,nz,nt,false);
f=read_mf(fullfile(job,'fortran_states.bin'),nc,nz,nt,true);
assert(all(isfinite(m(:))) && all(isfinite(f(:))));
time=linspace(0,report.duration_seconds/60,nt);
position=(cumsum(width)-width/2)/1000;
keep=z<=20; z=z(keep); m=m(keep,:,:); f=f(keep,:,:); difference=f-m;
out=fullfile(job,'figures');assert(~isfolder(out),'Use a fresh figure directory');mkdir(out);
figure_handle=figure('Visible','off','Position',[100,100,1350,720],'Color','w');
cleanup=onCleanup(@() close(figure_handle));
layout=tiledlayout(figure_handle,2,3,'TileSpacing','compact','Padding','compact');
palette=interp1([-1,0,1],[0.15,0.30,0.70;1,1,1;0.70,0.15,0.20],linspace(-1,1,256));
titles={'MATLAB','Fortran','Fortran - MATLAB'};
for row=1:2
    if row==1
        values={reshape(m(:,1,:),numel(z),nt),reshape(f(:,1,:),numel(z),nt),reshape(difference(:,1,:),numel(z),nt)};
        x=time; xlabel_text='Time (min), ACE 1';
    else
        values={m(:,:,end),f(:,:,end),difference(:,:,end)};
        x=position; xlabel_text=sprintf('ACE center (km), t = %.1f min',time(end));
    end
    shared=max([abs(values{1}(:));abs(values{2}(:));eps]);
    error_scale=max([abs(values{3}(:));eps]);
    for column=1:3
        axes_handle=nexttile(layout);imagesc(axes_handle,x,z,values{column});
        axis(axes_handle,'xy');ylim(axes_handle,[0,20]);
        colormap(axes_handle,palette);
        scale=shared;if column==3,scale=error_scale;end
        caxis(axes_handle,[-scale,scale]);title(axes_handle,titles{column});
        xlabel(axes_handle,xlabel_text);ylabel(axes_handle,'Height (km)');
        colorbar_handle=colorbar(axes_handle);colorbar_handle.Label.String='MF (kg m^{-2} s^{-1})';
    end
end
title(layout,sprintf('%s profile %d | physics=%s | dt=%g s | DHh=%d, DHv=%d | scientific review pending', ...
    ncreadatt(cfg.input,'/','case_name'),ncreadatt(cfg.input,'/','profile_index'), ...
    case_cfg.physics,case_cfg.dt,case_cfg.h,case_cfg.v),'Interpreter','none');
exportgraphics(figure_handle,fullfile(out,'mf_comparison.png'),'Resolution',200);
exportgraphics(figure_handle,fullfile(out,'mf_comparison.pdf'),'ContentType','vector');
scope=struct('duration_seconds',report.duration_seconds,'saved_states',nt,'height_range_km',[0,20], ...
    'field','MF','difference','Fortran minus MATLAB','input_sha256',cfg.input_sha256, ...
    'state_hashes',report.sha256,'scientific_acceptance','pending');
fid=fopen(fullfile(out,'scope.json'),'w');assert(fid>0);fprintf(fid,'%s\n',jsonencode(scope));fclose(fid);
fprintf('Saved MF comparison to %s\n',out);
end

function result=read_mf(file,nc,nz,nt,fortran)
fid=fopen(file,'r','ieee-le');assert(fid>0);cleanup=onCleanup(@() fclose(fid));
n=nc;
if fortran
    header=fread(fid,3,'int32');assert(isequal(header,[nc;nz;3]));n=nc+1;
end
result=zeros(nz,nc,nt);
for k=1:nt
    state=fread(fid,n*nz*3,'double');assert(numel(state)==n*nz*3,'Incomplete state stream');
    state=reshape(state,n,nz,3);result(:,:,k)=state(1:nc,:,1)';
    if fortran && k==1,assert(numel(fread(fid,nz,'double'))==nz);end
end
assert(isempty(fread(fid,1,'uint8')),'Unexpected trailing state data');
end
