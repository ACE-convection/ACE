function plot_gravity_wave(work)
% PNG-only equivalents of the earlier KHN26 multiACE MF response plots.
cfg=jsondecode(fileread(fullfile(work,'configuration.json')));
job=fullfile(work,'native_8h');r=jsondecode(fileread(fullfile(job,'results.json')));
width=ncread(cfg.input,'ace_width')/1000;z=ncread(cfg.input,'zm')/1000;
nc=numel(width);nz=numel(z);nt=r.saved_states;
assert(r.duration_seconds==28800 && nt==481);
assert(all(abs(width-width(1))<1e-12),'imagesc requires equal widths');
m=read_mf(fullfile(job,'matlab_states.bin'),nc,nz,nt,false);
f=read_mf(fullfile(job,'fortran_states.bin'),nc,nz,nt,true);
time=(0:nt-1)/60;centers=cumsum(width)-width/2;
out=fullfile(job,'gravity_wave_png');assert(~isfolder(out));mkdir(out);
palette=interp1([-1,0,1],[.15,.30,.70;1,1,1;.70,.15,.20],linspace(-1,1,256));
headings={'MATLAB','Fortran','Fortran minus MATLAB'};
fig=figure('Visible','off','Color','w','Position',[100,100,1500,1100]);
layout=tiledlayout(fig,3,3,'TileSpacing','compact','Padding','compact');
levels=zeros(1,3);
for row=1:3
    targets=[1,5,10];[~,k]=min(abs(z-targets(row)));levels(row)=z(k);
    a=reshape(m(k,:,:),nc,nt);b=reshape(f(k,:,:),nc,nt);values={a,b,b-a};
    shared=max([abs(a(:));abs(b(:));eps]);
    for col=1:3
        ax=nexttile(layout);imagesc(ax,time,centers,values{col});axis(ax,'xy');
        xlim(ax,[0,8]);ylim(ax,[0,sum(width)]);colormap(ax,palette);
        bound=shared;if col==3,bound=max([abs(values{col}(:));eps]);end
        caxis(ax,[-bound,bound]);title(ax,sprintf('%s / z=%g km',headings{col},z(k)));
        xlabel(ax,'Time (hours)');ylabel(ax,'Distance from left boundary (km)');
        cb=colorbar(ax);cb.Label.String='MF (kg m^{-2} s^{-1})';
    end
end
title(layout,'ACE v0.21.87 | GOAmazon 314 | 88 ACEs | native precipitation | 8 hours');
exportgraphics(fig,fullfile(out,'spatial_mf.png'),'Resolution',180);close(fig);
selected=[1,2,10,44,88];keep=z<=20;
fig=figure('Visible','off','Color','w','Position',[100,100,1500,1450]);
layout=tiledlayout(fig,5,3,'TileSpacing','compact','Padding','compact');
for row=1:numel(selected)
    ace=selected(row);a=reshape(m(keep,ace,:),sum(keep),nt);b=reshape(f(keep,ace,:),sum(keep),nt);
    values={a,b,b-a};shared=max([abs(a(:));abs(b(:));eps]);
    for col=1:3
        ax=nexttile(layout);imagesc(ax,time,z(keep),values{col});axis(ax,'xy');
        xlim(ax,[0,8]);ylim(ax,[0,20]);colormap(ax,palette);
        bound=shared;if col==3,bound=max([abs(values{col}(:));eps]);end
        caxis(ax,[-bound,bound]);title(ax,sprintf('%s / ACE %d / x=%g km',headings{col},ace,centers(ace)));
        xlabel(ax,'Time (hours)');ylabel(ax,'Height (km)');
        cb=colorbar(ax);cb.Label.String='MF (kg m^{-2} s^{-1})';
    end
end
title(layout,'ACE v0.21.87 | selected ACE mass-flux response | native precipitation');
exportgraphics(fig,fullfile(out,'selected_aces.png'),'Resolution',180);close(fig);
fig=figure('Visible','off','Color','w','Position',[100,100,1600,1700]);
layout=tiledlayout(fig,8,2,'TileSpacing','compact','Padding','compact');
minutes=20:20:160;
for row=1:numel(minutes)
    values={m(:,:,minutes(row)+1),f(:,:,minutes(row)+1)};
    for col=1:2
        ax=nexttile(layout);imagesc(ax,1:nc,z,values{col});axis(ax,'xy');
        xlim(ax,[.5,nc+.5]);ylim(ax,[0,20]);colormap(ax,palette);caxis(ax,[-1,1]);pbaspect(ax,[5,1,1]);
        title(ax,sprintf('%s / %d min',headings{col},minutes(row)));ylabel(ax,'Height (km)');
        if row==8,xlabel(ax,'ACE column');else,set(ax,'XTickLabel',[]);end
    end
end
cb=colorbar(ax,'southoutside');cb.Layout.Tile='south';cb.Label.String='MF (kg m^{-2} s^{-1})';
title(layout,'ACE v0.21.87 | 20-minute MF snapshots | shared color limits [-1, 1]');
exportgraphics(fig,fullfile(out,'mf_20min_snapshots.png'),'Resolution',180);close(fig);
scope=struct('duration_seconds',r.duration_seconds,'saved_states',nt,'selected_ACE_one_based',selected, ...
    'selected_heights_km',levels,'snapshot_minutes',minutes,'snapshot_color_limits',[-1,1], ...
    'reference_scripts',{{'tests/khn26/plot_multi.py','tests/khn26/plot_multi_snapshots.py'}}, ...
    'state_hashes',r.sha256,'scope','Descriptive MF response; nonlocal pressure and mean projection can cause immediate remote response. Physical wave interpretation remains pending.');
fid=fopen(fullfile(out,'scope.json'),'w');fprintf(fid,'%s\n',jsonencode(scope));fclose(fid);
fprintf('Saved PNGs to %s\n',out);
end

function result=read_mf(file,nc,nz,nt,fortran)
fid=fopen(file,'r','ieee-le');assert(fid>0);cleanup=onCleanup(@() fclose(fid));n=nc;
if fortran
    header=fread(fid,3,'int32');assert(isequal(header,[nc;nz;3]));n=nc+1;
end
result=zeros(nz,nc,nt);
for k=1:nt
    state=fread(fid,n*nz*3,'double');assert(numel(state)==n*nz*3);
    state=reshape(state,n,nz,3);result(:,:,k)=state(1:nc,:,1)';
    if fortran && k==1,assert(numel(fread(fid,nz,'double'))==nz);end
end
assert(isempty(fread(fid,1,'uint8')));assert(all(isfinite(result(:))));
end
