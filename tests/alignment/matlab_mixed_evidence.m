function matlab_mixed_evidence(root,work)
% Diagnose saved cloud-level trajectories; do not repeat time integration.
addpath(fullfile(root,'matlab/active/util_thermodynamics'));
p=ncread(fullfile(root,'data/input/manus208.nc'),'p_zc');
levels=91:110; T0=273.1636783445389;
for label={'single_mixed_precip','multi_mixed_precip'}
  name=label{1};
  data=load(fullfile(work,['matlab_' name '_history.mat']),'history','times');
  assert(isequal(size(data.history),[801,5,8,31]));
  assert(isequal(data.times,0:4:120));
  if startsWith(name,'single'), pulse=1; else, pulse=8; end
  loss=squeeze(data.history(:,5,:,:));
  assert(all(isfinite(loss),'all') && all(loss(:,:,1)==0,'all'));
  increments=diff(loss,1,3); assert(all(increments>=0,'all'));
  updates=squeeze(any(any(increments>0,1),2)); assert(all(updates));
  fid=fopen(fullfile(work,['fortran_' name '.bin']),'r','ieee-le');
  first=permute(reshape(fread(fid,8*801*3,'double'),[8,801,3]),[2,3,1]);
  header=14*8*801+801+16; fseek(fid,8*header,'bof');
  tail=permute(reshape(fread(fid,30*8*801*3,'double'),[8,801,3,30]),[2,3,1,4]);
  fclose(fid); fh=cat(4,first,tail);
  inputs=zeros(1240,3); output=zeros(1240,4); margin=zeros(20,1);
  for source=1:2
    if source==1, h=data.history; else, h=fh; end
    for t=1:31
      for j=1:20
        k=levels(j); i=(source-1)*620+(t-1)*20+j;
        inputs(i,:)=[h(k,1,pulse,t),h(k,2,pulse,t),p(k)];
        [output(i,1),output(i,2),output(i,3),output(i,4)]=...
          inv_T_from_theta_e(inputs(i,1),inputs(i,2),inputs(i,3));
        if source==1 && t==1
          total=inputs(i,2); theta=inputs(i,1); pressure=p(k);
          RE=(1-total)*287.04; CPL=1005.7+3184.3*total; chi=RE/CPL;
          G0=theta*(pressure*RE/1e5)^chi;
          qs=eval_qs(T0,pressure,total); qsi=eval_qsi(T0,pressure,total);
          GT0=T0*(RE+461.5*qs)^chi*exp(qs*9155.566660243245/CPL);
          HT0=T0*(RE+461.5*qsi)^chi*exp((qsi*2.500968266240670e6-0.3337e6*(total-qsi))/CPL/T0);
          margin(j)=(G0-min(GT0,HT0))/abs(GT0-HT0);
        end
      end
    end
  end
  assert(all(margin>0.25 & margin<0.75));
  fid=fopen(fullfile(work,[name '_phase_input.bin']),'w','ieee-le');
  fwrite(fid,1240,'int32'); fwrite(fid,inputs,'double'); fclose(fid);
  % Paths are quoted for the external probe; reject embedded quote characters.
  assert(~contains(work,'"'));
  command=sprintf('"%s" "%s" "%s"',fullfile(work,'phase_history.exe'),...
    fullfile(work,[name '_phase_input.bin']),fullfile(work,[name '_phase_output.bin']));
  [status,message]=system(command); assert(status==0,message);
  fid=fopen(fullfile(work,[name '_phase_output.bin']),'r','ieee-le');
  fortran=fread(fid,[1240,4],'double'); fclose(fid);
  assert(isequal(size(fortran),[1240,4]));
  assert(isreal(output) && all(isfinite(output),'all') && all(isfinite(fortran),'all'));
  relative=abs(output-fortran)./abs(output); relative(output==0)=NaN;
  ownM=reshape(output(1:620,:),[20,31,4]);
  ownF=reshape(fortran(621:1240,:),[20,31,4]);
  initial_fraction=ownM(:,1,4)./(ownM(:,1,3)+ownM(:,1,4));
  assert(all(initial_fraction>0.25 & initial_fraction<0.75));
  selected_loss=loss(levels,pulse,end);
  evidence=struct('levels',[91,110],'pulse_ace',pulse,'times_seconds',data.times,...
    'initial_endpoint_fractional_margin_min',min(margin),...
    'initial_endpoint_fractional_margin_max',max(margin),...
    'initial_ice_fraction_min',min(initial_fraction),...
    'initial_ice_fraction_max',max(initial_fraction),...
    'active_precipitation_update_count',sum(updates),'precipitation_accumulation_monotonic',true,...
    'final_precipitation_qt_loss_min_kgkg',min(selected_loss),...
    'final_precipitation_qt_loss_max_kgkg',max(selected_loss),...
    'matlab_mixed_count',sum(ownM(:,:,3)>0 & ownM(:,:,4)>0,1),...
    'fortran_mixed_count',sum(ownF(:,:,3)>0 & ownF(:,:,4)>0,1),...
    'trajectory_phase_mask_mismatches',sum(any((ownM(:,:,3:4)>0)~=(ownF(:,:,3:4)>0),3),1),...
    'common_input_count',1240,...
    'common_input_phase_mask_mismatches',sum(any((output(:,3:4)>0)~=(fortran(:,3:4)>0),2)),...
    'common_input_max_abs_T_qv_ql_qi',max(abs(output-fortran),[],1),...
    'common_input_max_rel_nonzero_T_qv_ql_qi',max(relative,[],1,'omitnan'),...
    'water_closure_max_matlab',max(abs(sum(output(:,2:4),2)-inputs(:,2))),...
    'water_closure_max_fortran',max(abs(sum(fortran(:,2:4),2)-inputs(:,2))));
  fid=fopen(fullfile(work,[name '_mixed_evidence.json']),'w');
  fprintf(fid,'%s\n',jsonencode(evidence)); fclose(fid);
  disp(name); disp(evidence);
end
end
